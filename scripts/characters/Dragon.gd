extends CharacterBody2D

class_name Dragon

## Player: the dragon. Pure consumer of GameManager (per the decision record):
## reads progression levels, requests upgrades, reports theft via the
## GoldInterceptionSystem, breathes fire onto flammable fields.

signal health_changed(health: int)
signal fire_attacked

@export_group("Controls")
@export var speed: float = 200.0
@export var fire_rate: float = 1.0

var health: int = 100
var max_health: int = 100
var is_firing: bool = false
var fire_cooldown: float = 0.0

var game_manager: GameManager

@onready var sprite: Node2D = $Sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var fire_area: Area2D = $FireArea
@onready var interception_system: GoldInterceptionSystem = $GoldInterceptionSystem

func _ready() -> void:
	add_to_group("dragon")
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if game_manager == null:
		push_error("Dragon: GameManager not found — progression/pool reading disabled")
		return
	game_manager.upgrade_purchased.connect(_on_upgrade_purchased)
	sync_from_game_manager()
	interception_system.setup(game_manager)

	# Fire breath window wiring handled in fire_breath(); the idle starts on play.
	fire_area.monitoring = false  # breath window only, set in fire_breath()

func sync_from_game_manager() -> void:
	# Armor (scales) sets max health; fire power sets breath damage per burn tick.
	max_health = 100 + (game_manager.scales_level - 1) * 25
	health = mini(health, max_health)
	health_changed.emit(health)

func _on_upgrade_purchased(kind: String, level: int) -> void:
	print("Dragon upgraded ", kind, " to level ", level)
	sync_from_game_manager()

func _physics_process(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta

	var input_direction := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		input_direction.x += 1
	if Input.is_action_pressed("move_up"):
		input_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		input_direction.y += 1

	if input_direction.length() > 0:
		input_direction = input_direction.normalized()

	velocity = input_direction * speed
	move_and_slide()

	if Input.is_action_just_pressed("fire"):
		fire_breath()

func _process(delta: float) -> void:
	# Auto-theft: the core loop. When a payload carrier is in range and
	#cooldown allows, attempt an interception.
	if interception_system == null or game_manager == null:
		return
	var opportunities := interception_system.check_interception_opportunities(global_position)
	if opportunities.size() > 0:
		interception_system.attempt_interception(self, opportunities[0])

func fire_breath() -> void:
	if is_firing or fire_cooldown > 0.0:
		return
	is_firing = true
	fire_cooldown = fire_rate
	fire_area.monitoring = true  # breath window: ignites flammable fields
	animation_player.play("fire_breath")
	fire_attacked.emit()
	await animation_player.animation_finished
	is_firing = false
	fire_area.monitoring = false
	if animation_player.has_animation("idle"):
		animation_player.play("idle")

func take_damage(amount: int) -> void:
	var damage_reduction := 0
	if game_manager != null:
		damage_reduction = (game_manager.scales_level - 1) * 2
	health -= maxi(1, amount - damage_reduction)
	health_changed.emit(health)
	if health <= 0:
		die()

func die() -> void:
	animation_player.play("death")
	await animation_player.animation_finished
	get_tree().reload_current_scene()

# Animations (idle, fire_breath, death) live in Dragon.tscn's AnimationPlayer
# library — do not recreate them in code.

## Direct pickup of loose resources (dropped ore, food) → dragon stash pool.
func collect_resources(resources: Dictionary) -> void:
	if game_manager == null:
		return
	if resources.has("gold"):
		game_manager.add_stolen("gold", resources["gold"])
	if resources.has("gems"):
		game_manager.add_stolen("gems", resources["gems"])

func eat_food(food_value: int) -> void:
	health = mini(health + food_value, max_health)
	health_changed.emit(health)
