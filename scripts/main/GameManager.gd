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
## requirement on the flagship items. Gold part may be gem-topped at
## GEM_GOLD_VALUE (2026-11-12, user: "1 gem = 2gp but you can't get gems for
## gold" — the only gem flow is goblin protection fees; the top-up exists so
## spare gems are not dead weight).
## Wizard-shop prices (re-priced 2026-11-09, user: "lower prices for all
## upgrades"; the claw-strike upgrade 'brute' explicitly at 8g so the claw
## attack improves early and often).
## 1 gem buys GEM_GOLD_VALUE gold when topping up a gold cost (never
## the reverse — gold cannot buy gems).
const GEM_GOLD_VALUE := 2
const WIZARD_PRICES := {
	"flame_1": {"gold": 10, "gems": 0},
	"flame_2": {"gold": 20, "gems": 1},
	"shield": {"gold": 8, "gems": 0},
	"speed": {"gold": 12, "gems": 0},
	"range": {"gold": 15, "gems": 1},
	"brute": {"gold": 8, "gems": 0},
	"rider_train": {"gold": 10, "gems": 0},
	# New (2026-11-11, user: "add a new item for longer flight time +3s").
	"flight": {"gold": 12, "gems": 0},
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
signal sacrifice_choice_made(choice_index: int)

## Death chapters (2026-11-09): the dragon's slayer names the tale —
## each take_damage caller passes a killer key; unknowns get the
## generic "hoard goes cold" chapter.
const DRAGON_DEATH_KINDS := {
	"soldier": "dragon_death_soldier",
	"archer": "dragon_death_archer",
	"king": "dragon_death_king",
	"wizard": "dragon_death_wizard",
	"dragon_slayer": "dragon_death_slayer",
}
var dragon_death_served: bool = false   # one death chapter per run
var _pending_death_reload: bool = false

## Called by Dragon.die() (after the death animation). Opens the
## killer-named chapter; the scene reloads when the chapter closes.
func notify_dragon_death(killer_key: String) -> void:
	if dragon_death_served:
		_run_scene_reload()   # chapter already told: end the run now
		return
	dragon_death_served = true
	_pending_death_reload = true
	_open_story_now(DRAGON_DEATH_KINDS.get(killer_key, "dragon_death"))

func _run_scene_reload() -> void:
	if get_tree() != null and get_tree().current_scene != null:
		get_tree().reload_current_scene()

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

## Peasant-burn story (2026-11-09): when a farmer catches fire, pick ONE of
## the five horror stories and open it. Once-per-run, so only the FIRST
## farmer fire triggers the story.
func notify_peasant_burn() -> void:
	if story_shown.get("peasant_burn", false):
		return
	story_shown["peasant_burn"] = true
	if story_popup == null:
		story_popup = STORY_SCENE.instantiate()
		story_popup.process_mode = Node.PROCESS_MODE_ALWAYS
		story_popup.story_close_requested.connect(_on_story_closed)
		story_popup.story_choice_made.connect(_on_story_choice)
		add_child(story_popup)
	var story_kind := "peasant_burn_%d" % (randi() % 5 + 1)
	_open_story_now(story_kind)

## Open the shared popup for one kind and pause the world beneath it.
func _open_story_now(kind: String, note: String = "") -> void:
	story_open = true
	print("GameManager: Opening story '%s'" % kind)
	if story_popup == null:
		print("GameManager: Creating new story_popup...")
		story_popup = STORY_SCENE.instantiate()
		story_popup.process_mode = Node.PROCESS_MODE_ALWAYS
		story_popup.story_close_requested.connect(_on_story_closed)
		story_popup.story_choice_made.connect(_on_story_choice)
		add_child(story_popup)
	print("GameManager: Calling story_popup.open()...")
	story_popup.call("open", kind, note)
	get_tree().paused = true

## Public entry for the sacrifice encounter (Sacrifice.gd): opens the popup
## through the ONE canonical creation path so every signal is connected
## (bug fix 2026-11-11 — Sacrifice.gd used to duplicate popup creation and
## skip the sacrifice_choice_made wiring when the popup already existed).
## Deliberately bypasses story_shown: the popup is once per SACRIFICE
## (Sacrifice._story_triggered), not once per run.
func open_sacrifice_story(kind: String) -> void:
	_open_story_now(kind)

## The chosen answer joins the run's progression policy.
func _on_story_choice(kind: String, choice_index: int) -> void:
	ttrpg_choices[kind] = choice_index
	story_choice_made.emit(kind, choice_index)
	print("TTRPG — '%s' answered: choice %d" % [kind, choice_index + 1])
	_apply_story_effects(kind, choice_index)
	# Sacrifice answers route through HERE (bug fix 2026-11-11): the old
	# Sacrifice.gd connected sacrifice_choice_made only when IT created the
	# popup — but the popup already exists (field_burn created it), so the
	# signal fired into the void and the rider option never unlocked.
	if kind.begins_with("sacrifice_"):
		_on_sacrifice_choice(kind, choice_index)
	elif kind.begins_with("intro_") or kind.begins_with("hag_"):
		_on_chapter_choice(kind, choice_index)
	elif kind.begins_with("prince_"):
		_on_prince_choice(kind, choice_index)
	elif kind.begins_with("adventurer_"):
		_on_adventurer_choice(kind, choice_index)
	elif kind.begins_with("wizard_girl_") or kind.begins_with("wizard_tome_") \
			or kind.begins_with("temple_"):
		_on_tome_choice(kind, choice_index)
	elif kind.begins_with("usurper_") or kind.begins_with("ending_"):
		_on_finale_choice(kind)
	# Goblin-encounter answers are handled by WorldManager (it connects
	# story_choice_made). The answer is tribal once-per-run, so GameManager
	# must NOT pick goblins — get_first_node_in_group would strand the rest.

## Sacrifice dialogues (2026-11-14). Every captive is a named personality
## (Sacrifice.gd picks one). EVERY board of the negotiation offers the same
## three answers (user 2026-11-14: "always have options to either eat or
## train or leave. The dialogue changes but not the options"):
##   0 Train as rider · 1 Eat! · 2 Leave
## Answering the board's own path again walks it on (approach → _2 → _3 →
## the deed); switching path makes the captive plead the OTHER case from
## its stage 2. Leave always ends it. The deed opens a closing report.
const SACRIFICE_PERSONALITIES: Array[String] = ["defiant", "courageous",
	"cunning", "devout", "brute", "thief", "renegade"]
const SACRIFICE_PATHS: Array[String] = ["lair", "eat"]   # by choice index
## The next dialogue to open once the current popup closes (stages chain
## through _on_story_closed so the popup's own close doesn't eat them),
## plus an optional closing paragraph appended to its text.
var _pending_story_kind: String = ""
var _pending_story_note: String = ""

func _on_sacrifice_choice(kind: String, choice_index: int) -> void:
	var parts := kind.trim_prefix("sacrifice_").split("_")
	var personality := parts[0]
	var path := parts[1] if parts.size() > 1 else ""   # "" = the approach
	if path == "outcome":
		return                    # the closing report: nothing more to do
	if choice_index >= SACRIFICE_PATHS.size():
		print("GameManager: the dragon leaves %s at the stake" % personality)
		_release_sacrifice()
		return
	var want := SACRIFICE_PATHS[choice_index]
	var stage := int(parts[2]) if path == want else 1
	if stage < 3:
		_pending_story_kind = "sacrifice_%s_%s_%d" % [personality, want, stage + 1]
		return
	# The deed, then a plain report of what just happened.
	var who := _sacrifice_name(personality)
	if want == "lair":
		train_sacrifice_as_rider(personality)
		_pending_story_note = ("%s waits in your lair — but the wizard is dead, and no one is left to train a rider." % who) \
			if wizard_dead else \
			("%s waits in your lair, among the gold. The wizard can train %s as your dragon rider: visit his tower and choose \"Train Dragon Rider\" (10g)." % [who, "him" if personality in ["brute", "thief", "renegade"] else "her"])
		_pending_story_kind = "sacrifice_%s_outcome_lair" % personality
	else:
		var gain := eat_sacrifice(personality)
		_pending_story_note = ("Your fire grows: +%d flame capacity." % gain) if gain > 0 \
			else "The meal sits heavy, but no new flame kindles."
		_pending_story_kind = "sacrifice_%s_outcome_eat" % personality
	_release_sacrifice()

## "Brannagh Thornwick — The Defiant" → "Brannagh Thornwick".
func _sacrifice_name(personality: String) -> String:
	var story: Dictionary = StoryPopup.STORIES.get("sacrifice_" + personality, {})
	return str(story.get("title", "The captive")).get_slice(" — ", 0)

## The pole is done: eaten, carried off to the lair, or spared.
func _release_sacrifice() -> void:
	for node: Node in get_tree().get_nodes_in_group("sacrifice"):
		var sacrifice := node as Sacrifice
		if sacrifice != null and sacrifice._story_triggered:
			sacrifice.remove_sacrifice()

## Train the sacrifice as a dragon rider (unlocks the 10g wizard option).
## The personality rides along: the defiant one shoots 1.5x faster.
var _trainable_personality: String = ""

func train_sacrifice_as_rider(personality: String = "") -> void:
	_trainable_sacrifice = true
	_trainable_personality = personality
	print("GameManager: %s waits in the lair to be trained as a rider" % personality)

## Eating: the defiant one burns hot (+2 flame capacity); every other
## captive has a 50% chance of +1.
func eat_sacrifice(personality: String = "") -> int:
	if dragon == null or not is_instance_valid(dragon):
		return 0
	var gain := 2 if personality == "defiant" else (1 if randf() < 0.5 else 0)
	if gain > 0:
		dragon.call("increase_flame_capacity", gain)
	print("GameManager: the dragon ate %s — +%d flame capacity" % [personality, gain])
	return gain

## Captive rotation (2026-11-14 fix: "circulate the characters so we don't
## end up showing the same sacrifice"): a shuffled deck of all seven. Every
## captive appears once before anyone repeats, and on a reshuffle the last
## three captives go to the BACK — at least three others between repeats.
const RECENT_GAP := 3
var _sacrifice_deck: Array[String] = []
var _recent_sacrifices: Array[String] = []

func next_sacrifice_personality() -> String:
	if _sacrifice_deck.is_empty():
		var fresh: Array[String] = []
		var recent: Array[String] = []
		for p in SACRIFICE_PERSONALITIES:
			if p in _recent_sacrifices:
				recent.append(p)
			else:
				fresh.append(p)
		fresh.shuffle()
		recent.shuffle()
		_sacrifice_deck = fresh + recent
	var next: String = _sacrifice_deck.pop_front()
	_recent_sacrifices.append(next)
	if _recent_sacrifices.size() > RECENT_GAP:
		_recent_sacrifices.pop_front()
	return next

# --- story-choice effects (2026-11-14) -------------------------------------------

## Run memory set by story effects ({"flag": "spared_child"}) — later story
## branches read it.
var story_flags: Dictionary = {}

## Look up the answer's effects in StoryPopup.STORIES and apply them
## (StoryEffects documents the keys); the dragon hears what changed.
func _apply_story_effects(kind: String, choice_index: int) -> void:
	var story: Dictionary = StoryPopup.STORIES.get(kind, {})
	var effects: Array = story.get("effects", [])
	if choice_index >= effects.size() or not effects[choice_index] is Dictionary:
		return
	var report := StoryEffects.apply(effects[choice_index], self)
	if report.is_empty():
		return
	print("GameManager: story effects — %s" % ", ".join(report))
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", " · ".join(report), 4.0)

## A story effect asked for a follow-up chapter: it opens as soon as the
## current one closes (same chaining as the sacrifice stages).
func queue_followup_story(kind: String) -> void:
	if _pending_story_kind == "":
		_pending_story_kind = kind
	else:
		story_queue.append(kind)

## Show epic story when rider is upgraded
func _on_rider_upgraded() -> void:
	print("GameManager: Rider upgraded, showing epic story")
	notify_story("rider_upgraded")

## Story resolution: close, unpause, then serve anything queued behind it.
## A dragon-death chapter ENDS the run instead: the chapter has played,
## so the world reloads (hub owns the teardown; Dragon.die only asks).
func _on_story_closed() -> void:
	if _pending_story_kind != "":
		# the next sacrifice dialogue: stay paused, reopen right away
		var next := _pending_story_kind
		var note := _pending_story_note
		_pending_story_kind = ""
		_pending_story_note = ""
		_open_story_now(next, note)
		return
	story_open = false
	get_tree().paused = false
	if _pending_death_reload:
		_pending_death_reload = false
		_run_scene_reload()
		return
	_drain_story_queue()

## Check if there's a trainable sacrifice (from story choice)
func has_trainable_sacrifice() -> bool:
	return _trainable_sacrifice

func _drain_story_queue() -> void:
	if story_queue.is_empty() or story_open:
		return
	_open_story_now(story_queue.pop_front())

var wizard_menu: CanvasLayer

signal wizard_menu_opened
signal wizard_menu_closed

var _trainable_sacrifice: bool = false

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
	# Rider chapters (bug fix 2026-11-11): connected HERE, once, instead of
	# at sacrifice-choice time — the upgrade must tell its story even if the
	# choice handler is ever bypassed.
	if dragon != null and dragon.has_signal("rider_upgraded") \
			and not dragon.rider_upgraded.is_connected(_on_rider_upgraded):
		dragon.rider_upgraded.connect(_on_rider_upgraded)
	emit_signal("gold_changed", treasury["gold"])
	emit_signal("food_changed", food)
	_build_color_grade()
	_start_intro.call_deferred()

# --- colour: the vignette + layered palettes (2026-11-15) -----------------------------

## The full-screen pass (assets/shaders/color_grade.gdshader, CanvasLayer 1,
## under the HUD on layer 2) now only frames the world in a vignette with
## faded, cold blacks; the colour itself is graded PER LAYER by the active
## palette (scripts/systems/Palettes.gd — user: "back layer, ie the ground
## should be grim dark. Houses should be more saturated towards a warm tone
## and characters should be bright"):
##   back   the ground (GroundTerrain) + the land: mountains, trees, lakes, glade
##   middle houses and works: city, tower, mines, pens, fields, the hag's hut,
##          the temple, the lair, the camp, a sacrifice pole
##   front  the dragon and every NPC
## Each layer root gets a layer_grade.gdshader material that its drawn
## descendants inherit (nodes with a shader of their own — the flame, the
## burning fire — keep it). C cycles the four palettes.
const COLOR_GRADE_SHADER := preload("res://assets/shaders/color_grade.gdshader")
const LAYER_GRADE_SHADER := preload("res://assets/shaders/layer_grade.gdshader")
const PALETTES_SCRIPT := preload("res://scripts/systems/Palettes.gd")
const BACK_SCENES: Array[String] = ["res://scenes/props/Mountain.tscn",
	"res://scenes/props/Lake.tscn", "res://scenes/props/Glade.tscn"]
## Trees: the back layer's palette but a gentler hand (user: "stem needs to
## be more brownish" — the full grim ramp washed bark to olive-grey).
const LAND_SCENES: Array[String] = ["res://scenes/props/Tree.tscn",
	"res://scenes/props/FirTree.tscn"]
const MIDDLE_SCENES: Array[String] = ["res://scenes/props/City.tscn",
	"res://scenes/objects/WizardTower.tscn", "res://scenes/objects/Mine.tscn",
	"res://scenes/props/PigPen.tscn", "res://scenes/props/CowPen.tscn",
	"res://scenes/systems/Field.tscn", "res://scenes/props/HagNest.tscn",
	"res://scenes/props/DragonTemple.tscn", "res://scenes/props/DragonLair.tscn",
	"res://scenes/props/InvaderCamp.tscn", "res://scenes/props/Sacrifice.tscn"]
var color_grade: CanvasLayer
var palette_index := 0
var _layer_mats := {}   # "back"/"middle"/"front" → ShaderMaterial

func _build_color_grade() -> void:
	color_grade = CanvasLayer.new()
	color_grade.name = "ColorGrade"
	color_grade.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = COLOR_GRADE_SHADER
	# vignette and faded blacks only — the palettes grade the colour
	mat.set_shader_parameter("exposure", 1.0)
	mat.set_shader_parameter("saturation", 1.0)
	mat.set_shader_parameter("fire_saturation", 1.0)
	mat.set_shader_parameter("contrast", 1.06)
	mat.set_shader_parameter("shadow_tint", Vector3(1.0, 1.0, 1.0))
	mat.set_shader_parameter("highlight_tint", Vector3(1.0, 1.0, 1.0))
	mat.set_shader_parameter("lift_color", Vector3(0.03, 0.035, 0.05))
	mat.set_shader_parameter("vignette", 0.5)
	rect.material = mat
	color_grade.add_child(rect)
	add_child(color_grade)
	for layer: String in ["back", "land", "middle", "front"]:
		var m := ShaderMaterial.new()
		m.shader = LAYER_GRADE_SHADER
		_layer_mats[layer] = m
	apply_palette(PALETTES_SCRIPT.DEFAULT)
	# grade everything that exists, and everything that arrives later
	if world_manager != null:
		for child: Node in world_manager.get_children():
			_grade_node(child)
		world_manager.child_entered_tree.connect(func(n: Node) -> void: _grade_node.call_deferred(n))
	if dragon != null:
		_grade_node(dragon)
		if dragon.has_signal("form_changed"):
			dragon.form_changed.connect(func(_on: bool) -> void: _grade_node.call_deferred(dragon))

func apply_palette(index: int) -> void:
	var list: Array = PALETTES_SCRIPT.PALETTES
	palette_index = posmod(index, list.size())
	var pal: Dictionary = list[palette_index]
	for layer: String in ["back", "land", "middle", "front"]:
		var src: Dictionary = pal.get(layer, {})
		if layer == "land" and src.is_empty():
			src = _land_from(pal["back"])
		var m: ShaderMaterial = _layer_mats[layer]
		m.set_shader_parameter("ramp_dark", src["dark"])
		m.set_shader_parameter("ramp_mid", src["mid"])
		m.set_shader_parameter("ramp_light", src["light"])
		m.set_shader_parameter("ramp_mix", src["mix"])
		m.set_shader_parameter("saturation", src["sat"])
		m.set_shader_parameter("exposure", src["exp"])
	var wm := world_manager as WorldManager
	if wm != null and wm.ground != null and wm.ground.has_method("set_grade"):
		wm.ground.call("set_grade", pal["back"])
	print("GameManager: palette %d — %s" % [palette_index + 1, pal["name"]])

## Trees' grade when a palette names none: the back ramp at under half the
## strength, more of the art's own colour (brown bark, green leaves) kept.
func _land_from(back: Dictionary) -> Dictionary:
	var land := back.duplicate()
	land["mix"] = float(back["mix"]) * 0.4
	land["sat"] = minf(float(back["sat"]) + 0.25, 1.05)
	land["exp"] = float(back["exp"]) + 0.16
	return land

func cycle_palette() -> void:
	apply_palette(palette_index + 1)
	var pal: Dictionary = PALETTES_SCRIPT.PALETTES[palette_index]
	_hud_message("Palette %d/%d: %s — %s" % [palette_index + 1,
		PALETTES_SCRIPT.PALETTES.size(), pal["name"], pal["blurb"]], 3.0)

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_C \
			and not story_open and not get_tree().paused:
		cycle_palette()
		get_viewport().set_input_as_handled()

## Which layer a world node belongs to ("" = leave it alone).
func _layer_of(n: Node) -> String:
	if n == dragon or n is BaseNPC:
		return "front"
	var path := n.scene_file_path
	if path in MIDDLE_SCENES:
		return "middle"
	if path in BACK_SCENES:
		return "back"
	if path in LAND_SCENES:
		return "land"
	return ""

func _grade_node(n: Node) -> void:
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var layer := _layer_of(n)
	if layer == "":
		return
	var item := n as CanvasItem
	if item == null:
		return
	item.material = _layer_mats[layer]
	_inherit_grade(item)

## Drawn descendants use the root's grade — except anything with a shader
## of its own (the dragon's flame, a burning body), which keeps it.
func _inherit_grade(item: CanvasItem) -> void:
	for child: Node in item.get_children():
		var ci := child as CanvasItem
		if ci == null:
			continue
		if ci.material != null and ci.material != item.material:
			continue
		ci.use_parent_material = true
		_inherit_grade(ci)

# --- the opening chapter (2026-11-14) -------------------------------------------

## True once the run is being PLAYED (Main is the running scene). Probe
## scenes embed Main as a child — they skip the intro and the hag quest so
## nothing pauses under them.
var story_mode := false
## The player let the old wizard die in the ruins: his tower stays sealed.
var wizard_dead := false

func _start_intro() -> void:
	if get_tree().current_scene != self:
		return
	story_mode = true
	_open_story_now("intro_awakening")

## Intro + hag-quest answers (routed from _on_story_choice).
func _on_chapter_choice(kind: String, choice_index: int) -> void:
	match kind:
		"intro_awakening":
			_pending_story_kind = "intro_memories"
		"intro_memories":
			_pending_story_kind = "intro_wizard"
		"intro_wizard":
			if choice_index == 0:
				_pending_story_kind = "intro_wizard_saved"
			else:
				_seal_wizard_tower()
				_pending_story_kind = "intro_wizard_dead"
		"hag_quest":
			if world_manager != null and world_manager.has_method("spawn_hag_nest"):
				world_manager.call("spawn_hag_nest")
		# --- the hag's house, she lives: tea with a sweet old lady ---
		"hag_tea":
			if choice_index == 0:
				_pending_story_kind = "hag_tea_change"
		"hag_tea_change":
			# the first change: the tea teaches the human shape
			var d := dragon as Dragon
			if d != null:
				d.can_shapeshift = true
				d.set_human_form(true)
			_pending_story_kind = "hag_tea_warning"
		"hag_tea_warning":
			story_flags["hag_tea_done"] = true
			_pending_story_kind = "hag_spared" if choice_index == 0 else "hag_unmasked"
		"hag_spared":
			var wm := world_manager as WorldManager
			if wm != null:
				if wm.hag_alive():
					wm.fen_hag.befriend()
				wm.force_wizard_turn()
			_hud_message("Ambrose Fairweather waits in his tower. Press T to wake the dragon.", 6.0)
		"hag_unmasked":
			# she was attacked during the visit: she knows the girl's face now
			story_flags["hag_attacked_at_house"] = true
			var wm := world_manager as WorldManager
			if wm != null and wm.hag_alive():
				wm.fen_hag.unmask()
			_hud_message("Mother Grisla attacks! Press T to wake the dragon.", 6.0)
		# --- the hag's house, she is dead: the book of Lorindel ---
		"hag_house_ruin", "hag_house_book":
			if choice_index == 0:
				_pending_story_kind = "hag_book_lorindel"
		"hag_book_lorindel":
			_pending_story_kind = "hag_book_lorindel_2"
		"hag_book_lorindel_2":
			story_flags["lorindel_read"] = true

# --- the hag's house + the human shape (2026-11-14) ------------------------------

## The dragon walked up to Mother Grisla's door (HagNest's trigger).
func notify_hag_house() -> void:
	if story_open or get_tree().paused or not story_mode:
		return
	var wm := world_manager as WorldManager
	if wm == null:
		return
	if wm.hag_alive():
		var hag := wm.fen_hag
		if not story_flags.has("hag_tea_done"):
			# Whatever happened outside, across her threshold she is the
			# sweet old lady again (user: "If the hag isn't defeated an old
			# woman encounter starts").
			hag.play_old_lady()
			_open_story_now("hag_tea")
		elif hag.hostile:
			_hud_message("Mother Grisla bars her door — claws first, tea never.")
		else:
			_hud_message("The old woman waves from her window. The kettle is on.")
	elif story_flags.has("lorindel_read"):
		_hud_message("Only cold ashes and the hag's empty chair remain.")
	else:
		_open_story_now("hag_house_book" if story_flags.has("hag_house_seen") else "hag_house_ruin")
		story_flags["hag_house_seen"] = true

## T: change shape — and every change is told (three tellings each way,
## taken in turn so the change never reads the same twice running).
const SHAPESHIFT_TELLINGS := 3
var _shapeshift_count := {"human": 0, "dragon": 0}

func request_shapeshift() -> void:
	var d := dragon as Dragon
	if d == null or story_open or get_tree().paused:
		return
	var to_human := not d.human_form
	if not d.set_human_form(to_human):
		_hud_message("Not over open water — a girl would drown here.")
		return
	var way := "human" if to_human else "dragon"
	var n: int = _shapeshift_count[way] % SHAPESHIFT_TELLINGS + 1
	_shapeshift_count[way] += 1
	_open_story_now("shapeshift_%s_%d" % [way, n])

## The girl walked into the King's men and they took her for easy prey:
## the dragon comes back out (its own chapter replaces the usual T telling)
## and the fight resumes the moment the popup closes.
const ACCOST_SOLDIER_TELLINGS := 2
var _accost_count := 0

func notify_girl_accosted(by: String) -> void:
	var d := dragon as Dragon
	if d == null or not d.human_form or story_open or get_tree().paused:
		return
	if not d.set_human_form(false):
		return
	var kind := "girl_accosted_king"
	if by != "king":
		kind = "girl_accosted_soldier_%d" % (_accost_count % ACCOST_SOLDIER_TELLINGS + 1)
		_accost_count += 1
	_open_story_now(kind)

# --- the girl's meetings (2026-11-15) ---------------------------------------------

## The girl walked into Mother Grisla (Dragon._check_meetings). User: "For
## the Hag, the same thing should happen [as with the soldiers] if and only
## if the Hag wasn't attacked during the visit in her house. Hag will still
## attack the dragon because she is a Hag." Spared at tea (or never asked):
## she smells the dragon on the girl, the claws come out, the dragon tears
## back out of her. Attacked at tea: she already knows that face — no
## chapter, no forced change; she is hunting the dragon regardless.
func notify_girl_meets_hag() -> void:
	var d := dragon as Dragon
	var wm := world_manager as WorldManager
	if d == null or not d.human_form or wm == null or not wm.hag_alive() \
			or story_open or get_tree().paused or not story_mode:
		return
	if story_flags.has("hag_attacked_at_house"):
		_hud_message("Mother Grisla grins through her teeth: she knows that face. No disguise fools a hag twice.")
		return
	if not d.set_human_form(false):
		return
	wm.fen_hag.unmask()   # because she is a hag
	_open_story_now("girl_accosted_hag")

## The girl walked into the adventurer. A three-level courtship (Disney
## flirt, then — literally — the bees and the flowers); seduced, he turns
## his trade around: from now on he robs the CITY and hauls its gold to
## her lair, and the King's soldiers hunt him for it.
var _adventurer: WeakRef = null

func notify_girl_meets_adventurer(adv: Node2D) -> void:
	var d := dragon as Dragon
	if d == null or not d.human_form or story_open or get_tree().paused or not story_mode:
		return
	if adv == null or not is_instance_valid(adv):
		return
	if bool(adv.get("smitten")):
		_hud_message("Corvin blows you a kiss over his sack of the King's gold.")
		return
	_adventurer = weakref(adv)
	_open_story_now("adventurer_meet")

func _on_adventurer_choice(kind: String, choice_index: int) -> void:
	match kind:
		"adventurer_meet":
			_pending_story_kind = ["adventurer_flirt", "adventurer_banter",
				"adventurer_walk_on"][mini(choice_index, 2)]
		"adventurer_flirt", "adventurer_banter":
			_pending_story_kind = ["adventurer_moment", "adventurer_backpack",
				"adventurer_wanting"][mini(choice_index, 2)]
		"adventurer_moment", "adventurer_backpack":
			_pending_story_kind = "adventurer_bees" if choice_index == 0 else "adventurer_parted"
		"adventurer_bees":
			_pending_story_kind = "adventurer_turned"
		"adventurer_turned":
			var adv: Node2D = _adventurer.get_ref() as Node2D if _adventurer != null else null
			if adv != null and is_instance_valid(adv) and adv.has_method("turn_outlaw"):
				adv.call("turn_outlaw")
				_hud_message("Corvin robs the city for you now — his loot goes to your lair. The King's soldiers will hunt him.", 6.0)

## Meeting the kindly wizard — as the girl (the Lorindel chapter and the
## temple quest), or carrying the Ember Tome in either shape (the offer).
func notify_meets_kind_wizard() -> void:
	var d := dragon as Dragon
	var wm := world_manager as WorldManager
	if d == null or wm == null or story_open or get_tree().paused or not story_mode:
		return
	if wm.tower_wizard == null or not is_instance_valid(wm.tower_wizard) \
			or not wm.tower_wizard.is_alive or not wm.tower_wizard.is_kind():
		return
	if story_flags.has("has_tome"):
		# Kept once: he only asks again when the girl comes calling (the
		# dragon visits the shop past his door far too often for that).
		if story_flags.has("tome_kept") and not d.human_form:
			return
		_open_story_now("wizard_tome_offer")
	elif not d.human_form:
		return
	elif not story_flags.has("temple_quest"):
		_open_story_now("wizard_girl_meet")
	else:
		_hud_message("Ambrose tips his hat to you. \"Any luck at the old temple, my dear? Near the old dragon's mountain, they say.\"")

## The Temple of the Dragon Queen (DragonTemple.gd's trigger): the first
## visit — in either shape — is the dream, the hidden stair and the tome.
func notify_temple() -> void:
	if story_open or get_tree().paused or not story_mode:
		return
	if story_flags.has("has_tome"):
		_hud_message("The Queen's ruins are quiet. Her tome is warm against your heart.")
		return
	_open_story_now("temple_enter")

func _on_tome_choice(kind: String, choice_index: int) -> void:
	var wm := world_manager as WorldManager
	match kind:
		"wizard_girl_meet":
			_pending_story_kind = "wizard_girl_lorindel"
		"wizard_girl_lorindel":
			_pending_story_kind = "wizard_girl_quest"
		"wizard_girl_quest":
			story_flags["temple_quest"] = true
			if wm != null and wm.has_method("spawn_dragon_temple"):
				wm.call("spawn_dragon_temple")
			_hud_message("Find the Temple of the Dragon Queen near your mountain.", 6.0)
		"temple_enter":
			_pending_story_kind = "temple_secret"
		"temple_secret":
			_pending_story_kind = "temple_tome"
		"temple_tome":
			story_flags["has_tome"] = true
			_hud_message("You carry the Ember Tome of Queen Ysolde.", 5.0)
			_maybe_learn_greater_flame()
		"wizard_tome_offer":
			_pending_story_kind = "wizard_tome_betrayal" if choice_index == 0 else "wizard_tome_kept"
			if choice_index != 0:
				story_flags["tome_kept"] = true
		"wizard_tome_betrayal":
			# User: "If she returns the book to the wizard he turns evil and
			# tries to kill her to get the book." The tome will not go to
			# him; it stays with her, and he comes for it.
			story_flags["tome_offered"] = true
			story_shown["wizard_emerge"] = true   # this chapter told his fall
			var d := dragon as Dragon
			if d != null and d.human_form:
				d.set_human_form(false)
			if wm != null:
				wm.force_wizard_turn()
			_hud_message("Ambrose Fairweather has turned — he will kill you for the tome!", 6.0)

## User: "If she keeps it until the second wave of the invasion, she will
## learn automatically Greater flame". WorldManager reports every wave; a
## tome found after the second wave has marched teaches at once.
var invasion_wave := 0

func on_invasion_wave(wave: int) -> void:
	invasion_wave = wave
	_maybe_learn_greater_flame()

func _maybe_learn_greater_flame() -> void:
	var d := dragon as Dragon
	if d == null or d.greater_flame or not story_flags.has("has_tome"):
		return
	if invasion_wave < 2 or (phase != Phase.INVASION and phase != Phase.RECKONING):
		return
	d.learn_greater_flame()
	_open_or_queue("greater_flame")

func _hud_message(text: String, duration: float = 4.0) -> void:
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, duration)

