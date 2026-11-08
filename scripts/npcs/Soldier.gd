extends BaseNPC

class_name Soldier

## Town soldier: patrols, chases the dragon when it gets close, attacks in
## range. Runs on the same Activity engine (CHASE = attack activity whose
## work-tick lands damage on the dragon). docs/plans/2026-11-08-behavior-system-rebuild.md

signal defeated(reward_gold: int)

@export_group("Combat")
@export var aggro_range: float = 300.0
@export var attack_range: float = 60.0
@export var attack_damage: int = 15
@export var attack_interval: float = 2.0
@export var reward_gold: int = 25

func _ready() -> void:
	# Configure before super._ready() — it syncs health from max_health.
	npc_type = "soldier"
	max_health = 50
	speed = 80.0
	danger_radius = 0.0  # soldiers never flee the dragon

	super._ready()

	behavior_tree = BehaviorTree.new()
	add_child(behavior_tree)
	behavior_tree.setup(self)
	behavior_tree.register_activity(
		"attack_dragon", 60,
		_pick_dragon_target, attack_interval,
		0.5, _complete_attack,
		Callable(), _dragon_in_attack_range
	)
	behavior_tree.register_activity(
		"patrol", 10,
		_pick_patrol_target, 0.0,
		1.0, Callable()
	)
	behavior_tree.register_activity(
		"idle", 1,
		_pick_idle_target, 1.5,
		2.0, Callable()
	)

# --- danger override: soldiers do NOT flee the dragon -----------------------

## Soldiers stand their ground (danger_radius = 0 in _ready) so the engine's
## flee reaction never applies to them.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)

# --- activity providers & completers ---------------------------------------

func _pick_dragon_target() -> Vector2:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return BehaviorTree.TARGET_NONE
	if global_position.distance_to(dragon.global_position) > aggro_range:
		return BehaviorTree.TARGET_NONE
	return dragon.global_position

## Mid-attack abort gate: dragon out of reach (or dead) → abort without hit.
func _dragon_in_attack_range() -> bool:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return false
	return global_position.distance_to(dragon.global_position) <= attack_range

func _complete_attack() -> void:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node
	if dragon != null and dragon.has_method("take_damage"):
		dragon.take_damage(attack_damage)

func _pick_patrol_target() -> Vector2:
	return home_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))

func _pick_idle_target() -> Vector2:
	return home_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))

func take_damage(amount: int) -> void:
	# Soldiers take fire/dragon damage; routed into the base class.
	super.take_damage(amount)

func die() -> void:
	defeated.emit(reward_gold)
	super.die()
