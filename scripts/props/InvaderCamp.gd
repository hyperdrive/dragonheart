extends Node2D

## The usurper's war camp (2026-11-15). A flat compound like the city
## (drawn under the y-sorted pool, no collision): the invasion's waves
## march out of its gate (gate_position, the +y side) toward the realm.

const GATE_OFFSET := Vector2(0.0, 105.0)

func _ready() -> void:
	add_to_group("invader_camp")
	var ground := Sprite2D.new()
	ground.texture = load("res://assets/sprites/invader_camp.svg")
	ground.scale = Vector2(0.5, 0.5)     # imported at 2x
	ground.z_index = -1
	add_child(ground)

func gate_position() -> Vector2:
	return global_position + GATE_OFFSET
