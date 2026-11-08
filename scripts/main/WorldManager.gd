extends Node2D

class_name WorldManager

## World spawner + escalation director.
## Layout: a city in the south (soldiers spawn there), a farm belt around it
## (fields + animal pens + farmer homes), a mining district in the northwest,
## and blocking scenery (trees/lakes/mountains) scattered with clearance checks.
## Soldier tactics: when the dragon nears the city soldiers RALLY at the city
## gate; when enough have massed (or the dragon is at the walls) they ATTACK.
## docs/plans/2026-11-08-behavior-system-rebuild.md

signal entity_spawned(entity_type: String, position: Vector2)
signal swarm_state_changed(new_state: SwarmState)

enum SwarmState { CALM, RALLY, ATTACK }

@export_group("World")
@export var world_size: Vector2 = Vector2(1600, 1600)
@export var farmer_count: int = 5
@export var mine_count: int = 8
@export var field_count: int = 6
@export var initial_soldier_count: int = 4

@export_group("Landmarks")
@export var city_position: Vector2 = Vector2(0, 620)
@export var mine_center: Vector2 = Vector2(-480, -420)
@export var rally_point: Vector2 = Vector2(0, 500)   # north gate of the city
@export var pig_pen_position: Vector2 = Vector2(-260, 760)
@export var cow_pen_position: Vector2 = Vector2(260, 820)
@export var lair_position: Vector2 = Vector2(-620, 60)   # dragon's home mountain
@export var tower_position: Vector2 = Vector2(520, -420)  # wizard tower

@export_group("Terrain")
@export var tree_count: int = 14
@export var lake_count: int = 3
@export var mountain_count: int = 5

@export_group("Miner support chain")
@export var initial_miner_count: int = 2
@export var miner_spawn_requirement_farmers: int = 3
@export var miner_spawn_requirement_food: int = 10
@export var miner_spawn_timer: float = 30.0

@export_group("Escalation")
@export var soldier_spawn_interval: float = 8.0
@export var king_threshold: int = 15

@export_group("Swarm tactics")
@export var rally_range: float = 340.0          # dragon distance to city → RALLY
@export var swarm_size: int = 3                 # gathered soldiers → ATTACK
@export var swarm_gather_radius: float = 110.0
@export var attack_range_city: float = 170.0    # dragon at the walls → ATTACK

const ESCALATING := "soldier"   # entity spawned on the escalation curve

var entity_scenes := {
	"farmer": preload("res://scenes/npcs/Farmer.tscn"),
	"miner": preload("res://scenes/npcs/Miner.tscn"),
	"mine": preload("res://scenes/objects/Mine.tscn"),
	"soldier": preload("res://scenes/objects/Soldier.tscn"),
	"field": preload("res://scenes/systems/Field.tscn"),
	"tower": preload("res://scenes/objects/WizardTower.tscn"),
	"king": preload("res://scenes/objects/King.tscn"),
	"city": preload("res://scenes/props/City.tscn"),
	"pig_pen": preload("res://scenes/props/PigPen.tscn"),
	"cow_pen": preload("res://scenes/props/CowPen.tscn"),
	"lair": preload("res://scenes/props/DragonLair.tscn"),
}

var scenery_scenes := [
	preload("res://scenes/props/Tree.tscn"),
	preload("res://scenes/props/Lake.tscn"),
	preload("res://scenes/props/Mountain.tscn"),
]

var game_manager: GameManager
var soldiers_spawned: int = 0
var king_spawned: bool = false
var swarm_state: SwarmState = SwarmState.CALM
var field_positions: Array[Vector2] = []
var _soldier_timer: Timer
var _swarm_timer: Timer
## Blocking scenery footprint (position + radius) for spawn-clearance checks.
var _terrain_clearances: Array = []


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	add_to_group("world_manager")
	if game_manager != null:
		swarm_state_changed.connect(game_manager._on_swarm_state_changed)
	generate_world()

	# Escalation timer: one soldier per interval until the King threshold.
	_soldier_timer = Timer.new()
	_soldier_timer.wait_time = soldier_spawn_interval
	_soldier_timer.autostart = true
	_soldier_timer.timeout.connect(_on_escalation_tick)
	add_child(_soldier_timer)

	# Miner support-chain spawn timer (the "farmers enable miners" chain).
	var miner_timer := Timer.new()
	miner_timer.wait_time = miner_spawn_timer
	miner_timer.autostart = true
	miner_timer.timeout.connect(try_spawn_miner)
	add_child(miner_timer)

	# Swarm coordination tick (see _on_swarm_tick).
	_swarm_timer = Timer.new()
	_swarm_timer.wait_time = 0.5
	_swarm_timer.autostart = true
	_swarm_timer.timeout.connect(_on_swarm_tick)
	add_child(_swarm_timer)


