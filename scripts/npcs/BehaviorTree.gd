extends Node

class_name BehaviorTree

## Activity-based behavior engine.
## Design: docs/plans/2026-11-08-behavior-system-rebuild.md — Approach B.
## Contract (docs/decisions/2026-11-08-behavior-system.md):
##   - Activities are synchronous; work_time + tick(delta) handles all waiting.
##   - The tree stays on an activity until it completes: an activity moves
##     (MOVING), then works (WORKING), then reports completion with its reward.
##     Cooldowns are real seconds, decremented by tick delta.
##   - `check_danger` is priority 0 and preempts everything into FLEEING.
##   - Coroutines are forbidden: Callable.call() cannot await in Godot 4.

signal state_changed(new_state: State)
signal activity_completed(activity_id: String)
signal fled_from_dragon(dragon_position: Vector2)

enum State { IDLE, MOVING, WORKING, FLEEING, DEAD }

## Sentinel returned by target providers when no valid target exists this tick.
## (Also the initial value of Activity.target.)
const TARGET_NONE := Vector2.INF
const ARRIVAL_DISTANCE := 12.0

## One schedulable piece of work. Subclasses define activities in code
## (decision record: no .tres behavior configs).
class Activity:
	var id: String
	var priority: int
	## Returns the world-space target to move to, or BehaviorTree.TARGET_NONE
	## when the activity is not currently placeable.
	var target_provider: Callable
	## Extra availability gate (e.g.: payload present, field grown). Returns bool.
	var ready_check: Callable
	## Re-evaluated every tick while WORKING; returning false cancels the
	## activity without its reward (e.g. field was burnt mid-work).
	var work_check: Callable
	var work_time: float
	var cooldown: float
	## Called once when the activity completes: emits output signals / grants payload.
	var on_complete: Callable
	## Placed destination (set once at pick time by _pick_activity).
	var target: Vector2 = BehaviorTree.TARGET_NONE
	var cooldown_left: float = 0.0
	var work_timer: float = 0.0

	func _init(
		p_id: String,
		p_priority: int,
		p_target_provider: Callable,
		p_work_time: float,
		p_cooldown: float,
		p_on_complete: Callable,
		p_ready_check := Callable(),
		p_work_check := Callable()
	) -> void:
		id = p_id
		priority = p_priority
		target_provider = p_target_provider
		work_time = p_work_time
		cooldown = p_cooldown
		on_complete = p_on_complete
		ready_check = p_ready_check
		work_check = p_work_check

	## Ready = off cooldown, extra gate passes, and a target provider exists.
	## Target placement happens in _pick_activity (providers can be stateful).
	func is_ready() -> bool:
		if cooldown_left > 0.0:
			return false
		if ready_check.is_valid() and not bool(ready_check.call()):
			return false
		return target_provider.is_valid()

var npc: BaseNPC
var state: State = State.IDLE
var current_activity: Activity = null

## Escape reaction tuning (dragon proximity). Exports live on BaseNPC;
## the engine reads them from there.
## Flee without grants: interrupted work pays nothing (economy-only consequences).

func setup(npc_node: BaseNPC) -> void:
	npc = npc_node

## Register a schedulable activity. Higher priority wins when several are ready.
func register_activity(
	id: String,
	priority: int,
	target_provider: Callable,
	work_time: float,
	cooldown: float,
	on_complete: Callable,
	ready_check := Callable(),
	work_check := Callable()
) -> void:
	var activity := Activity.new(
		id, priority, target_provider, work_time, cooldown, on_complete,
		ready_check, work_check
	)
	activities.append(activity)

var activities: Array[Activity] = []

## Main entry point, called once per physics frame by BaseNPC.
func tick(delta: float) -> void:
	if state == State.DEAD:
		return
	_tick_cooldowns(delta)
	_tick_danger()
	match state:
		State.MOVING:
			_tick_moving(delta)
		State.WORKING:
			_tick_working(delta)
		State.FLEEING:
			_tick_fleeing()
		State.IDLE:
			_pick_activity()
		State.DEAD:
			pass  # unreachable; kept because match wants a default branch
		_:
			push_warning("BehaviorTree: unknown state %d" % state)