## Antagonised (2026-11-14, user: "if the wizard is antagonised for some
## reason then the wizard tower must be off limits"): he has turned — by
## his own provocation lines, by the dragon's fire, or by the hag's
## warning — or he already lies dead after turning. No more shopping.
var tower_barred := false

func wizard_hostile() -> bool:
	var wm := world_manager as WorldManager
	if wm == null:
		return false
	if wm.wizard_spawned:
		return true
	return wm.tower_wizard != null and is_instance_valid(wm.tower_wizard) \
		and not wm.tower_wizard.is_kind()

## The tower goes dark and violet-warded the moment he turns (idempotent).
func bar_wizard_tower() -> void:
	if tower_barred or wizard_dead:
		return
	tower_barred = true
	for tower: Node in get_tree().get_nodes_in_group("wizard_tower"):
		(tower as CanvasItem).modulate = Color(0.48, 0.38, 0.62)
	print("GameManager: the wizard has turned — his tower is barred")

## The old man died in the ash: the tower door seals for the whole run.
func _seal_wizard_tower() -> void:
	wizard_dead = true
	for tower: Node in get_tree().get_nodes_in_group("wizard_tower"):
		(tower as CanvasItem).modulate = Color(0.42, 0.42, 0.48)
	print("GameManager: the wizard is dead — his tower is sealed")

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

