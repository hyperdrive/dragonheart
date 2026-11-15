extends Node2D

class_name WorldManager

## World spawner + escalation director.
## Layout: a city in the south (soldiers spawn there), a farm belt around it
## (fields + animal pens + farmer homes), a mining district in the northwest,
## and blocking scenery (trees/lakes/mountains) scattered with clearance checks.
## Soldier tactics: when the dragon nears the city soldiers RALLY at the city
## gate; when enough have massed (or the dragon is at the walls) they ATTACK.
## docs/plans/2026-11-08-behavior-system-rebuild.md
##
## King story variants (2026-11-12): when the King emerges, pick a story
## variant at random — the same popup scene handles all story kinds.

signal entity_spawned(entity_type: String, position: Vector2)
signal swarm_state_changed(new_state: SwarmState)

enum SwarmState { CALM, RALLY, ATTACK }

@export_group("World")
## Interior world area (user spec 2026-11-10: +20% after the goblins made
## the map feel crowded — 1600² was tight for the extra tribe traffic).
@export var world_size: Vector2 = Vector2(1920, 1920)
@export var farmer_count: int = 5
@export var mine_count: int = 8
@export var field_count: int = 6
@export var initial_soldier_count: int = 4

@export_group("Landmarks")
@export var city_position: Vector2 = Vector2(0, 620)
@export var mine_center: Vector2 = Vector2(-480, -420)
@export var rally_point: Vector2 = Vector2(0, 500)   # north gate of the city
@export var pig_pen_position: Vector2 = Vector2(-260, 760)
@export var cow_pen_position: Vector2 = Vector2(260, 820)
@export var lair_position: Vector2 = Vector2(-620, 60)   # dragon's home mountain
## Goblin Mountain (user spec): the tribe's dedicated home rock, placed
## close to the lair so the dragon discovers goblins on the way home.
@export var goblin_mountain_position: Vector2 = Vector2(-680, 250)
@export var tower_position: Vector2 = Vector2(520, -420)  # wizard tower

@export_group("Terrain")
@export var tree_count: int = 14
@export var lake_count: int = 3
@export var mountain_count: int = 5
## Two tree densities (user spec 2026-11-12): a layout world splits the trees
## across a DENSE and a SPARSE forest mask; these counts only apply when a
## WorldLayout is active (no layout → legacy tree_count random scatter).
@export var tree_dense_count: int = 7
@export var tree_sparse_count: int = 7

@export_group("Miner support chain")
@export var initial_miner_count: int = 2
@export var miner_spawn_requirement_farmers: int = 3
@export var miner_spawn_requirement_food: int = 10
@export var miner_spawn_timer: float = 30.0

@export_group("Town respawn")
## Dead farmers return only if the town pays a pig from the pig pen (dead
## miners pay a cow); retries every check interval until the pen can pay.
@export var npc_respawn_delay: float = 10.0
@export var npc_respawn_check_interval: float = 2.0

@export_group("Escalation")
@export var soldier_spawn_interval: float = 8.0
@export var king_threshold: int = 15

@export_group("Adventurer")
## Wandering hero (user spec 2026-11-12): walks to the lair, kills goblins,
## steals the whole gold hoard, and hauls it back to the town treasury.
## Counter-play: dragon fire.
## Trigger (2026-11-13 user spec): the hero comes as soon as the lair hoard
## holds adventurer_gold_trigger gold — event-driven off GameManager
## .stash_changed; the old 300 s spawn timer is gone. A successful raid
## zeroes the hoard, so the hero only returns once the dragon re-banks
## the trigger amount.
@export var adventurer_gold_trigger: int = 10
## Concurrent hero cap: one adventurer at a time — the hoard raid drains
## ALL the lair gold, so overlapping heroes would just double-walk to an
## empty rock. Raise this for proper hero parties.
@export var adventurer_max_alive: int = 1

@export_group("Swarm tactics")
@export var rally_range: float = 340.0          # dragon distance to city → RALLY
@export var swarm_size: int = 3                 # gathered soldiers → ATTACK
@export var swarm_gather_radius: float = 110.0
@export var attack_range_city: float = 170.0    # dragon at the walls → ATTACK

const ESCALATING := "soldier"   # entity spawned on the escalation curve
var entity_scenes := {
	"farmer": preload("res://scenes/npcs/Farmer.tscn"),
	"miner": preload("res://scenes/npcs/Miner.tscn"),
	"goblin": preload("res://scenes/npcs/Goblin.tscn"),
	"mine": preload("res://scenes/objects/Mine.tscn"),
	"soldier": preload("res://scenes/objects/Soldier.tscn"),
	"archer": preload("res://scenes/objects/Archer.tscn"),
	"wizard": preload("res://scenes/objects/Wizard.tscn"),
	"field": preload("res://scenes/systems/Field.tscn"),
	"tower": preload("res://scenes/objects/WizardTower.tscn"),
	"king": preload("res://scenes/objects/King.tscn"),
	"adventurer": preload("res://scenes/objects/Adventurer.tscn"),
	"city": preload("res://scenes/props/City.tscn"),
	"pig_pen": preload("res://scenes/props/PigPen.tscn"),
	"cow_pen": preload("res://scenes/props/CowPen.tscn"),
	"lair": preload("res://scenes/props/DragonLair.tscn"),
	"sacrifice": preload("res://scenes/props/Sacrifice.tscn"),
}

var scenery_scenes := [
	preload("res://scenes/props/Tree.tscn"),
	preload("res://scenes/props/Lake.tscn"),
	preload("res://scenes/props/Mountain.tscn"),
]

var game_manager: GameManager
var soldiers_spawned: int = 0
var king_spawned: bool = false
var swarm_state: SwarmState = SwarmState.CALM
var field_positions: Array[Vector2] = []
## Sacrifice system: track fields burnt to spawn sacrifice every 3 fields
var fields_burnt_count: int = 0
## Pending NPC respawns: {"type", "position", "timer_left"} — gated on the
## matching pen having a live animal (farmer↔pig, miner↔cow).
var _respawn_queue: Array[Dictionary] = []
var _soldier_timer: Timer
var _swarm_timer: Timer
var _goblin_timer: Timer
var _goblin_raid_timer: Timer
var _raid_timer: Timer  # For ending goblin raids
var _goblin_count: int = 0
const MAX_GOBLINS: int = 6
## The tribe's home rock ("Goblin Mountain", user spec): designated at world
## generation as the mountain NEAREST the dragon's lair — the tribe nests
## next door to the dragon's den, encounterable on the way home.
var goblin_mountain: Node2D = null
## Tribe-wide service standing (user spec): the goblin-encounter story answer
## binds EVERY goblin — acceptance turns the whole tribe into the town's
## gem-for-gold miners, refusal makes them hostile. New spawns are born into
## it (Goblin._ready checks here); the popup ledger opens the story once per
## run, so the answer cannot be per-goblin.
var goblin_service_standing: Goblin.ServiceState = Goblin.ServiceState.UNINITIALIZED
## One goblin per minute into the tribe (user spec), spawned on a ring just
## outside the mountain body (Mountain collision r=54) so nobody spawns
## inside the rock.
const GOBLIN_SPAWN_INTERVAL := 60.0
const GOBLIN_SPAWN_RING := 90.0
const GOBLIN_SPAWN_JITTER := 15.0
## StuckMonitor (decision 2026-11-09): per-NPC supervision records trusted by
## the audit — see _audit_npc_stuck/_remediate_stuck.
var _stuck_timer: Timer
var _stuck_records: Dictionary = {}

@export_group("StuckMonitor")
## Audit cadence in seconds.
@export var stuck_audit_interval: float = 2.5
## Seconds of near-zero movement while MOVING before forcing a detour /
## teleporting to the current target vicinity.
@export var detour_after_sec: float = 5.0
@export var teleport_after_sec: float = 10.0
## Seconds the same activity id may hold without completion before the trip
## is rescued (covers circling, not just wall-wedging). 3 rescues of the
## SAME activity end in an abort instead of another teleport.
@export var activity_stall_after_sec: float = 30.0
## Blocking scenery footprint (position + radius) for spawn-clearance checks.
## Grows during world generation: landmarks, fields and mines all register,
## so every later placement (scenery, mines, NPC jitter) keeps clear of all
## of it — no more overlapping terrain.
var _terrain_clearances: Array = []

## Footprint radii used for registration/probing (visual, in px).
const FOOTPRINT_RADIUS := {
	"city": 120.0, "pig_pen": 85.0, "cow_pen": 85.0, "lair": 100.0,
	"tower": 75.0, "field": 55.0, "tree": 30.0, "lake": 85.0,
	"mountain": 80.0, "mine": 30.0,
}

## Walkable interior band: boundary walls sit at ±world_size/2 (20px thick);
## everything reachable must stay WORLD_MARGIN inside them — minus any own
## footprint. Bug fix (decision 2026-11-08-dragon-strikes-respawn-prices):
## stale anchor defaults put the cow pen y=820 and whole fields behind the
## south wall, wedging farmers and starving miner→cow respawns.
const WORLD_MARGIN := 80.0

# --- layout mode (decision record 2026-11-12-world-editor) --------------------

## The selected WorldLayout, or null → full-procedural fallback. Selected via
## WorldSession (editor Play button / probe) or the --world= command-line arg.
var active_layout: WorldLayout = null
## Seeded placement RNG: a layout carries a seed, so the same layout always
## generates the identical world (probe-verifiable). Unseeded (procedural
## fallback) it is randomized per boot.
var _rng := RandomNumberGenerator.new()
## Per-category decoded mask images (cached once at layout application —
## sampling runs hundreds of times per generation).
var _mask_images: Dictionary = {}
## Categories whose mask has NO bright pixel at all — placement skips the
## pointless 120-sample scan and falls back to random (also cached).
var _mask_empty: Dictionary = {}
## World positions of mask-placed mines — miner work spots snap to REAL
## mines when the mines mask scattered them away from mine_center.
var _mine_spots: Array[Vector2] = []

func _clamp_to_interior(pos: Vector2, radius := 0.0) -> Vector2:
	var pad := WORLD_MARGIN + radius
	var half := world_size * 0.5 - Vector2(pad, pad)
	return pos.clamp(-half, half)


func register_footprint(position: Vector2, radius: float) -> void:
	_terrain_clearances.append({"pos": position, "radius": radius})


## Push the saved world's anchors, counts and seed into the exports BEFORE the
## interior clamp runs — every later placement rule keeps working unchanged.
func _apply_layout(layout: WorldLayout) -> void:
	active_layout = layout
	if layout.world_size.x > 0:
		world_size = layout.world_size
	city_position = layout.city_position
	lair_position = layout.lair_position
	goblin_mountain_position = layout.goblin_mountain_position
	tower_position = layout.tower_position
	pig_pen_position = layout.pig_pen_position
	cow_pen_position = layout.cow_pen_position
	mine_center = layout.mine_center
	# The soldiers' rally point rides the city's north gate (default offset).
	rally_point = layout.city_position + Vector2(0, -120)
	# Counts: non-zero layout values override the exports.
	if layout.tree_dense_count > 0:
		tree_dense_count = layout.tree_dense_count
	if layout.tree_sparse_count > 0:
		tree_sparse_count = layout.tree_sparse_count
	if layout.lake_count > 0:
		lake_count = layout.lake_count
	if layout.mountain_count > 0:
		mountain_count = layout.mountain_count
	if layout.field_count > 0:
		field_count = layout.field_count
	if layout.mine_count > 0:
		mine_count = layout.mine_count
	_rng.seed = layout.seed_value
	for category: String in WorldLayout.MASK_CATEGORIES:
		var img := layout.get_mask_image(category)
		_mask_images[category] = img
		_mask_empty[category] = not _mask_has_bright(img)
		var msg := "WorldManager: layout applied (seed %d) — city %s, lair %s, goblin mountain %s, tower %s" % [
			layout.seed_value,
			str(layout.city_position), str(layout.lair_position),
			str(layout.goblin_mountain_position), str(layout.tower_position)]
		print(msg)


