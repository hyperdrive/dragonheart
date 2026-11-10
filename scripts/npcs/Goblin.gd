extends BaseNPC

class_name Goblin

## Goblin NPC: smaller, greener cousin of soldiers.
## Spawns from mountains, mines gems for the dragon, steals gold if aggro.
## First encounter: popup to buy mining services. If refused, warns about theft.
## Kill goblins: they attack like soldiers but also steal gold.
## Some goblins go "waargh!" and plunder mode.

## Mining service state
enum ServiceState { UNINITIALIZED, OFFERED, BUYING, WARNED, HOSTILE }

## Raid state - triggered when all goblins go on a raiding party
var goblin_raid_active: bool = false

@export_group("Goblin")
@export var mining_service_cost: int = 1  # gems per trade trip
## Gold fetched per trade trip (user spec: 1g per trip from a nearby mine).
@export_range(1, 10) var haul_size: int = 1
@export var goblin_health: int = 30
@export var goblin_speed: float = 120.0
@export var flee_distance: float = 200.0  # Distance to run from soldiers
@export var attack_range: float = 40.0  # Range to attack targets

var service_state: ServiceState = ServiceState.UNINITIALIZED
var _plunder_mode: bool = false
var _goblin_home: Vector2 = Vector2.ZERO
var _contact_debt: float = 0.0
var _has_gold: bool = false  # 20% chance to spawn with gold
var _carrying_gold: int = 0  # Gold stolen from dragon's stash
var _target_mountain: Node2D = null
var _encounter_done: bool = false  # Track if popup has been triggered
## The tribe's paid gem fees, banked at the mountain (cosmetic hoard tally).
var _gem_hoard: int = 0

func _ready() -> void:
	# Configure goblin stats before super._ready()
	npc_type = "goblin"
	max_health = goblin_health
	speed = goblin_speed
	_goblin_home = global_position
	
	# Call super._ready() to initialize BaseNPC properties
	super._ready()
	
	# Adopt the tribe's standing (user spec: the story answer binds the whole
	# tribe) — goblins spawned after the popup never saw it but are born into
	# the deal (or into hostility after a refusal).
	var world := get_tree().get_first_node_in_group("world_manager") as WorldManager
	if world != null and world.goblin_service_standing != ServiceState.UNINITIALIZED:
		service_state = world.goblin_service_standing
		_plunder_mode = service_state == ServiceState.HOSTILE
	
	# 20% chance to spawn with gold
	if randf() < 0.2:
		_has_gold = true
		_carrying_gold = 5  # Start with 5 gold to offer mining services
	
	# Find nearest mountain for stealing operations
	_target_mountain = get_tree().get_nodes_in_group("mountain")[0] if get_tree().get_nodes_in_group("mountain").size() > 0 else null
	
	# Create behavior tree before super._ready() to avoid parent busy error
	_behavior_tree_setup()
	
	# Don't trigger popup on spawn - wait for dragon encounter


# --- behavior tree setup ------------------------------------------------------

## Activities (decision record 2026-11-08: the shared Activity engine, no
## side plans). The paid trade loop (user spec 2026-11-10 — gem-for-gold
## AT THE LAIR): fetch gold at the NEAREST mine → haul it to the dragon's
## lair → transact 1 gold for 1 gem from the dragon's STASH → carry the
## gem fee home to the tribe hoard. As long as the dragon's hoard holds
## gems, the tribe keeps the cycle running; "idle" stays the fallback.
func _behavior_tree_setup() -> void:
	behavior_tree = BehaviorTree.new()
	add_child(behavior_tree)
	behavior_tree.setup(self)
	# 1) Fetch: pick up gold at the nearest live mine.
	behavior_tree.register_activity(
		"trade_fetch", 30,
		_pick_nearby_mine, 2.0,
		1.0, _complete_fetch_gold,
		_can_fetch_gold
	)
	# 2) Transact: haul the gold to the lair, exchange it for a gem.
	behavior_tree.register_activity(
		"trade_transact", 20,
		_pick_lair_target, 1.0,
		0.0, _complete_transact,
		_carrying_gold_haul
	)
	# 3) Hoard: bank the gem fee at the tribe's mountain.
	behavior_tree.register_activity(
		"trade_hoard", 10,
		_pick_home_target, 0.5,
		0.0, _complete_hoard_gem,
		_carrying_fee_gem
	)
	# Fallback when no trade leg is placeable (no gems in the hoard,
	# mid-trip interruptions).
	behavior_tree.register_activity(
		"idle", 1,
		_pick_idle_target, 1.5,
		2.0, Callable()
	)