# --- world generation --------------------------------------------------------

func generate_world() -> void:
	spawn_entity("city", 1, city_position)
	spawn_entity("pig_pen", 1, pig_pen_position)
	spawn_entity("cow_pen", 1, cow_pen_position)
	spawn_entity("lair", 1, lair_position)     # solid like other mountains
	spawn_entity("tower", 1, tower_position)   # wizard upgrades landmark
	spawn_fields()
	# Scenery avoids ALL landmarks (incl. lair + tower) with clearances.
	spawn_scenery()
	spawn_entity("mine", mine_count, mine_center, 180.0)
	spawn_farmers()
	spawn_entity("soldier", initial_soldier_count, rally_point, 90.0)
	soldiers_spawned = initial_soldier_count
	if farmer_count >= miner_spawn_requirement_farmers:
		spawn_entity("miner", initial_miner_count, mine_center, 140.0)
	create_boundaries()


## Fields ring the farm belt around the city (the food engine next to town).
func spawn_fields() -> void:
	for i in field_count:
		var angle := TAU * float(i) / float(field_count) + 0.4
		var position := city_position + Vector2.RIGHT.rotated(angle) * 230.0
		spawn_entity("field", 1, position)
		field_positions.append(position)


## One farmer per field-ish position; the rest drift near the pens.
func spawn_farmers() -> void:
	for i in farmer_count:
		var anchor := field_positions[i % field_positions.size()] \
			if field_positions.size() > 0 else city_position
		var position := _terrain_free_position(
			_clear_position(anchor, 40.0), 40.0)
		var farmer: Node = (entity_scenes["farmer"] as PackedScene).instantiate()
		farmer.global_position = position
		add_child(farmer)
		setup_entity("farmer", farmer)
		entity_spawned.emit("farmer", position)


## Blocking scenery: trees, lakes, mountains — placed clear of all features
## (city, fields, pens, dragon start) so travel routes stay open.
func spawn_scenery() -> void:
	var protected: Array = [
		city_position, Vector2.ZERO, pig_pen_position, cow_pen_position,
		lair_position, tower_position,
	]
	for field_pos: Vector2 in field_positions:
		protected.append(field_pos)
	var counts := [tree_count, lake_count, mountain_count]
	for kind_id in counts.size():
		for i in counts[kind_id]:
			var radius: float = [22.0, 66.0, 60.0][kind_id]
			var position := _terrain_free_position(
				get_random_position(), radius, protected, 110.0)
			if position == Vector2.INF:
				continue  # map too crowded at this spot; skip
			var scene: PackedScene = scenery_scenes[kind_id]
			var obstacle := scene.instantiate()
			obstacle.global_position = position
			add_child(obstacle)
			_terrain_clearances.append({"pos": position, "radius": radius})
			entity_spawned.emit("terrain", position)


## Jitter around an anchor until the spot is reasonably free of scenery.
func _terrain_free_position(anchor: Vector2, self_radius: float,
	protected := [] as Array, protected_margin := 90.0) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for attempt in 24:
		var candidate := anchor + Vector2(
			rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)
		) * float(attempt) * 12.0
		if candidate.distance_to(city_position) < 140.0:
			continue
		if candidate.distance_to(Vector2.ZERO) < 120.0:
			continue  # keep dragon's start spot open
		var blocked := false
		for clearance: Dictionary in _terrain_clearances:
			if candidate.distance_to(clearance["pos"]) \
					< self_radius + float(clearance["radius"]) + 30.0:
				blocked = true
				break
		if blocked:
			continue
		var clear := true
		for spot: Vector2 in protected:
			if candidate.distance_to(spot) < protected_margin:
				clear = false
				break
		if clear:
			return candidate
	return Vector2.INF