## Pay OUT of the dragon's stolen hoard (goblin trade fees draw here —
## mirror of spend_treasury; the two pools never mix, decision record).
func spend_stash(res_type: String, amount: int) -> bool:
	if not stash.has(res_type) or stash[res_type] < amount:
		return false
	stash[res_type] -= amount
	stash_changed.emit(res_type, stash[res_type])
	return true

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

## Pay a cost from the stash (gold first, gems worth GEM_GOLD_VALUE gold
## each as top-up). One-way: gems buy gold, never gold buys gems.
func _pay_stash(cost: int) -> bool:
	if run_finished or cost <= 0:
		return false
	if stash["gold"] + stash["gems"] * GEM_GOLD_VALUE < cost:
		return false
	var need := cost
	var from_gold := mini(need, stash["gold"])
	need -= from_gold
	stash["gold"] -= from_gold
	if need > 0:
		stash["gems"] -= ceili(float(need) / float(GEM_GOLD_VALUE))
	stash_changed.emit("gold", stash["gold"])
	stash_changed.emit("gems", stash["gems"])
	return true

# --- wizard shop (the tower site; replaces the old U-key panel) ---------------

const WIZARD_MENU_SCENE := preload("res://scenes/ui/WizardMenu.tscn")

## Stash-value readout (gold-equivalent; gems worth GEM_GOLD_VALUE gold
## each — display only).
func stash_value() -> int:
	return stash["gold"] + stash["gems"] * GEM_GOLD_VALUE