func _mask_has_bright(img: Image) -> bool:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).r >= WorldLayout.BRIGHT_THRESHOLD:
				return true
	return false


## A mask-guided placement anchor: rejection-sample bright pixels (brightness
## = keep-going weight), locally jitter, then run the STANDARD clearance
## checks (_terrain_free_position) — a candidate that drifted off its mask or
## into a footprint is rejected. Empty/missing mask → fully random anchor.
func _mask_anchor(category: String, self_radius: float,
	protected := [] as Array, protected_margin := 90.0,
	allow_fallback := true) -> Vector2:
	if active_layout == null or _mask_empty.get(category, true):
		# No painted region: keep the standard random + clearance behavior.
		return _terrain_free_position(
			get_random_position(), self_radius, protected, protected_margin)
	var img: Image = _mask_images[category]
	var size := Vector2i((world_size * WorldLayout.MASK_SCALE).round())
	for attempt in 120:
		var px := Vector2i(
			_rng.randi_range(0, size.x - 1), _rng.randi_range(0, size.y - 1))
		if img.get_pixelv(px).r < WorldLayout.BRIGHT_THRESHOLD:
			continue
		var candidate := active_layout.mask_to_world(px) \
			+ Vector2(_rng.randf_range(-20, 20), _rng.randf_range(-20, 20))
		candidate = _clamp_to_interior(candidate, self_radius)
		var spot := _terrain_free_position(
			candidate, self_radius, protected, protected_margin)
		if spot == Vector2.INF:
			continue
		# The clearance jitter may have drifted — re-check the mask at the
		# FINAL spot so nothing spawns off its painted region.
		if active_layout.sample_mask(category, spot) < WorldLayout.BRIGHT_THRESHOLD:
			continue
		return spot
	if not allow_fallback:
		return Vector2.INF  # caller retries smaller / skips
	push_warning(("WorldManager: mask '%s' never produced a clear spot "
		+ "— random fallback") % category)
	return _terrain_free_position(
		get_random_position(), self_radius, protected, protected_margin)


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	add_to_group("world_manager")
	# Mode selection (decision 2026-11-12-world-editor): a saved world layout
	# overrides the exported landmark anchors and seeds placement; with no
	# layout selected the generation below is fully procedural as before.
	active_layout = WorldLayout.load_from_world(WorldSession.active_world()) \
		if WorldSession.active_world() != "" else null
	if active_layout != null:
		_apply_layout(active_layout)
	else:
		_rng.randomize()
	if game_manager != null:
		swarm_state_changed.connect(game_manager._on_swarm_state_changed)
		# Hero trigger (2026-11-13): the adventurer comes as soon as the
		# hoard holds the trigger gold — event-driven, no spawn timer.
		game_manager.stash_changed.connect(_on_stash_changed)
		# The goblin-encounter story answer selects the tribe's fate
		# (user spec: accept → the whole tribe mines gem-for-gold).
		if game_manager.has_signal("story_choice_made"):
			game_manager.story_choice_made.connect(_on_goblin_story_choice)
	# Pre-clamp landmark anchors BEFORE generation: they are design numbers
	# exported before the margin rule existed.
	city_position = _clamp_to_interior(city_position, FOOTPRINT_RADIUS["city"])
	mine_center = _clamp_to_interior(mine_center, FOOTPRINT_RADIUS["mine"])
	rally_point = _clamp_to_interior(rally_point)
	pig_pen_position = _clamp_to_interior(pig_pen_position, FOOTPRINT_RADIUS["pig_pen"])
	cow_pen_position = _clamp_to_interior(cow_pen_position, FOOTPRINT_RADIUS["cow_pen"])
	lair_position = _clamp_to_interior(lair_position, FOOTPRINT_RADIUS["lair"])
	goblin_mountain_position = _clamp_to_interior(
		goblin_mountain_position, FOOTPRINT_RADIUS["mountain"])
	tower_position = _clamp_to_interior(tower_position, FOOTPRINT_RADIUS["tower"])
	generate_world()
	_build_nav_grid()
	# Connect to field_burnt signal AFTER generation (fields are created in generate_world)
	for field_node in get_tree().get_nodes_in_group("fields"):
		var field := field_node as Field
		if field != null:
			field.field_burnt.connect(_on_field_burnt)

	# Escalation timer: one soldier per interval until the King threshold.
	_soldier_timer = Timer.new()
	_soldier_timer.wait_time = soldier_spawn_interval
	_soldier_timer.autostart = true
	_soldier_timer.timeout.connect(_on_escalation_tick)
	add_child(_soldier_timer)

	# Miner support-chain spawn timer (the "farmers enable miners" chain).
	var miner_timer := Timer.new()
	miner_timer.wait_time = miner_spawn_timer
	miner_timer.autostart = true
	miner_timer.timeout.connect(try_spawn_miner)
	add_child(miner_timer)

	# Goblin tribe timer: 1 goblin per minute, max 6 (user spec)
	_goblin_timer = Timer.new()
	_goblin_timer.wait_time = GOBLIN_SPAWN_INTERVAL
	_goblin_timer.autostart = true
	_goblin_timer.timeout.connect(_on_goblin_spawn_tick)
	add_child(_goblin_timer)
	
	# Goblin raid timer: occasional raiding parties (every 60s)
	_goblin_raid_timer = Timer.new()
	_goblin_raid_timer.wait_time = 60.0
	_goblin_raid_timer.autostart = true
	_goblin_raid_timer.timeout.connect(_on_goblin_raid_tick)
	add_child(_goblin_raid_timer)

	# Swarm coordination tick (see _on_swarm_tick).
	_swarm_timer = Timer.new()
	_swarm_timer.wait_time = 0.5
	_swarm_timer.autostart = true
	_swarm_timer.timeout.connect(_on_swarm_tick)
	add_child(_swarm_timer)

	# Adventurer spawning (2026-11-13): no timer — the hero is triggered
	# by the stash_changed connection in the game_manager block below.

	# StuckMonitor watch (decision 2026-11-09): NPC supervision heartbeat.
	_stuck_timer = Timer.new()
	_stuck_timer.wait_time = stuck_audit_interval
	_stuck_timer.autostart = true
	_stuck_timer.timeout.connect(_audit_npc_stuck)
	add_child(_stuck_timer)

	# Treasury spend heartbeat (2026-11-09): soldiers bought between
	# deliveries too, so miner money is never parked.
	_purchase_timer = Timer.new()
	_purchase_timer.wait_time = soldier_purchase_interval
	_purchase_timer.autostart = true
	_purchase_timer.timeout.connect(_try_buy_soldiers)
	add_child(_purchase_timer)

	# The dragon slayer rides in at random intervals (2026-11-14).
	_slayer_timer = Timer.new()
	_slayer_timer.one_shot = true
	_slayer_timer.timeout.connect(_on_slayer_timer)
	add_child(_slayer_timer)
	_slayer_timer.start(randf_range(slayer_first_min_s, slayer_first_max_s))


# --- StuckMonitor (2026-11-09) ------------------------------------------------

## Two failure alarms, decided per NPC per audit — all thresholds in ELAPSED
## TIME so audit cadence (real timer, probes, future callers) can't skew the
## escalation clock:
##  • MOVEMENT STALL: state == MOVING and moved < max(4px, speed x 0.05)
##    since the last recorded progress. detour_after_sec → force a tangent
##    detour (pathfinding tweak); teleport_after_sec → teleport next to the
##    CURRENT activity target so the trip can still complete naturally.
##  • ACTIVITY STALL: the same activity id without completion for
##    activity_stall_after_sec (circle/loop detection) → one teleport rescue;
##    after 3 rescues of the SAME activity the target is declared
##    unreachable and the trip aborts (no teleport-loop forever).
## Burning/dead NPCs are skipped; WORKING is legitimately stationary and the
## activity alarm covers it.
func _audit_npc_stuck() -> void:
	if game_manager != null and game_manager.run_finished:
		return
	var seen: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("farmers"):
		seen[_audit_one_npc(node)] = true
	for node: Node in get_tree().get_nodes_in_group("miners"):
		seen[_audit_one_npc(node)] = true
	for node: Node in get_tree().get_nodes_in_group("soldiers"):
		seen[_audit_one_npc(node)] = true
	for node: Node in get_tree().get_nodes_in_group("goblins"):
		seen[_audit_one_npc(node)] = true
	for node: Node in get_tree().get_nodes_in_group("adventurers"):
		seen[_audit_one_npc(node)] = true
	# Scrub records for freed NPCs.
	for id: int in _stuck_records.keys():
		if not seen.has(id):
			_stuck_records.erase(id)

func _audit_one_npc(node: Node) -> int:
	var npc := node as BaseNPC
	var id := npc.get_instance_id()
	if npc == null or not npc.is_alive:
		return id
	var bt := npc.behavior_tree
	if bt == null or bt.state == BehaviorTree.State.DEAD \
			or float(npc._burning_left) > 0.0:
		return id
	var state := bt.state
	var act_id: String = str(bt.current_activity.id) \
		if bt.current_activity != null else ""
	var now := Time.get_ticks_msec()
	var record: Dictionary = _stuck_records.get(id, {})
	var prev_pos: Vector2 = record.get("pos", npc.global_position)
	var moved: float = npc.global_position.distance_to(prev_pos)
	var activity_changed: bool = act_id != String(record.get("activity_id", ""))
	if record.is_empty():
		# Fresh clock starts NOW; nothing escalates before its first window.
		record = {"pos": npc.global_position, "state": state,
			"activity_id": act_id, "rescues": 0, "last_progress_ms": now,
			"activity_start_ms": now, "hold_fired": false}
	elif activity_changed or int(record.get("state", -1)) != state:
		# The tree did something new: reset the progress clock; a NEW trip
		# gets a fresh rescue budget (rescues are scoped per activity).
		record["last_progress_ms"] = now
		record["activity_start_ms"] = now
		record["hold_fired"] = false
		if activity_changed:
			record["rescues"] = 0
	elif moved >= maxf(4.0, npc.speed * 0.05):
		# Refresh the progress clock on REAL movement (dither in place does
		# NOT clear the movement alarm; honest steps do).
		record["last_progress_ms"] = now
	record["pos"] = npc.global_position
	record["state"] = state
	record["activity_id"] = act_id
	_stuck_records[id] = record
	_remediate_stuck(npc, record, now)
	return id

func _remediate_stuck(npc: BaseNPC, record: Dictionary, now: int) -> void:
	var bt := npc.behavior_tree
	# Alarm 2: activity hold (any state — a legit tend walk+work is well
	# under the threshold; a hold that long means a loop).
	if bt.current_activity != null \
			and now - int(record.get("activity_start_ms", now)) \
				>= int(activity_stall_after_sec * 1000.0) \
			and not bool(record.get("hold_fired", false)):
		record["hold_fired"] = true
		_rescue_npc(npc, record, "activity-stall", now)
		return
	# Alarm 1: movement-stall ladder (MOVING and FLEEING — a flee wedged
	# against terrain never self-arrives and the tree's own detours may
	# orbit; 2026-11-09 forensic: one miner crossed the whole run fleeing
	# unpinned terrain with zero monitor coverage).
	var stalling_states: Array = [
		BehaviorTree.State.MOVING, BehaviorTree.State.FLEEING]
	var stall_ms: int = now - int(record.get("last_progress_ms", now))
	if not stalling_states.has(bt.state) \
			or stall_ms < int(detour_after_sec * 1000.0):
		return
	if stall_ms >= int(teleport_after_sec * 1000.0):
		_rescue_npc(npc, record, "move-stall", now)
	else:
		bt.force_detour()
		record["last_progress_ms"] = now  # the detour earns its own window
		print("StuckMonitor: %s not moving — forced detour" % npc.name)

