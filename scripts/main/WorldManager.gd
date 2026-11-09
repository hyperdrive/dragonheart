extends Node2D

class_name WorldManager

## World spawner + escalation director.
## Layout: a city in the south (soldiers spawn there), a farm belt around it
## (fields + animal pens + farmer homes), a mining district in the northwest,
## and blocking scenery (trees/lakes/mountains) scattered with clearance checks.
## Soldier tactics: when the dragon nears the city soldiers RALLY at the city
## gate; when enough have massed (or the dragon is at the walls) they ATTACK.
## docs/plans/2026-11-08-behavior-system-rebuild.md

signal entity_spawned(entity_type: String, position: Vector2)
signal swarm_state_changed(new_state: SwarmState)

enum SwarmState { CALM, RALLY, ATTACK }

@export_group("World")
@export var world_size: Vector2 = Vector2(1600, 1600)
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
@export var tower_position: Vector2 = Vector2(520, -420)  # wizard tower

@export_group("Terrain")
@export var tree_count: int = 14
@export var lake_count: int = 3
@export var mountain_count: int = 5

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

@export_group("Swarm tactics")
@export var rally_range: float = 340.0          # dragon distance to city → RALLY
@export var swarm_size: int = 3                 # gathered soldiers → ATTACK
@export var swarm_gather_radius: float = 110.0
@export var attack_range_city: float = 170.0    # dragon at the walls → ATTACK

