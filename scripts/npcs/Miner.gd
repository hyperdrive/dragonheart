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

## Mining swing (2026-11-14 rig pass): a two-handed overhead pick swing on
## the HumanoidRig — a slow wind-up over the shoulder (leaning back), a
## fast slam into the seam (leaning in), a short recovery. At impact the
## pick head throws stone chips and sparks. The Pick node pivots at the
## grip (its steel head crowns the handle), so the arms carry the head
## through the arc.
const PICK_SWING_HZ := 1.1
const ARM_RAISED_DEG := -168.0
const ARM_SLAM_DEG := -38.0
const PICK_RAISED_DEG := 135.0   # head thrown back over the shoulder
const PICK_SLAM_DEG := 175.0     # head driven into the seam ahead
## Cart push (2026-11-14): leaning arms on the push bar, wheels turning.
const CART_SCALE := 1.4
const CART_WHEEL_R := 3.3 * CART_SCALE
var _pick_swing_phase := 0.0
var _pick_animating := false
var _impact_done := false
var _pick: Node2D
var _rig: HumanoidRig
var _cart_roll := 0.0
var _last_pos := Vector2.ZERO

@onready var cart: Node2D = $Cart

func _physics_process(delta: float) -> void:
	# Post-interception recovery timer (blocks the mine activity until elapsed).
	if mining_cooldown > 0.0:
		mining_cooldown -= delta
	super._physics_process(delta)
	_animate_mining(delta)
	_push_cart()
	_check_dragon_drop()

# --- mining hammering (2026-11-09) --------------------------------------------

func _animate_mining(delta: float) -> void:
	if _pick == null or _rig == null:
		return
	var working: bool = is_alive and _burning_left <= 0.0 \
		and behavior_tree != null \
		and behavior_tree.state == BehaviorTree.State.WORKING \
		and behavior_tree.current_activity != null \
		and str(behavior_tree.current_activity.id) == "mine"
	if working:
		_pick_animating = true
		_rig.arms_override = true
		_pick_swing_phase = fmod(_pick_swing_phase + delta * PICK_SWING_HZ, 1.0)
		var p := _pick_swing_phase
		_apply_mining_pose(p)
		if p >= 0.71 and not _impact_done:
			_impact_done = true
			_spawn_strike_debris()
		elif p < 0.5:
			_impact_done = false
	elif _pick_animating:
		_pick_animating = false
		_rig.arms_override = false
		_rig.lean = 0.0
		_pick.rotation_degrees = -20.0
		_pick.modulate = Color.WHITE

## One sample of the swing at cycle phase p ∈ [0,1):
## 0..0.6 wind-up (ease out), 0.6..0.72 slam, 0.72..1 recover.
func _apply_mining_pose(p: float) -> void:
	var lift: float
	if p < 0.6:
		lift = smoothstep(0.0, 1.0, p / 0.6)
	elif p < 0.72:
		lift = 1.0 - pow((p - 0.6) / 0.12, 2.0)
	else:
		lift = smoothstep(0.0, 1.0, (p - 0.72) / 0.28) * 0.15
	var arm := lerpf(ARM_SLAM_DEG, ARM_RAISED_DEG, lift)
	_rig.set_arms(arm, arm + 8.0)
	_pick.rotation_degrees = lerpf(PICK_SLAM_DEG, PICK_RAISED_DEG, lift)
	_rig.lean = lerpf(0.28, -0.14, lift)
	var slam := p >= 0.71 and p < 0.78
	_pick.modulate = Color(1.0, 0.85, 0.55) if slam else Color.WHITE