## Shared affordability rule (decision 2026-11-08-dragon-strikes-respawn-
## prices): the gem part is a HARD requirement (the currencies have distinct
## duties); the gold part may be topped up with SPARE gems at 1 gem =
## GEM_GOLD_VALUE gold — the same rule the stash economy already applies.
## Gems are never sold for gold (user 2026-11-12: "you can't get gems for
## gold" — the only gem inflow is goblin protection fees).
func can_afford_wizard(kind: String) -> bool:
	var cost: Dictionary = WIZARD_PRICES[kind]
	var gem_need := int(cost["gems"])
	if int(stash["gems"]) < gem_need:
		return false
	var spare_gems := int(stash["gems"]) - gem_need
	return int(stash["gold"]) + spare_gems * GEM_GOLD_VALUE >= int(cost["gold"])

## Pay a wizard cost {"gold", "gems"} — same rule as can_afford_wizard.
## A refused purchase never half-pays (gold-first, gems flatten the rest).
## Bug fix (2026-11-11): no run_finished gate — purchases keep working
## after the King's final fall (post-victory shop, user report).
func _pay_wizard_cost(kind: String) -> bool:
	if not can_afford_wizard(kind):
		return false
	var cost: Dictionary = WIZARD_PRICES[kind]
	var gem_need := int(cost["gems"])
	stash["gems"] -= gem_need
	var gold_need := int(cost["gold"])
	var from_gold := mini(gold_need, int(stash["gold"]))
	stash["gold"] -= from_gold
	var leftover := gold_need - from_gold
	if leftover > 0:
		stash["gems"] -= ceili(float(leftover) / float(GEM_GOLD_VALUE))
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
	if kind == "brute" and not bool(dragon_ref.call("can_add_claw_damage")):
		return false
	# Rider training requires a trainable sacrifice
	if kind == "rider_train" and not _trainable_sacrifice:
		return false
	if not _pay_wizard_cost(kind):
		return false
	match kind:
		"flame_1":
			dragon_ref.call("increase_flame_capacity", 1)
		"flame_2":
			dragon_ref.call("increase_flame_capacity", 2)
		"shield":
			# Improved offer (2026-11-11, user: "40 points of consumable
			# absorption") — was 10.
			dragon_ref.call("add_shield", 40)
		"speed":
			dragon_ref.call("activate_speed_boost")
			dragon_ref.call("unlock_fast_strike")
		"range":
			dragon_ref.call("increase_flame_range", 20.0)
		"brute":
			dragon_ref.call("buy_brute_force")
		"flight":
			dragon_ref.call("extend_flight", 3.0)
		"rider_train":
			if dragon_ref.has_method("upgrade_rider"):
				dragon_ref.call("upgrade_rider")
				# Brannagh the Defiant shoots out of pure spite: 1.5x faster.
				dragon_ref.set("rider_fire_mult", 1.5 if _trainable_personality == "defiant" else 1.0)
				_trainable_sacrifice = false  # consumed
				_trainable_personality = ""
			else:
				print("Dragon: upgrade_rider method not found")
				return false
	upgrade_purchased.emit(kind, int(WIZARD_PRICES[kind]["gold"]))
	upgrade_purchases += 1  # the wizard keeps count (emergence trigger)
	return true

