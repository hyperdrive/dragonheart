extends Soldier

class_name Wizard

## The BACKSTABBING wizard (2026-11-09 user spec). The tower shop's owner —
## he stays out of the war until the dragon provokes him: three upgrades
## bought AND more than three tower visits, or 30+ gold hoarded in the
## stash. Then he emerges from his tower and hunts the dragon ACROSS THE
## WHOLE MAP, throwing lightning (30 damage, long range, 2s recharge).
##
## The wizard is vulnerable to fire (no fire immunity or shield absorption).
## Dragon's shield absorbs wizard lightning damage before the shield is consumed.
##
## STORY ARC (2026-11-14, user: "a main character, starting off as a
## protagonist then turns into an evil antagonist trying to take the heart
## of the dragon"): the world spawns him KIND at his tower — slate-blue
## robes, white beard, a warm amber orb, and an EMPTY heart-shaped locket
## on his chest. He potters about his doorstep, harmless. When the dragon
## crosses his provocation lines (or breathes fire on him) he TURNS:
## head bowed, staff raised, slammed down in a shockwave — the robes bleed
## to violet-black, the eyes ignite, the orb turns crimson, a dark aura
## blooms, he rises off the ground, and the empty locket starts to glow:
## it hungers for the dragon's heart. Then the hunt begins.

signal turned  # the fall is complete (WorldManager tells the story then)

enum Phase { KIND, TURNING, FALLEN }
## Spawned directly (spawn_entity, probes) he is already fallen; the
## world's tower spawn sets this before add_child.
@export var start_kind := false
var phase: int = Phase.FALLEN
var _turn_t := 0.0
var _hover := 0.0
var _cast_left := 0.0
const TURN_TIME := 2.6
const HOVER_PX := 5.0
const FALLEN_ROBE := Color(0.46, 0.26, 0.56)
const FALLEN_TRIM := Color(1.0, 0.42, 0.40)
const KIND_SPEED := 30.0
const HUNT_SPEED := 75.0

const LIGHTNING_RANGE := 500.0   # "long range" — outclasses the breath cone
const LIGHTNING_DAMAGE := 30
const LIGHTNING_RECHARGE := 2.0

var _lightning_left: float = 0.0

func _ready() -> void:
	# Configure before super._ready() — it syncs health from max_health.
	npc_type = "wizard"
	max_health = 80
	speed = 75.0
	danger_radius = 0.0          # he never flees either
	attack_damage = LIGHTNING_DAMAGE  # his per-hit payload lives here
	attack_range = 0.0           # NO melee contact — lightning carries all
	aggro_range = 10000.0        # whole-map hunt
	reward_gold = 100
	# NO fire immunity — fire CAN hit the wizard (shield absorbs the first hit)
	# fire_immunity_seconds = 5.0  # removed: wizard is vulnerable to fire

	super._ready()
	add_to_group("wizard")
	if start_kind:
		phase = Phase.KIND
		aggro_range = 0.0   # a kindly merchant raises no alarms
		speed = KIND_SPEED
	else:
		_apply_fall_look(1.0)
		_hover = 1.0

# --- the fall (2026-11-14) ------------------------------------------------------

func is_kind() -> bool:
	return phase == Phase.KIND

## Begin the transformation (idempotent). Burning him also triggers it.
func turn_evil() -> void:
	if phase != Phase.KIND or not is_alive:
		return
	phase = Phase.TURNING
	_turn_t = 0.0
	velocity = Vector2.ZERO
	print("The old wizard bows his head… and something in him breaks.")

func _tick_turn(delta: float) -> void:
	_turn_t = minf(_turn_t + delta / TURN_TIME, 1.0)
	var t := _turn_t
	var rig := sprite as HumanoidRig
	var head := rig.part("Head") if rig != null else null
	if rig != null:
		rig.arms_override = true
		# bow → raise the staff → SLAM → rise
		var arm: float
		if t < 0.3:
			arm = lerpf(0.0, -20.0, t / 0.3)
		elif t < 0.6:
			arm = lerpf(-20.0, -172.0, smoothstep(0.0, 1.0, (t - 0.3) / 0.3))
		elif t < 0.68:
			arm = lerpf(-172.0, -18.0, (t - 0.6) / 0.08)
		else:
			arm = lerpf(-18.0, -60.0, smoothstep(0.0, 1.0, (t - 0.68) / 0.32))
		rig.set_arms(arm, 20.0 - 30.0 * smoothstep(0.6, 1.0, t))
		var staff := get_node_or_null("Sprite/ArmFront/Staff") as Node2D
		if staff != null:
			staff.rotation_degrees = -arm   # orb stays on top, held aloft
		rig.lean = 0.2 * (1.0 - smoothstep(0.0, 0.3, t)) if t < 0.3 else -0.08 * smoothstep(0.6, 1.0, t)
	if head != null:
		head.rotation = 0.25 * sin(minf(t / 0.3, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.55, 0.7, t))
	if t >= 0.66 and _turn_t - delta / TURN_TIME < 0.66:
		_spawn_shockwave()
	_apply_fall_look(smoothstep(0.62, 0.95, t))
	_hover = smoothstep(0.7, 1.0, t)
	if t >= 1.0:
		phase = Phase.FALLEN
		aggro_range = 10000.0
		speed = HUNT_SPEED
		if rig != null:
			rig.arms_override = false
			rig.lean = 0.0
		var staff_done := get_node_or_null("Sprite/ArmFront/Staff") as Node2D
		if staff_done != null:
			staff_done.rotation_degrees = 0.0
		print("The wizard rises, eyes burning — he has come for the dragon's HEART.")
		turned.emit()

