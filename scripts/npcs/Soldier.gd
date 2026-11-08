extends BaseNPC

class_name Soldier

## Town soldier: patrols the city, RALLIES at the gate when the dragon nears,
## and attacks only once the swarm is released (WorldManager.swarm_state).
## docs/plans/2026-11-08-behavior-system-rebuild.md

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
		_swarm_released, _dragon_in_attack_range
	)
	behavior_tree.register_activity(
		"rally", 40,
		_pick_rally_target, 0.0,
		0.5, _complete_rally,
		_swarm_rallying
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

# --- swarm state access ------------------------------------------------------

## The WorldManager owns the swarm coordination; missing manager = old-style
## independent behavior (chase on sight).
func _world_manager() -> WorldManager:
	return get_tree().get_first_node_in_group("world_manager") as WorldManager

func _swarm_rallying() -> bool:
	var world := _world_manager()
	return world != null and world.swarm_state == WorldManager.SwarmState.RALLY

func _swarm_released() -> bool:
	var world := _world_manager()
	return world == null or world.swarm_state == WorldManager.SwarmState.ATTACK

# --- activity providers & completers ---------------------------------------

## During ATTACK the aggro range widens hugely: the whole swarm hunts.
func _pick_dragon_target() -> Vector2:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return BehaviorTree.TARGET_NONE
	var reach := aggro_range
	if _swarm_released():
		reach = 4000.0
	if global_position.distance_to(dragon.global_position) > reach:
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

## Muster on a loose ring at the rally point (swarm cohesion before the charge).
func _pick_rally_target() -> Vector2:
	var world := _world_manager()
	if world == null:
		return BehaviorTree.TARGET_NONE
	var jitter := Vector2(randf_range(-50, 50), randf_range(-50, 50))
	return world.rally_point + jitter

func _complete_rally() -> void:
	pass  # arrival is the point; WorldManager counts heads at the gate

func _pick_patrol_target() -> Vector2:
	return home_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))

func _pick_idle_target() -> Vector2:
	return home_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))

## Soldiers keep a slack aggro: spotting the dragon near them raises the alarm
## state so distant comrades rally even before the city-radius alarm triggers.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon != null and is_instance_valid(dragon) \
			and global_position.distance_to(dragon.global_position) < aggro_range:
		var world := _world_manager()
		if world != null:
			world.report_dragon_sighting(dragon.global_position)

func take_damage(amount: int) -> void:
	# Soldiers take fire/dragon damage; routed into the base class.
	super.take_damage(amount)

func die() -> void:
	defeated.emit(reward_gold)
	super.die()