## Open the wizard overlay (pause the live world beneath it). Lazily built so
## GameManager's scene tree stays lean; the instance survives for reopen.
## Bug fix (2026-11-11, user: "if the king is defeated, the wizard tower
## stops to work"): NO run_finished gate — the shop stays open in
## post-victory play; the wizard never lost his love of gold.
func open_wizard_menu() -> void:
	if wizard_dead:
		_hud_message("The wizard is dead. His tower is sealed.", 3.0)
		return
	if wizard_hostile():
		bar_wizard_tower()
		_hud_message("The tower door is barred and warded. Ambrose is your enemy now.", 3.0)
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
	if run_finished or phase != Phase.REALM:
		return
	notify_story("king_defeat")  # the FINAL fall gets its epic chapter
	king_defeated.emit()
	begin_aftermath()

## The run's score card — emitted by the true ending (invasion_won), no
## longer at the King's fall (2026-11-15: the story goes on).
func _victory_tally() -> Dictionary:
	return {
		"time_survived": run_timer,
		"gold_stolen": stash["gold"],
		"gems_stolen": stash["gems"],
		"treasury_left": treasury,
		"fire_level": fire_power_level,
		"scales_level": scales_level,
		"soldiers_seen": soldier_count,
	}

# --- the aftermath, the courtship, the invasion (2026-11-15) ----------------------

