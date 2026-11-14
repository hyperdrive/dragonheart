extends Soldier

class_name Hag

## Mother Grisla, the hag of the fen (2026-11-14, user: "spawn a vicious
## hag. For now she fights hard like the King but with her claws"). The
## wizard's quest places her nest west of the dragon's mountain when the
## King rides out. She guards her territory: inside TERRITORY_RADIUS of her
## nest she hunts the dragon with King-grade stats (245 HP, 50 contact
## DPS, fire cloak); otherwise she prowls her fen. No storm, no rally, no
## town alarms — she is nobody's soldier.
##
## The house visit (2026-11-14): until provoked she plays the sweet old
## lady of the fen — pottering by her door, claws tucked away. Hurting her
## (or choosing to kill her over tea) makes her HOSTILE for good; after the
## tea warning the dragon may instead spare her (befriend) and hunt the
## wizard — then only a fresh wound turns her again.

const TERRITORY_RADIUS := 420.0
const SWIPE_HZ := 2.0

## Toughness (2026-11-14, user: "at least two fires and five claw hits"):
## 245 HP = two burns (2 × 60 dragon fire) + five base claw strikes (5 × 25).

## A Thousand and One Cuts (user: "a cloud of claws that inflict 50p of
## damage, with an init charge of 0.5s and a recharge of 5s"): she marks
## the ground where the dragon stands, the mark draws in for CUTS_CHARGE
## seconds — time to get out — then a storm of spectral claws rakes it.
const CUTS_DAMAGE := 50
const CUTS_CHARGE := 0.5
const CUTS_RECHARGE := 5.0
const CUTS_RADIUS := 62.0
const CUTS_TRIGGER_RANGE := 190.0
const CUTS_COUNT := 26
var _cuts_recharge_left := 2.0   # a short breath after she unmasks
var _cutting := false

var nest_position := Vector2.ZERO
## False = the kindly-old-lady act; true = Mother Grisla, claws out.
var hostile := false
## The dragon spared her and went after the wizard instead.
var befriended := false
var _swipe_phase := 0.0
var _clawing := false

func _ready() -> void:
	# Configure before super._ready() — it syncs health from max_health.
	npc_type = "hag"
	max_health = 245
	speed = 62.0
	attack_damage = 50.0       # King-grade contact DPS, delivered by claws
	attack_range = 70.0
	aggro_range = 0.0          # raises no town alarms
	reward_gold = 0
	fire_immunity_seconds = 5.0
	danger_radius = 0.0        # she never flees
	super._ready()
	add_to_group("hag")
	if nest_position == Vector2.ZERO:
		nest_position = global_position

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_animate_claws(delta)
	_tick_cuts(delta)

# --- territory -----------------------------------------------------------------

## Drop the act: from now on she hunts the dragon in her territory.
func unmask() -> void:
	if hostile or not is_alive:
		return
	hostile = true
	befriended = false
	print("Mother Grisla's smile splits into a mouthful of teeth!")

func befriend() -> void:
	befriended = true
	hostile = false

## A wound is a wound: whoever she was pretending to be, she isn't now.
func take_damage(amount: int, type: Damage.Type = Damage.Type.WEAPON,
		source: String = "") -> void:
	super.take_damage(amount, type, source)
	unmask()

## Tea time: the dragon came to her door, so the old lady is back —
## whatever happened outside. She waits on her doorstep.
func play_old_lady() -> void:
	hostile = false
	velocity = Vector2.ZERO
	global_position = nest_position

func catch_fire() -> void:
	super.catch_fire()
	unmask()

## Claws only for a hostile hag (Soldier's contact DPS is ungated).
func _contact_damage(delta: float) -> void:
	if hostile:
		super._contact_damage(delta)

func _dragon_in_territory() -> Node2D:
	if not hostile:
		return null
	var dragon := get_tree().get_first_node_in_group("dragon_threat") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return null
	var dying: Variant = dragon.get("_dying")
	if dying == null or bool(dying):
		return null
	if dragon.global_position.distance_to(nest_position) > TERRITORY_RADIUS:
		return null
	return dragon

func _attack_ready() -> bool:
	return _dragon_in_territory() != null

func _dragon_in_chase_range() -> bool:
	return _dragon_in_territory() != null

