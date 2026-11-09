extends Soldier

class_name Wizard

## The BACKSTABBING wizard (2026-11-09 user spec). The tower shop's owner —
## he stays out of the war until the dragon provokes him: three upgrades
## bought AND more than three tower visits, or 30+ gold hoarded in the
## stash. Then he emerges from his tower and hunts the dragon ACROSS THE
## WHOLE MAP, throwing lightning (30 damage, long range, 2s recharge) and
## he does not stop until the dragon is dead. Carries a fire shield like
## the King's cloak (5s immunity from every ignition).

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
	fire_immunity_seconds = 5.0  # "a shield like the king"

	super._ready()
	add_to_group("wizard")

func catch_fire() -> void:
	var cloak_was_down: bool = _fire_immune_left <= 0.0
	super.catch_fire()
	if cloak_was_down and _burning_left > 0.0:
		print("The wizard's shield shimmers to life — fire-proof for %ds!"
			% int(fire_immunity_seconds))

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
	# bypass_shield: the backstabbing wizard pierces the shop shield
	# (user 2026-11-09: no shield against his attacks).
	dragon.take_damage(LIGHTNING_DAMAGE, true)
	_spawn_bolt(dragon.global_position)
	print("The wizard's lightning hits you for %d!" % LIGHTNING_DAMAGE)

## Brief electric bolt visual — a Line2D flash between wizard and dragon,
## freed by a SceneTreeTimer (synchronous: no coroutine in the NPC code).
func _spawn_bolt(target: Vector2) -> void:
	var bolt := Line2D.new()
	bolt.width = 3.0
	bolt.default_color = Color(0.6, 0.8, 1.0)
	get_parent().add_child(bolt)
	# The world layer sits at the origin, so rect-local points ARE world
	# coordinates — draw the bolt directly between the two fighters.
	bolt.points = PackedVector2Array([global_position, target])
	var timer := get_tree().create_timer(0.18)
	timer.timeout.connect(bolt.queue_free)

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
