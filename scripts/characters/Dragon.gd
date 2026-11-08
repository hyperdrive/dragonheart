extends CharacterBody2D

class_name Dragon

## Player: the dragon. Pure consumer of GameManager (per the decision record):
## reads progression levels, requests upgrades, reports theft via the
## GoldInterceptionSystem, breathes fire onto flammable fields.

signal health_changed(health: int)
signal fire_attacked
signal loot_carried(carry_total: int)
signal flame_charges_changed(charges: int, max_charges: int)
## E on a full dragon: "health" (no heal ⇒ no flames ⇒ waste) or "flames"
## (recharge clamps). HUD flashes the matching chip.
signal eat_refused(what: String)
signal shield_changed(points: int)

@export_group("Controls")
@export var speed: float = 200.0
@export var fire_rate: float = 1.0

@export_group("Fire breath")
@export var fire_reach: float = 95.0        # ignition distance from the mouth
@export var fire_ignite_cone: float = 0.25  # facing half-plane dot threshold
## Flame economy: breaths are a resource — spent on fire, refilled by eating
## animals (pig +1, cow +2). Empty claws = a very quiet dragon.
@export var max_flame_charges: int = 4
## Wizard-shop shield: absorbs incoming damage until depleted (then gone).
## Purchasable again only once fully lost (see shield_points: 0 ⇒ free slot).
var shield_points: int = 0

var health: int = 100
var max_health: int = 100
var is_firing: bool = false
var fire_cooldown: float = 0.0
var flame_charges: float = max_flame_charges
## Temporary speed boost (wizard shop): multiplier on the unmodified `speed`
## while _speed_boost_left > 0. Purchasing refreshes the duration.
var _speed_boost_left: float = 0.0
@export var speed_boost_multiplier: float = 1.6
@export var speed_boost_duration: float = 6.0
## Facing state: 1 = right, -1 = left; mirrors body AND the fire assembly.
var facing: int = 1
## Loot in the claws — banked only when delivered at the lair.
var carried_loot: Dictionary = {"gold": 0, "gems": 0}

@export_group("Loot hauling")
@export var pickup_radius: float = 70.0
@export var lair_delivery_radius: float = 150.0
## True from die() onward: blocks extra damage, input, activity re-entry.
var _dying: bool = false

var game_manager: GameManager

@onready var sprite: Node2D = $Sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var fire_area: Area2D = $FireArea
@onready var flame: Node2D = $FireArea/Flame
@onready var fire_collision: CollisionShape2D = $FireArea/FireCollision
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
	flame_charges_changed.emit(int(flame_charges), max_flame_charges)

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
	if _dying:
		velocity = Vector2.ZERO
		return
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	if _speed_boost_left > 0.0:
		_speed_boost_left -= delta

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

	velocity = input_direction * effective_speed()
	move_and_slide()

	# While the breath window is open, flammable actors/fields in the cone
	# catch fire.
	if is_firing:
		_ignite_flammables()

	# Face travel direction: mirrors the body and the whole fire assembly.
	if input_direction.x != 0.0:
		var new_facing := 1 if input_direction.x > 0.0 else -1
		if new_facing != facing:
			facing = new_facing
			_apply_facing()

	if Input.is_action_just_pressed("fire"):
		fire_breath()

## Intentional snacking (E): one animal from the NEAREST pen in reach.
## Full dragons get nothing from eating (no heal ⇒ no flames ⇒ pure waste)
## — refused with a chip flash instead of consuming stock. Note: eating an
## animal CAN only ever grant flames as a side effect of the heal, so a
## full-health dragon is always refused even with flame room. (Decision
## record 2026-11-08-manual-eat-wizard-menu.)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("eat") and not _dying:
		_try_eat_at_pen()

func _try_eat_at_pen() -> void:
	if health >= max_health:
		eat_refused.emit("health")
		if flame_charges >= max_flame_charges:
			eat_refused.emit("flames")  # both chips flash on a fully-full dragon
		print("Dragon: full — eating would be wasted!")
		return
	var meal := _take_meal_from_nearest_pen()
	if meal.is_empty():
		print("Dragon: no animals in reach to eat!")
		return
	var healed := mini(int(meal["heal"]), max_health - health)
	health += healed
	health_changed.emit(health)
	var had := flame_charges
	flame_charges = minf(
		flame_charges + float(int(meal["flame"])), float(max_flame_charges))
	if flame_charges != had:
		flame_charges_changed.emit(int(flame_charges), max_flame_charges)
	if flame_charges >= max_flame_charges:
		eat_refused.emit("flames")  # heal happened, but the recharge clamped