## Blend the kind palette into the fallen one (k: 0 kind → 1 fallen).
func _apply_fall_look(k: float) -> void:
	var robe := Color.WHITE.lerp(FALLEN_ROBE, k)
	var trim := Color.WHITE.lerp(FALLEN_TRIM, k)
	for path: String in ["Sprite/Torso/Robe", "Sprite/Torso/RobeFold1", "Sprite/Torso/RobeFold2",
			"Sprite/ArmFront/Sleeve", "Sprite/ArmBack/Sleeve", "Sprite/Head/HatCone",
			"Sprite/Head/HatBrim", "Sprite/LegBack/Pants", "Sprite/LegFront/Pants"]:
		var n := get_node_or_null(path) as CanvasItem
		if n != null:
			n.modulate = robe
	for path: String in ["Sprite/Torso/Hem", "Sprite/Torso/Placket", "Sprite/Head/HatBand",
			"Sprite/ArmFront/SleeveTrim", "Sprite/Torso/Star1", "Sprite/Torso/Star2"]:
		var n := get_node_or_null(path) as CanvasItem
		if n != null:
			n.modulate = trim
	var beard := get_node_or_null("Sprite/Head/Beard") as CanvasItem
	if beard != null:
		beard.modulate = Color.WHITE.lerp(Color(0.78, 0.76, 0.80), k)
	for path: String in ["Sprite/Head/EyeGlow", "Sprite/ArmFront/Staff/OrbFallen", "Sprite/Aura"]:
		var n := get_node_or_null(path) as CanvasItem
		if n != null:
			n.visible = k > 0.02
			n.modulate.a = k
	var glow := get_node_or_null("Sprite/ArmFront/Staff/OrbGlow") as Polygon2D
	if glow != null:
		glow.color = Color(1.0, 0.80, 0.40, 0.35).lerp(Color(0.9, 0.08, 0.16, 0.45), k)
	var socket := get_node_or_null("Sprite/Torso/HeartSocket") as Polygon2D
	if socket != null:
		socket.color = Color(0.14, 0.10, 0.14).lerp(Color(1.0, 0.16, 0.18), k)

## The staff-slam shockwave: a violet ring racing out across the ground.
func _spawn_shockwave() -> void:
	if not is_inside_tree():
		return
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a) * 10.0, sin(a) * 3.2))
	ring.points = pts
	ring.width = 2.0
	ring.default_color = Color(0.7, 0.3, 0.9, 0.9)
	ring.z_index = -1
	get_parent().add_child(ring)
	ring.global_position = global_position
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * 7.0, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(ring.queue_free)

## Fallen: he drifts above the ground; the aura pulses; the locket throbs.
func _tick_fallen_look(delta: float) -> void:
	var bob := sin(float(Time.get_ticks_msec()) * 0.004) * 1.2
	if sprite != null:
		sprite.position = _sprite_home + Vector2(0.0, -(HOVER_PX + bob) * _hover)
	var aura := get_node_or_null("Sprite/Aura") as Node2D
	if aura != null and aura.visible:
		var pulse := 1.0 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.006)
		aura.scale = Vector2(pulse, pulse)
		aura.position.y = (HOVER_PX + bob) * _hover   # stays on the ground
	var socket := get_node_or_null("Sprite/Torso/HeartSocket") as CanvasItem
	if socket != null and phase == Phase.FALLEN:
		socket.modulate.a = 0.7 + 0.3 * sin(float(Time.get_ticks_msec()) * 0.008)

# --- kind life: pottering about his doorstep -----------------------------------