## The rescue (2026-11-14, user: "the teleport is a little over the top —
## just teleport a few steps towards the goal"): a short HOP of about three
## body-lengths along the NPC's planned route toward its goal, onto ground
## the walkable grid vouches for, as a quick slide rather than a pop. The
## trip then simply carries on from there. After RESCUE_MAX_HOPS hops for
## the SAME activity — or a non-finite target, or no spot ahead at all —
## the trip is abandoned instead (claim released, tree re-picks).
const RESCUE_HOP_PX := 56.0
const RESCUE_SLIDE_S := 0.35
const RESCUE_MAX_HOPS := 4

func _rescue_npc(npc: BaseNPC, record: Dictionary, reason: String, now: int) -> void:
	var rescues := int(record.get("rescues", 0)) + 1
	record["rescues"] = rescues
	var bt := npc.behavior_tree
	var activity := bt.current_activity
	var restart_clock := func() -> void:
		record["pos"] = npc.global_position
		record["last_progress_ms"] = now
		record["activity_start_ms"] = now
		record["hold_fired"] = false
	if activity == null or rescues > RESCUE_MAX_HOPS \
			or not (activity.target as Vector2).is_finite():
		bt.force_repick()
		restart_clock.call()
		print("StuckMonitor: %s abandoned stuck %s trip (%s, rescue #%d)" % [
			npc.name, npc.npc_type, reason, rescues])
		return
	var spot := _rescue_hop_spot(npc.global_position, activity.target)
	if spot == Vector2.INF:
		bt.force_repick()
		restart_clock.call()
		print("StuckMonitor: %s aborted %s trip — no ground ahead (%s #%d)" % [
			npc.name, npc.npc_type, reason, rescues])
		return
	npc._waypoint = Vector2.INF
	npc.invalidate_route()
	npc.velocity = Vector2.ZERO
	var slide := npc.create_tween()
	slide.tween_property(npc, "global_position", spot, RESCUE_SLIDE_S) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	restart_clock.call()
	record["pos"] = spot   # judge progress from where the hop lands
	print("StuckMonitor: %s hopped %d px toward its %s goal (%s, rescue #%d)" % [
		npc.name, int(npc.global_position.distance_to(spot)), npc.npc_type, reason, rescues])

## A walkable spot ~RESCUE_HOP_PX ahead along the route to `goal` (straight
## toward it when there is no grid/route). INF when nothing walkable is
## meaningfully ahead.
func _rescue_hop_spot(from: Vector2, goal: Vector2) -> Vector2:
	var ahead := Vector2.INF
	if nav_grid != null and nav_grid.is_built:
		var pts := PackedVector2Array([from])
		pts.append_array(nav_grid.route(from, goal))
		var left := RESCUE_HOP_PX
		for k in range(1, pts.size()):
			var leg := pts[k - 1].distance_to(pts[k])
			if leg >= left:
				ahead = pts[k - 1].move_toward(pts[k], left)
				break
			left -= leg
			ahead = pts[k]
		if ahead == Vector2.INF:
			ahead = from.move_toward(goal, RESCUE_HOP_PX)
		ahead = nav_grid.nearest_walkable(ahead, 6)
		if not nav_grid.is_walkable(ahead):
			return Vector2.INF
	else:
		ahead = _terrain_free_position(from.move_toward(goal, RESCUE_HOP_PX),
			20.0, [], 60.0, true)
	if ahead == Vector2.INF or ahead.distance_to(from) < 12.0:
		return Vector2.INF
	return ahead


# --- world generation --------------------------------------------------------

func generate_world() -> void:
	spawn_entity("city", 1, city_position)
	register_footprint(city_position, FOOTPRINT_RADIUS["city"])
	spawn_entity("pig_pen", 1, pig_pen_position)
	register_footprint(pig_pen_position, FOOTPRINT_RADIUS["pig_pen"])
	spawn_entity("cow_pen", 1, cow_pen_position)
	register_footprint(cow_pen_position, FOOTPRINT_RADIUS["cow_pen"])
	spawn_entity("lair", 1, lair_position)     # solid like other mountains
	register_footprint(lair_position, FOOTPRINT_RADIUS["lair"])
	# Goblin Mountain first: early footprint registration keeps scenery,
	# fields and mines from crowding the tribe's home rock.
	spawn_goblin_mountain()
	spawn_entity("tower", 1, tower_position)   # wizard upgrades landmark
	register_footprint(tower_position, FOOTPRINT_RADIUS["tower"])
	spawn_fields()
	# Scenery avoids ALL registered footprints (landmarks + fields) with
	# per-spot radius padding — no more visual overlaps with the farm belt.
	spawn_scenery()
	merge_adjacent_lakes()
	if active_layout != null and not _mask_empty.get("mines", true):
		# Mask-scattered mines: one placement per mine, each anchored on a
		# bright mines-mask pixel (miner work spots snap to them below).
		for i in mine_count:
			var mine_position := _mask_anchor("mines", FOOTPRINT_RADIUS["mine"])
			if mine_position == Vector2.INF:
				continue
			spawn_entity("mine", 1, mine_position)
			_mine_spots.append(mine_position)
	else:
		spawn_entity("mine", mine_count, mine_center, 180.0)
	spawn_farmers()
	spawn_entity("soldier", initial_soldier_count, rally_point, 90.0)
	soldiers_spawned = initial_soldier_count
	# Founding goblin takes up residence right away (1/minute tops up to 6);
	# the mountain itself was placed at generation start, before scenery.
	spawn_goblin()
	if farmer_count >= miner_spawn_requirement_farmers:
		spawn_entity("miner", initial_miner_count, mine_center, 140.0)
	create_boundaries()


## Fields ring the farm belt — deliberately FARTHER from the city (user
## request): each placement resolves against the whole footprint registry
## (landmarks AND each other) so plots never collide before anything is
## placed on top.
func spawn_fields() -> void:
	var field_radius: float = FOOTPRINT_RADIUS["field"]
	for i in field_count:
		var position: Vector2
		if active_layout != null and not _mask_empty.get("fields", true):
			# Layout mode: fields land wherever the fields mask is painted.
			position = _mask_anchor("fields", field_radius)
			if position == Vector2.INF:
				position = _clamp_to_interior(city_position, field_radius)
		else:
			# Procedural fallback: the farm belt ring around the city.
			var angle := TAU * float(i) / float(field_count) + 0.4
			var anchor := _clamp_to_interior(
				city_position + Vector2.RIGHT.rotated(angle) * 420.0, field_radius)
			position = _terrain_free_position(anchor, field_radius)
			if position == Vector2.INF:
				position = anchor  # map too crowded at this spot; never lose a field
		spawn_entity("field", 1, position)
		register_footprint(position, field_radius)
		field_positions.append(position)


## One farmer per field-ish position; the rest drift near the pens.
## Bug fix (2026-11-08): this was the only caller of _terrain_free_position
## without an INF fallback — a crowded spot spawned a farmer AT Vector2.INF,
## whose physics then NaN'd forever (the "normalize" warning spam + a farmer
## that never farms). Fallback = the clamped anchor itself.
func spawn_farmers() -> void:
	for i in farmer_count:
		var anchor := field_positions[i % field_positions.size()] \
			if field_positions.size() > 0 else city_position
		var position := _terrain_free_position(
			_clear_position(anchor, 40.0), 40.0)
		if position == Vector2.INF:
			position = _clamp_to_interior(anchor, 40.0)
		var farmer: Node = (entity_scenes["farmer"] as PackedScene).instantiate()
		farmer.global_position = position
		add_child(farmer)
		setup_entity("farmer", farmer)
		entity_spawned.emit("farmer", position)


## Blocking scenery: trees, lakes, mountains — placed clear of EVERYTHING in
## the footprint registry (landmarks, fields) with proper radius padding.
## Only the dragon's spawn clearing stays a special protected spot.
## Layout mode (2026-11-12-world-editor): the two tree densities come from
## their own masks (user spec), lakes from the lakes mask, and mountains
## from the mountains mask (2026-11-13 user request — an empty/unpainted
## mountains mask falls back to random via _mask_anchor, so pre-existing
## saved worlds keep generating); no layout → the legacy random scatter.
func spawn_scenery() -> void:
	var protected: Array = [
		{"pos": Vector2.ZERO, "pad": 90.0},  # dragon start
	]
	if active_layout != null:
		_spawn_scenery_batch("forest_dense", tree_dense_count, 0, protected)
		_spawn_scenery_batch("forest_sparse", tree_sparse_count, 0, protected)
		_spawn_scenery_batch("lakes", lake_count, 1, protected)
		_spawn_scenery_batch("mountains", mountain_count, 2, protected)
		return
	var counts := [tree_count, lake_count, mountain_count]
	for kind_id in counts.size():
		for i in counts[kind_id]:
			var scene: PackedScene = scenery_scenes[kind_id]
			var obstacle := scene.instantiate()
			var radius := _scenery_radius(kind_id, obstacle)
			var position := _terrain_free_position(
				get_random_position(), radius, protected, 110.0)
			if position == Vector2.INF:
				obstacle.free()
				continue  # map too crowded at this spot; skip
			obstacle.global_position = position
			add_child(obstacle)
			register_footprint(position, radius)
			entity_spawned.emit("terrain", position)


## One masked scenery batch (shared by the layout-mode loops above).
func _spawn_scenery_batch(category: String, count: int, kind_id: int,
	protected: Array) -> void:
	for i in count:
		var scene: PackedScene = scenery_scenes[kind_id]
		var obstacle := scene.instantiate()
		var radius := _scenery_radius(kind_id, obstacle)
		var position := Vector2.INF
		if obstacle is Mountain and category != "":
			# A big mountain may not fit its painted region: step DOWN a
			# size and retry inside the mask; never fall back off-mask.
			var mountain := obstacle as Mountain
			while true:
				position = _mask_anchor(category, radius, protected, 110.0, false)
				if position != Vector2.INF or mountain.size_index == 0:
					break
				mountain.size_index -= 1
				radius = mountain.footprint_radius()
		else:
			position = _mask_anchor(category, radius, protected, 110.0) \
				if category != "" else _terrain_free_position(
					get_random_position(), radius, protected, 110.0)
		if position == Vector2.INF:
			obstacle.free()
			continue  # map too crowded at this spot; skip
		obstacle.global_position = position
		add_child(obstacle)
		register_footprint(position, radius)
		entity_spawned.emit("terrain", position)


## Placement radius for one scenery piece. Mountains roll their variant +
## size (2026-11-13: three artworks x three sizes) with the world RNG BEFORE
## placement, so spacing clears the mountain's real base, not a fixed guess.
func _scenery_radius(kind_id: int, obstacle: Node) -> float:
	if obstacle is Mountain:
		return (obstacle as Mountain).roll(_rng)
	return [22.0, 66.0, 60.0][kind_id]


