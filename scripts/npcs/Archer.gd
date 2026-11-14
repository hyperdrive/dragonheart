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
	_animate_archery(delta)

# --- archery (2026-11-14 rig pass, user: "the archer doesn't aim") -------------

## While the dragon is in reach the archer squares up, raises the bow
## straight at it (bow arm on the aim line, bow upright to it) and draws:
## the string hand pulls the nocked arrow back to the cheek over the
## DRAW_TIME before each 2s shot, then the string snaps and the arrow
## leaves from the bow itself.
const DRAW_TIME := 1.4
const DRAW_PX := 9.0
const STRING_X := -4.0
const ARM_LEN := 12.0
var _aiming := false
var _snap := 0.0      # string-snap wobble after a release

func _animate_archery(delta: float) -> void:
	if _rig == null:
		return
	var bow := get_node_or_null("Sprite/ArmFront/Bow") as Node2D
	if bow == null:
		return
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	var dragon_dying: Variant = dragon.get("_dying") if dragon != null else null
	var aiming := is_alive and _burning_left <= 0.0 and dragon != null \
		and is_instance_valid(dragon) and dragon_dying != null and not bool(dragon_dying) \
		and global_position.distance_to(dragon.global_position) <= arrow_range
	var nock := bow.get_node_or_null("Nock") as Node2D
	var string := bow.get_node_or_null("String") as Line2D
	var arm_back := _rig.part("ArmBack")
	if not aiming:
		if _aiming:
			_aiming = false
			_rig.arms_override = false
			bow.rotation_degrees = 0.0
			if arm_back != null:
				arm_back.scale.y = 1.0
			if nock != null:
				nock.visible = false
			_set_string(string, 0.0)
		return
	_aiming = true
	_rig.arms_override = true
	var want := 1 if dragon.global_position.x >= global_position.x else -1
	if want != facing:
		facing = want
		_apply_facing()
	# Aim in the rig's own (unmirrored) frame: aim at the dragon's body.
	var arm_front := _rig.part("ArmFront")
	var target := dragon.global_position + Vector2(0.0, -24.0)
	var local := sprite.to_local(target) - arm_front.position
	var ang := atan2(local.y, local.x)
	arm_front.rotation = ang - PI / 2.0
	bow.rotation = PI / 2.0              # bow stands across the aim line
	# Draw amount: 0 right after a shot → 1 just before the next.
	var draw := clampf(1.0 - (_ranged_recharge - 0.15) / DRAW_TIME, 0.0, 1.0)
	_snap = maxf(0.0, _snap - delta * 4.0)
	_set_string(string, draw)
	if nock != null:
		nock.visible = draw > 0.05
		nock.position.x = STRING_X - DRAW_PX * draw
	# The string hand reaches the nock point (arm stretched/shortened).
	if arm_back != null:
		var nock_pt := sprite.to_local(bow.to_global(Vector2(STRING_X - DRAW_PX * draw, 0.0)))
		var v := nock_pt - arm_back.position
		arm_back.rotation = atan2(v.y, v.x) - PI / 2.0
		arm_back.scale.y = clampf(v.length() / ARM_LEN, 0.35, 1.3)
	_rig.lean = -0.05

func _set_string(string: Line2D, draw: float) -> void:
	if string == null:
		return
	var wobble := sin(_snap * 40.0) * _snap * 2.0
	string.points = PackedVector2Array([Vector2(STRING_X, -15.0),
		Vector2(STRING_X - DRAW_PX * draw + wobble, 0.0), Vector2(STRING_X, 15.0)])

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
	# Loosed from the bow itself (falls back to the feet without a rig).
	var bow := get_node_or_null("Sprite/ArmFront/Bow") as Node2D
	arrow.global_position = bow.global_position if bow != null else global_position
	arrow.launch(dragon.global_position, ARROW_SPEED)
	_snap = 1.0

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
