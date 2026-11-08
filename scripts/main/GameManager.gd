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

var treasury: Dictionary = {"gold": 0, "gems": 0}
var stash: Dictionary = {"gold": 0, "gems": 0}      # dragon's stolen loot
var food: int = 0
var scales_level: int = 1
var fire_power_level: int = 1
var soldier_count: int = 0
var king_spawned: bool = false
var run_finished: bool = false
var run_timer: float = 0.0

@onready var dragon: CharacterBody2D = $World/Dragon
@onready var camera: Camera2D = $Camera
@onready var world_manager: Node2D = $World/WorldManager
@onready var hud: Control = $HUD

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

## Dragon flame upgrade — paid from the dragon stash.
func upgrade_fire() -> bool:
	var ok := _pay_stash(fire_upgrade_cost())
	if ok:
		fire_power_level += 1
		upgrade_purchased.emit("fire", fire_power_level)
	return ok

## Dragon armor (scales) upgrade — paid from the dragon stash.
func upgrade_scales() -> bool:
	var ok := _pay_stash(scales_upgrade_cost())
	if ok:
		scales_level += 1
		upgrade_purchased.emit("scales", scales_level)
	return ok

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

func scales_upgrade_cost() -> int:
	return scales_cost_base * scales_level

func fire_upgrade_cost() -> int:
	return fire_cost_base * fire_power_level

# --- escalation ------------------------------------------------------------

func increment_soldier_count() -> void:
	soldier_count += 1

func start_boss_battle(king) -> void:
	king_spawned = true
	boss_battle_started.emit(king)

func notify_king_defeated() -> void:
	if run_finished:
		return
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
	if carry_total > 0 and hud is GameHUD:
		(hud as GameHUD).show_message(
			"Carrying %d loot — haul it to the lair!" % carry_total)


## WorldManager raises the alarm: rally/attack messages surface on the HUD.
func _on_swarm_state_changed(new_state: WorldManager.SwarmState) -> void:	if hud is GameHUD:
		match new_state:
			WorldManager.SwarmState.RALLY:
				(hud as GameHUD).show_message("The soldiers mass at the city gate!")
			WorldManager.SwarmState.ATTACK:
				(hud as GameHUD).show_message("The swarm charges! Defend yourself!")
