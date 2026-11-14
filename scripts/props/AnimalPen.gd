extends Node2D

class_name AnimalPen

## Animal pen component (attached to PigPen/CowPen scenes). A slot pool:
## the dragon eats an animal BY COMMAND (E;Dragon handles the trigger),
## town consumes the species for NPC respawns (farmer↔pig, miner↔cow);
## farm harvests pay 20 food per animal to fill empty slots (cap = max_animals).
## Animals no longer self-respawn on a timer — the farm cycle is their only
## return path (user spec 2026-11-08).

@export_group("Pen")
@export var animal_name: String = "pig"
@export var heal_amount: int = 15
## Healing rolls between heal_amount and heal_max per animal (2026-11-14:
## pigs heal 10-20). heal_max below heal_amount = a fixed heal.
@export var heal_max: int = 0
## Flame charges restored to the dragon per animal eaten (max 4).
@export var flame_recharge: int = 1
## Full restore (user spec 2026-11-10): the dragon gets FULL health AND
## full flames regardless of heal_amount/flame_recharge. Cows are prized
## stock — the meal is a complete reset; pigs stay a flame snack.
@export var full_restore: bool = false
@export var pen_radius: float = 80.0
@export var max_animals: int = 4
## Food the town pays to fill one empty slot (paid by WorldManager on farm
## harvests). Species-priced in _ready per user spec 2026-11-09:
## pigs are cheap stock (10 food), cows are prized stock (20 food).
## NOTE: set in code, so inspector values are intentionally recomputed.
@export var refill_cost: int = 20
## Slot offsets for sprite layout (used if the scene has fewer than
## max_animals sprite children).
@export var slot_offsets: Array[Vector2] = [
	Vector2(-45, -10), Vector2(-18, 10), Vector2(18, 12), Vector2(45, -8),
]

var _animals: Array[Sprite2D] = []

func _ready() -> void:
	# Species pricing (2026-11-09): 10 food buys a pig, 20 a cow. Computed
	# here so both pen scenes share one rule without per-scene edits.
	refill_cost = 10 if animal_name == "pig" else 20
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

## Intentional meal extraction (E key handled by the Dragon): takes one
## animal from the pen IF the dragon is within reach and stock exists.
## Returns {"heal", "flame"} — or an empty Dictionary when nothing was
## eaten (empty pen / not in reach), which the Dragon answers with a print.
func take_animal_for_dragon(from_dragon: CharacterBody2D) -> Dictionary:
	if from_dragon == null \
			or from_dragon.global_position.distance_to(global_position) > pen_radius:
		return {}
	if not consume_animal():
		return {}
	print(" Dragon snacked on a %s at the pen" % animal_name)
	var heal := randi_range(heal_amount, heal_max) if heal_max > heal_amount else heal_amount
	return {"heal": heal, "flame": flame_recharge}

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
