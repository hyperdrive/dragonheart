extends BaseNPC

class_name NPCFarmer

## Farmer: the food engine of the support chain.
## Activities: tend_fields (grown Fields only — burnt ones abort without yield),
## tend_pigs, deliver (food to town → GameManager food pool), idle.
## Consequences loop: dragon burns fields → work aborts → food thins →
## support checks (pigs/cows/miners) fail sooner. docs/decisions/2026-11-08-behavior-system.md

signal food_delivered(amount: int)
signal field_tended
signal pigs_tended

@export var food_per_tend: int = 1
@export var tend_work_time: float = 3.0
@export var tend_cooldown: float = 2.0

@export_group("Loaded panic")
## Carrying the city's food? The farmer bolts MUCH earlier and faster, so the
## delivery stalls while the dragon lurks — the town starves for it.
@export var loaded_danger_radius: float = 220.0
@export var loaded_flee_speed: float = 1.3
@export var unloaded_danger_radius: float = 120.0

## Food gathered since the last delivery (delivered in one trip).
var food_carrying: int = 0

## Field node cached by _pick_field_target (stateful provider, engine contract:
## providers may cache placement decisions resolved once per trip).
var _current_field: Node2D

func _ready() -> void:
	# Configure before super._ready() — it syncs health from max_health.
	npc_type = "farmer"
	max_health = 50
	speed = 80.0

	super._ready()

	# After super._ready(): it initializes the anchors from spawn position;
	# our town lies north of the farm (override the default southward anchor).
	town_position = home_position + Vector2(0, -300)

	behavior_tree = BehaviorTree.new()
	add_child(behavior_tree)
	behavior_tree.setup(self)
	# Aborted work (burnt mid-tend, flee preemption) leaves a stale field
	# claim — hand the plot back the instant work is no longer in progress.
	behavior_tree.state_changed.connect(_on_tree_state_changed)
	behavior_tree.register_activity(
		"tend_fields", 20,
		_pick_field_target, tend_work_time * level_multiplier(),
		tend_cooldown, _complete_field_tend,
		Callable(), _field_still_workable
	)
	behavior_tree.register_activity(
		"tend_pigs", 10,
		_pick_pigs_target, tend_work_time * level_multiplier(),
		tend_cooldown, _complete_pigs_tend
	)
	behavior_tree.register_activity(
		"deliver", 50,
		_pick_town_target, 1.0,
		0.0, _complete_deliver,
		_have_food_to_deliver
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

	print("Farmer initialized at position: ", global_position)

## Run/Fight tuning flips each frame with the payload (BehaviorTree's danger
## check reads danger_radius per tick, so a live value works).
func _physics_process(delta: float) -> void:
	if food_carrying > 0:
		danger_radius = loaded_danger_radius
		flee_speed_multiplier = loaded_flee_speed
	else:
		danger_radius = unloaded_danger_radius
		flee_speed_multiplier = 1.0
	super._physics_process(delta)
	_animate_farming(delta)

# --- farm work (2026-11-14 rig pass) -------------------------------------------

## Field work: a two-handed hoe chop into the furrow — raise, bite, drag —
## kicking up clods of soil. Pig tending: sweeping scatters of feed grain.
## The produce basket rides the far arm whenever he carries food.
const HOE_HZ := 1.3
const FEED_HZ := 1.0
var _work_phase := 0.0
var _working := false
var _kicked := false

func _animate_farming(delta: float) -> void:
	var rig := sprite as HumanoidRig
	if rig == null:
		return
	var basket := get_node_or_null("Sprite/ArmBack/Basket") as Node2D
	if basket != null:
		basket.visible = food_carrying > 0 and is_alive
	var hoe := get_node_or_null("Sprite/ArmFront/Hoe") as Node2D
	var act := ""
	if is_alive and _burning_left <= 0.0 and behavior_tree != null \
			and behavior_tree.state == BehaviorTree.State.WORKING \
			and behavior_tree.current_activity != null:
		act = str(behavior_tree.current_activity.id)
	if act == "tend_fields" and hoe != null:
		_working = true
		rig.arms_override = true
		_work_phase = fmod(_work_phase + delta * HOE_HZ, 1.0)
		_apply_hoe_pose(_work_phase, rig, hoe)
		if _work_phase >= 0.62 and not _kicked:
			_kicked = true
			_spawn_bits(hoe.to_global(Vector2(4.0, -19.0)), Color(0.36, 0.24, 0.12), 5, 10.0)
		elif _work_phase < 0.4:
			_kicked = false
	elif act == "tend_pigs":
		_working = true
		rig.arms_override = true
		_work_phase = fmod(_work_phase + delta * FEED_HZ, 1.0)
		var sweep := sin(_work_phase * TAU)
		rig.set_arms(-50.0 + sweep * 30.0, 10.0)
		rig.lean = 0.08
		if hoe != null:
			hoe.visible = false
		if _work_phase >= 0.5 and not _kicked:
			_kicked = true
			var hand := rig.part("ArmFront")
			if hand != null:
				_spawn_bits(hand.to_global(Vector2(0.2, 12.0)), Color(0.92, 0.82, 0.42), 6, 14.0)
		elif _work_phase < 0.25:
			_kicked = false
	elif _working:
		_working = false
		rig.arms_override = false
		rig.lean = 0.0
		if hoe != null:
			hoe.visible = true
			hoe.rotation_degrees = 11.5

## Hoe cycle p ∈ [0,1): 0..0.5 raise, 0.5..0.62 chop, 0.62..1 drag back.
func _apply_hoe_pose(p: float, rig: HumanoidRig, hoe: Node2D) -> void:
	var lift: float
	if p < 0.5:
		lift = smoothstep(0.0, 1.0, p / 0.5)
	elif p < 0.62:
		lift = 1.0 - pow((p - 0.5) / 0.12, 2.0)
	else:
		lift = -0.15 * sin((p - 0.62) / 0.38 * PI)  # the drag through the soil
	var arm := lerpf(-40.0, -150.0, lift)
	rig.set_arms(arm, arm + 10.0)
	hoe.rotation_degrees = lerpf(175.0, 140.0, maxf(lift, 0.0))
	rig.lean = lerpf(0.26, -0.08, maxf(lift, 0.0))

## Little flying bits (soil clods / feed grain) that arc and fade.
func _spawn_bits(origin: Vector2, col: Color, n: int, spread: float) -> void:
	if not is_inside_tree():
		return
	for i in n:
		var bit := Polygon2D.new()
		bit.polygon = PackedVector2Array([Vector2(-0.7, -0.6), Vector2(0.7, -0.6),
			Vector2(0.8, 0.6), Vector2(-0.6, 0.7)])
		bit.color = col
		bit.z_index = 3
		get_parent().add_child(bit)
		bit.global_position = origin
		var to := origin + Vector2(randf_range(-0.4, 1.0) * spread * float(facing),
			randf_range(-1.0, -0.2) * spread)
		var tw := bit.create_tween().set_parallel(true)
		tw.tween_property(bit, "global_position", to + Vector2(0, spread * 0.8), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(bit, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(bit.queue_free)

# --- activity providers & completers --------------------------------------

## Nearest GROWN field that is not claimed by another farmer (rule
## 2026-11-08: one farmer per field at a time); TARGET_NONE when town has no
## workable unclaimed acreage. Stateful: caches the chosen field node for the
## mid-work abort gate, and takes the field's claim lease.
func _pick_field_target() -> Vector2:
	_current_field = null
	var best: Vector2 = BehaviorTree.TARGET_NONE
	var best_dist := INF
	for field: Node2D in get_tree().get_nodes_in_group("fields"):
		var plot := field as Field
		if plot == null:
			continue
		if not plot.is_workable() or plot.is_claimed_other(get_instance_id()):
			continue
		var dist := global_position.distance_squared_to(field.global_position)
		if dist < best_dist:
			best_dist = dist
			best = field.global_position
			_current_field = plot
	if _current_field != null:
		_current_field.claim(get_instance_id(), _claim_lease_ms())
	return best

## Work-phase gate: field burnt (or freed) while working → abort without yield.
func _field_still_workable() -> bool:
	return _current_field != null \
		and is_instance_valid(_current_field) \
		and _current_field.is_workable()

## Claim lease: comfortably covers the walk to a far field + work + slack.
## Abandonment (flee, garbage-death) self-heals when the lease lapses.
func _claim_lease_ms() -> int:
	return int((tend_work_time * level_multiplier() + 14.0) * 1000.0)

## The plot is free again once this farmer is done with it.
func _release_field() -> void:
	if _current_field != null and is_instance_valid(_current_field):
		(_current_field as Field).release(get_instance_id())
	_current_field = null

## Work is no longer in progress (flee preemption, burnt-mid-tend abort):
## drop the stale claim immediately instead of making the town wait out the
## lease. Normal completion already released (this becomes a no-op). Gated to
## FLEEING/IDLE so the claim survives its own pick → MOVING commit.
func _on_tree_state_changed(new_state: BehaviorTree.State) -> void:
	if new_state == BehaviorTree.State.MOVING \
			or new_state == BehaviorTree.State.WORKING:
		return
	if _current_field != null:
		_release_field()

func _pick_pigs_target() -> Vector2:
	return pig_pen_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))

func _pick_town_target() -> Vector2:
	return town_position

func _pick_home_target() -> Vector2:
	return home_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))