## The run's phases. REALM: the King lives. AFTERMATH: the King is dead —
## a glade blooms, deer graze, Prince Aurel walks (the courtship). INVASION:
## the kiss brought the usurper's army (tower defence). RECKONING: the
## usurper fell; the evil wizard comes for the heart. ENDED: the cycle
## repeated, or the wedding — and the last ember.
enum Phase { REALM, AFTERMATH, INVASION, RECKONING, ENDED }
var phase := Phase.REALM
signal phase_changed(new_phase: Phase)
signal invasion_started

func _set_phase(p: Phase) -> void:
	if phase == p:
		return
	phase = p
	phase_changed.emit(p)
	print("GameManager: phase → %s" % Phase.keys()[p])

func begin_aftermath() -> void:
	_set_phase(Phase.AFTERMATH)
	queue_followup_story("glade_blooms")
	if world_manager != null and world_manager.has_method("spawn_glade"):
		world_manager.call("spawn_glade")

## The farm girl walked into the Prince. Meeting 1 is all flirting (no kiss;
## either may turn the other down); from meeting 2 on she may kiss him — or
## turn him away, and he goes back to the city road to be found again.
var prince_meetings := 0

func notify_prince_meeting() -> void:
	if phase != Phase.AFTERMATH or story_open or get_tree().paused:
		return
	prince_meetings += 1
	if prince_meetings == 1:
		_open_story_now("prince_meet_1")
	else:
		_open_story_now("prince_meet_2_wary" if story_flags.has("prince_spurned") else "prince_meet_2")

