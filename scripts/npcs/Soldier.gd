extends BaseNPC

class_name Soldier

## Town soldier: patrols the city, RALLIES at the gate when the dragon nears,
## and attacks only once the swarm is released (WorldManager.swarm_state).
## docs/plans/2026-11-08-behavior-system-rebuild.md

signal defeated(reward_gold: int)

@export_group("Combat")
@export var aggro_range: float = 300.0
@export var attack_range: float = 60.0
@export var attack_damage: float = 10.0  # DPS while the hitbox touches the dragon
@export var attack_interval: float = 0.5
@export var reward_gold: int = 25

@export_group("Ablaze")
@export var burn_damage: float = 10.0   # per second while on fire
@export var burn_duration: float = 3.0  # panics, then always dies

## Burning status: the soldier abandons orders (behavior killed), runs in
## random bursts, burns, and dies when the fire burns out.
var _burning_left: float = 0.0
var _burn_move_timer: float = 0.0
var _burn_direction: Vector2 = Vector2.ONE
var _burn_debt: float = 0.0
## Contact-DPS accumulator: take_damage wants ints (10 DPS → 1 per 0.1s).
var _contact_debt: float = 0.0

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
		0.0, _complete_attack,
		_swarm_released, _dragon_in_chase_range
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

## Chase gate: the dragon must still exist — damage flows through the
## per-frame contact channel (attack_damage is DPS there), not a discrete hit.
func _dragon_in_chase_range() -> bool:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	return dragon != null and is_instance_valid(dragon)

func _complete_attack() -> void:
	pass  # contact DPS is applied in _contact_damage()

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

## Soldiers spot the dragon → alarm (swarm sighting), plus the two per-frame
## combat channels: burning status and contact DPS on the dragon.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_tick_burning(delta)
	_contact_damage(delta)
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon != null and is_instance_valid(dragon) \
			and global_position.distance_to(dragon.global_position) < aggro_range:
		var world := _world_manager()
		if world != null:
			world.report_dragon_sighting(dragon.global_position)

# --- combat: ablaze status + contact DPS ------------------------------------

## Flame breath hit: abandon orders (the behavior tree stops driving), panic
## in random bursts, burn at burn_damage/s, and die when the fire burns out.
func catch_fire() -> void:
	if _burning_left > 0.0 or not is_alive:
		return
	_burning_left = burn_duration
	_burn_move_timer = 0.0
	_burn_debt = 0.0
	if behavior_tree != null:
		behavior_tree.kill()
	if sprite != null:
		sprite.modulate = Color(1.0, 0.4, 0.1)  # scorched tint
	print("Soldier caught fire — panicking!")

## Ablaze physics: random-burst running, burn damage in int chunks, then death.
func _tick_burning(delta: float) -> void:
	if _burning_left <= 0.0 or not is_alive:
		return
	_burning_left -= delta
	_burn_move_timer -= delta
	if _burn_move_timer <= 0.0:
		_burn_move_timer = randf_range(0.25, 0.45)
		_burn_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	velocity = _burn_direction * speed * 1.4
	update_facing()
	move_and_slide()
	_burn_debt += burn_damage * delta
	var whole := int(_burn_debt)
	if whole > 0:
		_burn_debt -= float(whole)
		take_damage(whole)
	if _burning_left <= 0.0:
		die()

## 10 DPS while the hitbox collides with the dragon (integer-chunked debt).
func _contact_damage(delta: float) -> void:
	if _burning_left > 0.0 or not is_alive:
		return
	var dragon := get_tree().get_first_node_in_group("dragon") as CharacterBody2D
	if dragon == null or not is_instance_valid(dragon):
		return
	var dragon_dying: Variant = dragon.get("_dying")
	if dragon_dying == null or bool(dragon_dying):
		return
	if global_position.distance_to(dragon.global_position) > attack_range:
		return
	_contact_debt += attack_damage * delta
	var whole := int(_contact_debt)
	if whole > 0:
		_contact_debt -= float(whole)
		dragon.take_damage(whole)

func take_damage(amount: int) -> void:
	# Soldiers take fire/dragon damage; routed into the base class.
	super.take_damage(amount)

func die() -> void:
	defeated.emit(reward_gold)
	super.die()
