extends Soldier

class_name King

## Final boss: spawned by WorldManager once the soldier threshold is met
## (docs/decisions/2026-11-08-behavior-system.md — escalation row).
## Stronger soldier profile + the Lightning Sword-Cloud special. Defeat =
## victory ONLY after the last respawn is spent (user spec
## 2026-11-09-king-lives: the King rises again THREE times, each time immune
## to fire for 5s per ignition via his cloak, and swinging a magic sword for
## heavy damage). Storm economy (2026-11-11, user: "2 sword storms ... more
## aggressively"): two charges, auto-cast by proximity rolls while the
## dragon lingers in trigger range, recharging one at a time.

@export_group("Boss stats")
@export var special_attack_radius: float = 80.0
@export_group("Lightning sword-cloud")
## 2026-11-11, user: "His special attack should be a cloud of swords I think
## to give the impression that he moves like lightning", then "The king
## should have 2 sword storms attacks and he should use them more
## aggressively." The King holds TWO storm charges. While the dragon
## lingers in trigger range he rolls for a cast several times a second —
## both storms dump within seconds of an engagement — and each spent
## charge recharges on a timer.
@export var storm_max_charges: int = 2
@export var storm_recharge_s: float = 8.0
## Cast rolls happen while the dragon is inside this range (1.4 x the
## damage radius): the King opens with the storm BEFORE melee contact.
@export var storm_trigger_range: float = 112.0
## Cast-roll rate (per second) while the dragon is in trigger range.
@export var storm_trigger_rate: float = 2.5
@export_group("Storm visuals")
@export var cloud_sword_count: int = 12
@export var cloud_stagger_s: float = 0.03
@export var cloud_linger_s: float = 0.55

var _storm_charges: int = 2
var _storm_recharge_left: float = 0.0
var _casting_storm: bool = false
var _sprite: Node2D = null
var game_manager: GameManager

func _ready() -> void:
	# Configure before super._ready() — it syncs health from max_health.
	npc_type = "king"
	max_health = 200
	speed = 60.0
	# Magic sword (2026-11-09): contact DPS is the main threat — 5x the
	# soldier's 10/s so a botched contact costs real dragon skin.
	attack_damage = 50
	attack_range = 70.0
	aggro_range = 10000.0  # hunts the dragon across the whole map
	reward_gold = 0
	fire_immunity_seconds = 5.0
	# Bosses never flee (was incidentally zeroed by the old Soldier._ready
	# stomp; honoring the King's own config exposed the leak).
	danger_radius = 0.0

	# Arm the storm economy from the tunables (2026-11-11).
	_storm_charges = storm_max_charges
	_storm_recharge_left = storm_recharge_s

	super._ready()

	_sprite = get_node_or_null("Sprite")
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	add_to_group("king")

func _physics_process(delta: float) -> void:
	_tick_storm_charges(delta)
	_try_storm(delta)
	super._physics_process(delta)

## Recharge spent storm charges one at a time on the recharge timer.
func _tick_storm_charges(delta: float) -> void:
	if _storm_charges >= storm_max_charges:
		return
	_storm_recharge_left -= delta
	if _storm_recharge_left <= 0.0:
		_storm_charges += 1
		_storm_recharge_left = storm_recharge_s
		print("The King's storm recharges — %d sword storm(s) ready!"
			% _storm_charges)

## Aggressive autonomous casting (2026-11-11, user: "use them more
## aggressively"): no more waiting for a melee swing to complete — the
## King rolls for a cast SEVERAL times a second while the dragon merely
## LINGERS in storm range, so an engagement opens with both storms
## dumped in seconds. The dragon must be alive and not dying.
func _try_storm(delta: float) -> void:
	if _casting_storm or _storm_charges <= 0 or not is_alive:
		return
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return
	var dragon_dying: Variant = dragon.get("_dying")
	if dragon_dying != null and bool(dragon_dying):
		return
	if global_position.distance_to(dragon.global_position) > storm_trigger_range:
		return
	if randf() < storm_trigger_rate * delta:
		_storm_charges -= 1
		# Restart the recharge clock HERE (bug fix 2026-11-11: it started
		# at 0.0, so a spent charge recharged INSTANTLY and the King
		# chain-stormed forever while the dragon stayed in range).
		_storm_recharge_left = storm_recharge_s
		_perform_special_attack()

## The cloak grants itself inside super.catch_fire (base grant path);
## surfacing the moment it activates so the player can read the rules.
func catch_fire() -> void:
	var cloak_was_down: bool = _fire_immune_left <= 0.0
	super.catch_fire()
	if cloak_was_down and _burning_left > 0.0:
		print("The King's magic cloak flares bright — fire-proof for %ds!"
			% int(fire_immunity_seconds))