func kill() -> void:
	_set_state(State.DEAD)
	current_activity = null

## Cancel the in-progress activity without reward (e.g. burnt field, steal damage).
func interrupt_current_activity() -> void:
	if current_activity != null and state != State.FLEEING:
		current_activity = null
		velocity_zero()
		_set_state(State.IDLE)

# --- StuckMonitor bridges (world supervision, decision 2026-11-09) -----------

## Lazy world cache for target clamping (playfield band), set once.
## Deliberately UNTYPED: a WorldManager annotation here would add a compile
## edge BehaviorTree→WorldManager and break the WorldManager→Miner.tscn→
## Miner.gd preload cycle (ext_resource "non-existent" parse error).
var _world_cache = null
var _world_cache_checked := false

func _cached_world():
	if not _world_cache_checked:
		_world_cache_checked = true
		_world_cache = get_tree() \
			.get_first_node_in_group("world_manager")
	return _world_cache

## World-level watchdog: force the tangent-hop detour without waiting for
## the tree's own stuck window (same math, superseding trigger).
func force_detour() -> void:
	_stuck_window = 0.0
	_last_stuck_pos = npc.global_position
	_place_detour()

## World-level watchdog: abandon the current trip WITHOUT completion and
## re-pick from IDLE (releases field claims via the state-change hook).
func force_repick() -> void:
	interrupt_current_activity()

func velocity_zero() -> void:
	if npc is CharacterBody2D:
		npc.velocity = Vector2.ZERO

# --- internals -----------------------------------------------------------

func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(new_state)

func _tick_cooldowns(delta: float) -> void:
	for activity in activities:
		if activity.cooldown_left > 0.0:
			activity.cooldown_left = maxf(activity.cooldown_left - delta, 0.0)

## Priority 0: dragon proximity preempts everything (except an active escape).
func _tick_danger() -> void:
	if state == State.FLEEING:
		return
	# Gate hand-off exemption (2026-11-09): a loaded cargo keeper inside the
	# gates' handoff band finishes the delivery even with the dragon inside
	# his flee ring (Miner/Farmer override _handoff_stretch) — otherwise a
	# dragon parked near the town wedges every carrier in the 180px panic
	# loop forever (miners circled 45s with full carts, ZERO deliveries,
	# treasury starved, no soldier purchases = "we still fail to spawn
	# soldiers"). The drop rule still wins: below drop_radius (85) the
	# claws spill the payload as before (Miner._check_dragon_drop).
	if npc._handoff_stretch():
		return
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null:
		return
	if npc.global_position.distance_to(dragon.global_position) < npc.danger_radius:
		interrupt_current_activity()
		_start_flee(dragon.global_position)

func _start_flee(dragon_position: Vector2) -> void:
	var away := (npc.global_position - dragon_position).normalized()
	npc.flee_target = npc.global_position + away * npc.safe_radius
	_set_state(State.FLEEING)
	fled_from_dragon.emit(dragon_position)

func _tick_fleeing() -> void:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon != null:
		var dist := npc.global_position.distance_to(dragon.global_position)
		if dist < npc.danger_radius:
			# Refresh the escape vector while still too close.
			var away := (npc.global_position - dragon.global_position).normalized()
			var target := npc.global_position + away * npc.safe_radius
			# Border fix (2026-11-09): clamp the escape inside the playfield
			# band so the runner slides along boundary walls instead of
			# pinning into them while the dragon keeps up the pressure.
			var world: Variant = _cached_world()
			if world != null:
				target = world.clamp_into_playfield(target, 12.0)
			npc.flee_target = target
	var flee_speed := npc.speed * npc.flee_speed_multiplier
	# Detour hop takes precedence over the raw escape vector.
	var flee_direction_target := npc.flee_target
	if npc._waypoint != Vector2.INF:
		if npc.global_position.distance_to(npc._waypoint) <= 16.0:
			npc._waypoint = Vector2.INF
		else:
			flee_direction_target = npc._waypoint
	npc.velocity = (flee_direction_target - npc.global_position).normalized() * flee_speed
	npc.update_facing()
	npc.move_and_slide()
	_check_stuck()
	if npc.global_position.distance_to(npc.flee_target) < ARRIVAL_DISTANCE:
		npc.velocity = Vector2.ZERO
		npc._waypoint = Vector2.INF
		_set_state(State.IDLE)

