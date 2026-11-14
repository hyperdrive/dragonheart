extends Soldier

class_name DragonSlayer

## The dragon slayer (2026-11-14, user: "a new NPC that appears randomly
## like the adventurer… riding and with a lance. His attack is that he aims
## his lance then dashes forward very quickly. 50p weapon damage on impact.
## He is immune to dragon fire and must be clawed").
##
## A knight of Osric's sun on a white charger. He rides the dragon down
## across the whole map, holding off at lance distance, then jousts:
##
## (2026-11-15, user: "aim faster and strike from a longer distance":
## aim 1.0 → 0.6 s, reach 270 → 440 px, charge 640 → 800 px/s.)
##
##   AIM      stop, level the lance, track the dragon — the last AIM_LOCK
##            seconds the line is FIXED (a red mark on the ground shows
##            it): that is the player's moment to step aside
##   DASH     a very fast charge along the locked line; touching the dragon
##            deals LANCE_DAMAGE (WEAPON) once, a wall or DASH_MAX ends it
##   RECOVER  rein in, raise the lance, then COOLDOWN before the next joust
##
## Fire slides off his enchanted plate (no burn, DRAGON_FIRE ×0); 75 HP =
## three base claw strikes. Like every antagonist he cannot see the farm
## girl (he hunts "dragon_threat").

enum Joust { RIDE, AIM, DASH, RECOVER }

const LANCE_DAMAGE := 50
const CHARGE_RANGE := 440.0     # starts a joust within this distance…
const CHARGE_MIN := 60.0        # …but not when the dragon is on top of him
const STANDOFF := 340.0         # rides to this distance from the dragon
const AIM_TIME := 0.6
const AIM_LOCK := 0.25          # the line is fixed for the last part of the aim
const DASH_SPEED := 800.0
const DASH_MAX := 560.0
const HIT_RADIUS := 34.0
const RECOVER_TIME := 0.9
const COOLDOWN := 2.5
const REPOSITION_AFTER := 1.0   # lane blocked this long → find another angle

var joust := Joust.RIDE
var _joust_t := 0.0
var _aim_dir := Vector2.RIGHT
var _dashed := 0.0
var _cooldown := 1.5
var _telegraph: Line2D = null
var _blocked_t := 0.0

func _ready() -> void:
	npc_type = "dragon_slayer"
	max_health = 75
	speed = 95.0
	attack_damage = 0.0          # no contact blows: the lance is the weapon
	attack_range = 0.0
	aggro_range = 0.0
	reward_gold = 0
	danger_radius = 0.0          # he came for the dragon; he does not flee
	is_flammable = false
	visual_scale = 0.85          # 2026-11-15, user: "15% smaller" (art only; hooves stay on the origin)
	super._ready()
	damage_taken = {Damage.Type.DRAGON_FIRE: 0.0}
	add_to_group("dragon_slayer")
	_telegraph = Line2D.new()
	_telegraph.width = 6.0
	_telegraph.default_color = Color(1.0, 0.15, 0.1, 0.0)
	_telegraph.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_telegraph.end_cap_mode = Line2D.LINE_CAP_ROUND
	_telegraph.z_index = -1
	add_child(_telegraph)

func _slayer_rig() -> SlayerRig:
	return sprite as SlayerRig

func _dragon() -> Node2D:
	var dragon := get_tree().get_first_node_in_group("dragon_threat") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return null
	var dying: Variant = dragon.get("_dying")
	return null if dying == null or bool(dying) else dragon

# --- riding (the behavior tree) -------------------------------------------------

func _attack_ready() -> bool:
	return _dragon() != null

func _dragon_in_chase_range() -> bool:
	return _dragon() != null

## Ride to lance distance, not into the dragon: a stand-off spot on open
## ground with a clear charging lane, nearest to where he is now (eight
## bearings around the dragon; the near side when none is clear).
func _pick_dragon_target() -> Vector2:
	var dragon := _dragon()
	if dragon == null:
		return BehaviorTree.TARGET_NONE
	var away := (global_position - dragon.global_position).normalized()
	if away == Vector2.ZERO:
		away = Vector2.LEFT
	var fallback := dragon.global_position + away * STANDOFF
	var nav := _nav()
	if nav == null:
		return fallback
	var best := Vector2.INF
	var best_d := INF
	for i in 8:
		var spot := dragon.global_position + away.rotated(TAU * float(i) / 8.0) * STANDOFF
		if not nav.is_walkable(spot) or not _lane_clear(spot, dragon.global_position):
			continue
		var d := spot.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = spot
	return best if best != Vector2.INF else fallback

