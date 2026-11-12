extends Soldier

class_name Adventurer

## Wandering adventurer (user spec 2026-11-12): spawns at the CITY every
## 5 minutes (WorldManager timer), walks to the dragon's lair, kills the
## goblins he meets, then steals ALL the gold from the dragon's lair hoard
## (GameManager.stash — the same pool the dragon banks stolen loot into)
## and hauls it back to the TOWN TREASURY before leaving the world.
##
## Built on the King NPC (extends Soldier like him): same sword-swing
## animation (Soldier._resolve_weapon finds the scene's "Sword" node),
## same contact-DPS combat — but NO boss storm and NO dragon hunt (the
## soldier activity set is cleared in _ready). He fights the dragon only
## at melee contact; the intended counter is dragon FIRE — he is flammable
## like every NPC (BaseNPC.catch_fire) and never flees (danger_radius 0).

@export_group("Hunt")
## Goblin-seeking reach: whole map, like the bold-soldier hunt — the hero
## clears goblins wherever they are before touching the hoard.
@export var goblin_hunt_range: float = 4000.0
@export_group("Lair raid")
## Stand-off ring around the lair rock (same math as the goblin trader,
## which works at 90 — the lair body is a r=58 circle; a target inside the
## rock can never be reached at the 12px arrival threshold).
@export var lair_raid_ring: float = 95.0
## Seconds spent looting at the hoard before the payload is claimed.
@export var loot_time: float = 3.0
## The hoard's guard ring (user spec order: "kill goblins AND FINALLY
## steal"): the raid is only placeable when NO living goblin is inside
## this radius of the lair. The goblin mountain sits ~200px from the lair,
## so the hero must clear the lair's neighbourhood before touching the
## gold. Goblins respawning 60s later don't re-lock the raid — the loot
## is long done by then.
@export var lair_guard_radius: float = 500.0

const GOLD_DROP_SCENE := preload("res://scenes/objects/GoldDrop.tscn")

## Goblin-combat debt: the hero's own contact-DPS accumulator. The
## inherited Soldier._contact_damage feeds the goblin branch ONLY from
## the dragon-contact debt (its `if _contact_debt <= 0.0: return` gate
## sits before the goblin loop) — soldiers practically never kill
## goblins. Goblin slaying is the hero's CORE job, so his blade carries
## its own debt (2026-11-12, probe-verified: the hero stood 20px from a
## goblin for 30s without landing a hit under the inherited flow).
var _goblin_debt: float = 0.0

var game_manager: GameManager

func _ready() -> void:
	# Configure before super._ready() — it syncs health from max_health
	# (same contract the King follows; the Soldier profile stomp is gated
	# on npc_type "villager" so an already-configured subclass keeps this).
	npc_type = "adventurer"
	max_health = 120
	speed = 70.0
	attack_damage = 15.0  # contact DPS vs goblins (and a melee dragon)
	attack_range = 50.0
	aggro_range = 600.0   # unused: the soldier dragon-hunt activity is cleared
	reward_gold = 0
	danger_radius = 0.0   # a hero never panics at dragon proximity — fire still kills

	super._ready()        # Soldier._ready: resolves the Sword node, registers soldier activities

	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	add_to_group("adventurers")

	# Replace the soldier activity set: no dragon hunt, no rally. The
	# adventurer's job list (user spec order): kill goblins, THEN raid the
	# lair hoard, then haul the gold home.
	behavior_tree.clear_activities()
	# hunt_goblin cooldown 0.0: after every chase leg he re-picks the hunt
	# IMMEDIATELY — any cooldown here lets lower activities slip in between
	# legs (probe-verified: the 1.5s cooldown interleaved idle wander, and
	# one idle leg wedged the hero into the goblin mountain for 50s).
	behavior_tree.register_activity(
		"hunt_goblin", 50,
		_pick_goblin_target, 0.0,
		0.0, Callable()
	)
	behavior_tree.register_activity(
		"raid_lair", 40,
		_pick_lair_target, loot_time,
		1.0, _complete_raid_lair,
		_can_raid_lair
	)
	behavior_tree.register_activity(
		"haul_home", 30,
		_pick_home_target, 0.0,
		0.0, _complete_haul_home,
		_carrying_loot
	)
	behavior_tree.register_activity(
		"idle", 1,
		_pick_idle_target, 1.5,
		2.0, Callable()
	)

# --- activity target providers ----------------------------------------------

## Goblin hunt DPS (independent accumulator — see _goblin_debt): 15/s into
## the first living goblin inside attack range, integer-chunked like the
## soldier flow. The dragon branch stays in the inherited super call.
func _contact_damage(delta: float) -> void:
	if _burning_left > 0.0 or not is_alive:
		return
	for node: Node in get_tree().get_nodes_in_group("goblins"):
		var goblin := node as BaseNPC
		if goblin == null or not goblin.is_alive:
			continue
		if global_position.distance_to(goblin.global_position) > attack_range:
			continue
		_goblin_debt += attack_damage * delta
		var whole := int(_goblin_debt)
		if whole > 0:
			_goblin_debt -= float(whole)
			goblin.take_damage(whole)
			break
	super._contact_damage(delta)  # dragon self-defense at melee contact

