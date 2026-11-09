extends Soldier

class_name Archer

## Ranged town soldier (2026-11-09 user spec): an Archer fires ONE arrow
## every 2s whenever the dragon is inside his arrow reach — 5 damage each.
## The arrow aims at the dragon's CURRENT position, so a stationary dragon
## never misses and a moving dragon can naturally dodge. Everything else
## (morale, bold phalanx, rampart behavior) soldiers from Soldier.

const ARROW_SCENE := preload("res://scenes/objects/Arrow.tscn")
const ARROW_SPEED := 500.0
const STANDOFF_PX := 60.0   # hold this far inside the arrow reach

@export var arrow_range: float = 350.0

var _ranged_recharge: float = 0.0   # fires the INSTANT he is in range, then 1/2s

func _ready() -> void:
	# Configure before super._ready() — it syncs health from max_health.
	# (The Soldier profile gate only fires for its "villager" default, so
	# the Archer's own config survives.) super._ready() is Soldier._ready:
	# it builds the identical attack/patrol/idle tree — the Archer only
	# overrides providers/gates below (stand-off ring, arrows instead of
	# melee).
	npc_type = "archer"
	max_health = 50
	speed = 80.0
	danger_radius = 0.0  # archers never flee either

	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_tick_ranged_fire(delta)

## One arrow per 2s while the dragon is in reach — INDEPENDENT of the
## behavior tree (a calm-town archer still fires at an in-range dragon;
## the soldier morale gates only drive the stand-off positioning).
func _tick_ranged_fire(delta: float) -> void:
	if not is_alive or _burning_left > 0.0:
		return
	if _ranged_recharge > 0.0:
		_ranged_recharge -= delta
		return
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return
	var dragon_dying: Variant = dragon.get("_dying")
	if dragon_dying == null or bool(dragon_dying):
		return
	if global_position.distance_to(dragon.global_position) > arrow_range:
		return
	_ranged_recharge = 2.0  # user spec: 1 per 2s
	var arrow := ARROW_SCENE.instantiate() as Arrow
	get_parent().add_child(arrow)
	arrow.global_position = global_position
	arrow.launch(dragon.global_position, ARROW_SPEED)

## No melee at all: the ranged attack replaces the soldier's contact DPS.
func _contact_damage(delta: float) -> void:
	pass

## Stand-off positioning: the Archer closes until he can shoot, then holds
## a ring just inside his reach instead of walking into breath melee range.
func _pick_dragon_target() -> Vector2:
	var target := super._pick_dragon_target()
	if target == BehaviorTree.TARGET_NONE:
		return target
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null:
		return target
	if global_position.distance_to(dragon.global_position) > arrow_range:
		return target  # close in on the dragon
	var dir := (global_position - dragon.global_position).normalized()
	return dragon.global_position + dir * (arrow_range - STANDOFF_PX)