const ESCALATING := "soldier"   # entity spawned on the escalation curve
var entity_scenes := {
	"farmer": preload("res://scenes/npcs/Farmer.tscn"),
	"miner": preload("res://scenes/npcs/Miner.tscn"),
	"mine": preload("res://scenes/objects/Mine.tscn"),
	"soldier": preload("res://scenes/objects/Soldier.tscn"),
	"archer": preload("res://scenes/objects/Archer.tscn"),
	"wizard": preload("res://scenes/objects/Wizard.tscn"),
	"field": preload("res://scenes/systems/Field.tscn"),
	"tower": preload("res://scenes/objects/WizardTower.tscn"),
	"king": preload("res://scenes/objects/King.tscn"),
	"city": preload("res://scenes/props/City.tscn"),
	"pig_pen": preload("res://scenes/props/PigPen.tscn"),
	"cow_pen": preload("res://scenes/props/CowPen.tscn"),
	"lair": preload("res://scenes/props/DragonLair.tscn"),
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
## Pending NPC respawns: {"type", "position", "timer_left"} — gated on the
## matching pen having a live animal (farmer↔pig, miner↔cow).
var _respawn_queue: Array[Dictionary] = []
var _soldier_timer: Timer
var _swarm_timer: Timer
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

func _clamp_to_interior(pos: Vector2, radius := 0.0) -> Vector2:
	var pad := WORLD_MARGIN + radius
	var half := world_size * 0.5 - Vector2(pad, pad)
	return pos.clamp(-half, half)


func register_footprint(position: Vector2, radius: float) -> void:
	_terrain_clearances.append({"pos": position, "radius": radius})


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	add_to_group("world_manager")
	if game_manager != null:
		swarm_state_changed.connect(game_manager._on_swarm_state_changed)
	# Pre-clamp landmark anchors BEFORE generation: they are design numbers
	# exported before the margin rule existed.
	city_position = _clamp_to_interior(city_position, FOOTPRINT_RADIUS["city"])
	mine_center = _clamp_to_interior(mine_center, FOOTPRINT_RADIUS["mine"])
	rally_point = _clamp_to_interior(rally_point)
	pig_pen_position = _clamp_to_interior(pig_pen_position, FOOTPRINT_RADIUS["pig_pen"])
	cow_pen_position = _clamp_to_interior(cow_pen_position, FOOTPRINT_RADIUS["cow_pen"])
	lair_position = _clamp_to_interior(lair_position, FOOTPRINT_RADIUS["lair"])
	tower_position = _clamp_to_interior(tower_position, FOOTPRINT_RADIUS["tower"])
	generate_world()

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

	# Swarm coordination tick (see _on_swarm_tick).
	_swarm_timer = Timer.new()
	_swarm_timer.wait_time = 0.5
	_swarm_timer.autostart = true
	_swarm_timer.timeout.connect(_on_swarm_tick)
	add_child(_swarm_timer)

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

## The rescue: teleport next to the CURRENT activity target (clamped to the
## interior band, ±35px jitter) so the trip can complete naturally. On the
## 3rd rescue for the SAME activity — or a non-finite target — abort the
## trip instead (claim released, tree re-picks something else).
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
	if activity == null or rescues > 2 or not (activity.target as Vector2).is_finite():
		bt.force_repick()
		restart_clock.call()
		print("StuckMonitor: %s abandoned stuck %s trip (%s, rescue #%d)" % [
			npc.name, npc.npc_type, reason, rescues])
		return
	var goal: Vector2 = activity.target
	var offset := Vector2(randf_range(-35.0, 35.0), randf_range(-35.0, 35.0))
	# 2026-11-09 fix: the teleport spot must be TERRAIN-CLEAR — a rescue that
	# drops an NPC inside a city wall recreates the wedge it was healing.
	var spot := _terrain_free_position(goal + offset, 30.0, [], 90.0, true)
	if spot == Vector2.INF:
		# Nowhere safe near the goal: the target is effectively unreachable —
		# abort the trip instead (fresh re-pick beats a wall-drop).
		bt.force_repick()
		restart_clock.call()
		print("StuckMonitor: %s aborted %s trip — rescue spot blocked (%s #%d)" % [
			npc.name, npc.npc_type, reason, rescues])
		return
	npc.global_position = spot
	npc.velocity = Vector2.ZERO
	restart_clock.call()
	print("StuckMonitor: %s teleported near its %s goal %s (%s, rescue #%d)" % [
		npc.name, npc.npc_type, str(npc.global_position), reason, rescues])


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
	spawn_entity("tower", 1, tower_position)   # wizard upgrades landmark
	register_footprint(tower_position, FOOTPRINT_RADIUS["tower"])
	spawn_fields()
	# Scenery avoids ALL registered footprints (landmarks + fields) with
	# per-spot radius padding — no more visual overlaps with the farm belt.
	spawn_scenery()
	spawn_entity("mine", mine_count, mine_center, 180.0)
	spawn_farmers()
	spawn_entity("soldier", initial_soldier_count, rally_point, 90.0)
	soldiers_spawned = initial_soldier_count
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
		var angle := TAU * float(i) / float(field_count) + 0.4
		var anchor := _clamp_to_interior(
			city_position + Vector2.RIGHT.rotated(angle) * 420.0, field_radius)
		var position := _terrain_free_position(anchor, field_radius)
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
func spawn_scenery() -> void:
	var protected: Array = [
		{"pos": Vector2.ZERO, "pad": 90.0},  # dragon start
	]
	var counts := [tree_count, lake_count, mountain_count]
	for kind_id in counts.size():
		for i in counts[kind_id]:
			var radius: float = [22.0, 66.0, 60.0][kind_id]
			var position := _terrain_free_position(
				get_random_position(), radius, protected, 110.0)
			if position == Vector2.INF:
				continue  # map too crowded at this spot; skip
			var scene: PackedScene = scenery_scenes[kind_id]
			var obstacle := scene.instantiate()
			obstacle.global_position = position
			add_child(obstacle)
			register_footprint(position, radius)
			entity_spawned.emit("terrain", position)


## Jitter around an anchor until the spot is reasonably free (checks the
## whole footprint registry); `protected` overrides use dict spots:
## {"pos": Vector2, "pad": float} — blocked inside protected_margin + pad.
## Every candidate is clamped into the interior band minus self_radius —
## large attempt-based jitter (up to ±276px) can otherwise escape the band.
func _terrain_free_position(anchor: Vector2, self_radius: float,
	protected := [] as Array, protected_margin := 90.0,
	nearest := false) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var best := Vector2.INF
	var best_dist := INF
	for attempt in 24:
		var candidate := _clamp_to_interior(anchor + Vector2(
			rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)
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
	return anchor + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))


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
		"mine":
			var mine := instance as Node2D
			if mine != null:
				register_footprint(mine.global_position, FOOTPRINT_RADIUS["mine"])