## Merge OVERLAPPING lakes into one (2026-11-13 user spec: "if two lakes
## end up overlapping, merge them into one lake"). Lakes whose collision
## circles intersect — chains included — cluster together, and each
## cluster becomes ONE lake covering the union: area-weighted centroid as
## the center, radius grown to cover every member. The scene's SHARED
## shape SubResource is replaced with a fresh CircleShape2D first
## (mutating the shared one would resize every lake at once), the sprite
## scales to match, and the merged footprint is registered with its real
## radius. Placement already keeps fresh lakes 30px apart, so generated
## worlds rarely trigger this — it is the guarantee when overlaps do
## appear (and it replaces the old 50px "near" merge, which fused lakes
## that were NOT touching and replaced them with a smaller lake).
func merge_adjacent_lakes() -> void:
	var circles: Array = []  # [StaticBody2D, Vector2 center, float radius]
	for lake: Node in get_tree().get_nodes_in_group("water"):
		var body := lake as StaticBody2D
		if body == null:
			continue
		var col := body.get_node_or_null("CollisionShape2D") \
			as CollisionShape2D
		var radius := 62.0
		if col != null and col.shape is CircleShape2D:
			radius = (col.shape as CircleShape2D).radius
		circles.append([body, body.global_position, radius])
	if circles.size() < 2:
		return
	# Union-find clustering: link every pair of intersecting circles.
	var parent: Array[int] = []
	parent.resize(circles.size())
	for i in circles.size():
		parent[i] = i
	for i in circles.size():
		for j in range(i + 1, circles.size()):
			var dist: float = (circles[i][1] as Vector2) \
				.distance_to(circles[j][1] as Vector2)
			if dist >= float(circles[i][2]) + float(circles[j][2]):
				continue  # not overlapping
			var ri := _find_root(parent, i)
			var rj := _find_root(parent, j)
			if ri != rj:
				parent[rj] = ri
	# Gather cluster members under their root index.
	var clusters := {}  # root index → Array of member indices
	for i in circles.size():
		var root := _find_root(parent, i)
		if not clusters.has(root):
			clusters[root] = []
		(clusters[root] as Array).append(i)
	for root: int in clusters:
		var members: Array = clusters[root]
		if members.size() < 2:
			continue
		# Area-weighted centroid, then the radius that covers the union.
		var center := Vector2.ZERO
		var weight_sum := 0.0
		for idx: int in members:
			var c: Array = circles[idx]
			var weight: float = float(c[2]) * float(c[2])
			center += (c[1] as Vector2) * weight
			weight_sum += weight
		center /= weight_sum
		var radius := 0.0
		for idx: int in members:
			var c: Array = circles[idx]
			radius = maxf(radius,
				center.distance_to(c[1] as Vector2) + float(c[2]))
		# Reuse the FIRST member as the merged lake; absorb the rest.
		var keep := circles[members[0]][0] as StaticBody2D
		var shape := CircleShape2D.new()
		shape.radius = radius
		(keep.get_node("CollisionShape2D") as CollisionShape2D).shape = shape
		keep.global_position = center
		var spr := keep.get_node_or_null("Sprite") as Sprite2D
		if spr != null:
			# native shape is r=62; the SVG imports at 2x (crisp), hence 0.5
			spr.scale = Vector2.ONE * (radius / 62.0) * 0.5
		for k in range(1, members.size()):
			(circles[members[k]][0] as Node).queue_free()
		register_footprint(center, radius)
		print(("WorldManager: merged %d overlapping lakes into one "
			+ "(radius %.0f at %s)") % [members.size(), radius, str(center)])


func _find_root(parent: Array[int], i: int) -> int:
	var r := i
	while parent[r] != r:
		r = parent[r]
	return r


## Jitter around an anchor until the spot is reasonably free (checks the
## whole footprint registry); `protected` overrides use dict spots:
## {"pos": Vector2, "pad": float} — blocked inside protected_margin + pad.
## Every candidate is clamped into the interior band minus self_radius —
## large attempt-based jitter (up to ±276px) can otherwise escape the band.
func _terrain_free_position(anchor: Vector2, self_radius: float,
	protected := [] as Array, protected_margin := 90.0,
	nearest := false) -> Vector2:
	var best := Vector2.INF
	var best_dist := INF
	for attempt in 24:
		var candidate := _clamp_to_interior(anchor + Vector2(
			_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)
		) * float(attempt) * 12.0, self_radius)
		if candidate.distance_to(city_position) < 140.0:
			continue
		if candidate.distance_to(Vector2.ZERO) < 120.0:
			continue  # keep dragon's start spot open
		var blocked := false
		for clearance: Dictionary in _terrain_clearances:
			if candidate.distance_to(clearance["pos"]) \
					< self_radius + float(clearance["radius"]) + 30.0:
				blocked = true
				break
		if blocked:
			continue
		var clear := true
		for spot: Dictionary in protected:
			if candidate.distance_to(spot["pos"]) \
					< protected_margin + float(spot.get("pad", 0.0)):
				clear = false
				break
		if not clear:
			continue
		if not nearest:
			return candidate
		var dist := candidate.distance_to(anchor)
		if dist < best_dist:
			best_dist = dist
			best = candidate
	return best


func _clear_position(anchor: Vector2, spread: float) -> Vector2:
	return anchor + Vector2(
		_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))


## PUBLIC terrain-safe target for NPC target providers (2026-11-09): NPCs may
## only TRIP toward spots that can actually be stood on — inside a city wall
## or a pen footprint the raycast detours never converge (forensic finding:
## soldiers ground to a halt in MOVING for 99s+ with goals inside the city).
## Tries a jitter search (same rules as spawn placement), falls back to the
## interior-clamped anchor itself.
func terrain_free_target(anchor: Vector2, self_radius: float) -> Vector2:
	var spot := _terrain_free_position(
		_clear_position(anchor, self_radius), self_radius)
	return _clamp_to_interior(anchor, self_radius) if spot == Vector2.INF \
		else spot


## PUBLIC playfield clamp (2026-11-09): flee targets use it so an NPC pushed
## toward the boundary keeps a slide-along-the-wall target instead of a pin-
## point into the walls (the neighboring body keeps the pressure and the
## runner wedges — "miners stuck on the border"). Same interior band as all
## placement, padded by the caller's own radius.
func clamp_into_playfield(pos: Vector2, self_radius := 0.0) -> Vector2:
	return _clamp_to_interior(pos, self_radius)


# --- spawn plumbing ---------------------------------------------------------

## Position rules: anchor INF → random on the map; spread 0 → anchor exact
## (city, pens); otherwise jitter around the anchor, clear of scenery.
func spawn_entity(entity_type: String, count: int, anchor := Vector2.INF,
	spread := 0.0) -> void:
	if not entity_scenes.has(entity_type):
		push_error("Unknown entity type: %s" % entity_type)
		return
	for i in count:
		var scene: PackedScene = entity_scenes[entity_type] as PackedScene
		if scene == null:
			continue
		var instance: Node = scene.instantiate()
		var position: Vector2
		if anchor == Vector2.INF:
			position = get_random_position()
		elif spread <= 0.0:
			position = anchor
		else:
			position = _terrain_free_position(_clear_position(anchor, spread), 24.0)
			if position == Vector2.INF:
				position = anchor  # fall back to the anchor; never lose the spawn
		instance.global_position = position
		add_child(instance)          # _ready runs: subclass configures itself
		setup_entity(entity_type, instance)  # then we override the anchors
		entity_spawned.emit(entity_type, position)


## Rewiring point: NPC output signals → GameManager (the hub) + anchor setup.
## Called AFTER add_child so overrides beat BaseNPC's spawn-relative defaults.
func setup_entity(entity_type: String, instance: Node) -> void:
	if game_manager == null:
		game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	match entity_type:
		"farmer":
			var farmer := instance as NPCFarmer
			if farmer != null:
				farmer.home_position = farmer.global_position
				farmer.town_position = city_position + Vector2(0, -90)  # north gate
				farmer.pig_pen_position = pig_pen_position
				farmer.food_delivered.connect(_on_food_delivered)
				farmer.npc_died.connect(_on_npc_died.bind(farmer))
		"miner":
			var miner := instance as Miner
			if miner != null:
				miner.home_position = miner.global_position
				miner.mine_position = _mine_spot()
				miner.town_position = city_position + Vector2(0, -90)
				miner.resource_delivered.connect(_on_resource_delivered)
				miner.npc_died.connect(_on_npc_died.bind(miner))
		"soldier":
			var soldier := instance as Soldier
			if soldier != null:
				soldier.home_position = soldier.global_position
				soldier.npc_died.connect(_on_npc_died.bind(soldier))
		"goblin":
			# Goblin extends BaseNPC - anchors make the trade legs walkable:
			# gold is fetched at the nearest mine, transacted at the lair.
			var goblin_base := instance as BaseNPC
			if goblin_base != null:
				goblin_base.home_position = goblin_base.global_position
				goblin_base.mine_position = _mine_spot()
				goblin_base.npc_died.connect(_on_npc_died.bind(goblin_base))
		"adventurer":
			# The hero anchors at his spawn spot; the haul leg targets the
			# city gate via WorldManager.city_position (see _pick_home_target).
			var hero := instance as Adventurer
			if hero != null:
				hero.home_position = hero.global_position
		"mine":
			var mine := instance as Node2D
			if mine != null:
				# Live mine registry: goblin "go fetch at a NEARBY mine" needs
				# mine NODES to pick from, and the minimap's "mines" dot pass
				# scanned this group name long before it had members.
				mine.add_to_group("mines")
				register_footprint(mine.global_position, FOOTPRINT_RADIUS["mine"])
		"sacrifice":
			# Sacrifices are non-colliding markers for the story popup system
			var sacrifice := instance as Sacrifice
			if sacrifice != null:
				# Add to a group for the dragon to find during encounter checks
				sacrifice.add_to_group("sacrifice")


## Spawn a sacrifice near the given position (when 3 fields are burnt)
func _spawn_sacrifice(burnt_field_position: Vector2) -> void:
	print("WorldManager: Spawning sacrifice after %d fields burnt" % fields_burnt_count)
	# Spawn the sacrifice near the burnt field position
	var scene: PackedScene = entity_scenes.get("sacrifice")
	if scene == null:
		push_error("WorldManager: sacrifice scene not found in entity_scenes")
		return
	var instance: Node = scene.instantiate()
	var position: Vector2
	# Spawn near the burnt field (with some jitter)
	var jitter := Vector2(randf_range(-50.0, 50.0), randf_range(-50.0, 50.0))
	position = burnt_field_position + jitter
	# Clamp to interior and ensure terrain-free
	position = _clamp_to_interior(position, 20.0)
	position = _terrain_free_position(position, 20.0)
	if position == Vector2.INF:
		position = burnt_field_position  # fallback to original position
	instance.global_position = position
	add_child(instance)
	setup_entity("sacrifice", instance)
	print("WorldManager: Sacrifice spawned at %s" % str(position))


## Jittered position inside the mining district (spreads miners across it).
## Layout mode: miners work the REAL mask-scattered mines instead.
func _mine_spot() -> Vector2:
	if _mine_spots.size() > 0:
		var spot: Vector2 = _mine_spots[_rng.randi_range(0, _mine_spots.size() - 1)]
		return spot + Vector2(_rng.randf_range(-24, 24), _rng.randf_range(-24, 24))
	return mine_center + Vector2(_rng.randf_range(-160, 160), _rng.randf_range(-160, 160))


func get_random_position() -> Vector2:
	var margin := 100.0
	return Vector2(
		_rng.randf_range(-world_size.x / 2 + margin, world_size.x / 2 - margin),
		_rng.randf_range(-world_size.y / 2 + margin, world_size.y / 2 - margin)
	)


## Invisible walls at the world edges (keeps entities on the map).
func create_boundaries() -> void:
	for wall: Dictionary in [
		{"size": Vector2(20.0, world_size.y), "pos": Vector2(-world_size.x / 2, 0.0)},
		{"size": Vector2(20.0, world_size.y), "pos": Vector2(world_size.x / 2, 0.0)},
		{"size": Vector2(world_size.x, 20.0), "pos": Vector2(0.0, -world_size.y / 2)},
		{"size": Vector2(world_size.x, 20.0), "pos": Vector2(0.0, world_size.y / 2)},
	]:
		var wall_body := StaticBody2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wall["size"]
		var collision := CollisionShape2D.new()
		collision.shape = shape
		wall_body.add_child(collision)
		wall_body.position = wall["pos"]
		add_child(wall_body)


# --- goblin spawning ---------------------------------------------------------

