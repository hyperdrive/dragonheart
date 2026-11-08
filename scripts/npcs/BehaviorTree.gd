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
			_tick_moving()
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

func _tick_fleeing() -> void:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon != null:
		var dist := npc.global_position.distance_to(dragon.global_position)
		if dist < npc.danger_radius:
			# Refresh the escape vector while still too close.
			var away := (npc.global_position - dragon.global_position).normalized()
			npc.flee_target = npc.global_position + away * npc.safe_radius
	var flee_speed := npc.speed * npc.flee_speed_multiplier
	npc.velocity = (npc.flee_target - npc.global_position).normalized() * flee_speed
	npc.update_facing()
	npc.move_and_slide()
	if npc.global_position.distance_to(npc.flee_target) < ARRIVAL_DISTANCE:
		npc.velocity = Vector2.ZERO
		_set_state(State.IDLE)

func _tick_moving() -> void:
	if current_activity == null:
		_set_state(State.IDLE)
		return
	if npc.move_towards(current_activity.target):
		if current_activity.work_time > 0.0:
			current_activity.work_timer = current_activity.work_time
			_set_state(State.WORKING)
		else:
			_complete_activity()

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