func _tick_moving(delta: float) -> void:
	if current_activity == null:
		_set_state(State.IDLE)
		return
	if npc.move_towards(current_activity.target):
		if current_activity.work_time > 0.0:
			current_activity.work_timer = current_activity.work_time
			_set_state(State.WORKING)
		else:
			_complete_activity()
	else:
		_check_stuck()

# --- stuck detection & detour ------------------------------------------------

## Movement watchdog: if the NPC barely moved over the window while it should
## be going somewhere, raycast toward the goal and sidestep the blocker.
var _stuck_window: float = 0.0
var _last_stuck_pos: Vector2 = Vector2.ZERO
const STUCK_WINDOW := 0.7            # seconds of stalled motion before reacting
const STUCK_MOVE_EPS := 6.0          # px travelled below this = stuck
const DETOUR_CLEAR := 95.0           # stand-off from the blocker (lair radius 58)

## Called after a movement tick. A detour in progress suppresses re-checks
## (the waypoint itself may face a wall briefly while rounding the corner).
func _check_stuck() -> void:
	if npc._waypoint != Vector2.INF:
		return
	_stuck_window += get_physics_process_delta_time()
	if npc.global_position.distance_to(_last_stuck_pos) > STUCK_MOVE_EPS:
		_last_stuck_pos = npc.global_position
		_stuck_window = 0.0
		return
	if _stuck_window < STUCK_WINDOW:
		return
	_stuck_window = 0.0
	_last_stuck_pos = npc.global_position
	_place_detour()

## Ray into scenery (layer 1) toward the current goal; set a waypoint at the
## blocker center + outward stand-off + tangent bias so the seek slides around.
## Three parallel rays (shadow cast) — a single widthless ray slips past
## circular obstacles; if even the shadow misses, sidestep anyway (flipping
## sign each retry) so a detected stuck never becomes a forever-stuck.
const RAY_EXTRA := 160.0  # reach ahead of the goal direction
const RAY_SPREAD := 26.0  # perpendicular ray spacing (shadow width)

var _detour_flip: int = 1

func _place_detour() -> void:
	var goal := npc.flee_target if state == State.FLEEING \
		else (current_activity.target if current_activity != null else Vector2.INF)
	if goal == Vector2.INF or npc.global_position.distance_to(goal) < 40.0:
		return  # arrived or nowhere to go
	var to_goal := (goal - npc.global_position)
	var forward := to_goal.normalized()
	var perp := forward.rotated(PI / 2.0)
	var space := npc.get_world_2d().direct_space_state
	var blocker := Vector2.INF
	var nearest := INF
	var best_tangent := INF
	for offset: float in [0.0, RAY_SPREAD, -RAY_SPREAD]:
		var from := npc.global_position + perp * offset
		var ray := PhysicsRayQueryParameters2D.create(from, from + forward * RAY_EXTRA, 1)
		var hit := space.intersect_ray(ray)
		if hit.is_empty():
			continue
		var length := npc.global_position.distance_to(hit["position"] as Vector2)
		if length < nearest:
			nearest = length
			blocker = hit["position"] as Vector2
	if blocker != Vector2.INF:
		var outward := (npc.global_position - blocker).normalized()
		var tangent_axis := outward.rotated(PI / 2.0)
		# Grow the sideways hop until clearing the obstacle: the smaller
		# tangent start orbits large convex blockers (mountain blobs). Both
		# sides compete; the side that clears with the shorter hop wins, and
		# candidates outside the world bounds (scenery/edge walls are also
		# layer 1) are rejected — a waypoint against the boundary wedges the
		# body inside the wall's collision overlap.
		for side: int in [1, -1]:
			for tangent_len: float in [50.0, 110.0, 170.0, 230.0, 300.0]:
				var candidate := blocker + outward * DETOUR_CLEAR \
					+ tangent_axis * (tangent_len * float(side))
				if not _in_world(candidate) or not _shadow_clear(candidate, goal):
					continue
				if npc._waypoint == Vector2.INF \
						or tangent_len < best_tangent:
					best_tangent = tangent_len
					npc._waypoint = candidate
		if npc._waypoint == Vector2.INF:
			# No clearing candidate in reach: alternate perpendicular
			# sidesteps — collisions slide while seeking, so the loop
			# eventually rounds convex blockers without ever aiming outside
			# the world (the old blind 300px tangent wedged into boundary
			# walls).
			_detour_flip = -_detour_flip
			var wide := perp * DETOUR_CLEAR * float(_detour_flip)
			if not _in_world(npc.global_position + wide):
				wide = -wide
			npc._waypoint = npc.global_position + wide
	else:
		# Rays clear but still grinding (wedged body, corner pocket):
		# sidestep perpendicular, alternate the side on consecutive retries,
		# and never step outside the world.
		_detour_flip = -_detour_flip
		var sideways := perp * DETOUR_CLEAR * float(_detour_flip)
		if not _in_world(npc.global_position + sideways):
			sideways = -sideways
		npc._waypoint = npc.global_position + sideways
	_last_stuck_pos = npc.global_position