func _pick_patrol_target() -> Vector2:
	if phase != Phase.FALLEN:
		return home_position + Vector2(randf_range(-50.0, 50.0), randf_range(-20.0, 30.0))
	return super._pick_patrol_target()

func _pick_idle_target() -> Vector2:
	if phase != Phase.FALLEN:
		return home_position + Vector2(randf_range(-40.0, 40.0), randf_range(-15.0, 25.0))
	return super._pick_idle_target()

func _swarm_rallying() -> bool:
	return false if phase != Phase.FALLEN else super._swarm_rallying()

func _swarm_released() -> bool:
	return false if phase != Phase.FALLEN else super._swarm_released()

# --- ablaze status -----------------------------------------------------------

## Fire rule (2026-11-14 user: "fire should kill all the actors, but the
## wizard who survives two blasts"): his wards turn the first TWO breath
## blasts (a singe and a stagger, no burn); the third sets him ablaze like
## anyone else. The dragon re-ignites every frame of a breath window, so a
## blast only counts once per BLAST_WINDOW_MS (one 0.8s breath pulse).
const WARDED_BLASTS := 2
const BLAST_WINDOW_MS := 900
const WARD_SINGE_DAMAGE := 10
var _blasts_taken: int = 0
var _blast_window_until: int = 0

func catch_fire() -> void:
	if not is_alive or _burning_left > 0.0:
		return
	var now := Time.get_ticks_msec()
	if now < _blast_window_until:
		return  # same breath pulse — already counted
	_blast_window_until = now + BLAST_WINDOW_MS
	_blasts_taken += 1
	if phase == Phase.KIND:
		turn_evil()   # you burned the old man — now he shows his true face
	if _blasts_taken <= WARDED_BLASTS:
		print("The wizard's wards drink the flames! (%d/%d)" % [_blasts_taken, WARDED_BLASTS])
		take_damage(WARD_SINGE_DAMAGE)
		if sprite != null and is_alive:
			sprite.modulate = Color(1.0, 0.55, 0.3)
			var tw := create_tween()
			tw.tween_property(sprite, "modulate", Color.WHITE, 0.6)
		return
	print("The wards shatter — the wizard is ablaze!")
	super.catch_fire()

func _physics_process(delta: float) -> void:
	if phase == Phase.TURNING and is_alive:
		_tick_turn(delta)
		_tick_rig(delta)
		_tick_fallen_look(delta)
		return
	if _lightning_left > 0.0:
		_lightning_left -= delta
	super._physics_process(delta)
	if phase == Phase.FALLEN:
		_tick_lightning(delta)
		_animate_cast(delta)
	_tick_fallen_look(delta)

## Casting: the staff rises toward the dragon in the half-second before a
## bolt and snaps forward at the strike; the orb flares crimson.
const CAST_WINDUP := 0.5
func _animate_cast(delta: float) -> void:
	var rig := sprite as HumanoidRig
	if rig == null or not is_alive or _burning_left > 0.0:
		return
	_cast_left = maxf(0.0, _cast_left - delta)
	var dragon := _dragon_huntable()
	var in_range := dragon != null \
		and global_position.distance_to(dragon.global_position) <= LIGHTNING_RANGE
	if not in_range:
		if rig.arms_override:
			rig.arms_override = false
			var rest := get_node_or_null("Sprite/ArmFront/Staff") as Node2D
			if rest != null:
				rest.rotation_degrees = 0.0
		return
	var want := 1 if dragon.global_position.x >= global_position.x else -1
	if want != facing:
		facing = want
		_apply_facing()
	rig.arms_override = true
	var windup := clampf(1.0 - _lightning_left / CAST_WINDUP, 0.0, 1.0)
	var strike := _cast_left / 0.25   # 1 right after a bolt → 0
	var arm := lerpf(-40.0, -160.0, smoothstep(0.0, 1.0, windup))
	arm = lerpf(arm, -95.0, strike)
	rig.set_arms(arm, -25.0)
	# Staff's WORLD angle (0 = upright): held overhead on the wind-up,
	# levelled at the dragon on the strike, relaxed in between.
	var staff_world := lerpf(10.0, -8.0, windup)
	staff_world = lerpf(staff_world, 78.0, strike)
	var staff := get_node_or_null("Sprite/ArmFront/Staff") as Node2D
	if staff != null:
		staff.rotation_degrees = staff_world - arm
	var glow := get_node_or_null("Sprite/ArmFront/Staff/OrbGlow") as CanvasItem
	if glow != null:
		glow.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.3, 1.3), maxf(windup, strike))