func _clear_position(anchor: Vector2, spread: float) -> Vector2:
	return anchor + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))


# --- spawn plumbing ---------------------------------------------------------

## Position rules: anchor INF → random on the map; spread 0 → anchor exact
## (city, pens); otherwise jitter around the anchor, clear of scenery.
func spawn_entity(entity_type: String, count: int, anchor := Vector2.INF,
	spread := 0.0) -> void:
	if not entity_scenes.has(entity_type):
		push_error("Unknown entity type: %s" % entity_type)
		return
	for i in count:
		var scene: PackedScene = entity_scenes[entity_type] as PackedScene
		if scene == null:
			continue
		var instance: Node = scene.instantiate()
		var position: Vector2
		if anchor == Vector2.INF:
			position = get_random_position()
		elif spread <= 0.0:
			position = anchor
		else:
			position = _terrain_free_position(_clear_position(anchor, spread), 24.0)
			if position == Vector2.INF:
				position = anchor  # fall back to the anchor; never lose the spawn
		instance.global_position = position
		add_child(instance)          # _ready runs: subclass configures itself
		setup_entity(entity_type, instance)  # then we override the anchors
		entity_spawned.emit(entity_type, position)


## Rewiring point: NPC output signals → GameManager (the hub) + anchor setup.
## Called AFTER add_child so overrides beat BaseNPC's spawn-relative defaults.
func setup_entity(entity_type: String, instance: Node) -> void:
	if game_manager == null:
		game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	match entity_type:
		"farmer":
			var farmer := instance as NPCFarmer
			if farmer != null:
				farmer.home_position = farmer.global_position
				farmer.town_position = city_position + Vector2(0, -90)  # north gate
				farmer.pig_pen_position = pig_pen_position
				farmer.food_delivered.connect(_on_food_delivered)
		"miner":
			var miner := instance as Miner
			if miner != null:
				miner.home_position = miner.global_position
				miner.mine_position = _mine_spot()
				miner.town_position = city_position + Vector2(0, -90)
				miner.resource_delivered.connect(_on_resource_delivered)
		"soldier":
			var soldier := instance as Soldier
			if soldier != null:
				soldier.home_position = soldier.global_position
	if entity_type in ["farmer", "miner", "soldier"]:
		var npc := instance as BaseNPC
		npc.npc_died.connect(_on_npc_died)


## Jittered position inside the mining district (spreads miners across it).
func _mine_spot() -> Vector2:
	return mine_center + Vector2(randf_range(-160, 160), randf_range(-160, 160))


func get_random_position() -> Vector2:
	var margin := 100.0
	return Vector2(
		randf_range(-world_size.x / 2 + margin, world_size.x / 2 - margin),
		randf_range(-world_size.y / 2 + margin, world_size.y / 2 - margin)
	)


## Invisible walls at the world edges (keeps entities on the map).
func create_boundaries() -> void:
	for wall: Dictionary in [
		{"size": Vector2(20.0, world_size.y), "pos": Vector2(-world_size.x / 2, 0.0)},
		{"size": Vector2(20.0, world_size.y), "pos": Vector2(world_size.x / 2, 0.0)},
		{"size": Vector2(world_size.x, 20.0), "pos": Vector2(0.0, -world_size.y / 2)},
		{"size": Vector2(world_size.x, 20.0), "pos": Vector2(0.0, world_size.y / 2)},
	]:
		var wall_body := StaticBody2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wall["size"]
		var collision := CollisionShape2D.new()
		collision.shape = shape
		wall_body.add_child(collision)
		wall_body.position = wall["pos"]
		add_child(wall_body)


# --- swarm tactics: CALM → RALLY → ATTACK ------------------------------------
##
## CALM  : soldiers patrol the city.
## RALLY : dragon approached the city — soldiers mass at the north gate.
## ATTACK: enough soldiers massed, dragon at the walls, or the King is up —
##         everyone hunts the dragon.

