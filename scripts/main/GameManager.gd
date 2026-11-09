extends Node2D

class_name GameManager

## Central state hub — single source of truth (docs/decisions/2026-11-08-behavior-system.md):
##   town treasury (gold/gems — filled by miners), town food (filled by farmers),
##   dragon stash (gold/gems — stolen), progression levels (scales/fire),
##   escalation counters, victory state. Nodes read/report; nothing else
##   duplicates these numbers. HUD binds to the *_changed signals.

signal gold_changed(amount: int)
signal treasury_changed(res_type: String, amount: int)
signal stash_changed(res_type: String, amount: int)
signal food_changed(amount: int)
signal upgrade_purchased(kind: String, level: int)
signal resource_delivered(npc_type: String, res_type: String, amount: int)
signal soldier_spawned(soldier)   # arg is a Soldier node (pre-class-load safety)
signal boss_battle_started(king)
signal king_defeated
signal victory_achieved(tally: Dictionary)

@export_group("Economy")
@export var starting_food: int = 10

@export_group("Progression")
@export var scales_cost_base: int = 50
@export var fire_cost_base: int = 75

## Wizard-shop price table (decision 2026-11-08-dragon-strikes-respawn-prices):
## {kind: {"gold": int, "gems": int}} — retuned ("too steep") with a HARD gem
## requirement on the flagship items. Gold part may be gem-topped 10:1.
## Wizard-shop prices (re-priced 2026-11-09, user: "lower prices for all
## upgrades"; the claw-strike upgrade 'brute' explicitly at 8g so the claw
## attack improves early and often).
const WIZARD_PRICES := {
	"flame_1": {"gold": 10, "gems": 0},
	"flame_2": {"gold": 20, "gems": 1},
	"shield": {"gold": 8, "gems": 0},
	"speed": {"gold": 12, "gems": 0},
	"range": {"gold": 15, "gems": 1},
	"brute": {"gold": 8, "gems": 0},
}

# --- TTRPG story popups (2026-11-09) -------------------------------------------

## The story overlay system: six events open a PAUSED popup (field burn,
## miner burn, King emerge, King defeat, wizard emerge, first pig/cow).
## Each story shows ONCE per run; answers land in ttrpg_choices — the
## "progression policy" ledger every story-answer joins.
const STORY_SCENE := preload("res://scenes/ui/StoryPopup.tscn")
var story_popup: CanvasLayer
var story_open: bool = false
var story_shown: Dictionary = {}        # kind → true (once per run)
var story_queue: Array[String] = []     # told-while-paused stories wait here
var ttrpg_choices: Dictionary = {}      # kind → chosen answer index
signal story_choice_made(kind: String, choice_index: int)

## Fire-and-forget from any gameplay node (Field.burn, BaseNPC.catch_fire,
## WorldManager king/wizard paths, Dragon meals). While a popup or any
## pause-menu is up the story waits in the queue instead.
func notify_story(kind: String) -> void:
	if story_shown.get(kind, false):
		return
	story_shown[kind] = true
	if story_open or get_tree().paused:
		story_queue.append(kind)
		return
	_open_story_now(kind)

## Open the shared popup for one kind and pause the world beneath it.
func _open_story_now(kind: String) -> void:
	story_open = true
	if story_popup == null:
		story_popup = STORY_SCENE.instantiate()
		story_popup.process_mode = Node.PROCESS_MODE_ALWAYS
		story_popup.story_close_requested.connect(_on_story_closed)
		story_popup.story_choice_made.connect(_on_story_choice)
		add_child(story_popup)
	story_popup.call("open", kind)
	get_tree().paused = true

## The chosen answer joins the run's progression policy.
func _on_story_choice(kind: String, choice_index: int) -> void:
	ttrpg_choices[kind] = choice_index
	story_choice_made.emit(kind, choice_index)
	print("TTRPG — '%s' answered: choice %d" % [kind, choice_index + 1])

## Story resolution: close, unpause, then serve anything queued behind it.
func _on_story_closed() -> void:
	story_open = false
	get_tree().paused = false
	_drain_story_queue()

func _drain_story_queue() -> void:
	if story_queue.is_empty() or story_open:
		return
	_open_story_now(story_queue.pop_front())

var wizard_menu: CanvasLayer

signal wizard_menu_opened
signal wizard_menu_closed

var treasury: Dictionary = {"gold": 0, "gems": 0}
var stash: Dictionary = {"gold": 0, "gems": 0}      # dragon's stolen loot
var food: int = 0
var scales_level: int = 1
var fire_power_level: int = 1
var soldier_count: int = 0
var king_spawned: bool = false
var run_finished: bool = false
var run_timer: float = 0.0

