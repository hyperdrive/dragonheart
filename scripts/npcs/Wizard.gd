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
	if _lightning_left > 0.0:
		_lightning_left -= delta
	super._physics_process(delta)
	_tick_lightning(delta)

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

func _spawn_bolt(target: Vector2) -> void:
	var start := global_position
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
	return _dragon_huntable() != null

func _dragon_in_chase_range() -> bool:
	return _dragon_huntable() != null

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
