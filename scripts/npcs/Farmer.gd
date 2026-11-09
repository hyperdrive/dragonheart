extends BaseNPC

class_name NPCFarmer

## Farmer: the food engine of the support chain.
## Activities: tend_fields (grown Fields only — burnt ones abort without yield),
## tend_pigs, deliver (food to town → GameManager food pool), idle.
## Consequences loop: dragon burns fields → work aborts → food thins →
## support checks (pigs/cows/miners) fail sooner. docs/decisions/2026-11-08-behavior-system.md

signal food_delivered(amount: int)
signal field_tended
signal pigs_tended

@export var food_per_tend: int = 1
@export var tend_work_time: float = 3.0
@export var tend_cooldown: float = 2.0

@export_group("Loaded panic")
## Carrying the city's food? The farmer bolts MUCH earlier and faster, so the
## delivery stalls while the dragon lurks — the town starves for it.
@export var loaded_danger_radius: float = 220.0
@export var loaded_flee_speed: float = 1.3
@export var unloaded_danger_radius: float = 120.0

## Food gathered since the last delivery (delivered in one trip).
var food_carrying: int = 0

## Field node cached by _pick_field_target (stateful provider, engine contract:
## providers may cache placement decisions resolved once per trip).
var _current_field: Node2D

func _ready() -> void:
	# Configure before super._ready() — it syncs health from max_health.
	npc_type = "farmer"
	max_health = 50
	speed = 80.0

	super._ready()

	# After super._ready(): it initializes the anchors from spawn position;
	# our town lies north of the farm (override the default southward anchor).
	town_position = home_position + Vector2(0, -300)

	behavior_tree = BehaviorTree.new()
	add_child(behavior_tree)
	behavior_tree.setup(self)
	# Aborted work (burnt mid-tend, flee preemption) leaves a stale field
	# claim — hand the plot back the instant work is no longer in progress.
	behavior_tree.state_changed.connect(_on_tree_state_changed)
	behavior_tree.register_activity(
		"tend_fields", 20,
		_pick_field_target, tend_work_time * level_multiplier(),
		tend_cooldown, _complete_field_tend,
		Callable(), _field_still_workable
	)
	behavior_tree.register_activity(
		"tend_pigs", 10,
		_pick_pigs_target, tend_work_time * level_multiplier(),
		tend_cooldown, _complete_pigs_tend
	)
	behavior_tree.register_activity(
		"deliver", 50,
		_pick_town_target, 1.0,
		0.0, _complete_deliver,
		_have_food_to_deliver
	)
	behavior_tree.register_activity(
		"go_home", 5,
		_pick_home_target, 0.0,
		4.0, Callable()
	)
	behavior_tree.register_activity(
		"idle", 1,
		_pick_idle_target, 1.0,
		3.0, Callable()
	)

	print("Farmer initialized at position: ", global_position)

## Run/Fight tuning flips each frame with the payload (BehaviorTree's danger
## check reads danger_radius per tick, so a live value works).
func _physics_process(delta: float) -> void:
	if food_carrying > 0:
		danger_radius = loaded_danger_radius
		flee_speed_multiplier = loaded_flee_speed
	else:
		danger_radius = unloaded_danger_radius
		flee_speed_multiplier = 1.0
	super._physics_process(delta)

# --- activity providers & completers --------------------------------------

## Nearest GROWN field that is not claimed by another farmer (rule
## 2026-11-08: one farmer per field at a time); TARGET_NONE when town has no
## workable unclaimed acreage. Stateful: caches the chosen field node for the
## mid-work abort gate, and takes the field's claim lease.
func _pick_field_target() -> Vector2:
	_current_field = null
	var best: Vector2 = BehaviorTree.TARGET_NONE
	var best_dist := INF
	for field: Node2D in get_tree().get_nodes_in_group("fields"):
		var plot := field as Field
		if plot == null:
			continue
		if not plot.is_workable() or plot.is_claimed_other(get_instance_id()):
			continue
		var dist := global_position.distance_squared_to(field.global_position)
		if dist < best_dist:
			best_dist = dist
			best = field.global_position
			_current_field = plot
	if _current_field != null:
		_current_field.claim(get_instance_id(), _claim_lease_ms())
	return best

## Work-phase gate: field burnt (or freed) while working → abort without yield.
func _field_still_workable() -> bool:
	return _current_field != null \
		and is_instance_valid(_current_field) \
		and _current_field.is_workable()

## Claim lease: comfortably covers the walk to a far field + work + slack.
## Abandonment (flee, garbage-death) self-heals when the lease lapses.
func _claim_lease_ms() -> int:
	return int((tend_work_time * level_multiplier() + 14.0) * 1000.0)

## The plot is free again once this farmer is done with it.
func _release_field() -> void:
	if _current_field != null and is_instance_valid(_current_field):
		(_current_field as Field).release(get_instance_id())
	_current_field = null

## Work is no longer in progress (flee preemption, burnt-mid-tend abort):
## drop the stale claim immediately instead of making the town wait out the
## lease. Normal completion already released (this becomes a no-op). Gated to
## FLEEING/IDLE so the claim survives its own pick → MOVING commit.
func _on_tree_state_changed(new_state: BehaviorTree.State) -> void:
	if new_state == BehaviorTree.State.MOVING \
			or new_state == BehaviorTree.State.WORKING:
		return
	if _current_field != null:
		_release_field()

func _pick_pigs_target() -> Vector2:
	return pig_pen_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))

func _pick_town_target() -> Vector2:
	return town_position

func _pick_home_target() -> Vector2:
	return home_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))

func _pick_idle_target() -> Vector2:
	return home_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))

func _have_food_to_deliver() -> bool:
	return food_carrying > 0

## Gate hand-off (2026-11-09, same rule as the miner's): a farmer on the
## deliver leg finishes the food hand-off even with the dragon inside his
## flee ring — the ring sits right on the gates and used to wedge every
## loaded farmer in a panic loop (food never reaching the pens). Robbery
## of food is physical: eating the farmer is what costs the town, and
## that path is untouched.
func _handoff_stretch() -> bool:
	if food_carrying <= 0 or behavior_tree == null:
		return false
	var act := behavior_tree.current_activity
	return act != null and str(act.id) == "deliver"

func _complete_field_tend() -> void:
	field_tended.emit()
	food_carrying += food_per_tend * npc_level
	_release_field()  # plot up for grabs again (incl. re-picking it himself)
	print("Farmer tended fields — carrying %d food" % food_carrying)

func _complete_pigs_tend() -> void:
	pigs_tended.emit()
	food_carrying += food_per_tend * npc_level
	print("Farmer tended pigs — carrying %d food" % food_carrying)

## Delivery: hand the accumulated food to GameManager (owner of the food pool).
func _complete_deliver() -> void:
	if food_carrying > 0:
		food_delivered.emit(food_carrying)
		print("Farmer delivered %d food to town" % food_carrying)
		food_carrying = 0

## A dead farmer cannot keep a field claimed.
func die() -> void:
	_release_field()
	super.die()