## A charging lane from `from` toward the dragon: open ground up to a lance
## length short of it (the dragon itself may stand hard by a rock, in a
## cell no walker could occupy).
func _lane_clear(from: Vector2, dragon_pos: Vector2) -> bool:
	var nav := _nav()
	if nav == null:
		return true
	var to := dragon_pos.move_toward(from, HIT_RADIUS)
	return nav.line_clear(from, to)

func _swarm_rallying() -> bool:
	return false

func _swarm_released() -> bool:
	return false

func _contact_damage(_delta: float) -> void:
	pass

func _animate_combat(_delta: float) -> void:
	pass

func _killer_key() -> String:
	return "dragon_slayer"

# --- the joust -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	if joust == Joust.RIDE:
		super._physics_process(delta)
		_cooldown = maxf(0.0, _cooldown - delta)
		_try_start_joust()
	else:
		_tick_joust(delta)
		_tick_rig(delta)

func _try_start_joust() -> void:
	if _cooldown > 0.0:
		return
	var dragon := _dragon()
	if dragon == null:
		return
	var d := global_position.distance_to(dragon.global_position)
	if d > CHARGE_RANGE or d < CHARGE_MIN:
		return
	if not _lane_clear(global_position, dragon.global_position):
		# No clear lane from here: after a moment, ride for a better angle.
		_blocked_t += get_physics_process_delta_time()
		if _blocked_t >= REPOSITION_AFTER and behavior_tree != null:
			_blocked_t = 0.0
			behavior_tree.force_repick()
		return
	_blocked_t = 0.0
	joust = Joust.AIM
	_joust_t = 0.0
	velocity = Vector2.ZERO
	_aim_dir = (dragon.global_position - global_position).normalized()
	print("The dragon slayer levels his lance!")

func _tick_joust(delta: float) -> void:
	_joust_t += delta
	var rig := _slayer_rig()
	match joust:
		Joust.AIM:
			var dragon := _dragon()
			if dragon == null:
				_end_joust()   # the dragon vanished (or became a farm girl)
				return
			if _joust_t < AIM_TIME - AIM_LOCK:
				_aim_dir = (dragon.global_position - global_position).normalized()
			_face(_aim_dir)
			var k := clampf(_joust_t / AIM_TIME, 0.0, 1.0)
			if rig != null:
				rig.lance_couch = k
				rig.rider_lean = k
			var locked := _joust_t >= AIM_TIME - AIM_LOCK
			_telegraph.points = PackedVector2Array([Vector2.ZERO, _aim_dir * DASH_MAX])
			_telegraph.default_color = Color(1.0, 0.15, 0.1, 0.55 if locked else 0.18 * k)
			if _joust_t >= AIM_TIME:
				joust = Joust.DASH
				_joust_t = 0.0
				_dashed = 0.0
				_telegraph.default_color.a = 0.0
		Joust.DASH:
			velocity = _aim_dir * DASH_SPEED
			var before := global_position
			move_and_slide()
			_dashed += before.distance_to(global_position)
			var dragon := _dragon()
			if dragon != null and global_position.distance_to(dragon.global_position) <= HIT_RADIUS:
				dragon.take_damage(LANCE_DAMAGE, Damage.Type.WEAPON, "dragon_slayer")
				print("The dragon slayer's lance strikes home! (%d)" % LANCE_DAMAGE)
				_begin_recover()
			elif get_slide_collision_count() > 0 or _dashed >= DASH_MAX \
					or before.distance_to(global_position) < 1.0:
				_begin_recover()
		Joust.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, DASH_SPEED * 3.0 * delta)
			move_and_slide()
			var k := clampf(1.0 - _joust_t / RECOVER_TIME, 0.0, 1.0)
			if rig != null:
				rig.lance_couch = k
				rig.rider_lean = k
			if _joust_t >= RECOVER_TIME:
				_end_joust()

func _begin_recover() -> void:
	joust = Joust.RECOVER
	_joust_t = 0.0

func _end_joust() -> void:
	joust = Joust.RIDE
	_cooldown = COOLDOWN
	_telegraph.default_color.a = 0.0
	velocity = Vector2.ZERO
	invalidate_route()
	var rig := _slayer_rig()
	if rig != null:
		rig.lance_couch = 0.0
		rig.rider_lean = 0.0

func _face(dir: Vector2) -> void:
	var want := 1 if dir.x >= 0.0 else -1
	if want != facing:
		facing = want
		_apply_facing()

func die() -> void:
	print("The dragon slayer falls from his saddle, and his white horse bolts riderless.")
	if _telegraph != null:
		_telegraph.default_color.a = 0.0
	super.die()