## Tower provocation telemetry (2026-11-09 wizard emergence): every tower
## door entry counts, every SUCCESSFUL upgrade purchase counts. WorldManager
## spawns the wizard when (purchases >= 3 AND visits > 3) OR stash > 30g.
var tower_visits: int = 0
var upgrade_purchases: int = 0

@onready var dragon: CharacterBody2D = $World/Dragon
@onready var camera: Camera2D = $Camera
@onready var world_manager: Node2D = $World/WorldManager
@onready var hud: Control = $HUDLayer/HUD

func _ready() -> void:
	food = starting_food
	update_camera_position()
	if world_manager and hud and world_manager.has_signal("entity_spawned"):
		world_manager.entity_spawned.connect(hud.update_minimap_entity)
		world_manager.entity_spawned.connect(_on_entity_spawned)
	if hud is GameHUD:
		(hud as GameHUD).bind_manager(self)
	else:
		push_warning("HUD missing or not a GameHUD")
	# Loot-haul loop messaging: pickups tell the player where to bank them.
	if dragon != null and dragon.has_signal("loot_carried"):
		dragon.loot_carried.connect(_on_dragon_loot_carried)
	emit_signal("gold_changed", treasury["gold"])
	emit_signal("food_changed", food)

func _process(delta: float) -> void:
	update_camera_position()
	if not run_finished:
		run_timer += delta
	if hud and dragon:
		hud.update_minimap_dragon(dragon.global_position)

# --- pools -----------------------------------------------------------------

## Miners' deliveries fill the town treasury.
func deposit_treasury(res_type: String, amount: int) -> void:
	if not treasury.has(res_type):
		push_warning("Unknown treasury resource: %s" % res_type)
		return
	treasury[res_type] += amount
	treasury_changed.emit(res_type, treasury[res_type])

## Dragon stolen loot, in stash (separate pool; the two never mix).
func add_stolen(res_type: String, amount: int) -> void:
	if not stash.has(res_type):
		return
	stash[res_type] += amount
	stash_changed.emit(res_type, stash[res_type])

## Farmers' deliveries fill the town food pool (support-chain input).
func add_food(amount: int) -> void:
	food += amount
	food_changed.emit(food)

func consume_food(amount: int = 1) -> bool:
	if food >= amount:
		food -= amount
		food_changed.emit(food)
		return true
	return false

# --- progression -----------------------------------------------------------

## Purchase paths retired: upgrades now happen ONLY at the wizard tower via
## purchase_upgrade (decision record 2026-11-08-manual-eat-wizard-menu).
## scales_level / fire_power_level stay as state for existing math.

# --- wizard shop (the tower site; replaces the old U-key panel) ---------------

## Pay a cost from the stash (gold first, gems worth 10x gold as top-up).
func _pay_stash(cost: int) -> bool:
	if run_finished or cost <= 0:
		return false
	if stash["gold"] + stash["gems"] * 10 < cost:
		return false
	var need := cost
	var from_gold := mini(need, stash["gold"])
	need -= from_gold
	stash["gold"] -= from_gold
	if need > 0:
		stash["gems"] -= ceili(float(need) / 10.0)
	stash_changed.emit("gold", stash["gold"])
	stash_changed.emit("gems", stash["gems"])
	return true

# --- wizard shop (the tower site; replaces the old U-key panel) ---------------

const WIZARD_MENU_SCENE := preload("res://scenes/ui/WizardMenu.tscn")

## Stash-value readout (gold-equivalent; gems worth 10x — display only).
func stash_value() -> int:
	return stash["gold"] + stash["gems"] * 10

## Shared affordability rule (decision 2026-11-08-dragon-strikes-respawn-
## prices): the gem part is a HARD requirement (the currencies have distinct
## duties); the gold part may be topped up with SPARE gems at 10:1 — the
## same rule the stash economy already applies.
func can_afford_wizard(kind: String) -> bool:
	var cost: Dictionary = WIZARD_PRICES[kind]
	var gem_need := int(cost["gems"])
	if int(stash["gems"]) < gem_need:
		return false
	var spare_gems := int(stash["gems"]) - gem_need
	return int(stash["gold"]) + spare_gems * 10 >= int(cost["gold"])

## Pay a wizard cost {"gold", "gems"} — same rule as can_afford_wizard.
## A refused purchase never half-pays (gold-first, gems flatten the rest).
func _pay_wizard_cost(kind: String) -> bool:
	if run_finished or not can_afford_wizard(kind):
		return false
	var cost: Dictionary = WIZARD_PRICES[kind]
	var gem_need := int(cost["gems"])
	stash["gems"] -= gem_need
	var gold_need := int(cost["gold"])
	var from_gold := mini(gold_need, int(stash["gold"]))
	stash["gold"] -= from_gold
	var leftover := gold_need - from_gold
	if leftover > 0:
		stash["gems"] -= ceili(float(leftover) / 10.0)
	stash_changed.emit("gold", stash["gold"])
	stash_changed.emit("gems", stash["gems"])
	return true

