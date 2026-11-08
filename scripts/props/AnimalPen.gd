extends Node2D

class_name AnimalPen

## Animal pen component (attached to PigPen/CowPen scenes). The dragon can eat
## an animal in reach — heals it (eat_food clamps at max health). The animal
## hides and respawns later, so the farmers' food chain stays replenishable.

@export_group("Pen")
@export var animal_name: String = "pig"
@export var heal_amount: int = 15
@export var pen_radius: float = 80.0
@export var respawn_time: float = 25.0

var _animals: Array[Sprite2D] = []
var _respawn_left: Array[float] = []

func _ready() -> void:
	# Animal sprites are exactly the Sprite2D children of the pen scene.
	for child in get_children():
		var animal := child as Sprite2D
		if animal != null:
			_animals.append(animal)
			_respawn_left.append(0.0)

func _physics_process(delta: float) -> void:
	_tick_respawns(delta)
	_try_eat()

func _tick_respawns(delta: float) -> void:
	for i in _animals.size():
		if _animals[i] != null and _animals[i].visible:
			continue
		_respawn_left[i] -= delta
		if _respawn_left[i] <= 0.0:
			_animals[i].visible = true
			print("A new %s grew up at the pen" % animal_name)

func _try_eat() -> void:
	var dragon := get_tree().get_first_node_in_group("dragon") as CharacterBody2D
	if dragon == null or not is_instance_valid(dragon):
		return
	if bool(dragon.get("_dying")):
		return
	if dragon.global_position.distance_to(global_position) > pen_radius:
		return
	for i in _animals.size():
		if _animals[i] == null or not _animals[i].visible:
			continue
		# This animal becomes dinner; the dragon heals (capped at max health).
		_animals[i].visible = false
		_respawn_left[i] = respawn_time
		dragon.call("eat_food", heal_amount)
		print("Dragon ate a %s (+%d health)!" % [animal_name, heal_amount])
		return  # one animal per frame
