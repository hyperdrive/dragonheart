extends BaseNPC

## Wolves (2026-11-15, user: "Let's introduce wolves! They eat your food:
## cows, pigs and deer. Kill them! Introduce a pack (4) wolf every other 30s
## of game play, no more than three packs. Soldiers kill wolves too. They
## run fast but a flying dragon can catch them.")
##
## A pack of four comes in from the wild edge of the map (WorldManager.
## spawn_wolf_pack). The PACK thinks, not the wolf (WorldManager._tick_packs,
## user: "the wolves should have a squad brain, just as the soldiers"): it
## musters, is released on ONE prey — a deer, or a pig/cow pen with stock
## left, where a wolf that gets in takes an animal (AnimalPen.consume_animal,
## the dragon's own meals) — rests at its den after a meal, and turns as one
## on any soldier who closes in. This wolf only follows the pack's order:
## close on the target from its own side of the ring, or muster.
##
## Against the dragon it is prey: it bolts (danger_radius) at 183 px/s —
## faster than a walking dragon (150), slower than a flying one (300). Claws
## and fire kill it. Soldiers hunt it (Soldier._nearest_outlaw covers the
## "wolves" group); it bites whoever is on top of it.
##
## Reuses the deer's rig (same part names): the grazing dip reads as a nose
## to the ground. No class_name on purpose (editor rescan caveat):
## WorldManager loads the scene by path.

const KILL_REACH := 26.0
const BITE_DPS := 7.0
const BITE_REACH := 22.0

var pack_id := 0
var pack_slot := 0      # this wolf's place on the pack's encircling ring
var den := Vector2.ZERO
var _bite_debt := 0.0

func _ready() -> void:
	npc_type = "wolf"
	max_health = 40
	speed = 78.0
	danger_radius = 190.0
	safe_radius = 330.0
	flee_speed_multiplier = 2.35     # 183 px/s: outruns a walking dragon, not a flying one
	super._ready()
	add_to_group("wolves")
	if den == Vector2.ZERO:
		den = global_position
	behavior_tree = BehaviorTree.new()
	add_child(behavior_tree)
	behavior_tree.setup(self)
	behavior_tree.register_activity("pack_hunt", 30, _pick_pack_target, 0.4, 0.0,
		_complete_hunt, _pack_released, _pack_released)
	behavior_tree.register_activity("muster", 20, _pick_muster, randf_range(0.8, 1.6), 0.3, Callable())
	behavior_tree.register_activity("idle", 1, _pick_idle, 1.5, 1.0, Callable())

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_alive:
		return
	_keep_pack_order()
	_bite(delta)

# --- the pack's orders -------------------------------------------------------------

func _world() -> WorldManager:
	return get_tree().get_first_node_in_group("world_manager") as WorldManager

func _order() -> Dictionary:
	var world := _world()
	return world.pack_order(pack_id) if world != null else {}

func _pack_target() -> Node2D:
	var t: Variant = _order().get("target")
	return t as Node2D if t != null and is_instance_valid(t) else null

func _pack_released() -> bool:
	return bool(_order().get("released", false)) and _pack_target() != null

## The pack's order for this wolf: while the pack ENCIRCLES, run to its
## own place on the wide ring; once it STRIKES (each wolf a beat after the
## one before it — the rush ripples round the ring), close on the prey from
## that same side; into a pen among the animals.
func _pick_pack_target() -> Vector2:
	var t := _pack_target()
	if t == null:
		return BehaviorTree.TARGET_NONE
	var o := _order()
	var world := _world()
	var striking := str(o.get("phase", "strike")) == "strike" \
		and float(o.get("strike_age", 0.0)) >= float(pack_slot) * WorldManager.PACK_STAGGER
	if not striking and world != null:
		return world.pack_slot_spot(o, self)
	var side := (global_position - t.global_position).normalized()
	if side == Vector2.ZERO:
		side = Vector2.from_angle(float(pack_slot) * TAU / 4.0)
	if t is AnimalPen:
		return t.global_position + side * Vector2(22.0, 10.0)
	return t.global_position + side * 14.0

## Like the garrison's squad discipline: the moment the pack is released
## everyone drops what it is doing; while closing in, aim at the LIVE target
## (deer run, soldiers move); when the order changes, re-pick at once.
func _keep_pack_order() -> void:
	if behavior_tree == null or behavior_tree.state == BehaviorTree.State.FLEEING:
		return
	var act := behavior_tree.current_activity
	var on_hunt := act != null and str(act.id) == "pack_hunt"
	if _pack_released():
		if not on_hunt:
			behavior_tree.force_repick()
			return
		var aim := _pick_pack_target()
		if aim != BehaviorTree.TARGET_NONE:
			act.target = aim
	elif on_hunt:
		behavior_tree.force_repick()

## Muster on the pack's middle — or at the den while the pack rests.
func _pick_muster() -> Vector2:
	var o := _order()
	var spot: Vector2 = den
	if not o.is_empty() and float(o.get("rest", 0.0)) <= 0.0:
		spot = (o.get("centre", den) as Vector2).lerp(den, 0.15)
	# loose, not a huddle: each wolf keeps to its own side of the pack
	var own := Vector2.from_angle(TAU * float(pack_slot) / 4.0 + 0.4) * Vector2(55.0, 38.0)
	return _clear(spot + own + Vector2(randf_range(-25.0, 25.0), randf_range(-18.0, 18.0)))

func _pick_idle() -> Vector2:
	return _clear(global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-14.0, 14.0)))

func _clear(p: Vector2) -> Vector2:
	var world := _world()
	return world.terrain_free_target(p, 14.0) if world != null else p

## At the target: a pen gives up an animal, a deer dies; a soldier is
## fought by the bites (_bite). Each kill counts toward the pack's meal.
func _complete_hunt() -> void:
	var prey := _pack_target()
	if prey == null or global_position.distance_to(prey.global_position) > KILL_REACH + 30.0:
		return
	var killed := ""
	if prey is AnimalPen:
		if (prey as AnimalPen).consume_animal():
			killed = "a %s from the pen" % (prey as AnimalPen).animal_name
	elif prey is BaseNPC and (prey as BaseNPC).npc_type == "deer" and (prey as BaseNPC).is_alive:
		(prey as BaseNPC).take_damage(999, Damage.Type.WEAPON, "wolf")
		killed = "a deer"
	if killed == "":
		return
	var world := _world()
	if world != null:
		world.pack_kill(pack_id)
	print("A wolf drags off %s!" % killed)
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm != null and gm.has_method("_hud_message"):
		gm.call("_hud_message", "Wolves! They took %s." % killed, 3.0)

# --- teeth ---------------------------------------------------------------------------

## Whoever is on top of it — a soldier come to kill it — gets bitten.
func _bite(delta: float) -> void:
	if _burning_left > 0.0:
		return
	for node: Node in get_tree().get_nodes_in_group("soldiers"):
		var s := node as BaseNPC
		if s == null or not s.is_alive:
			continue
		if global_position.distance_to(s.global_position) > BITE_REACH:
			continue
		_bite_debt += BITE_DPS * delta
		var whole := int(_bite_debt)
		if whole > 0:
			_bite_debt -= float(whole)
			s.take_damage(whole, Damage.Type.WEAPON, "wolf")
		return