## World-bounds guard (best effort: needs the WorldManager's world_size).
func _in_world(point: Vector2) -> bool:
	var world := get_tree().get_first_node_in_group("world_manager") as WorldManager
	if world == null:
		return true
	var half: Vector2 = world.world_size * 0.5 - Vector2(70, 70)
	return absf(point.x) < half.x and absf(point.y) < half.y


## True when the direct seek from `from` to `goal` casts no scenery hit on the
## 3-ray shadow (same width as the self body, approximately).
func _shadow_clear(from: Vector2, goal: Vector2) -> bool:
	var forward := (goal - from).normalized()
	var perp := forward.rotated(PI / 2.0)
	var space := npc.get_world_2d().direct_space_state
	for offset: float in [0.0, RAY_SPREAD, -RAY_SPREAD]:
		var ray_origin := from + perp * offset
		var ray := PhysicsRayQueryParameters2D.create(
			ray_origin, goal + perp * offset, 1)
		if not space.intersect_ray(ray).is_empty():
			return false
	return true

func _tick_working(delta: float) -> void:
	if current_activity == null:
		_set_state(State.IDLE)
		return
	current_activity.work_timer -= delta
	# Mid-work abort gate: burnt field, emptied mine, etc. No reward, no cooldown.
	if current_activity.work_check.is_valid() and not bool(current_activity.work_check.call()):
		interrupt_current_activity()
		return
	if current_activity.work_timer <= 0.0:
		_complete_activity()

func _complete_activity() -> void:
	var finished := current_activity
	current_activity = null
	if npc is CharacterBody2D:
		npc.velocity = Vector2.ZERO
	if finished.cooldown > 0.0:
		finished.cooldown_left = finished.cooldown
	if finished.on_complete.is_valid():
		finished.on_complete.call()
	activity_completed.emit(finished.id)
	_set_state(State.IDLE)

## Pick the highest-priority ready activity and start moving toward it.
## Target providers run once per trip: placement and any cached work target
## (e.g. the chosen field node) are resolved here, in priority order, falling
## back to the next ready activity when one cannot be placed this tick.
func _pick_activity() -> void:
	var ready_list := _ready_activities()
	# sort_custom wants a bool comparator: "a should come before b".
	ready_list.sort_custom(func(a: Activity, b: Activity) -> bool: return a.priority > b.priority)
	for activity in ready_list:
		var target: Variant = activity.target_provider.call()
		if typeof(target) == TYPE_VECTOR2 and target != TARGET_NONE:
			activity.target = target
			current_activity = activity
			_set_state(State.MOVING)
			return

func _ready_activities() -> Array[Activity]:
	var ready_list: Array[Activity] = []
	for activity in activities:
		if activity.is_ready():
			ready_list.append(activity)
	return ready_list
