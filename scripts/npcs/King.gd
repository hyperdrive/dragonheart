extends Soldier

class_name King

## Final boss: spawned by WorldManager once the soldier threshold is met
## (docs/decisions/2026-11-08-behavior-system.md — escalation row).
## Stronger soldier profile + periodic area special attack. Defeat = victory
## ONLY after the last respawn is spent (user spec 2026-11-09-king-lives:
## the King rises again THREE times, each time immune to fire for 5s per
## ignition via his cloak, and swinging a magic sword for heavy damage).

@export_group("Boss stats")
@export var special_attack_cooldown: float = 10.0
@export var special_attack_chance: float = 0.3
@export var special_attack_radius: float = 80.0

var _special_attack_timer: float = 0.0
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

	super._ready()

	_sprite = get_node_or_null("Sprite")
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	add_to_group("king")

func _physics_process(delta: float) -> void:
	if _special_attack_timer > 0.0:
		_special_attack_timer -= delta
	super._physics_process(delta)

## The cloak grants itself inside super.catch_fire (base grant path);
## surfacing the moment it activates so the player can read the rules.
func catch_fire() -> void:
	var cloak_was_down: bool = _fire_immune_left <= 0.0
	super.catch_fire()
	if cloak_was_down and _burning_left > 0.0:
		print("The King's magic cloak flares bright — fire-proof for %ds!"
			% int(fire_immunity_seconds))

## King employs the periodic area special between regular attacks.
func _complete_attack() -> void:
	super._complete_attack()
	if _special_attack_timer <= 0.0 and randf() < special_attack_chance:
		_special_attack_timer = special_attack_cooldown
		_perform_special_attack()

func _perform_special_attack() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(1.0, 0.5, 0.0, 1.0)
	await get_tree().create_timer(0.5).timeout
	var attack_effect := ColorRect.new()
	attack_effect.size = Vector2(special_attack_radius * 2, special_attack_radius * 2)
	attack_effect.color = Color(1.0, 0.5, 0.0, 0.5)
	attack_effect.position = Vector2(-special_attack_radius, -special_attack_radius)
	add_child(attack_effect)
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon != null and global_position.distance_to(dragon.global_position) < special_attack_radius \
			and dragon.has_method("take_damage"):
		dragon.take_damage(int(attack_damage * 1.5))
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(attack_effect):
		attack_effect.queue_free()
	if is_instance_valid(_sprite):
		_sprite.modulate = Color.WHITE

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