## Place the dedicated Goblin Mountain (user spec): the tribe's own rock,
## close to the lair. Placed at generation start — well before scenery,
## fields and mines — and its registered footprint keeps everything else
## clear of the rock.
func spawn_goblin_mountain() -> void:
	var mountain := (scenery_scenes[2] as PackedScene).instantiate() as Node2D
	if mountain == null:
		push_warning("WorldManager: Goblin Mountain scene failed to load")
		return
	if mountain is Mountain:
		# Any artwork, but medium size: its footprint was reserved up front.
		(mountain as Mountain).size_index = 1
		(mountain as Mountain).roll(_rng)
	mountain.global_position = goblin_mountain_position
	add_child(mountain)
	register_footprint(goblin_mountain_position, FOOTPRINT_RADIUS["mountain"])
	goblin_mountain = mountain
	print("Goblin Mountain designated at %s (%dpx from the lair)" % [
		goblin_mountain_position,
		int(goblin_mountain_position.distance_to(lair_position))])


## Resolve the tribe's home rock: the dedicated Goblin Mountain, with a
## nearest-to-lair fallback if the world freed it later (run-length edge
## cases in long play sessions).
func _designate_goblin_mountain() -> void:
	if goblin_mountain != null and is_instance_valid(goblin_mountain):
		return
	var best: Node2D = null
	var best_dist := INF
	for node: Node in get_tree().get_nodes_in_group("mountains"):
		var mountain := node as Node2D
		if mountain == null or not is_instance_valid(mountain):
			continue
		var dist := mountain.global_position.distance_to(lair_position)
		if dist < best_dist:
			best_dist = dist
			best = mountain
	goblin_mountain = best
	if goblin_mountain == null:
		push_warning("WorldManager: no mountain for the goblin tribe")


## Spawn ONE goblin at the Goblin Mountain (user spec: 1/minute, max 6).
## Each goblin spawns on a ring around the rock — outside the body, with a
## little jitter so the tribe members don't stack in a tower.
func spawn_goblin() -> void:
	if _goblin_count >= MAX_GOBLINS:
		return
	if goblin_mountain == null or not is_instance_valid(goblin_mountain):
		_designate_goblin_mountain()
		if goblin_mountain == null:
			push_warning("WorldManager: no mountain for the goblin tribe")
			return
	var angle := randf() * TAU
	var position := goblin_mountain.global_position \
		+ Vector2(cos(angle), sin(angle)) * GOBLIN_SPAWN_RING \
		+ Vector2(randf_range(-GOBLIN_SPAWN_JITTER, GOBLIN_SPAWN_JITTER),
			randf_range(-GOBLIN_SPAWN_JITTER, GOBLIN_SPAWN_JITTER))
	position = clamp_into_playfield(position, 12.0)
	var goblin := (entity_scenes["goblin"] as PackedScene).instantiate() as Node
	if goblin == null:
		return
	goblin.global_position = position
	add_child(goblin)
	setup_entity("goblin", goblin)
	_goblin_count += 1
	print("Goblin spawned at %s (tribe size: %d/%d)" % [
		goblin.global_position, _goblin_count, MAX_GOBLINS])


## Get the city position for distance calculations
func get_city_position() -> Vector2:
	# Return the city_position export variable
	return city_position


## The tribe's answer to the encounter story (came via GameManager's
## story_choice_made). Choice 0 = accept (BUYING), anything else = the
## tribe goes hostile (plunder mode sells nothing—the trade is over).
func _on_goblin_story_choice(kind: String, choice_index: int) -> void:
	if not kind.begins_with("goblin_encounter_"):
		return
	set_goblin_service(choice_index == 0)


func set_goblin_service(purchased: bool) -> void:
	if goblin_service_standing != Goblin.ServiceState.UNINITIALIZED:
		return
	goblin_service_standing = Goblin.ServiceState.BUYING if purchased \
		else Goblin.ServiceState.HOSTILE
	for node: Node in get_tree().get_nodes_in_group("goblins"):
		if node is Goblin:
			(node as Goblin)._on_service_response(purchased)


## Goblin death loot: drop gold on ground (20% chance if goblin had gold)
func handle_goblin_death_loot(goblin_position: Vector2) -> void:
	# Check if goblin had gold (20% chance)
	if randf() < 0.2:
		# Drop 5-10 gold on the ground
		var gold_amount: int = randi_range(5, 10)
		print("Goblin dropped %d gold at %s" % [gold_amount, str(goblin_position)])
		# Gold drop logic would update the game manager's treasure
		if game_manager != null:
			game_manager.treasury["gold"] += gold_amount
			print("Treasury updated: gold = %d" % game_manager.treasury["gold"])


# --- swarm tactics: CALM → RALLY → ATTACK ------------------------------------
##
## CALM  : soldiers patrol the city.
## RALLY : dragon approached the city — soldiers mass at the north gate.
## ATTACK: enough soldiers massed, dragon at the walls, or the King is up —
##         everyone hunts the dragon.

func _on_swarm_tick() -> void:
	# "dragon_threat": the farm girl is no threat — the city never rallies on her.
	var dragon := get_tree().get_first_node_in_group("dragon_threat") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return
	var dragon_dist := dragon.global_position.distance_to(city_position)
	var gathered := _gathered_count()
	match swarm_state:
		SwarmState.CALM:
			if dragon_dist < rally_range:
				_set_swarm_state(SwarmState.RALLY)
		SwarmState.RALLY:
			if dragon_dist < attack_range_city or gathered >= swarm_size:
				_set_swarm_state(SwarmState.ATTACK)
		SwarmState.ATTACK:
			# Disengage when the dragon leaves the city area for good.
			if dragon_dist > rally_range * 2.0:
				_set_swarm_state(SwarmState.CALM)

func _gathered_count() -> int:
	var count := 0
	for soldier: Node in get_tree().get_nodes_in_group("soldiers"):
		var npc := soldier as BaseNPC
		if npc != null and npc.is_alive \
				and npc.global_position.distance_to(rally_point) < swarm_gather_radius:
			count += 1
	return count

func _set_swarm_state(new_state: SwarmState) -> void:
	if swarm_state == new_state:
		return
	swarm_state = new_state
	print("Swarm state: ", ["CALM", "RALLY", "ATTACK"][int(new_state)])
	swarm_state_changed.emit(new_state)

## Called by Soldier when it spots the dragon close-in — but only raises the
## alarm when the sighting is cityward; the city gate is what gets defended.
func report_dragon_sighting(sighting_position: Vector2) -> void:
	if swarm_state == SwarmState.CALM \
			and sighting_position.distance_to(city_position) < rally_range * 1.4:
		_set_swarm_state(SwarmState.RALLY)


## Treasure spilled in the streets (miners panic-dropping) is a visible dragon
## crime: soldiers skip the RALLY gathering and hunt now. Called by Miner.
func report_loot_spill() -> void:
	if swarm_state != SwarmState.ATTACK:
		_set_swarm_state(SwarmState.ATTACK)

# --- escalation --------------------------------------------------------------

## The King arrives once the town has fielded king_threshold soldiers in
## total (initial + timer trickle + treasury purchases) — decision
## 2026-11-09 keeps the same threshold for the new purchase model.
func _escalation_soldier_spawned() -> void:
	soldiers_spawned += 1
	if game_manager != null:
		game_manager.increment_soldier_count()
	if soldiers_spawned >= king_threshold:
		spawn_king()

func _on_escalation_tick() -> void:
	# Recruit trickle keeps running during the boss battle (2026-11-09,
	# user: "soldiers should always be coming") — the King fights a living
	# army, and _escalation_soldier_spawned's spawn_king() call is already
	# a no-op while one is out.
	if game_manager == null or _dragon_hidden() or _invasion_on():
		return   # no dragon in sight (or the realm's war is over): no recruits
	spawn_entity(_next_recruit_type(), 1, rally_point, 90.0)
	_escalation_soldier_spawned()


func _on_goblin_spawn_tick() -> void:
	# Spawn a goblin if under the tribe limit
	if _goblin_count >= MAX_GOBLINS:
		return
	spawn_goblin()


# --- adventurer spawning (2026-11-12, user spec) ------------------------------

## Hero trigger (2026-11-13 user spec): "as soon as there are 10gp in the
## treasure" — event-driven off GameManager.stash_changed instead of the
## old 300 s timer. Gold only (the raid itself steals gold only). The cap
## is still counted by GROUP size, not a death counter: the successful hero
## leaves via queue_free after the treasury deposit (no die() → no
## npc_died), so a death-tracked counter would leak the slot and silently
## stop all future spawns.
func _on_stash_changed(res_type: String, amount: int) -> void:
	if res_type != "gold" or amount < adventurer_gold_trigger:
		return
	if get_tree().get_nodes_in_group("adventurers").size() \
			>= adventurer_max_alive:
		return
	spawn_adventurer()


## Spawn the wandering adventurer at the CITY (north-gate side, same door
## the King materializes at). His home anchor is the spawn spot; the haul
## leg targets the city gate itself.
func spawn_adventurer() -> void:
	var scene := entity_scenes.get("adventurer") as PackedScene
	if scene == null:
		push_warning("WorldManager: adventurer scene not found in entity_scenes")
		return
	var hero := scene.instantiate() as Adventurer
	if hero == null:
		return
	var position := city_position + Vector2(0, -140) \
		+ Vector2(randf_range(-30, 30), randf_range(-10, 10))
	hero.global_position = clamp_into_playfield(position, 12.0)
	add_child(hero)
	setup_entity("adventurer", hero)
	print("An adventurer strides out of the city gates — sword on his hip, backpack full of hope!")
	entity_spawned.emit("adventurer", hero.global_position)


func _on_goblin_raid_tick() -> void:
	# 20% chance to trigger a raiding party
	if randf() < 0.2:
		print("RAID! All goblins going on a plundering spree!")
		_start_goblin_raid()


func _start_goblin_raid() -> void:
	# Set all goblins to hostile and attack farmers/miners
	for goblin in get_tree().get_nodes_in_group("goblins"):
		if goblin.has_method("set_service_state_hostile"):
			goblin.set_service_state_hostile()
			goblin.goblin_raid_active = true
			print("Goblin raid mode activated!")
	
	# End raid after 30 seconds
	_raid_timer = Timer.new()
	_raid_timer.wait_time = 30.0
	_raid_timer.one_shot = true
	_raid_timer.timeout.connect(_end_goblin_raid)
	_raid_timer.timeout.connect(_raid_timer.queue_free)
	# add_child BEFORE start (2026-11-14 fix): a Timer outside the tree
	# refuses to start, so raids never ended — goblins stayed hostile.
	add_child(_raid_timer)
	_raid_timer.start()


func _end_goblin_raid() -> void:
	# End raid mode for all goblins
	for goblin in get_tree().get_nodes_in_group("goblins"):
		if goblin.has_method("set_raid_active"):
			goblin.set_raid_active(false)
			print("Goblin raid mode ended!")


# --- treasury soldier purchases (2026-11-09) ----------------------------------

## One soldier per 2 gold OR 2 soldiers per 1 gem — user spec, gold spent
## first so gold-only shop stock (Brute Force) stays meaningful. The town
## drains the treasury continuously: every miner delivery plus a 1s spend
## heartbeat. The 8s escalation timer still runs as the bare trickle.
@export_group("SoldierPurchases")
@export var soldier_gold_cost: int = 2
@export var soldiers_per_gem: int = 2
@export var soldier_purchase_interval: float = 1.0

var _purchase_timer: Timer

