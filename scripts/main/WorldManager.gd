extends Node2D

class_name WorldManager

## World spawner + escalation director.
## - Generates the world: boundaries, farmers, mines, soldiers (initial), fields.
## - Staggered soldier spawns (SpawnTimer) build up toward king_threshold;
##   at threshold the King spawns and the boss battle starts (decisions record:
##   soldier build-up runs on its own rate; crimes only hurt the economy).
## - Wires NPC output signals into GameManager (the single state hub).
## docs/plans/2026-11-08-behavior-system-rebuild.md

signal entity_spawned(entity_type: String, position: Vector2)

@export_group("World")
@export var world_size: Vector2 = Vector2(2000, 2000)
@export var farmer_count: int = 5
@export var mine_count: int = 8
@export var field_count: int = 6
@export var initial_soldier_count: int = 4

@export_group("Miner support chain")
@export var initial_miner_count: int = 2
@export var miner_spawn_requirement_farmers: int = 3
@export var miner_spawn_requirement_food: int = 10
@export var miner_spawn_timer: float = 30.0

@export_group("Escalation")
@export var soldier_spawn_interval: float = 8.0
@export var king_threshold: int = 15

const ESCALATING := "soldier"   # entity spawned on the escalation curve

var entity_scenes := {
	"farmer": preload("res://scenes/npcs/Farmer.tscn"),
	"miner": preload("res://scenes/npcs/Miner.tscn"),
	"mine": preload("res://scenes/objects/Mine.tscn"),
	"soldier": preload("res://scenes/objects/Soldier.tscn"),
	"field": preload("res://scenes/systems/Field.tscn"),
	"tower": preload("res://scenes/objects/WizardTower.tscn"),
	"king": preload("res://scenes/objects/King.tscn"),
}

var game_manager: GameManager
var soldiers_spawned: int = 0
var king_spawned: bool = false
var _soldier_timer: Timer

func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	generate_world()

	# Escalation timer: one soldier per interval until the King threshold.
	_soldier_timer = Timer.new()
	_soldier_timer.wait_time = soldier_spawn_interval
	_soldier_timer.autostart = true
	_soldier_timer.timeout.connect(_on_escalation_tick)
	add_child(_soldier_timer)

	# Miner support-chain spawn timer (existing behavior, new source of truth).
	var miner_timer := Timer.new()
	miner_timer.wait_time = miner_spawn_timer
	miner_timer.autostart = true
	miner_timer.timeout.connect(try_spawn_miner)
	add_child(miner_timer)

func generate_world() -> void:
	create_boundaries()
	spawn_entity("farmer", farmer_count)
	spawn_entity("mine", mine_count)
	spawn_entity("field", field_count)
	spawn_entity("soldier", initial_soldier_count)
	soldiers_spawned = initial_soldier_count
	if farmer_count >= miner_spawn_requirement_farmers:
		spawn_entity("miner", initial_miner_count)

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

# --- spawn plumbing ---------------------------------------------------------

func spawn_entity(entity_type: String, count: int) -> void:
	if not entity_scenes.has(entity_type):
		push_error("Unknown entity type: %s" % entity_type)
		return
	for i in count:
		var scene: PackedScene = entity_scenes[entity_type] as PackedScene
		if scene == null:
			continue
		var instance: Node = scene.instantiate()
		var position := get_random_position()
		setup_entity(entity_type, instance)
		# WorldManager (Node2D) gets the same random space as everyone else.
		instance.global_position = position
		add_child(instance)
		entity_spawned.emit(entity_type, position)

## Rewiring point: NPC output signals → GameManager (the hub). Scenes that
## are not workers (mine/tower/field) need no signal wiring here.
func setup_entity(entity_type: String, instance: Node) -> void:
	if game_manager == null:
		game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if entity_type == "farmer":
		var farmer := instance as NPCFarmer
		if farmer != null:
			farmer.food_delivered.connect(_on_food_delivered)
	elif entity_type == "miner":
		var miner := instance as Miner
		if miner != null:
			miner.resource_delivered.connect(_on_resource_delivered)
	if entity_type in ["farmer", "miner", "soldier"]:
		var npc := instance as BaseNPC
		npc.npc_died.connect(_on_npc_died)

func get_random_position() -> Vector2:
	var margin := 100.0
	return Vector2(
		randf_range(-world_size.x / 2 + margin, world_size.x / 2 - margin),
		randf_range(-world_size.y / 2 + margin, world_size.y / 2 - margin)
	)

# --- escalation --------------------------------------------------------------

func _on_escalation_tick() -> void:
	if king_spawned or game_manager == null:
		return
	spawn_entity(ESCALATING, 1)
	soldiers_spawned += 1
	game_manager.increment_soldier_count()
	if soldiers_spawned >= king_threshold:
		spawn_king()

## The final boss arrives with a fresh escort squad; defeating him ends the run.
func spawn_king() -> void:
	if king_spawned:
		return
	king_spawned = true
	_soldier_timer.stop()
	var king := entity_scenes["king"].instantiate() as King
	king.global_position = Vector2.ZERO
	add_child(king)
	if game_manager != null:
		game_manager.start_boss_battle(king)
	entity_spawned.emit("king", Vector2.ZERO)
	print("The King has arrived! (%d soldiers spawned)" % soldiers_spawned)

# --- signal handlers: NPC → GameManager (the hub) ---------------------------

func _on_food_delivered(amount: int) -> void:
	if game_manager != null:
		game_manager.add_food(amount)

func _on_resource_delivered(_npc_type: String, res_type: String, amount: int) -> void:
	if game_manager != null:
		game_manager.deposit_treasury(res_type, amount)

func _on_npc_died(npc_type: String) -> void:
	# Economy-only consequences: leader recount happens on the next support
	# tick; killed miners slow gold/gem production but never accelerate soldiers.
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
	var position := get_random_position()
	var miner := entity_scenes["miner"].instantiate() as Miner
	setup_entity("miner", miner)
	miner.global_position = position
	add_child(miner)
	game_manager.consume_food(miner_spawn_requirement_food)
	entity_spawned.emit("miner", position)
	print("Miner spawned (support satisfied: %d farmers, %d food)" % [
		farmer_count_now, game_manager.food])