func _pick_idle_target() -> Vector2:
	return home_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))

func _have_food_to_deliver() -> bool:
	return food_carrying > 0

## Gate hand-off (2026-11-09, same rule as the miner's): a farmer on the
## deliver leg finishes the food hand-off even with the dragon inside his
## flee ring — the ring sits right on the gates and used to wedge every
## loaded farmer in a panic loop (food never reaching the pens). Robbery
## of food is physical: eating the farmer is what costs the town, and
## that path is untouched.
func _handoff_stretch() -> bool:
	if food_carrying <= 0 or behavior_tree == null:
		return false
	var act := behavior_tree.current_activity
	return act != null and str(act.id) == "deliver"

func _complete_field_tend() -> void:
	field_tended.emit()
	food_carrying += food_per_tend * npc_level
	_release_field()  # plot up for grabs again (incl. re-picking it himself)
	print("Farmer tended fields — carrying %d food" % food_carrying)

func _complete_pigs_tend() -> void:
	pigs_tended.emit()
	food_carrying += food_per_tend * npc_level
	print("Farmer tended pigs — carrying %d food" % food_carrying)

## Delivery: hand the accumulated food to GameManager (owner of the food pool).
func _complete_deliver() -> void:
	if food_carrying > 0:
		food_delivered.emit(food_carrying)
		print("Farmer delivered %d food to town" % food_carrying)
		food_carrying = 0

## A dead farmer cannot keep a field claimed.
func die() -> void:
	_release_field()
	super.die()