func _on_prince_choice(kind: String, choice_index: int) -> void:
	var wm := world_manager as WorldManager
	match kind:
		"prince_meet_1":
			_pending_story_kind = ["prince_meet_1_flirt", "prince_meet_1_coy", "prince_meet_1_spurn"][mini(choice_index, 2)]
			if choice_index == 2:
				story_flags["prince_spurned"] = true
			if wm != null:
				wm.relocate_prince()
		"prince_meet_2", "prince_meet_2_wary":
			if choice_index == 0:
				story_flags.erase("prince_spurned")
				_pending_story_kind = "prince_kiss"
			else:
				story_flags["prince_spurned"] = true
				_pending_story_kind = "prince_rejected"
				if wm != null:
					wm.relocate_prince()
		"prince_kiss":
			begin_invasion()

## The kiss → the invasion (2026-11-15). The phase flips, the chapter
## "The Second Purification" tells it, and WorldManager raises the usurper's
## camp and starts the waves (tower defence: protect the Prince, the
## farmers and the miners; slay the usurper King).
func begin_invasion() -> void:
	if phase != Phase.AFTERMATH:
		return
	_set_phase(Phase.INVASION)
	invasion_started.emit()
	queue_followup_story("invasion_begins")
	if world_manager != null and world_manager.has_method("start_invasion"):
		world_manager.call("start_invasion")
	_hud_message("Defend the realm with the town's garrison: keep the Prince, the farmers and the miners alive — slay the usurper King.", 7.0)