## The Lightning Sword-Cloud special (replaces the old orange square pulse).
## Consumes one storm charge (the caller — _try_storm or a probe — has
## already decremented the counter); the casting flag blocks overlapping
## storms. Windup: the King's armor flares cold lightning-blue. Strike: the
## dragon eats the damage if inside the radius, then a ring of spectral
## greatswords rains down around him on rapid staggered beats.
func _perform_special_attack() -> void:
	if _casting_storm or _sprite == null or not is_inside_tree():
		return
	_casting_storm = true
	# Charge-up: a cold flare the player can read as "he moves like lightning".
	_sprite.modulate = Color(0.75, 0.85, 1.6)
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree() or not is_alive:
		if is_instance_valid(_sprite):
			_sprite.modulate = Color.WHITE
		_casting_storm = false
		return
	# The strike lands the moment the storm breaks.
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon != null and is_instance_valid(dragon) \
			and global_position.distance_to(dragon.global_position) \
				< special_attack_radius \
			and dragon.has_method("take_damage"):
		var dragon_dying: Variant = dragon.get("_dying")
		if dragon_dying == null or not bool(dragon_dying):
			dragon.take_damage(int(attack_damage * 1.5), false, "king")
	# Rain the swords: 30ms between falls = the lightning strobe.
	for i in cloud_sword_count:
		_spawn_cloud_sword()
		await get_tree().create_timer(cloud_stagger_s).timeout
		if not is_inside_tree():
			return
	if is_instance_valid(_sprite):
		_sprite.modulate = Color.WHITE
	_casting_storm = false

## One spectral greatsword of the cloud: a flat-rect composite dropped from
## the sky into the ring around the King, stabbed blade-down, lingering,
## then fading out. Grouped "king_swords" so probes can count the storm.
func _spawn_cloud_sword() -> void:
	# Spread the ring horizontally around him; keep it (mostly) above the
	# ground line so blades stab INTO the earth, not float below it.
	var pos := Vector2(
		randf_range(-special_attack_radius, special_attack_radius),
		randf_range(-special_attack_radius * 0.9, 10.0))
	if pos.length() < 24.0:
		pos = pos.normalized() * 24.0
	var sword := Node2D.new()
	sword.name = "CloudSword"
	sword.add_to_group("king_swords")
	sword.position = pos + Vector2(0, -140)  # starts high — lightning fall
	sword.rotation_degrees = randf_range(-14.0, 14.0)
	add_child(sword)
	# Blade points DOWN toward the ground (stabbed in); hilt above.
	_sword_rect(sword, -2.0, 6.0, 4.0, 24.0, Color(0.78, 0.84, 0.95))  # blade
	_sword_rect(sword, -2.0, 6.0, 1.2, 24.0, Color(0.9, 0.94, 1.0))    # edge
	_sword_rect(sword, -5.0, 2.0, 10.0, 4.0, Color(0.8, 0.64, 0.2))    # guard
	_sword_rect(sword, -1.5, -8.0, 3.0, 10.0, Color(0.3, 0.22, 0.15))  # grip
	_sword_rect(sword, -2.5, -11.0, 5.0, 4.0, Color(0.8, 0.64, 0.2))   # pommel
	# Lightning drop: slam into place in ~70ms, stick, fade like a spark.
	var fall := create_tween()
	fall.tween_property(sword, "position:y", pos.y, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_interval(cloud_linger_s)
	fall.tween_property(sword, "modulate:a", 0.0, 0.3)
	fall.tween_callback(sword.queue_free)

## One flat ColorRect in the world-art style (see also Dragon._rider_rect).
func _sword_rect(parent: Node2D, x: float, y: float, w: float, h: float,
		col: Color) -> void:
	var rect := ColorRect.new()
	rect.position = Vector2(x, y)
	rect.size = Vector2(w, h)
	rect.color = col
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)

func die() -> void:
	# Three respawns after the first defeat (user spec 2026-11-09-king-lives):
	# while lives remain, the death hands out to the WorldManager which
	# re-summons the King at the city; the run only ENDS on the last life.
	var world := get_tree().get_first_node_in_group("world_manager") as WorldManager
	if world != null and world.on_king_defeated():
		super.die()  # corpse out; the respawn is the world's business now
		return
	print("King defeated! Victory achieved!")
	if game_manager != null:
		game_manager.notify_king_defeated()
	else:
		push_warning("King: no GameManager — victory not registered")
	super.die()