func _on_swarm_tick() -> void:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return
	var dragon_dist := dragon.global_position.distance_to(city_position)
	var gathered := _gathered_count()
	match swarm_state:
		SwarmState.CALM:
			if dragon_dist < rally_range:
				_set_swarm_state(SwarmState.RALLY)
		SwarmState.RALLY:
			if dragon_dist < attack_range_city or gathered >= swarm_size:
				_set_swarm_state(SwarmState.ATTACK)
		SwarmState.ATTACK:
			# Disengage when the dragon leaves the city area for good.
			if dragon_dist > rally_range * 2.0:
				_set_swarm_state(SwarmState.CALM)

func _gathered_count() -> int:
	var count := 0
	for soldier: Node in get_tree().get_nodes_in_group("soldiers"):
		var npc := soldier as BaseNPC
		if npc != null and npc.is_alive \
				and npc.global_position.distance_to(rally_point) < swarm_gather_radius:
			count += 1
	return count

func _set_swarm_state(new_state: SwarmState) -> void:
	if swarm_state == new_state:
		return
	swarm_state = new_state
	print("Swarm state: ", ["CALM", "RALLY", "ATTACK"][int(new_state)])
	swarm_state_changed.emit(new_state)

## Called by Soldier when it spots the dragon close-in — but only raises the
## alarm when the sighting is cityward; the city gate is what gets defended.
func report_dragon_sighting(sighting_position: Vector2) -> void:
	if swarm_state == SwarmState.CALM \
			and sighting_position.distance_to(city_position) < rally_range * 1.4:
		_set_swarm_state(SwarmState.RALLY)


## Treasure spilled in the streets (miners panic-dropping) is a visible dragon
## crime: soldiers skip the RALLY gathering and hunt now. Called by Miner.
func report_loot_spill() -> void:
	if swarm_state != SwarmState.ATTACK:
		_set_swarm_state(SwarmState.ATTACK)

# --- escalation --------------------------------------------------------------


func _on_escalation_tick() -> void:
	if king_spawned or game_manager == null:
		return
	spawn_entity(ESCALATING, 1, rally_point, 90.0)
	soldiers_spawned += 1
	game_manager.increment_soldier_count()
	if soldiers_spawned >= king_threshold:
		spawn_king()


## The final boss arrives at the city; defeating him ends the run.
func spawn_king() -> void:
	if king_spawned:
		return
	king_spawned = true
	_soldier_timer.stop()
	var king := entity_scenes["king"].instantiate() as King
	king.global_position = city_position + Vector2(0, -140)
	add_child(king)
	var king_npc := king as BaseNPC
	if king_npc != null:
		king_npc.home_position = king.global_position
	if game_manager != null:
		game_manager.start_boss_battle(king)
	entity_spawned.emit("king", king.global_position)
	_set_swarm_state(SwarmState.ATTACK)
	print("The King has arrived! (%d soldiers spawned)" % soldiers_spawned)

# --- signal handlers: NPC → GameManager (the hub) ---------------------------

func _on_food_delivered(amount: int) -> void:
	if game_manager != null:
		game_manager.add_food(amount)


func _on_resource_delivered(_npc_type: String, res_type: String, amount: int) -> void:
	if game_manager != null:
		game_manager.deposit_treasury(res_type, amount)


func _on_npc_died(npc_type: String) -> void:
	# Economy-only consequences: killed miners slow gold/gem production but
	# never accelerate soldiers (decision record).
	print("NPC died: ", npc_type)

# --- miner support chain ------------------------------------------------------

## Farmers + food gate miner spawning (the "farmers enable miners" chain).
func try_spawn_miner() -> void:
	if game_manager == null:
		return
	var farmer_count_now := get_tree().get_nodes_in_group("farmers").size()
	var supported := farmer_count_now >= miner_spawn_requirement_farmers \
		and game_manager.food >= miner_spawn_requirement_food
	# Tell miners whether they may mine (support chain gates economic output).
	for miner: Node in get_tree().get_nodes_in_group("miners"):
		if miner is Miner:
			(miner as Miner).check_support_conditions(farmer_count_now, game_manager.food)
	if not supported:
		return
	spawn_entity("miner", 1, mine_center, 140.0)
	game_manager.consume_food(miner_spawn_requirement_food)
	print("Miner spawned (support satisfied: %d farmers, %d food)" % [
		farmer_count_now, game_manager.food])