func _try_buy_soldiers() -> void:
	# king_spawned removed from the guard (2026-11-09, user: "soldiers should
	# always be coming, especially if there are treasure in the treasury"):
	# the town keeps buying through the boss battle, so the King fights a
	# constantly refreshed army instead of a frozen 15.
	if game_manager == null or game_manager.run_finished or _dragon_hidden() or _invasion_on():
		return   # the treasury keeps its coin until there is a dragon to fight
	# NOTE: no gem reserve for the goblin trade anymore (2026-11-10): the
	# exchange moved to the dragon's STASH — the town's gems keep converting
	# to soldiers exactly as the 2026-11-09 user spec.
	var bought := 0
	var gold_spent := 0
	var gems_spent := 0
	while game_manager.spend_treasury("gold", soldier_gold_cost):
		bought += 1
		gold_spent += soldier_gold_cost
	while game_manager.spend_treasury("gems", 1):
		bought += soldiers_per_gem
		gems_spent += 1
	if bought == 0:
		return
	for i in bought:
		# one spawn per bought unit so the Archer rotation lands per unit
		spawn_entity(_next_recruit_type(), 1, rally_point, 90.0)
		_escalation_soldier_spawned()
	print("City bought %d soldier(s) with treasury funds — spent %d gold, %d gems (%d fielded total, %d gold / %d gems left)"
		% [bought, gold_spent, gems_spent, soldiers_spawned,
			game_manager.treasury["gold"], game_manager.treasury["gems"]])


## The final boss arrives at the city. Two lives (2026-11-15, user: "the
## King only deserves two lives" — was four: 2026-11-09-king-lives had him
## rise three times): he rises ONCE after his first fall; the second fall
## is the true one and opens the aftermath.
@export var king_respawn_count: int = 1
var king_respawns_left: int = 1

## Recruit rotation (2026-11-09 archer addition): every THIRD fielded unit
## is an Archer — a ranged soldier that peppers the dragon from the mortars-
## out-of-breath range with 5-dmg arrows. Counts toward the King threshold
## via _escalation_soldier_spawned like any soldier.
func _next_recruit_type() -> String:
	return "archer" if soldiers_spawned % 3 == 2 else "soldier"

func spawn_king() -> void:
	if king_spawned:
		return
	king_spawned = true
	# _soldier_timer deliberately KEEPS running (2026-11-09): recruits keep
	# arriving at the rally point during the boss battle.
	king_respawns_left = king_respawn_count
	_materialize_king()
	print("The King has arrived! (%d soldiers spawned)" % soldiers_spawned)

## The re-summon path: scheduled by on_king_defeated one defeat at a time.
func _materialize_king() -> void:
	var king := entity_scenes["king"].instantiate() as King
	king.global_position = city_position + Vector2(0, -140)
	add_child(king)
	var king_npc := king as BaseNPC
	if king_npc != null:
		king_npc.home_position = king.global_position
	# Pick a King story variant at random (user: 6 epic one-liners).
	var king_variants: Array[String] = [
		"king_defiant",
		"king_courageous",
		"king_challenger",
		"king_unbowed",
		"king_champion",
		"king_renegade",
	]
	var variant_idx := int(randi() % king_variants.size())
	var story_kind: String = king_variants[variant_idx]
	if game_manager != null:
		game_manager.notify_story(story_kind)
		game_manager.start_boss_battle(king)
		# The wizard's errand (2026-11-14): with the King on the march, a
		# living, still-kind Ambrose sends the dragon after the fen hag.
		if game_manager.story_mode and not game_manager.wizard_dead \
				and tower_wizard != null and is_instance_valid(tower_wizard) \
				and tower_wizard.is_kind():
			game_manager.notify_story("hag_quest")
	entity_spawned.emit("king", king.global_position)
	_set_swarm_state(SwarmState.ATTACK)

## The King has fallen — schedule the next life if any remain.
## Returns true when a respawn is planned (King.die skips the victory
## path then); false = last life spent → caller declares victory.
## Lives semantics: king_respawn_count = 1 → the King dies TWICE in total
## (first life + one rise). king_respawns_left counts remaining respawns
## after each decrement.
func on_king_defeated() -> bool:
	if game_manager == null or game_manager.run_finished:
		return false
	if king_respawns_left <= 0:
		return false
	king_respawns_left -= 1
	print("The King falls for now! (%d respawn(s) still to come)"
		% king_respawns_left)
	var respawn_timer := Timer.new()
	respawn_timer.wait_time = 3.0
	respawn_timer.one_shot = true
	respawn_timer.autostart = true
	respawn_timer.timeout.connect(func() -> void:
		print("The King rises again at the city! (%d respawn(s) left after this)"
			% king_respawns_left)
		_materialize_king()
	)
	add_child(respawn_timer)
	return true

# --- the backstabbing wizard (2026-11-09 user spec) ---------------------------

## He emerges from HIS tower when the dragon has crossed one of the
## provocation lines: bought 4+ upgrades (user, 2026-11-09: four) AND
## visited the tower more than 3 times, OR hoarded 20+ gold in the
## stash. Then he hunts the dragon across the whole map with lightning
## (30 dmg / 2s / long range) and never stops — see scripts/npcs/Wizard.gd.
@export_group("Wizard")
@export var wizard_upgrade_threshold: int = 4
@export var wizard_visit_threshold: int = 3     # "more than 3" → 4+
@export var wizard_stash_trigger: int = 20
## True once he has TURNED (kept under its old name: probes read it).
var wizard_spawned: bool = false
## The tower's master, kindly until provoked (2026-11-14 story arc).
var tower_wizard: Wizard = null

## Spawn the kind wizard at his doorstep (once, as soon as the world runs).
func _ensure_tower_wizard() -> void:
	if tower_wizard != null or wizard_spawned:
		return
	if game_manager != null and game_manager.wizard_dead:
		return   # he died in the ruins (opening chapter) — no wizard this run
	var wizard := entity_scenes["wizard"].instantiate() as Wizard
	wizard.start_kind = true
	var anchor := tower_position + Vector2(60, -40)
	wizard.global_position = anchor
	add_child(wizard)
	(wizard as BaseNPC).home_position = anchor
	tower_wizard = wizard
	entity_spawned.emit("wizard", wizard.global_position)

func _try_spawn_wizard() -> void:
	# Bug fix (2026-11-11, user: "the wizard never appears" after the King's
	# defeat): no run_finished gate — the backstabber turns whenever his
	# provocation lines are crossed, victory or not.
	if wizard_spawned or game_manager == null or game_manager.wizard_dead:
		return
	# His betrayal waits while the usurper's army is in the field (2026-11-15,
	# user: "I was defeated by the invading army because the wizard decided
	# to switch side"): he comes for the heart at the reckoning instead.
	if game_manager.phase == GameManager.Phase.INVASION:
		return
	_ensure_tower_wizard()
	var burned: bool = tower_wizard != null and is_instance_valid(tower_wizard) \
		and not tower_wizard.is_kind()
	var bought_enough: bool = game_manager.upgrade_purchases >= wizard_upgrade_threshold \
		and game_manager.tower_visits > wizard_visit_threshold
	var greedy: bool = int(game_manager.stash["gold"]) >= wizard_stash_trigger
	if not (bought_enough or greedy or burned):
		return
	wizard_spawned = true
	if tower_wizard == null or not is_instance_valid(tower_wizard):
		return
	tower_wizard.turned.connect(_on_wizard_turned, CONNECT_ONE_SHOT)
	tower_wizard.turn_evil()   # no-op if the dragon's fire already turned him

## The fall is complete: now the story names him.
func _on_wizard_turned() -> void:
	print("The wizard has turned — he hunts the dragon's heart!")
	if game_manager != null:
		game_manager.notify_story("wizard_emerge")

# --- the hag's nest (2026-11-14) ----------------------------------------------

const HAG_NEST_SCENE := preload("res://scenes/props/HagNest.tscn")
const FIR_TREE_SCENE := preload("res://scenes/props/FirTree.tscn")
const HAG_SCENE := preload("res://scenes/npcs/Hag.tscn")
var hag_nest_spawned := false
## Mother Grisla herself (null until the quest; freed after her death).
var fen_hag: Hag = null

func hag_alive() -> bool:
	return fen_hag != null and is_instance_valid(fen_hag) and fen_hag.is_alive

## The hag's warning over tea (2026-11-14): the dragon goes after the
## wizard NOW — the same fall as his provocation lines, just sooner.
func force_wizard_turn() -> bool:
	_ensure_tower_wizard()
	if tower_wizard == null or not is_instance_valid(tower_wizard) or not tower_wizard.is_alive:
		return false
	if not wizard_spawned:
		wizard_spawned = true
		tower_wizard.turned.connect(_on_wizard_turned, CONNECT_ONE_SHOT)
	tower_wizard.turn_evil()   # no-op if he already fell
	return true

## West of the dragon's mountain, a stand of firs, then the fen hut — and
## Mother Grisla prowling her doorstep.
func spawn_hag_nest() -> void:
	if hag_nest_spawned:
		return
	hag_nest_spawned = true
	# Due west first; when the map edge is too close (the lair often sits
	# near it), swing north-west / south-west until the fen lies a real
	# walk away from the mountain, with room for the firs in between.
	# Crowded maps: widen the search (every 30°, three distances) and only
	# then accept the nearest clear spot — never drop it onto the rock.
	var nest_pos := Vector2.INF
	var angles: Array[float] = [180.0, 150.0, 210.0, 120.0, 240.0, 90.0, 270.0, 60.0, 300.0, 30.0, 330.0, 0.0]
	for dist: float in [340.0, 440.0, 260.0]:
		for deg: float in angles:
			var dir := Vector2.RIGHT.rotated(deg_to_rad(deg))
			var anchor := _clamp_to_interior(lair_position + dir * dist, 95.0)
			if anchor.distance_to(lair_position) < 240.0:
				continue
			var spot := _terrain_free_position(anchor, 95.0)
			if spot != Vector2.INF and spot.distance_to(lair_position) >= 240.0:
				nest_pos = spot
				break
		if nest_pos != Vector2.INF:
			break
	if nest_pos == Vector2.INF:
		nest_pos = _terrain_free_position(
			_clamp_to_interior(lair_position + Vector2(-340.0, 160.0), 95.0), 95.0, [], 90.0, true)
	if nest_pos == Vector2.INF:
		nest_pos = _clamp_to_interior(lair_position + Vector2(-340.0, 160.0), 95.0)
	var nest := HAG_NEST_SCENE.instantiate() as Node2D
	nest.global_position = nest_pos
	add_child(nest)
	register_footprint(nest_pos, 95.0)
	entity_spawned.emit("terrain", nest_pos)
	# A few firs in the gap between the mountain and the fen.
	for i in 5:
		var t := 0.32 + 0.09 * float(i)
		var spot := lair_position.lerp(nest_pos, t) + Vector2(
			_rng.randf_range(-12.0, 12.0), _rng.randf_range(-70.0, 70.0))
		var free := _terrain_free_position(spot, 16.0)
		if free == Vector2.INF:
			continue
		var fir := FIR_TREE_SCENE.instantiate() as Node2D
		fir.global_position = free
		add_child(fir)
		register_footprint(free, 16.0)
	var hag := HAG_SCENE.instantiate() as Hag
	hag.nest_position = nest_pos + Vector2(0.0, 40.0)
	hag.global_position = hag.nest_position
	add_child(hag)
	(hag as BaseNPC).home_position = hag.nest_position
	fen_hag = hag
	entity_spawned.emit("hag", hag.global_position)
	print("WorldManager: the Hag's Nest rises in the fen at %s" % nest_pos)
	# New scenery: re-test the grid cells under the nest and its firs.
	var area := Rect2(nest_pos, Vector2.ZERO).grow(120.0)
	for fir_node: Node in get_tree().get_nodes_in_group("fir_trees"):
		area = area.expand((fir_node as Node2D).global_position)
	_refresh_nav_area(area.grow(40.0))

# --- the aftermath: the glade, the deer, the Prince (2026-11-15) --------------

## After the King's last fall (GameManager.begin_aftermath): a glade blooms
## on open ground away from every landmark, deer graze in it (one every
## DEER_EVERY s, at most DEER_MAX), and Prince Aurel strolls there until
## the farm girl meets him; after each meeting he goes back to the city
## road (relocate_prince).
const DEER_EVERY := 10.0
const DEER_MAX := 3
const GLADE_CLEARANCE := 330.0   # from city, lair, tower, nests, mountains
## The meadow's radius (mirrors Glade.RADIUS). The aftermath's new scripts
## (Glade, Deer, Prince) are reached through their instances, never by class
## name: an editor that has not rescanned yet does not know new class_names
## and refused to parse this whole file (2026-11-15).
const GLADE_RADIUS := 150.0
var glade_position := Vector2.INF
var prince: Node2D = null
var _deer_timer: Timer