## Nearest pen (either species) within its own reach; {} when none in reach
## or its pen is out of stock.
func _take_meal_from_nearest_pen() -> Dictionary:
	var best: AnimalPen = null
	var best_dist := INF
	for group: String in ["pig_pens", "cow_pens"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var pen := node as AnimalPen
			if pen == null:
				continue
			var dist := global_position.distance_to(pen.global_position)
			if dist < best_dist and dist <= pen.pen_radius:
				best_dist = dist
				best = pen
	if best == null or best.animal_count() == 0:
		return {}
	var meal: Dictionary = best.take_animal_for_dragon(self)
	if not meal.is_empty():
		print("Dragon ate a %s! (+%d health attempted, +%d flame)" % [
			best.animal_name, int(meal["heal"]), int(meal["flame"])])
	return meal

## Mirror the visual body AND the fire assembly to the facing side. Done with
## explicit component mirroring — no negative scale on the physics Area2D.
func _apply_facing() -> void:
	sprite.scale.x = float(facing)
	fire_area.position.x = 20.0 * float(facing)      # breath origin offset
	fire_collision.position.x = 15.0 * float(facing) # hitbox follows
	flame.scale.x = float(facing)                    # flame visual mirrors

## Everything flammable caught in the breath cone ignites: farmers, miners,
## soldiers (+ the King), and crop fields (Field.burn → stubble → slow regrow).
func _ignite_flammables() -> void:
	var facing_vec := Vector2(float(facing), 0.0)
	for group: String in ["farmers", "miners", "soldiers", "king", "fields"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var target_pos: Vector2 = (node as Node2D).global_position
			var to_target := target_pos - global_position
			if to_target.length() > fire_reach:
				continue
			if to_target.normalized().dot(facing_vec) < fire_ignite_cone:
				continue
			if node is Field:
				(node as Field).burn()
			elif node is BaseNPC:
				(node as BaseNPC).catch_fire()

func _process(delta: float) -> void:
	# Auto-theft: the core loop. When a payload carrier is in range and
	# cooldown allows, attempt an interception. (Dead dragons steal nothing.)
	if _dying:
		return
	if interception_system == null or game_manager == null:
		return
	var opportunities := interception_system.check_interception_opportunities(global_position)
	if opportunities.size() > 0:
		interception_system.attempt_interception(self, opportunities[0])
	_scoop_loose_loot()
	_deliver_carried_loot()

# --- loot hauling: scoop → claws → lair ---------------------------------------

## Loose drops (miner panic-drops) become collectible after their settle delay.
## One scoop per frame keeps the pocketing readable.
func _scoop_loose_loot() -> void:
	for drop: Node in get_tree().get_nodes_in_group("loose_loot"):
		var gold_drop := drop as GoldDrop
		if gold_drop == null or not gold_drop.settled:
			continue
		if global_position.distance_to(gold_drop.global_position) > pickup_radius:
			continue
		take_loot(gold_drop.res_type, gold_drop.amount)
		print("Dragon collected %d %s — %d loot carried, deliver to the lair!" % [
			gold_drop.amount, gold_drop.res_type, carried_total()])
		gold_drop.queue_free()
		return  # one pickup per frame

## Stash only grows at the lair: carried loot banks inside the cave radius.
func _deliver_carried_loot() -> void:
	var carry := carried_total()
	if carry == 0:
		return
	var lair := get_tree().get_first_node_in_group("dragon_lair") as Node2D
	if lair == null:
		return
	if global_position.distance_to(lair.global_position) > lair_delivery_radius:
		return
	for res_type: String in carried_loot:
		var amount: int = carried_loot[res_type]
		if amount > 0:
			game_manager.add_stolen(res_type, amount)
			print("Dragon banked %d %s at the lair" % [amount, res_type])
			carried_loot[res_type] = 0
	loot_carried.emit(0)

## Everything (drops, interception, mine landing) funnels through here.
func take_loot(res_type: String, amount: int) -> void:
	if not carried_loot.has(res_type):
		carried_loot[res_type] = 0
	carried_loot[res_type] += amount
	loot_carried.emit(carried_total())

func carried_total() -> int:
	var total := 0
	for amount: int in carried_loot.values():
		total += amount
	return total

func fire_breath() -> void:
	if _dying or is_firing or fire_cooldown > 0.0:
		return
	if flame_charges < 1.0:
		print("Dragon: flame spent — eat a pig (+1) or a cow (+2) to recharge!")
		return
	flame_charges -= 1.0
	flame_charges_changed.emit(int(flame_charges), max_flame_charges)
	is_firing = true
	fire_cooldown = fire_rate
	flame.visible = true          # visual breath (collision window matches)
	fire_area.monitoring = true   # breath window: ignites flammable fields
	animation_player.play("fire_breath")
	fire_attacked.emit()
	await animation_player.animation_finished
	is_firing = false
	flame.visible = false
	fire_area.monitoring = false
	if animation_player.has_animation("idle"):
		animation_player.play("idle")

func take_damage(amount: int) -> void:
	if _dying:
		return
	var damage_reduction := 0
	if game_manager != null:
		damage_reduction = (game_manager.scales_level - 1) * 2
	var incoming := maxi(1, amount - damage_reduction)
	# Wizard shield pool absorbs first (and is lost with use, decision record).
	if shield_points > 0:
		var absorbed := mini(shield_points, incoming)
		shield_points -= absorbed
		incoming -= absorbed
		shield_changed.emit(shield_points)
		print("Shield absorbed %d damage (%d shield left)!" % [
			absorbed, shield_points])
	health -= incoming
	health_changed.emit(health)
	if health <= 0:
		die()

# --- wizard-shop upgrades (purchased via GameManager.prices) -------------------

## Flame capacity +n (max). The purchased charges arrive loaded — a bought
## flame you cannot breathe immediately is a store complaint, not a feature.
func increase_flame_capacity(amount: int) -> void:
	max_flame_charges += amount
	flame_charges = minf(flame_charges + float(amount), float(max_flame_charges))
	flame_charges_changed.emit(int(flame_charges), max_flame_charges)
	print("Dragon flame capacity +%d (max %d)!" % [amount, max_flame_charges])

## Breath reach +px, permanent.
func increase_flame_range(add_px: float) -> void:
	fire_reach += add_px
	print("Dragon flame range +%dpx (reach %0.0f)!" % [int(add_px), fire_reach])

## Shield restock: refused while any shield remains (non-stackable pool).
func add_shield(points: int) -> bool:
	if shield_points > 0:
		return false
	shield_points = points
	shield_changed.emit(shield_points)
	print("Dragon shielded for %d points!" % shield_points)
	return true

## Speed boost: activates OR refreshes (non-stacking multiplier, decision
## record). Countdown runs in _physics_process.
func activate_speed_boost() -> void:
	_speed_boost_left = speed_boost_duration
	print("Dragon feels fast! (%.0fx for %ds)" % [
		speed_boost_multiplier, speed_boost_duration])

## Effective move speed in _physics_process — boost multiplier while active.
func effective_speed() -> float:
	return speed * (speed_boost_multiplier if _speed_boost_left > 0.0 else 1.0)

func die() -> void:
	# Re-entry guard: several attacks can land during the death animation;
	# each call would await animation_finished and try to reload the scene.
	if _dying:
		return
	_dying = true
	animation_player.play("death")
	await animation_player.animation_finished
	# After the await the scene may already be torn down (double reload) or
	# the node detached — reload only while we are still in a live tree.
	if is_inside_tree() and get_tree() != null:
		get_tree().reload_current_scene()

# Animations (idle, fire_breath, death) live in Dragon.tscn's AnimationPlayer
# library — do not recreate them in code.

## Loose resources grabbed straight off a mine (landing on the entrance) —
## goes into the claws like everything else; banking happens at the lair.
func collect_resources(resources: Dictionary) -> void:
	if resources.has("gold"):
		take_loot("gold", resources["gold"])
	if resources.has("gems"):
		take_loot("gems", resources["gems"])
	if resources.has("food"):
		eat_food(resources["food"])

func eat_food(food_value: int) -> void:
	health = mini(health + food_value, max_health)
	health_changed.emit(health)