## Stone chips + sparks flying off the pick head at the moment of impact.
func _spawn_strike_debris() -> void:
	var head := _pick.get_node_or_null("PickHead") as Node2D
	if head == null or not is_inside_tree():
		return
	var origin := _pick.to_global(Vector2(0.0, -17.0))  # the steel head
	for i in 7:
		var bit := Polygon2D.new()
		var spark := i < 3
		bit.polygon = PackedVector2Array([Vector2(-0.8, -0.8), Vector2(0.9, -0.5),
			Vector2(0.6, 0.9), Vector2(-0.7, 0.6)]) if not spark \
			else PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5),
			Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
		bit.color = Color(1.0, 0.85, 0.4) if spark else Color(0.55, 0.53, 0.5)
		bit.z_index = 3
		get_parent().add_child(bit)
		bit.global_position = origin
		var dir := Vector2(randf_range(-1.0, 1.0) + 0.6 * float(facing), randf_range(-1.6, -0.4)).normalized()
		var dist := randf_range(8.0, 18.0) * (1.4 if spark else 1.0)
		var tw := bit.create_tween().set_parallel(true)
		tw.tween_property(bit, "global_position", origin + dir * dist + Vector2(0, 6), 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(bit, "modulate:a", 0.0, 0.4)
		tw.tween_property(bit, "rotation", randf_range(-6.0, 6.0), 0.4)
		tw.chain().tween_callback(bit.queue_free)


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
	_rig = sprite as HumanoidRig
	# Pick rides the near hand; its node pivots at the grip (head on top).
	_pick = get_node_or_null("Sprite/ArmFront/Pick") as Node2D
	_last_pos = global_position

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

## 10% slowdown while returning with gold (user spec 2026-11-10).
func _get_effective_speed() -> float:
	if payload_amount > 0:
		return speed * 0.9
	return speed

func _has_payload() -> bool:
	return payload_amount > 0

## Gate hand-off band (2026-11-09, see BehaviorTree._tick_danger): a loaded
## miner on his deliver leg finishes it even when the dragon is inside his
## flee ring — the dragon camps AT the gates used to wedge him in a
## 180px panic loop with a full cart for minutes (forensic sim: 45s+,
## ZERO deliveries, treasury starved = "we still fail to spawn soldiers").
## Robbery stays intact: the claws still spill the cart below drop_radius
## (_check_dragon_drop) and the interception system still picks pockets —
## so the exemption only trades panic for a brave straight walk.
const HANDOFF_PX := 100.0

func _handoff_stretch() -> bool:
	if payload_amount <= 0 or behavior_tree == null:
		return false
	var act := behavior_tree.current_activity
	if act == null or str(act.id) != "deliver":
		return false
	# the claws rule still wins: below drop_radius the cart dumps anyway
	var dragon: Node2D = get_tree().get_first_node_in_group("dragon")
	if dragon != null and is_instance_valid(dragon):
		return global_position.distance_to(dragon.global_position) > drop_radius
	return true

## Mine emptied/damaged mid-work → abort without yield.
func _mine_still_available() -> bool:
	return mining_cooldown <= 0.0

## 10% slowdown while returning with gold (user spec 2026-11-10).
func _waypoint_update(delta: float) -> bool:
	if global_position == _waypoint:
		_waypoint = Vector2.INF
		return true
	var target := _waypoint
	if _waypoint != Vector2.INF:
		if global_position.distance_to(_waypoint) <= 16.0:
			_waypoint = Vector2.INF
		else:
			target = _waypoint
	# Miner override: 10% slowdown while returning with gold.
	var effective_speed := _get_effective_speed()
	velocity = (target - global_position).normalized() * effective_speed
	update_facing()
	move_and_slide()
	return false

## ~70% gold, ~30% gems; tiered yield; payload grows until delivery.
## Haul-size lottery (user spec: "50% one time, 25% 2 and 25% 3"): every
## working trip rolls how rich the strike is — a bone-lean pick, a good
## haul, or a lucky double-pocket seam.
func _roll_haul_size() -> int:
	var roll := randf()
	if roll < 0.50:
		return 1
	elif roll < 0.75:
		return 2
	return 3

func _complete_mine() -> void:
	var res_type := "gold" if randf() < 0.7 else "gems"
	var amount := npc_level * _roll_haul_size()
	set_payload(res_type, payload_amount + amount)
	mining_cooldown = mine_cooldown
	if res_type == "gold":
		gold_collected.emit()
		print("Miner collected %d gold — carrying %d %s" % [amount, payload_amount, payload_res_type])
	else:
		gems_collected.emit()
		print("Miner collected %d gems — carrying %d %s" % [amount, payload_amount, payload_res_type])

## Delivery: fill the town treasury (GameManager), clear the payload.
func _complete_deliver() -> void:
	if payload_amount > 0:
		resource_delivered.emit(npc_type, payload_res_type, payload_amount)
		print("Miner delivered %d %s to town treasury" % [payload_amount, payload_res_type])
		set_payload("", 0)

func intercepted_by_dragon() -> void:
	# Steal-only interception (decision 2026-11-08-dragon-strikes-respawn-
	# prices): the payload is gone (GoldInterceptionSystem.steal_payload) and
	# the miner takes NO damage — flyovers never kill. Just a long recovery.
	mining_cooldown = 10.0
	print("Miner intercepted by dragon — cart looted clean!")

## Burning to death spills the cart gold where he fell (also raises the
## street alarm via report_loot_spill — same rule as a panic drop).
func die() -> void:
	if payload_amount > 0 and _burning_left > 0.0:
		_drop_payload(global_position)
	super.die()

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

## The cart rides in front of the miner (they push it toward town). The
## handle side must always face the miner, so the CONTENTS mirror with the
## facing too (2026-11-11 cart rebuild) — position alone moved the cart
## without flipping it, which would have pointed the new push handle away
## from the miner on the left-facing side.
func _push_cart() -> void:
	if cart == null:
		return
	var k := CART_SCALE * visual_scale
	cart.position = Vector2(24.0 * float(facing), 2.0) * visual_scale
	cart.scale = Vector2(k * float(facing), k)
	var moved := global_position.distance_to(_last_pos)
	_last_pos = global_position
	if not cart.visible or _rig == null:
		return
	# Wheels roll with the ground covered; the load jounces on the ruts.
	_cart_roll += moved
	var spin := _cart_roll / (CART_WHEEL_R * visual_scale)
	for w: String in ["Wheel", "Wheel2"]:
		var wheel := cart.get_node_or_null(w) as Node2D
		if wheel != null:
			wheel.rotation = spin
	var cargo := cart.get_node_or_null("Load") as Node2D
	if cargo != null:
		cargo.position.y = -absf(sin(_cart_roll * 0.35)) * 0.7
	# Hands on the push bar while the cart is aboard (unless swinging).
	if not _pick_animating and _burning_left <= 0.0:
		_rig.arms_override = true
		_rig.set_arms(-58.0, -50.0)
		_rig.lean = 0.22 if velocity.length() > 6.0 else 0.1
		if _pick != null:
			_pick.visible = false  # the pick rides in the cart (CartPick)

## carrying_changed: show the cart only while a payload is actually aboard —
## filling it at the mine, hiding it after delivery or a dragon steal.
func _on_carrying_changed(_res_type: String, amount: int) -> void:
	if cart == null:
		return
	cart.visible = amount > 0
	if _pick != null:
		_pick.visible = amount <= 0
	if amount <= 0 and _rig != null and not _pick_animating:
		_rig.arms_override = false
		_rig.lean = 0.0
		if _pick != null:
			_pick.rotation_degrees = -20.0