func spawn_glade() -> void:
	if glade_position != Vector2.INF:
		return
	glade_position = _find_glade_spot()
	# The meadow is open: scenery trees standing inside it make way.
	for child: Node in get_children():
		var tree_node := child as Node2D
		if tree_node != null and tree_node.scene_file_path == "res://scenes/props/Tree.tscn" \
				and _in_meadow(tree_node.global_position, 1.15):
			tree_node.queue_free()
	var glade := (load("res://scenes/props/Glade.tscn") as PackedScene).instantiate() as Node2D
	glade.global_position = glade_position
	add_child(glade)
	# a ring of trees (they block like any tree; the grid learns them below)
	var tree_scene := load("res://scenes/props/Tree.tscn") as PackedScene
	for i in 6:
		var a := TAU * float(i) / 6.0 + randf_range(-0.25, 0.25)
		var spot := glade_position + Vector2.from_angle(a) * Vector2(205.0, 150.0)
		if nav_grid != null and nav_grid.is_built and not nav_grid.is_walkable(spot):
			continue
		var tree := tree_scene.instantiate() as Node2D
		tree.global_position = spot
		add_child(tree)
		register_footprint(spot, FOOTPRINT_RADIUS["tree"])
	_refresh_nav_area(Rect2(glade_position, Vector2.ZERO).grow(260.0))
	register_footprint(glade_position, 160.0)
	entity_spawned.emit("glade", glade_position)
	print("WorldManager: a glade blooms at %s" % glade_position)
	_deer_timer = Timer.new()
	_deer_timer.wait_time = DEER_EVERY
	_deer_timer.timeout.connect(_on_deer_timer)
	add_child(_deer_timer)
	_deer_timer.start()
	_on_deer_timer()
	spawn_prince()