func _physics_process(delta: float) -> void:
	# Behavior tree drives movement/fleeing; overrides add per-frame behavior.
	if is_instance_valid(behavior_tree) and behavior_tree.is_inside_tree():
		super._physics_process(delta)
		_contact_damage(delta)

	# Always check for Dragon proximity (not dependent on behavior tree)
	_check_dragon_encounter()


# --- service handling ---------------------------------------------------------

func offer_service() -> void:
	if service_state != ServiceState.UNINITIALIZED:
		return
	
	# Trigger story popup for goblin encounter
	var game_manager := get_tree().get_first_node_in_group("game_manager")
	if game_manager != null:
		game_manager.notify_story("goblin_encounter_neutral")
	
	service_state = ServiceState.OFFERED
	print("Goblin offers mining services for %d gem per turn" % mining_service_cost)

## The story answer lands on the WHOLE tribe (GameManager's popup ledger
## opens goblin_encounter_* once per run, so a per-goblin reply would strand
## the others). OFFERED goblins were waiting on this answer; spawning
## goblins arriving later never saw the popup but inherit the standing
## (checked in _ready against WorldManager.goblin_service_standing).
func _on_service_response(purchased: bool) -> void:
	if service_state == ServiceState.BUYING or service_state == ServiceState.HOSTILE:
		return
	
	if purchased:
		service_state = ServiceState.BUYING
		_plunder_mode = false
		print("Goblin deal accepted! Mining services started.")
	else:
		service_state = ServiceState.HOSTILE
		_plunder_mode = true
		print("Goblin deal refused! The tribe goes hostile.")


# --- combat -------------------------------------------------------------------

func _contact_damage(delta: float) -> void:
	if _plunder_mode:
		# In plunder mode, deal damage to dragon on contact
		# Use the Hurtbox Area2D to detect dragon overlaps
		var hurtbox := $Hurtbox
		if hurtbox != null:
			var overlap := hurtbox.get_overlapping_bodies() as Array[Node2D]
			for body in overlap:
				if body.is_in_group("dragon"):
					if _contact_debt <= 0.0:
						var damage := int(1 + randf() * 2)
						body.take_damage(damage)
						_contact_debt = 0.5  # Cooldown between contact hits


# --- behavior tree helpers ----------------------------------------------------

## The NEAREST live mine ("go fetch in a nearby mine") — falls back to the
## miner-district anchor when no mine node exists. Stand-off ring 45px keeps
## the approach point OUTSIDE the mine body (30x20 rect) — a target INSIDE
## the rock can never be reached (12px arrival threshold).
func _pick_nearby_mine() -> Vector2:
	var best: Node2D = null
	var best_dist := INF
	for node: Node in get_tree().get_nodes_in_group("mines"):
		var mine := node as Node2D
		if mine == null or not is_instance_valid(mine):
			continue
		var dist := global_position.distance_to(mine.global_position)
		if dist < best_dist:
			best_dist = dist
			best = mine
	var site := mine_position
	if best != null:
		site = best.global_position
	var angle := randf() * TAU
	return site + Vector2(cos(angle), sin(angle)) * 45.0

