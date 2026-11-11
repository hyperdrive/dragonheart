extends Node2D

class_name Arrow

## One arrow loosed by the Archer (2026-11-09 user spec). Flies STRAIGHT to
## the point captured at fire time — the dragon's position when loosed. A
## stationary dragon never misses (that point IS him); a moving dragon can
## dodge because the arrow never tracks him. 5 damage per hit.
##
## rider_arrow mode (2026-11-11): the DRAGON RIDER looses arrows too — same
## straight-flight ballistics, but the payload hunts soldiers/goblins
## instead of the dragon (bug fix: stock arrows homed on the dragon, so a
## rider arrow would have shot her own mount).

const HIT_RADIUS := 30.0
const ARROW_DAMAGE := 5
## Rider payload (2026-11-11, user: "should kill if the arrow hits a target,
## increase damage!"): a rider arrow is a LETHAL shot — one hit, one kill
## (soldiers field at 50 HP). Kept separate from the archer's 5 so the
## town's arrows stay survivable; the rider's don't.
const RIDER_ARROW_DAMAGE := 100

var _dir := Vector2.RIGHT
var _speed := 500.0
var _life := 1.6   # ≈ 500 px/s × 1.6 = 800px max flight — well past any shot
var _hit := false

## Rider mode: true → damages the nearest live soldier/goblin touched;
## false (default) → damages the dragon, exactly as before.
var rider_arrow: bool = false

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
	if rider_arrow:
		_check_rider_hit()
	else:
		_check_dragon_hit()

## Stock behaviour: hit the DRAGON.
func _check_dragon_hit() -> void:
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

## Rider behaviour: hit the nearest live soldier/goblin in the blast radius.
func _check_rider_hit() -> void:
	for group: String in ["soldiers", "goblins"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var npc := node as BaseNPC
			if npc == null or not npc.is_alive or npc.is_in_group("king"):
				continue
			if global_position.distance_to(npc.global_position) <= HIT_RADIUS:
				_hit = true
				npc.take_damage(RIDER_ARROW_DAMAGE)
				queue_free()
				return