## Open ground far from every landmark: score random walkable candidates
## by their distance to the nearest landmark; the meadow needs its radius
## clear on the grid too.
func _find_glade_spot() -> Vector2:
	var marks: Array[Vector2] = [city_position, lair_position, tower_position,
		goblin_mountain_position, pig_pen_position, cow_pen_position]
	for group: String in ["hag_nest", "mines", "fields"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			marks.append((node as Node2D).global_position)
	for m: Node in get_tree().get_nodes_in_group("mountains"):
		marks.append((m as Node2D).global_position)
	var half := world_size * 0.5 - Vector2(WORLD_MARGIN + 160.0, WORLD_MARGIN + 120.0)
	var best := Vector2.ZERO
	var best_score := -INF
	for i in 160:
		var p := Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
		var near := INF
		for m in marks:
			near = minf(near, p.distance_to(m))
		var clear := true
		if nav_grid != null and nav_grid.is_built:
			for k in 8:
				if not nav_grid.is_walkable(p + Vector2.from_angle(TAU * k / 8.0) * Vector2(130.0, 90.0)):
					clear = false
					break
		var score := near - (0.0 if clear else 1000.0)
		if score > best_score:
			best_score = score
			best = p
	return best

## Inside the meadow oval (Glade.RADIUS wide, a little flatter in y)?
func _in_meadow(p: Vector2, scale_by: float = 1.0) -> bool:
	var d := (p - glade_position) / (Vector2(GLADE_RADIUS, GLADE_RADIUS * 0.72) * scale_by)
	return d.length() <= 1.0

func _on_deer_timer() -> void:
	if get_tree().get_nodes_in_group("deer").size() >= DEER_MAX:
		return
	var deer := (load("res://scenes/npcs/Deer.tscn") as PackedScene).instantiate() as Node2D
	var spot := glade_position + Vector2.from_angle(randf() * TAU) * Vector2(110.0, 70.0)
	if nav_grid != null and nav_grid.is_built:
		spot = nav_grid.nearest_walkable(spot)
	deer.set("glade_center", glade_position)
	deer.global_position = spot
	add_child(deer)
	entity_spawned.emit("deer", spot)

func spawn_prince() -> void:
	if prince != null and is_instance_valid(prince):
		return
	prince = (load("res://scenes/npcs/Prince.tscn") as PackedScene).instantiate() as Node2D
	prince.global_position = glade_position + Vector2(-40.0, 20.0)
	add_child(prince)
	prince.set("home_position", prince.global_position)
	entity_spawned.emit("prince", prince.global_position)
	print("Prince Aurel walks in the glade, mourning his father.")

## After a meeting that did not end in a kiss: he goes back to the city
## road and strolls by the gate until she finds him again.
func relocate_prince() -> void:
	if prince == null or not is_instance_valid(prince):
		return
	var spot := city_position + Vector2(randf_range(-120.0, 120.0), -170.0 + randf_range(-30.0, 30.0))
	if nav_grid != null and nav_grid.is_built:
		spot = nav_grid.nearest_walkable(spot)
	prince.call("relocate", spot)

# --- the invasion (2026-11-15) --------------------------------------------------

## User: "create the trigger for the invasion. Create a new building: the
## invaders camp and spawn far away from the city so it becomes a tower
## defense situation. After the kiss and hand holding let the invaders
## come. Game over if the prince is killed. If the invading king dies,
## trigger the evil wizard to attack, and if he is dead too trigger the
## wedding."
##
## The camp rises on open ground as far from the city as the map allows.
## INVASION_SOLDIERS march out of its gate in INVASION_WAVES waves (one
## every WAVE_EVERY s, trickling out SPAWN_GAP s apart, at most
## MAX_INVADERS_ALIVE on the field); the usurper King rides with the last
## wave. They hunt the Prince, farmers and miners. Meanwhile the realm's
## own army lays down its arms (their King is dead) and the town stops
## recruiting, respawning and sending slayers.
##   lose  — the Prince dies, or no farmer or miner is left
##   win   — the usurper King falls → the army routs; the evil wizard
##           comes for the heart (GameManager.on_usurper_slain)
const INVASION_SOLDIERS := 200
## Ramping waves (sum = INVASION_SOLDIERS). First tuning (8 × 25, 28 s apart,
## 45 alive) wiped out an idle town in under a minute — too brutal.
const WAVE_SIZES: Array[int] = [10, 14, 18, 22, 26, 32, 36, 42]
const INVASION_WAVES := 8
const WAVE_EVERY := 40.0
const SPAWN_GAP := 0.35
const MAX_INVADERS_ALIVE := 30
const FIRST_WAVE_AFTER := 20.0
const USURPER_HP := 240

var invasion_active := false
var invasion_camp_position := Vector2.INF
var _wave := 0
var _wave_left := 0.0
var _to_spawn := 0
var _spawn_left := 0.0
var _invaders_spawned := 0
var _usurper_out := false
var _usurper: Node2D = null

func start_invasion() -> void:
	if invasion_active:
		return
	invasion_active = true
	invasion_camp_position = _find_camp_spot()
	var camp := (load("res://scenes/props/InvaderCamp.tscn") as PackedScene).instantiate() as Node2D
	camp.global_position = invasion_camp_position
	add_child(camp)
	entity_spawned.emit("invader_camp", invasion_camp_position)
	# The realm's army lays down its arms: their King is dead.
	for node: Node in get_tree().get_nodes_in_group("soldiers"):
		if node.has_method("retire") and node is BaseNPC and (node as BaseNPC).is_alive \
				and not node.is_in_group("king"):
			node.call("retire", city_position)
	_wave = 0
	_wave_left = FIRST_WAVE_AFTER
	# The Prince takes cover in the city.
	if prince != null and is_instance_valid(prince):
		prince.call("relocate", city_position + Vector2(0.0, -30.0))
	print("WorldManager: the usurper's camp stands at %s — %d soldiers in %d waves" % [
		invasion_camp_position, INVASION_SOLDIERS, INVASION_WAVES])

## As far from the city as possible, on open ground, clear of landmarks.
func _find_camp_spot() -> Vector2:
	var half := world_size * 0.5 - Vector2(WORLD_MARGIN + 170.0, WORLD_MARGIN + 120.0)
	var best := Vector2.ZERO
	var best_score := -INF
	for i in 120:
		var p := Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
		var score := p.distance_to(city_position)
		if glade_position != Vector2.INF and p.distance_to(glade_position) < 320.0:
			score -= 2000.0
		# keep the palisade off mines, fields, nests and mountains
		for group: String in ["mines", "fields", "hag_nest", "mountains"]:
			for node: Node in get_tree().get_nodes_in_group(group):
				if p.distance_to((node as Node2D).global_position) < 200.0:
					score -= 600.0
		if nav_grid != null and nav_grid.is_built and not nav_grid.is_walkable(p + Vector2(0.0, 110.0)):
			score -= 3000.0   # the gate must open onto walkable ground
		if score > best_score:
			best_score = score
			best = p
	return best

func _tick_invasion(delta: float) -> void:
	if not invasion_active:
		return
	if _wave < INVASION_WAVES and not _usurper_down():
		_wave_left -= delta
		if _wave_left <= 0.0:
			_wave += 1
			_wave_left = WAVE_EVERY
			_to_spawn += WAVE_SIZES[_wave - 1]
			if game_manager != null:
				game_manager.call("_hud_message", "Wave %d of %d marches out of the camp!" % [_wave, INVASION_WAVES], 3.0)
			if _wave == INVASION_WAVES:
				_spawn_usurper()
	_spawn_left -= delta
	if _to_spawn > 0 and _spawn_left <= 0.0 \
			and get_tree().get_nodes_in_group("invaders").size() < MAX_INVADERS_ALIVE:
		_spawn_left = SPAWN_GAP
		_to_spawn -= 1
		_spawn_invader()
	# Lose: nobody left to defend.
	if game_manager != null and invasion_townsfolk_left() == 0:
		invasion_active = false
		game_manager.invasion_lost("townsfolk")

func _camp_gate() -> Vector2:
	return invasion_camp_position + Vector2(0.0, 105.0)

func _spawn_invader() -> void:
	var inv := (load("res://scenes/npcs/Invader.tscn") as PackedScene).instantiate() as Node2D
	var spot := _camp_gate() + Vector2(randf_range(-40.0, 40.0), randf_range(-6.0, 20.0))
	if nav_grid != null and nav_grid.is_built:
		spot = nav_grid.nearest_walkable(spot)
	inv.set("city_target", city_position)
	inv.set("camp_position", invasion_camp_position)
	inv.global_position = spot
	add_child(inv)
	inv.set("home_position", spot)
	_invaders_spawned += 1

## The usurper: a King (King.tscn) flagged as the invader — no lives, more
## HP, his fall ends the invasion instead of opening the aftermath.
func _spawn_usurper() -> void:
	if _usurper_out:
		return
	_usurper_out = true
	var king := entity_scenes["king"].instantiate() as Node2D
	king.set("invader", true)
	king.global_position = _camp_gate()
	add_child(king)
	king.set("home_position", king.global_position)
	_usurper = king
	entity_spawned.emit("king", king.global_position)
	print("The usurper King rides out of the camp!")
	if game_manager != null:
		game_manager.call("_hud_message", "The usurper King rides out with the last wave! Slay him.", 5.0)

func _usurper_down() -> bool:
	return _usurper_out and (_usurper == null or not is_instance_valid(_usurper) \
		or not bool(_usurper.get("is_alive")))

## King.die() calls this for the usurper: the army breaks and runs.
func on_usurper_fallen() -> void:
	invasion_active = false
	_to_spawn = 0
	for node: Node in get_tree().get_nodes_in_group("invaders"):
		if node.has_method("rout") and bool(node.get("is_alive")):
			node.call("rout")
	if game_manager != null:
		game_manager.on_usurper_slain()

## The final reckoning: the evil wizard comes for the heart — if he still
## lives. Returns false when he is already dead (straight to the wedding).
func start_wizard_finale() -> bool:
	if game_manager != null and game_manager.wizard_dead:
		return false
	var wiz := tower_wizard
	if wiz == null or not is_instance_valid(wiz) or not wiz.is_alive:
		if wizard_spawned:
			return false          # he turned earlier and has been slain
		_ensure_tower_wizard()
		wiz = tower_wizard
		if wiz == null or not is_instance_valid(wiz):
			return false
	wiz.npc_died.connect(func(_t: String) -> void:
		if game_manager != null:
			game_manager.on_wizard_slain(), CONNECT_ONE_SHOT)
	force_wizard_turn()
	return true

## Win/lose bookkeeping.
func invasion_townsfolk_left() -> int:
	return get_tree().get_nodes_in_group("farmers").size() + get_tree().get_nodes_in_group("miners").size()

## Town systems that pause while the invasion runs (recruits, purchases,
## respawns, slayers): the realm's own war is over.
func _invasion_on() -> bool:
	return invasion_active or (game_manager != null and game_manager.phase >= GameManager.Phase.INVASION)

# --- the dragon slayer (2026-11-14) -------------------------------------------

## User: "a new NPC that appears randomly like the adventurer". One at a
## time: the first rides in after a few minutes, then another some minutes
## after each one falls (or while none is out). He enters from the map
## edge farthest from the dragon, on walkable ground. Not while the dragon
## hides as the farm girl (no dragon to hunt), nor after the run is over.
@export_group("Dragon slayer")
@export var slayer_first_min_s: float = 150.0
@export var slayer_first_max_s: float = 270.0
@export var slayer_again_min_s: float = 120.0
@export var slayer_again_max_s: float = 240.0
const DRAGON_SLAYER_SCENE := preload("res://scenes/npcs/DragonSlayer.tscn")
var _slayer_timer: Timer

func _on_slayer_timer() -> void:
	_slayer_timer.start(randf_range(slayer_again_min_s, slayer_again_max_s))
	if game_manager != null and game_manager.run_finished:
		return
	if not get_tree().get_nodes_in_group("dragon_slayer").is_empty() or _dragon_hidden() \
			or _invasion_on():
		return
	spawn_dragon_slayer()

func spawn_dragon_slayer() -> DragonSlayer:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	var from := dragon.global_position if dragon != null else Vector2.ZERO
	var half := world_size * 0.5 - Vector2(WORLD_MARGIN, WORLD_MARGIN)
	var best := Vector2.ZERO
	var best_d := -1.0
	for i in 12:
		var edge := Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
		if randf() < 0.5:
			edge.x = half.x * signf(randf() - 0.5)
		else:
			edge.y = half.y * signf(randf() - 0.5)
		if nav_grid != null and nav_grid.is_built:
			edge = nav_grid.nearest_walkable(edge)
		var d := edge.distance_to(from)
		if d > best_d:
			best_d = d
			best = edge
	var slayer := DRAGON_SLAYER_SCENE.instantiate() as DragonSlayer
	slayer.global_position = best
	add_child(slayer)
	slayer.home_position = best
	entity_spawned.emit("dragon_slayer", best)
	print("A dragon slayer rides into the realm — white horse, crimson plume, a lance like a church spire.")
	if game_manager != null:
		game_manager.call("_hud_message", "A dragon slayer rides into the realm! Fire won't touch him — use your claws.", 5.0)
	return slayer

# --- walkable-area grid (2026-11-14) -------------------------------------------

## NPC route planning (NavGrid): built once the generated scenery's bodies
## are in the physics space (one physics frame after generation); until
## then NPCs walk straight as before.
var nav_grid: NavGrid = null

func _build_nav_grid() -> void:
	await get_tree().physics_frame
	var grid := NavGrid.new()
	var t0 := Time.get_ticks_usec()
	grid.build(self, world_size)
	nav_grid = grid
	var solid := 0
	for y in grid.size.y:
		for x in grid.size.x:
			if grid.astar.is_point_solid(Vector2i(x, y)):
				solid += 1
	print("WorldManager: walkable grid %dx%d built in %.1f ms (%d%% blocked)" % [
		grid.size.x, grid.size.y, (Time.get_ticks_usec() - t0) / 1000.0,
		100 * solid / maxi(1, grid.size.x * grid.size.y)])

## Scenery appeared after generation: re-test those cells next physics frame.
func _refresh_nav_area(area: Rect2) -> void:
	await get_tree().physics_frame
	if nav_grid != null:
		nav_grid.refresh_area(area)

# --- signal handlers: NPC → GameManager (the hub) ---------------------------

func _process(delta: float) -> void:
	if not _invasion_on():
		_tick_respawn_queue(delta)
	_try_spawn_wizard()
	_tick_retirements(delta)
	_tick_invasion(delta)

# --- stand-down while the dragon hides (2026-11-14) ------------------------------

## User: "the King retires one soldier every 5s because there's no dragon
## threat. To a minimum of 4 soldiers." Runs only while the dragon wears
## the farm girl; the clock restarts whenever she turns back.
const RETIRE_EVERY := 5.0
const RETIRE_FLOOR := 4
var _retire_clock := 0.0

## The dragon walks as the farm girl: to the realm there is no dragon.
## Recruiting and soldier purchases pause too, or the stand-down would be
## refilled as fast as it drains.
func _dragon_hidden() -> bool:
	var dragon := get_tree().get_first_node_in_group("dragon") as Dragon
	return dragon != null and dragon.human_form

func _tick_retirements(delta: float) -> void:
	var dragon := get_tree().get_first_node_in_group("dragon") as Dragon
	if dragon == null or not dragon.human_form:
		_retire_clock = 0.0
		return
	_retire_clock += delta
	if _retire_clock < RETIRE_EVERY:
		return
	_retire_clock = 0.0
	var on_duty: Array[Soldier] = []
	for node: Node in get_tree().get_nodes_in_group("soldiers"):
		var s := node as Soldier
		# plain soldiers only: the King, archers, heroes and hags never retire
		if s != null and s.is_alive and s.npc_type == "soldier" and not s.is_retiring():
			on_duty.append(s)
	if on_duty.size() <= RETIRE_FLOOR:
		return
	var retiree: Soldier = on_duty.pick_random()
	retiree.retire(city_position)
	if game_manager != null:
		game_manager.call("_hud_message",
			"No dragon in sight — the King sends a soldier home (%d left)." % (on_duty.size() - 1), 3.0)

func _on_food_delivered(amount: int) -> void:
	if game_manager != null:
		game_manager.add_food(amount)
	# A farm delivery just fed the town: empty pen slots may now be bought
	# back (each animal costs refill_cost, so food scarcity rations stock).
	_attempt_pen_refills()

func _on_resource_delivered(_npc_type: String, res_type: String, amount: int) -> void:
	if game_manager != null:
		game_manager.deposit_treasury(res_type, amount)
	# A payment reaching the treasury sows one burnt field again (rule
	# 2026-11-08) — gold literally makes the farm belt come back.
	if res_type == "gold":
		_regrow_fields_on_gold()
	# Treasury just grew — the town spends soldier money immediately
	# (rule 2026-11-09: "always try to buy while there is gold").
	_try_buy_soldiers()

## One STUBBLE field per gold delivery (fields in the RP order they appear
## in the group; the rest keep waiting on the fund).
func _regrow_fields_on_gold() -> void:
	for node: Node in get_tree().get_nodes_in_group("fields"):
		var field := node as Field
		if field != null and not field.is_workable():
			field.regrow()
			return


## Field burning tracker for sacrifice system
## Called by Field.field_burnt signal when a field is burnt by dragon fire.
## Spawns a sacrifice every 3 fields burnt.
## Signal signature: field_burnt(field: Field)
func _on_field_burnt(field: Field) -> void:
	fields_burnt_count += 1
	print("WorldManager: Field burnt at %s (count: %d)" % [
		str(field.global_position), fields_burnt_count])
	# Spawn sacrifice every 3 fields burnt
	if fields_burnt_count % 3 == 0:
		_spawn_sacrifice(field.global_position)

## Farm cycle pays for livestock: after EVERY delivery, BOTH pens refill
## greedily — slots fill until the town's food runs dry (bug fix 2026-11-08:
## the one-attempt-per-delivery rule starved pen stock and thus NPC respawns;
## user spec "respawn as soon as farmers deliver food").
func _attempt_pen_refills() -> void:
	if game_manager == null:
		return
	for group: String in ["pig_pens", "cow_pens"]:
		var pen := get_tree().get_first_node_in_group(group) as AnimalPen
		if pen == null:
			continue
		while pen.has_empty_slot() and game_manager.consume_food(pen.refill_cost):
			pen.respawn_animal()

## Dead townsfolk come back IF their dedication animal is in stock:
## farmer ← pig, miner ← cow (one of each consumed — user spec 2026-11-08).
## Otherwise the runner retries every check interval until the pen can pay.
func add_respawn_request(npc_type: String, at_position: Vector2) -> void:
	_respawn_queue.append({
		"type": npc_type,
		"position": at_position,
		"timer_left": npc_respawn_delay,
	})
	print("%s will respawn in %ds if the %s is in stock" % [
		npc_type.capitalize(), int(npc_respawn_delay),
		"pig" if npc_type == "farmer" else "cow"])

func _tick_respawn_queue(delta: float) -> void:
	var i := 0
	while i < _respawn_queue.size():
		var entry: Dictionary = _respawn_queue[i]
		entry["timer_left"] = float(entry["timer_left"]) - delta
		if float(entry["timer_left"]) <= 0.0:
			# retry cadence while the animal species is out of stock
			entry["timer_left"] = npc_respawn_check_interval
			var pen_group := "pig_pens" if entry["type"] == "farmer" else "cow_pens"
			var pen := get_tree().get_first_node_in_group(pen_group) as AnimalPen
			if pen != null and pen.consume_animal():
				_respawn_queue.remove_at(i)
				spawn_respawned_npc(String(entry["type"]), entry["position"] as Vector2)
				continue  # don't advance past the removed entry
		i += 1

func spawn_respawned_npc(npc_type: String, at_position: Vector2) -> void:
	spawn_entity(npc_type, 1, at_position, 20.0)
	print("%s respawned (a %s was consumed)!" % [
		npc_type.capitalize(), "pig" if npc_type == "farmer" else "cow"])


func _on_npc_died(npc_type: String, npc: BaseNPC) -> void:
	# Economy-only consequences: killed miners slow gold/gem production but
	# never accelerate soldiers by themselves (decision record). Respawns are
	# the town's recovery loop, gated on pen livestock.
	if (npc_type == "farmer" or npc_type == "miner") and is_instance_valid(npc):
		add_respawn_request(npc_type, npc.home_position)
	
	# Goblin tracking: decrement count on death
	if npc_type == "goblin":
		_goblin_count = max(0, _goblin_count - 1)
	
	print("NPC died: ", npc_type)

# --- miner support chain ------------------------------------------------------

## Farmers + food gate miner spawning (the "farmers enable miners" chain).
func try_spawn_miner() -> void:
	if game_manager == null or _invasion_on():
		return   # no new miners while the realm is under invasion
	var farmer_count_now := get_tree().get_nodes_in_group("farmers").size()
	var supported := farmer_count_now >= miner_spawn_requirement_farmers \
		and game_manager.food >= miner_spawn_requirement_food
	# Tell miners whether they may mine (support chain gates economic output).
	for miner: Node in get_tree().get_nodes_in_group("miners"):
		if miner is Miner:
			(miner as Miner).check_support_conditions(farmer_count_now, game_manager.food)
	if not supported:
		return
	spawn_entity("miner", 1, mine_center, 140.0)
	game_manager.consume_food(miner_spawn_requirement_food)
	print("Miner spawned (support satisfied: %d farmers, %d food)" % [
		farmer_count_now, game_manager.food])