## The NEAREST living goblin, whole map (goblins cluster at their mountain
## beside the lair, so hunting them naturally walks the hero out of the
## city and toward the hoard).
func _pick_goblin_target() -> Vector2:
	var best: Node2D = null
	var best_dist := INF
	for node: Node in get_tree().get_nodes_in_group("goblins"):
		var goblin := node as BaseNPC
		if goblin == null or not goblin.is_alive:
			continue
		var dist := global_position.distance_to(goblin.global_position)
		if dist < best_dist:
			best_dist = dist
			best = goblin
	if best == null or best_dist > goblin_hunt_range:
		return BehaviorTree.TARGET_NONE
	# Terrain-cleared trip goal: the goblin can stand at the mountain's
	# edge, and an uncleared jitter once parked the hero against the rock
	# for a 30s activity-stall (probe-verified 2026-11-12). The arrival
	# point must be standable even though the prey has moved on.
	return _cleared_trip_target(
		(best as Node2D).global_position
			+ Vector2(randf_range(-20, 20), randf_range(-20, 20)),
		20.0)

## The dragon's lair hoard (stand-off ring outside the rock — see the
## goblin trader's 90px ring rationale; a centered target is unreachable).
func _pick_lair_target() -> Vector2:
	var site := _lair_site()
	if site == Vector2.INF:
		return home_position
	var angle := randf() * TAU
	return site + Vector2(cos(angle), sin(angle)) * lair_raid_ring

## The lair rock's world position: the DragonLair node when present,
## otherwise the WorldManager's exported anchor. INF when neither exists.
func _lair_site() -> Vector2:
	var lair := get_tree().get_first_node_in_group("dragon_lair") as Node2D
	if lair != null and is_instance_valid(lair):
		return lair.global_position
	var world := get_tree().get_first_node_in_group("world_manager") as WorldManager
	return world.lair_position if world != null else Vector2.INF

## The city's north gate (the same delivery door farmers/miners use),
## terrain-cleared so the trip goal is always standable.
func _pick_home_target() -> Vector2:
	var world := get_tree().get_first_node_in_group("world_manager") as WorldManager
	var anchor := home_position
	if world != null:
		anchor = world.city_position + Vector2(0, -90)
	return _cleared_trip_target(anchor, 24.0)

## Loose wander around where he stands (wandering adventurer): keeps the
## map alive while goblins are respawning or the hoard is empty. Targets
## are terrain-cleared like every soldier trip — an uncleared jitter once
## parked the hero against the goblin mountain for 50s (probe-verified).
func _pick_idle_target() -> Vector2:
	var anchor := global_position + Vector2(
		randf_range(-140.0, 140.0), randf_range(-140.0, 140.0))
	return _cleared_trip_target(anchor, 20.0)

# --- activity gates & completers ---------------------------------------------

## The raid is only placeable with free claws, gold actually in the hoard
## (an empty lair must not strand the hero in a raid loop), and the lair's
## goblin GUARDS cleared — user spec order: "kill goblins and finally
## steal". Without the guard gate the hunt's own cooldown gaps let the
## raid slip in between chase legs (probe-verified 2026-11-12).
func _can_raid_lair() -> bool:
	if payload_amount > 0:
		return false
	if game_manager == null:
		game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
		if game_manager == null:
			return false
	if int(game_manager.stash["gold"]) <= 0:
		return false
	var site := _lair_site()
	if site == Vector2.INF:
		return false
	for node: Node in get_tree().get_nodes_in_group("goblins"):
		var goblin := node as BaseNPC
		if goblin != null and goblin.is_alive \
				and site.distance_to(goblin.global_position) < lair_guard_radius:
			return false  # a guard still stands
	return true

func _carrying_loot() -> bool:
	return payload_res_type == "gold" and payload_amount > 0

## "Steal all gold in the lair": drain the ENTIRE gold pool from the
## dragon's stash (the lair hoard) into the backpack. Gems are left —
## the user spec is gold. The payload mounts the GoldInterceptionSystem:
## a dragon that catches him in the open steals it all back.
func _complete_raid_lair() -> void:
	if game_manager == null:
		return
	var stolen := int(game_manager.stash["gold"])
	if stolen <= 0:
		return
	if not game_manager.spend_stash("gold", stolen):
		return  # hoard drained mid-loot — re-pick; the raid retries later
	set_payload("gold", stolen)
	print("The adventurer loots the lair — ALL %d gold into his backpack!" % stolen)

## The haul home: deposit the stolen gold into the town treasury (the
## hero "returns" what the dragon stole — the town can buy soldiers with
## it again), then his job is done and he leaves the world.
func _complete_haul_home() -> void:
	if not _carrying_loot():
		return
	var hauled := payload_amount
	if game_manager != null:
		game_manager.deposit_treasury("gold", hauled)
	set_payload("", 0)
	print("The adventurer returns %d gold to the town treasury and departs." % hauled)
	queue_free()

## Death spills the carried haul where he fell (Miner.die precedent): the
## dragon can scoop the loose GoldDrop. No report_loot_spill alarm — that
## is the town's street-treasure signal and the hero usually dies far
## from the city.
func die() -> void:
	if _carrying_loot():
		var drop := GOLD_DROP_SCENE.instantiate() as GoldDrop
		if drop != null:
			drop.res_type = payload_res_type
			drop.amount = payload_amount
			set_payload("", 0)
			get_parent().add_child(drop)
			drop.global_position = global_position \
				+ Vector2(randf_range(-16, 16), randf_range(4, 12))
			print("The adventurer falls — his hoard of %d gold spills out!" % drop.amount)
	super.die()
