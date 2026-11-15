extends Node2D

class_name Glade

## The glade that blooms where the King's line ended (2026-11-15). The
## ground decal (assets/sprites/glade.svg) lies under everything; on top,
## soft sunbeams breathe and fireflies drift. Birches ring it (spawned as
## ordinary trees by WorldManager.spawn_glade, so they block like trees).
## Deer graze inside RADIUS; the Prince first strolls here.

const RADIUS := 150.0

var _beams: Array[Polygon2D] = []
var _t := 0.0

func _ready() -> void:
	add_to_group("glade")
	var ground := Sprite2D.new()
	ground.texture = load("res://assets/sprites/glade.svg")
	ground.scale = Vector2(0.5, 0.5)      # imported at 2x for crispness
	ground.z_index = -1                   # flat ground: under the y-sorted pool
	add_child(ground)
	for i in 4:
		var beam := Polygon2D.new()
		var x := -110.0 + i * 70.0
		beam.polygon = PackedVector2Array([Vector2(x, -170), Vector2(x + 26, -170),
			Vector2(x + 70, 60), Vector2(x + 18, 60)])
		beam.color = Color(1.0, 0.97, 0.78, 0.0)
		beam.z_index = 4
		add_child(beam)
		_beams.append(beam)
	var flies := CPUParticles2D.new()
	flies.amount = 22
	flies.lifetime = 4.0
	flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flies.emission_rect_extents = Vector2(140.0, 80.0)
	flies.direction = Vector2(0, -1)
	flies.spread = 180.0
	flies.gravity = Vector2.ZERO
	flies.initial_velocity_min = 4.0
	flies.initial_velocity_max = 14.0
	flies.scale_amount_min = 1.5
	flies.scale_amount_max = 2.6
	flies.color = Color(1.0, 0.98, 0.6, 0.9)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 0.7, 0.0))
	fade.add_point(0.3, Color(1, 1, 0.7, 1.0))
	fade.add_point(0.7, Color(1, 1, 0.7, 1.0))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 0.7, 0.0))
	flies.color_ramp = fade
	flies.z_index = 5
	add_child(flies)

func _process(delta: float) -> void:
	_t += delta
	for i in _beams.size():
		_beams[i].color.a = 0.07 + 0.05 * sin(_t * 0.6 + float(i) * 1.7)
