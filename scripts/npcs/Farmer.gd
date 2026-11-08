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

# --- activity providers & completers --------------------------------------

## Nearest GROWN field; TARGET_NONE when town has no workable fields
## (burnt acreage temporarily removes targets — the consequence loop).
## Stateful: caches the chosen field node for the mid-work abort gate.
func _pick_field_target() -> Vector2:
	_current_field = null
	var best: Vector2 = BehaviorTree.TARGET_NONE
	var best_dist := INF
	for field: Node2D in get_tree().get_nodes_in_group("fields"):
		if not field.has_method("is_workable") or not field.is_workable():
			continue
		var dist := global_position.distance_squared_to(field.global_position)
		if dist < best_dist:
			best_dist = dist
			best = field.global_position
			_current_field = field
	return best

## Work-phase gate: field burnt (or freed) while working → abort without yield.
func _field_still_workable() -> bool:
	return _current_field != null \
		and is_instance_valid(_current_field) \
		and _current_field.is_workable()

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

func _complete_field_tend() -> void:
	field_tended.emit()
	food_carrying += food_per_tend * npc_level
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