## The usurper King fell: his army routs. Now the evil wizard comes for the
## heart — or, if he is already dead, the wedding.
func on_usurper_slain() -> void:
	if phase != Phase.INVASION:
		return
	_set_phase(Phase.RECKONING)
	var wizard_comes := false
	if world_manager != null and world_manager.has_method("start_wizard_finale"):
		wizard_comes = bool(world_manager.call("start_wizard_finale"))
	if wizard_comes:
		_open_or_queue("usurper_falls")
	else:
		_open_or_queue("usurper_falls_quiet")

## The evil wizard is dead (or long dead): the wedding — and the last ember.
func on_wizard_slain() -> void:
	if phase != Phase.RECKONING:
		return
	_set_phase(Phase.ENDED)
	run_finished = true
	_open_or_queue("ending_wedding")
	victory_achieved.emit(_victory_tally())

func notify_prince_died() -> void:
	if phase == Phase.INVASION or phase == Phase.RECKONING:
		invasion_lost("prince")

## The invasion won: the Prince is dead, or no farmer or miner is left.
## The chapter tells it; closing it starts a new run (the cycle turns).
func invasion_lost(reason: String = "townsfolk") -> void:
	if phase != Phase.INVASION and phase != Phase.RECKONING:
		return
	_set_phase(Phase.ENDED)
	run_finished = true
	_pending_death_reload = true
	_open_or_queue("ending_prince_falls" if reason == "prince" else "ending_cycle")

## The finale's chapters chain: the usurper falls (quietly → the wedding
## at once); the wedding → the last ember → a new run.
func _on_finale_choice(kind: String) -> void:
	match kind:
		"usurper_falls_quiet":
			on_wizard_slain()
		"ending_wedding":
			_pending_story_kind = "ending_last_ember"
		"ending_last_ember":
			_pending_death_reload = true   # peace — and a new run

## Open now, or right after the chapter on screen.
func _open_or_queue(kind: String) -> void:
	if story_open:
		queue_followup_story(kind)
	else:
		_open_story_now(kind)

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
