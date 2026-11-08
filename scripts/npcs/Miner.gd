extends BaseNPC

class_name Miner

## Miner: gold/gems engine. Mines at the Mine site, carries the payload
## (stealable by the dragon), delivers to the town treasury.
## Support chain: needs farmer/food support — see check_support_conditions.
## docs/plans/2026-11-08-behavior-system-rebuild.md

signal gold_collected
signal gems_collected
signal resource_delivered(npc_type: String, res_type: String, amount: int)

const GOLD_DROP_SCENE := preload("res://scenes/objects/GoldDrop.tscn")

@export_group("Mining")
@export var mine_work_time: float = 4.0
@export var mine_cooldown: float = 3.0
@export_range(1, 5) var required_farmer_support: int = 3
@export_range(0, 50) var required_food_support: int = 10
## Payload spills when the dragon is THIS close (tighter than the 180 flee
## trigger — the drop happens as the claws arrive, not at first sight).
@export var drop_radius: float = 85.0

var can_mine: bool = true
var mining_cooldown: float = 0.0

@onready var cart: Node2D = $Cart

func _physics_process(delta: float) -> void:
	# Post-interception recovery timer (blocks the mine activity until elapsed).
	if mining_cooldown > 0.0:
		mining_cooldown -= delta
	super._physics_process(delta)
	_push_cart()
	_check_dragon_drop()


## The claws arriving under the dropper's nose (not the flee trigger at 180)
## is what spills the payload — so loot lands by the miner, not down the road.
func _check_dragon_drop() -> void:
	if payload_amount <= 0 or not is_alive:
		return
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return
	if global_position.distance_to(dragon.global_position) <= drop_radius:
		_drop_payload(dragon.global_position)

func _ready() -> void:
	# Configure before super._ready() — it syncs health from max_health.
	npc_type = "miner"
	max_health = 60
	speed = 90.0
	# Cart carriers are the gold economy on legs — they start fleeing earlier
	# and run faster while the payload (and its cart) is exposed.
	danger_radius = 180.0
	flee_speed_multiplier = 1.3

	super._ready()

	# Cart visibility tracks the payload slot (shown while gold/gems aboard).
	cart.visible = payload_amount > 0
	carrying_changed.connect(_on_carrying_changed)

	behavior_tree = BehaviorTree.new()
	add_child(behavior_tree)
	behavior_tree.setup(self)
	# NOTE: the payload release is deliberately NOT tied to fled_from_dragon
	# (flee starts at danger_radius 180) — the miner runs first and only
	# spills when the dragon actually closes to drop_radius (user bug report;
	# _check_dragon_drop owns the release now).
	behavior_tree.register_activity(
		"mine", 20,
		_pick_mine_target, mine_work_time * level_multiplier(),
		mine_cooldown, _complete_mine,
		Callable(), _mine_still_available
	)
	behavior_tree.register_activity(
		"deliver", 50,
		_pick_town_target, 1.0,
		0.0, _complete_deliver,
		_has_payload
	)
	behavior_tree.register_activity(
		"go_home", 5,
		_pick_home_target, 0.0,
		4.0, Callable()
	)
	behavior_tree.register_activity(
		"idle", 1,
		_pick_idle_target, 1.0,
		3.0, Callable()
	)

	print("Miner initialized at position: ", global_position)

# --- support chain ---------------------------------------------------------

## Farmers + food gates the ability to mine (the decision-record support chain).
## WorldManager/GameManager recalculate by calling this with current counts.
func check_support_conditions(farmer_count: int, food_count: int) -> bool:
	can_mine = farmer_count >= required_farmer_support and food_count >= required_food_support
	return can_mine

# --- activity providers & completers ---------------------------------------

func _pick_mine_target() -> Vector2:
	return mine_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))

func _pick_town_target() -> Vector2:
	return town_position

func _pick_home_target() -> Vector2:
	return home_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))

func _pick_idle_target() -> Vector2:
	return home_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))

func _has_payload() -> bool:
	return payload_amount > 0

## Mine emptied/damaged mid-work → abort without yield.
func _mine_still_available() -> bool:
	return mining_cooldown <= 0.0

## ~70% gold, ~30% gems; tiered yield; payload grows until delivery.
func _complete_mine() -> void:
	var res_type := "gold" if randf() < 0.7 else "gems"
	var amount := npc_level  # tiered level multiplies later at delivery; base = level
	set_payload(res_type, payload_amount + amount)
	mining_cooldown = mine_cooldown
	if res_type == "gold":
		gold_collected.emit()
		print("Miner collected gold — carrying %d %s" % [payload_amount, payload_res_type])
	else:
		gems_collected.emit()
		print("Miner collected gems — carrying %d %s" % [payload_amount, payload_res_type])

## Delivery: fill the town treasury (GameManager), clear the payload.
func _complete_deliver() -> void:
	if payload_amount > 0:
		resource_delivered.emit(npc_type, payload_res_type, payload_amount)
		print("Miner delivered %d %s to town treasury" % [payload_amount, payload_res_type])
		set_payload("", 0)

func intercepted_by_dragon() -> void:
	# Steal damage + long recovery; payload removal is handled by the
	# GoldInterceptionSystem via steal_payload().
	take_damage(40)
	mining_cooldown = 10.0
	print("Miner intercepted by dragon!")

# --- gold cart ----------------------------------------------------------------

## Panic response: the gold becomes a loose pickup (with settle delay for the
## dragon) and the miner keeps nothing. Spilling treasure in the street raises
## the town alarm — soldiers go ATTACK (user-requested consequence of DROPPING,
## not of stealing; economy-only-consequences record stays intact).
func _drop_payload(_dragon_position: Vector2) -> void:
	if payload_amount <= 0:
		return
	var drop := GOLD_DROP_SCENE.instantiate() as GoldDrop
	drop.res_type = payload_res_type
	drop.amount = payload_amount
	set_payload("", 0)
	get_parent().add_child(drop)   # world-space owner: the drop stays put
	# global AFTER add_child: the old code wrote a parent-relative jitter into
	# drop.position BEFORE parenting, and WorldManager sits at the world
	# origin — every drop therefore spawned at the map center.
	drop.global_position = global_position + Vector2(randf_range(-16, 16), randf_range(4, 12))
	var world := get_tree().get_first_node_in_group("world_manager") as WorldManager
	if world != null:
		world.report_loot_spill()
	print("Miner dropped %d %s at %s!" % [drop.amount, drop.res_type,
		drop.global_position])

## The cart rides in front of the miner (they push it toward town).
func _push_cart() -> void:
	if cart == null:
		return
	cart.position = Vector2(26.0 * float(facing), 8.0)

## carrying_changed: show the cart only while a payload is actually aboard —
## filling it at the mine, hiding it after delivery or a dragon steal.
func _on_carrying_changed(_res_type: String, amount: int) -> void:
	if cart == null:
		return
	cart.visible = amount > 0
