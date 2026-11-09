extends Node2D

class_name Arrow

## One arrow loosed by the Archer (2026-11-09 user spec). Flies STRAIGHT to
## the point captured at fire time — the dragon's position when loosed. A
## stationary dragon never misses (that point IS him); a moving dragon can
## dodge because the arrow never tracks him. 5 damage per hit.

const HIT_RADIUS := 30.0
const ARROW_DAMAGE := 5

var _dir := Vector2.RIGHT
var _speed := 500.0
var _life := 1.6   # ≈ 500 px/s × 1.6 = 800px max flight — well past any shot
var _hit := false

func launch(target: Vector2, speed: float) -> void:
	var to_target := target - global_position
	_dir = to_target.normalized() if to_target.length() > 1.0 else Vector2.RIGHT
	_speed = speed
	rotation = _dir.angle()   # $Shaft points right in local space

func _physics_process(delta: float) -> void:
	if _hit:
		return
	global_position += _dir * _speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return
	var dragon_dying: Variant = dragon.get("_dying")
	if dragon_dying == null or bool(dragon_dying):
		return
	if global_position.distance_to(dragon.global_position) <= HIT_RADIUS:
		_hit = true
		dragon.take_damage(ARROW_DAMAGE, false, "archer")
		queue_free()