func _pick_dragon_target() -> Vector2:
	var dragon := _dragon_in_territory()
	return dragon.global_position if dragon != null else BehaviorTree.TARGET_NONE

func _pick_patrol_target() -> Vector2:
	return nest_position + Vector2(randf_range(-90.0, 90.0), randf_range(-20.0, 70.0))

func _pick_idle_target() -> Vector2:
	return nest_position + Vector2(randf_range(-60.0, 60.0), randf_range(10.0, 50.0))

func _swarm_rallying() -> bool:
	return false

func _swarm_released() -> bool:
	return false

# --- the claws -------------------------------------------------------------------

## In reach of the dragon she rakes with both hands in turn: each arm rears
## up behind her head and slashes down-forward, half a beat apart.
func _animate_claws(delta: float) -> void:
	var rig := sprite as HumanoidRig
	if rig == null or not is_alive:
		return
	var dragon := get_tree().get_first_node_in_group("dragon_threat") as Node2D
	var in_reach := hostile and _burning_left <= 0.0 and dragon != null and is_instance_valid(dragon) \
		and global_position.distance_to(dragon.global_position) <= attack_range + 10.0
	if _cutting:
		_clawing = true
		rig.arms_override = true
		rig.set_arms(-160.0, -150.0)
		rig.lean = -0.1
	elif in_reach:
		_clawing = true
		var want := 1 if dragon.global_position.x >= global_position.x else -1
		if want != facing:
			facing = want
			_apply_facing()
		rig.arms_override = true
		_swipe_phase = fmod(_swipe_phase + delta * SWIPE_HZ, 1.0)
		rig.set_arms(_swipe_angle(_swipe_phase), _swipe_angle(fmod(_swipe_phase + 0.5, 1.0)))
		rig.lean = 0.3 + 0.1 * sin(_swipe_phase * TAU * 2.0)
	else:
		if _clawing:
			_clawing = false
			rig.arms_override = false
		rig.lean = 0.2   # the crone's stoop

## One arm's swipe: slow rear-up (0..0.6), vicious rake (0.6..0.75), recover.
func _swipe_angle(p: float) -> float:
	if p < 0.6:
		return lerpf(-30.0, -165.0, smoothstep(0.0, 1.0, p / 0.6))
	if p < 0.75:
		return lerpf(-165.0, -20.0, (p - 0.6) / 0.15)
	return lerpf(-20.0, -30.0, (p - 0.75) / 0.25)

# --- a thousand and one cuts ------------------------------------------------

func _tick_cuts(delta: float) -> void:
	if _cuts_recharge_left > 0.0:
		_cuts_recharge_left -= delta
		return
	if _cutting or not is_alive or _burning_left > 0.0:
		return
	var dragon := _dragon_in_territory()
	if dragon == null or global_position.distance_to(dragon.global_position) > CUTS_TRIGGER_RANGE:
		return
	_cast_cuts(dragon.global_position)

func _cast_cuts(target: Vector2) -> void:
	_cutting = true
	_cuts_recharge_left = CUTS_RECHARGE + CUTS_CHARGE
	print("Mother Grisla shrieks: A THOUSAND AND ONE CUTS!")
	var world := get_parent() as Node2D
	var cloud := HagClawCloud.new()
	cloud.radius = CUTS_RADIUS
	cloud.charge_time = CUTS_CHARGE
	cloud.claw_count = CUTS_COUNT
	world.add_child(cloud)
	cloud.global_position = target
	# the tell on her: arms flung up, a sick green glow
	if sprite != null:
		sprite.modulate = Color(0.75, 1.4, 0.7)
	await get_tree().create_timer(CUTS_CHARGE, false).timeout
	if is_instance_valid(sprite):
		sprite.modulate = Color.WHITE
	_cutting = false
	if not is_inside_tree() or not is_alive:
		if is_instance_valid(cloud):
			cloud.queue_free()
		return
	cloud.strike()
	var dragon := get_tree().get_first_node_in_group("dragon_threat") as Node2D
	if dragon != null and is_instance_valid(dragon) \
			and HagClawCloud.covers(target, dragon.global_position, CUTS_RADIUS):
		dragon.take_damage(CUTS_DAMAGE, Damage.Type.MAGIC, "hag")

func die() -> void:
	print("Mother Grisla shrieks, and the fen goes quiet.")
	super.die()