## Jittered position inside the mining district (spreads miners across it).
func _mine_spot() -> Vector2:
	return mine_center + Vector2(randf_range(-160, 160), randf_range(-160, 160))


func get_random_position() -> Vector2:
	var margin := 100.0
	return Vector2(
		randf_range(-world_size.x / 2 + margin, world_size.x / 2 - margin),
		randf_range(-world_size.y / 2 + margin, world_size.y / 2 - margin)
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


# --- swarm tactics: CALM → RALLY → ATTACK ------------------------------------
##
## CALM  : soldiers patrol the city.
## RALLY : dragon approached the city — soldiers mass at the north gate.
## ATTACK: enough soldiers massed, dragon at the walls, or the King is up —
##         everyone hunts the dragon.

func _on_swarm_tick() -> void:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
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
	if game_manager == null:
		return
	spawn_entity(_next_recruit_type(), 1, rally_point, 90.0)
	_escalation_soldier_spawned()


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
	if game_manager == null or game_manager.run_finished:
		return
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


## The final boss arrives at the city; defeating him ends the run.
## 2026-11-09-king-lives: he rises THREE times after each defeat; the
## last defeat is the true one and ends the run.
@export var king_respawn_count: int = 3
var king_respawns_left: int = 3

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
	if game_manager != null:
		game_manager.start_boss_battle(king)
	entity_spawned.emit("king", king.global_position)
	_set_swarm_state(SwarmState.ATTACK)

## The King has fallen — schedule the next life if any remain.
## Returns true when a respawn is planned (King.die skips the victory
## path then); false = last life spent → caller declares victory.
## Lives semantics: king_respawn_count = 3 → the King dies FOUR times in
## total (first life + three rises). king_respawns_left counts remaining
## respawns after each decrement.
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
## provocation lines: bought 3+ upgrades AND visited the tower more than
## 3 times, OR hoarded 20+ gold in the stash (repriced 2026-11-09: was
## 30). Then he hunts the dragon across the whole map with lightning
## (30 dmg / 2s / long range) and never stops — see scripts/npcs/Wizard.gd.
@export_group("Wizard")
@export var wizard_upgrade_threshold: int = 3
@export var wizard_visit_threshold: int = 3     # "more than 3" → 4+
@export var wizard_stash_trigger: int = 20
var wizard_spawned: bool = false

func _try_spawn_wizard() -> void:
	if wizard_spawned or game_manager == null or game_manager.run_finished:
		return
	var bought_enough: bool = game_manager.upgrade_purchases >= wizard_upgrade_threshold \
		and game_manager.tower_visits > wizard_visit_threshold
	var greedy: bool = int(game_manager.stash["gold"]) >= wizard_stash_trigger
	if not (bought_enough or greedy):
		return
	wizard_spawned = true
	var wizard := entity_scenes["wizard"].instantiate() as Wizard
	var spawn_anchor := tower_position + Vector2(60, -40)
	wizard.global_position = spawn_anchor
	add_child(wizard)
	(wizard as BaseNPC).home_position = spawn_anchor
	entity_spawned.emit("wizard", wizard.global_position)
	print("The wizard emerges from his tower — he has seen enough of your robberies!")

# --- signal handlers: NPC → GameManager (the hub) ---------------------------

func _process(delta: float) -> void:
	_tick_respawn_queue(delta)
	_try_spawn_wizard()

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
	print("NPC died: ", npc_type)

# --- miner support chain ------------------------------------------------------

## Farmers + food gate miner spawning (the "farmers enable miners" chain).
func try_spawn_miner() -> void:
	if game_manager == null:
		return
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