## Where the bolt leaves from: the orb on his staff.
func bolt_origin() -> Vector2:
	var orb := get_node_or_null("Sprite/ArmFront/Staff/Orb") as Polygon2D
	if orb == null:
		return global_position
	return orb.to_global(Vector2(0.2, -27.2))

## Lightning strike: INSTANT long-range bolt — aim is guaranteed by nature
## (the bolt IS a lightning strike), the recharge is the only relief. Fires
## the instant he is in range, then every 2s.
func _tick_lightning(delta: float) -> void:
	if _lightning_left > 0.0:
		return
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return
	var dragon_dying: Variant = dragon.get("_dying")
	if dragon_dying == null or bool(dragon_dying):
		return
	if global_position.distance_to(dragon.global_position) > LIGHTNING_RANGE:
		return
	_lightning_left = LIGHTNING_RECHARGE
	_cast_left = 0.25
	# Dragon's shield absorbs some lightning damage before the shield is consumed.
	dragon.take_damage(LIGHTNING_DAMAGE, false, "wizard")
	_spawn_bolt(dragon.global_position)

## Electric bolt visual (2026-11-11, user: "his attack is just a straight
## line. Lets divide it multiple segments and offset them to the normal of
## the line at random so it looks more like a lightning. Also add a small
## curve to it (sine)"): the bolt is now a jagged arc — N segments along
## the wizard→dragon line, every INTERIOR vertex shoved off the line's
## normal by a random-signed sine bow (the gentle curve) plus per-point
## random jitter (the crackle); endpoints stay pinned so the strike still
## visibly connects caster to victim. A wide translucent glow line runs
## underneath the bright core.
const BOLT_SEGMENTS := 10
const BOLT_CURVE_AMP := 26.0    # the gentle sine bow off the straight line
const BOLT_JITTER := 12.0       # per-vertex random normal noise
const BOLT_CORE_WIDTH := 3.0
const BOLT_GLOW_WIDTH := 9.0
const BOLT_FLASH_S := 0.18

## Where the last bolt actually left from (the staff keeps moving after).
var last_bolt_origin := Vector2.ZERO

func _spawn_bolt(target: Vector2) -> void:
	var start := bolt_origin()
	last_bolt_origin = start
	var to_target := target - start
	var length := to_target.length()
	if length < 1.0:
		return
	# The normal of the line: perpendicular unit vector.
	var normal := to_target.normalized().orthogonal()
	# The sine bow flips direction with every strike — no two bolts curve
	# the same way.
	var curve_sign := 1.0 if randf() < 0.5 else -1.0
	var points := PackedVector2Array()
	for i in BOLT_SEGMENTS + 1:
		var t := float(i) / float(BOLT_SEGMENTS)
		var p := start + to_target * t
		if i > 0 and i < BOLT_SEGMENTS:
			# Interior vertices only: a smooth sine arc plus crackle
			# jitter, both along the line's normal.
			var offset := curve_sign * sin(t * PI) * BOLT_CURVE_AMP \
				+ randf_range(-BOLT_JITTER, BOLT_JITTER)
			p += normal * offset
		points.append(p)
	# One assembly so the glow + core free together.
	var flash := Node2D.new()
	flash.name = "LightningBolt"
	flash.add_to_group("wizard_bolts")
	get_parent().add_child(flash)
	var glow := Line2D.new()
	glow.width = BOLT_GLOW_WIDTH
	glow.default_color = Color(0.55, 0.75, 1.0, 0.35)
	glow.points = points
	flash.add_child(glow)
	var core := Line2D.new()
	core.width = BOLT_CORE_WIDTH
	core.default_color = Color(0.85, 0.95, 1.0)
	core.points = points
	flash.add_child(core)
	var timer := get_tree().create_timer(BOLT_FLASH_S)
	timer.timeout.connect(flash.queue_free)

## No melee at all.
func _contact_damage(delta: float) -> void:
	pass

# --- relenless pursuit: every gate unlocked -----------------------------------

## The wizard does not care about swarm morale or rally — the moment he is
## out, the hunt is always on (user: "won't stop until he killed you").
func _attack_ready() -> bool:
	return phase == Phase.FALLEN and _dragon_huntable() != null

func _dragon_in_chase_range() -> bool:
	return phase == Phase.FALLEN and _dragon_huntable() != null

func _pick_dragon_target() -> Vector2:
	var hunt := _dragon_huntable()
	if hunt == null:
		return BehaviorTree.TARGET_NONE
	return hunt.global_position

func _dragon_huntable() -> Node2D:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return null
	var dragon_dying: Variant = dragon.get("_dying")
	if dragon_dying == null or bool(dragon_dying):
		return null
	return dragon