## The dragon's lair seat ("transact it for a gem at the dragon lair").
## Stand-off ring 90px: the lair body is a r=58 circle offset (0,-18), so a
## point near the CENTER is unreachable — the old in-body targets wedged the
## trader into a forever-detour loop just outside the rock.
func _pick_lair_target() -> Vector2:
	var lair := get_tree().get_first_node_in_group("dragon_lair") as Node2D
	var site := Vector2.INF
	if lair != null and is_instance_valid(lair):
		site = lair.global_position
	if site == Vector2.INF:
		var world := get_tree().get_first_node_in_group("world_manager") as WorldManager
		if world != null:
			site = world.lair_position
	if site == Vector2.INF:
		return home_position
	var angle := randf() * TAU
	return site + Vector2(cos(angle), sin(angle)) * 90.0

## The tribe's mountain hoard (where the paid gem fee is banked).
func _pick_home_target() -> Vector2:
	return _goblin_home + Vector2(randf_range(-30, 30), randf_range(-18, 18))

func _pick_idle_target() -> Vector2:
	# Goblin idles near its home position (mountain spawn area). The wander
	# stays within 50px: home sits on the 90px spawn ring, so targets keep
	# ≥40px clear of the rock — an idle leg wedged INTO the mountain can
	# never complete and (activity engine contract) starves every re-pick.
	return _goblin_home + Vector2(randf_range(-50, 50), randf_range(-50, 50))

# --- trade activity gates & completers (gem-for-gold at the lair) --------------

## The dragon funds every haul up-front FROM HIS STASH: a job is only
## placeable while the hoard still has a gem to pay with.
func _can_fetch_gold() -> bool:
	if service_state != ServiceState.BUYING or payload_amount > 0:
		return false
	var manager := get_tree().get_first_node_in_group("game_manager") as GameManager
	if manager == null:
		return false
	return manager.stash.get("gems", 0) >= mining_service_cost

func _carrying_gold_haul() -> bool:
	return payload_res_type == "gold"

func _carrying_fee_gem() -> bool:
	return payload_res_type == "gems"

## The haul: exactly haul_size gold — a carrying_changed here mounts the
## GoldInterceptionSystem on the goblin (the payload slot pays for theft).
func _complete_fetch_gold() -> void:
	set_payload("gold", haul_size)
	print("Goblin fetched %d gold from the mine" % haul_size)

## The transact (user: "fetch 1g in a nearby mine, then transact it for a
## gem at the dragon lair"): gold INTO the dragon's hoard, a gem OUT.
func _complete_transact() -> void:
	if payload_res_type != "gold" or payload_amount <= 0:
		return
	var manager := get_tree().get_first_node_in_group("game_manager") as GameManager
	if manager == null or not manager.spend_stash("gems", mining_service_cost):
		return  # hoard drained mid-haul — the haul goes back for the next job
	var hauled := payload_amount
	manager.add_stolen("gold", hauled)
	set_payload("gems", mining_service_cost)  # the fee: now in goblin claws
	print("Goblin traded %d gold for %d gem at the lair" % [
		hauled, mining_service_cost])

## The fee lands in the tribe's mountain hoard (their pay for the service).
func _complete_hoard_gem() -> void:
	if payload_res_type != "gems" or payload_amount <= 0:
		return
	_gem_hoard += payload_amount
	set_payload("", 0)
	print("Goblin stashed the gem fee in the tribe hoard (%d gems banked)" % _gem_hoard)


# --- goblin-specific encounter detection -------------------------------------

func _check_dragon_encounter() -> void:
	# Check if Dragon is close enough to trigger encounter popup
	# Only triggers once per goblin per run (before popup is shown)
	if _encounter_done or service_state != ServiceState.UNINITIALIZED:
		return
	
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return
	
	var distance := global_position.distance_to(dragon.global_position)
	if distance <= 200.0:  # Increased from 100px to 200px for better encounter rate
		_encounter_done = true
		offer_service()