## Buy one wizard option: pays, then applies the effect to the dragon.
## Returns false when unaffordable — or, for the shield, while any shield
## remains (non-stackable pool, decision record).
func purchase_upgrade(kind: String) -> bool:
	var dragon_ref := dragon as Node
	if dragon_ref == null or not is_instance_valid(dragon_ref):
		return false
	if kind == "shield" and int(dragon_ref.get("shield_points")) > 0:
		return false
	# Brute Force is capped — refuse BEFORE taking payment (decision record).
	if kind == "brute" and not bool(dragon_ref.call("can_add_strike")):
		return false
	if not _pay_wizard_cost(kind):
		return false
	match kind:
		"flame_1":
			dragon_ref.call("increase_flame_capacity", 1)
		"flame_2":
			dragon_ref.call("increase_flame_capacity", 2)
		"shield":
			dragon_ref.call("add_shield", 10)
		"speed":
			dragon_ref.call("activate_speed_boost")
			dragon_ref.call("unlock_fast_strike")
		"range":
			dragon_ref.call("increase_flame_range", 20.0)
		"brute":
			dragon_ref.call("add_strike_chance", 0.05)
	upgrade_purchased.emit(kind, int(WIZARD_PRICES[kind]["gold"]))
	upgrade_purchases += 1  # the wizard keeps count (emergence trigger)
	return true

## Open the wizard overlay (pause the live world beneath it). Lazily built so
## GameManager's scene tree stays lean; the instance survives for reopen.
func open_wizard_menu() -> void:
	if run_finished:
		return
	if wizard_menu == null:
		wizard_menu = WIZARD_MENU_SCENE.instantiate()
		wizard_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		wizard_menu.connect("menu_close_requested", _on_wizard_menu_close)
		add_child(wizard_menu)
	wizard_menu.call("open")
	get_tree().paused = true
	wizard_menu_opened.emit()

func _on_wizard_menu_close() -> void:
	get_tree().paused = false
	wizard_menu_closed.emit()
	_drain_story_queue()  # stories that arrived while shopping wait politely

# --- escalation ------------------------------------------------------------

func increment_soldier_count() -> void:
	soldier_count += 1

## Town spending (soldier purchases, 2026-11-09): pays out of the treasury
## pool — the same pool miner deliveries fill. Returns false when it
## can't afford it; callers loop to drain.
func spend_treasury(res_type: String, amount: int) -> bool:
	if not treasury.has(res_type) or treasury[res_type] < amount:
		return false
	treasury[res_type] -= amount
	treasury_changed.emit(res_type, treasury[res_type])
	return true

func start_boss_battle(king) -> void:
	king_spawned = true
	boss_battle_started.emit(king)

func notify_king_defeated() -> void:
	if run_finished:
		return
	notify_story("king_defeat")  # the FINAL fall gets its epic chapter
	run_finished = true
	king_defeated.emit()
	var tally := {
		"time_survived": run_timer,
		"gold_stolen": stash["gold"],
		"gems_stolen": stash["gems"],
		"treasury_left": treasury,
		"fire_level": fire_power_level,
		"scales_level": scales_level,
		"soldiers_seen": soldier_count,
	}
	victory_achieved.emit(tally)

# --- misc ------------------------------------------------------------------

func update_camera_position() -> void:
	if dragon:
		camera.position = dragon.global_position

func _on_entity_spawned(entity_type: String, position: Vector2) -> void:
	pass  # keep the hook for future minimap/gameplay expansions

## Dragon picked up more loot: nudge the player toward the lair.
func _on_dragon_loot_carried(carry_total: int) -> void:
	if hud is GameHUD:
		(hud as GameHUD).update_carried(carry_total)
		if carry_total > 0:
			(hud as GameHUD).show_message(
				"Carrying %d loot — haul it to the lair!" % carry_total)


## WorldManager raises the alarm: rally/attack messages surface on the HUD.
func _on_swarm_state_changed(new_state: WorldManager.SwarmState) -> void:	if hud is GameHUD:
		match new_state:
			WorldManager.SwarmState.RALLY:
				(hud as GameHUD).show_message("The soldiers mass at the city gate!")
			WorldManager.SwarmState.ATTACK:
				(hud as GameHUD).show_message("The swarm charges! Defend yourself!")
