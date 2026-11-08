extends Node2D

class_name AnimalPen

## Animal pen component (attached to PigPen/CowPen scenes). A slot pool:
## the dragon eats an animal in reach (+health, +flame recharge); town codes
## snack on the species for NPC respawns (farmer↔pig, miner↔cow); and farm
## harvests pay 20 food per animal to fill empty slots (cap = max_animals).
## Animals no longer self-respawn on a timer — the farm cycle is their only
## return path (user spec 2026-11-08).

@export_group("Pen")
@export var animal_name: String = "pig"
@export var heal_amount: int = 15
## Flame charges restored to the dragon per animal eaten (max 4).
@export var flame_recharge: int = 1
@export var pen_radius: float = 80.0
@export var max_animals: int = 4
## Eating pace: one animal per bite_interval while the dragon hovers the pen —
## otherwise the pen empties in a single frame and the farm chain collapses.
@export var bite_interval: float = 0.8
## Food the town pays to fill one empty slot (paid by WorldManager on farm
## harvests).
@export var refill_cost: int = 20
## Slot offsets for sprite layout (used if the scene has fewer than
## max_animals sprite children).
@export var slot_offsets: Array[Vector2] = [
	Vector2(-45, -10), Vector2(-18, 10), Vector2(18, 12), Vector2(45, -8),
]

var _animals: Array[Sprite2D] = []
var _bite_left: float = 0.0

func _ready() -> void:
	# Existing Sprite2D children in the pen scene are slot 0..n. Slots beyond
	# that (up to max_animals) are created hidden; a live sprite from the
	# scene supplies the texture/scale.
	var template: Sprite2D = null
	for child in get_children():
		var animal := child as Sprite2D
		if animal != null:
			_animals.append(animal)
			if template == null:
				template = animal
	# Fill remaining slots.
	while _animals.size() < max_animals:
		var slot := Sprite2D.new()
		slot.texture = template.texture if template != null else null
		slot.scale = template.scale if template != null else Vector2(1.1, 1.1)
		var offset: Vector2 = slot_offsets[_animals.size()] \
			if _animals.size() < slot_offsets.size() \
			else slot_offsets[slot_offsets.size() - 1]
		slot.position = offset
		slot.visible = false
		add_child(slot)
		_animals.append(slot)

## The dragon snacking (one animal per bite_interval while in reach); the
## dragon receives the heal + flame charge directly (capped on its side).
func _physics_process(delta: float) -> void:
	if _bite_left > 0.0:
		_bite_left -= delta
	_try_eat()

func _try_eat() -> void:
	if _bite_left > 0.0:
		return
	var dragon := get_tree().get_first_node_in_group("dragon") as CharacterBody2D
	if dragon == null or not is_instance_valid(dragon):
		return
	if bool(dragon.get("_dying")):
		return
	if dragon.global_position.distance_to(global_position) > pen_radius:
		return
	var consumed := consume_animal()
	if consumed:
		_bite_left = bite_interval
		dragon.call("eat_animal", heal_amount, flame_recharge)
		print(" dragon ate a %s at the pen (+%d health, +%d flame charge)" % [
			animal_name, heal_amount, flame_recharge])

## Empty-slot check for respawn rules.
func has_empty_slot() -> bool:
	for animal in _animals:
		if not animal.visible:
			return true
	return false

func animal_count() -> int:
	var count := 0
	for animal in _animals:
		if animal.visible:
			count += 1
	return count

## Town economy: fill one empty slot (paid by WorldManager BEFORE calling).
func respawn_animal() -> bool:
	for animal in _animals:
		if not animal.visible:
			animal.visible = true
			print("A new %s grew up at the pen (town paid %d food)" % [
				animal_name, refill_cost])
			return true
	return false

## Consumed by town bookkeeping (NPC respawn needs a live specimen). Returns
## false when the pen is empty — the caller's rule stays unsatisfied.
func consume_animal() -> bool:
	for animal in _animals:
		if animal.visible:
			animal.visible = false
			return true
	return false
