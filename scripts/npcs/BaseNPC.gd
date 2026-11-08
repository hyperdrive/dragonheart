extends CharacterBody2D

class_name BaseNPC

## Base class for all town NPCs (farmers, miners, soldiers, King).
## Owns: movement (steering-seek, no nav mesh on open fields), health, the
## payload slot (resources being carried — stealable), tier level, anchors.
## Behavior: the Activity engine in BehaviorTree.gd; subclasses register
## activities in _ready. See docs/plans/2026-11-08-behavior-system-rebuild.md.

signal npc_died(npc_type: String)
signal carrying_changed(res_type: String, amount: int)

@export_group("Identity")
@export var npc_type: String = "villager"
@export var max_health: int = 50
@export_group("Movement")
@export var speed: float = 100.0
## Speed multiplier while FLEEING (BehaviorTree applies it to the escape run).
@export var flee_speed_multiplier: float = 1.0

@export_group("Tier (TTRPG levels)")
@export_range(1, 5) var npc_level: int = 1

@export_group("Dragon danger")
@export var danger_radius: float = 150.0
@export var safe_radius: float = 320.0

var health: int = max_health
var is_alive: bool = true
var behavior_tree: BehaviorTree
## Escape vector refreshed by the engine while the dragon is still close.
var flee_target: Vector2 = Vector2.ZERO

## Anchors, initialized at spawn and overridden by subclasses/WorldManager.
var home_position: Vector2 = Vector2.ZERO
var town_position: Vector2 = Vector2.ZERO
var mine_position: Vector2 = Vector2.ZERO
var pig_pen_position: Vector2 = Vector2.ZERO

## Payload slot: resources currently being carried (walked to town / stealable).
var payload_res_type: String = ""
var payload_amount: int = 0

## Facing state: 1 = right, -1 = left. Mirrors the Sprite container (cheap
## left/right representation — composites mirror cleanly, see _apply_facing).
var facing: int = 1

@onready var sprite: Node2D = $Sprite

func _ready() -> void:
	# sync health — subclasses MUST set max_health before calling super._ready()
	health = max_health
	home_position = global_position
	town_position = global_position + Vector2(0, 200)
	mine_position = global_position + Vector2(0, -200)
	pig_pen_position = global_position + Vector2(-200, 0)

func _physics_process(delta: float) -> void:
	if is_alive and behavior_tree != null:
		behavior_tree.tick(delta)

func take_damage(amount: int) -> void:
	if not is_alive:
		return
	health -= amount
	print(npc_type, " took ", amount, " damage, health: ", health)
	if health <= 0:
		die()

func die() -> void:
	is_alive = false
	if behavior_tree != null:
		behavior_tree.kill()
	print(npc_type, " has died")
	npc_died.emit(npc_type)
	# Remove from the tree after a short corpse delay.
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self):
		queue_free()

## Steering-seek movement toward a world-space target.
## Returns true when the target is reached (arrival threshold 12px).
func move_towards(target: Vector2) -> bool:
	if not is_alive:
		return true
	if global_position.distance_to(target) <= 12.0:
		velocity = Vector2.ZERO
		return true
	velocity = (target - global_position).normalized() * speed
	update_facing()
	move_and_slide()
	return false

## Track last horizontal travel direction: 1 right, -1 left. Zero x keeps the
## current facing. Call sites: move_towards (aim walk), BehaviorTree fleeing.
func update_facing() -> void:
	if velocity.x == 0.0:
		return
	var new_facing := 1 if velocity.x > 0.0 else -1
	if new_facing != facing:
		facing = new_facing
		_apply_facing()

## Mirror the whole visual container horizontally. ColorRect composites mirror
## about the container origin, so outlines/animations stay consistent.
func _apply_facing() -> void:
	if sprite != null:
		sprite.scale.x = float(facing)

## Set/clear the payload being carried. Emits carrying_changed so the
## GoldInterceptionSystem sees this NPC as a steal target.
func set_payload(res_type: String, amount: int) -> void:
	payload_res_type = res_type
	payload_amount = maxi(amount, 0)
	carrying_changed.emit(payload_res_type, payload_amount)

## Remove carried payload in an interception (dragon steal).
## Returns what was actually taken; remainder stays owned by this NPC = zero.
func steal_payload() -> Dictionary:
	var stolen := {
		"res_type": payload_res_type,
		"amount": payload_amount,
	}
	set_payload("", 0)
	return stolen

## Tier multiplier hook: subclasses scale yields/speed with npc_level.
func level_multiplier() -> float:
	return 1.0 + float(npc_level - 1) * 0.25

func get_health_ratio() -> float:
	return clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)
