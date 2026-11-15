extends Node2D

## A claw hit's blood (2026-11-15, user: "add a blood splash effect when we
## hit"). Spawned at the victim by Dragon (claws, executions, the deer
## hunt): a spray of droplets thrown away from the dragon that patter down,
## a dark splat that soaks into the ground and fades, and a red flash on
## the victim. Frees itself when done. Goblins bleed green.
##
## No class_name on purpose: callers preload this script (an editor that
## has not rescanned would not know a new global class).

const SPRAY_TIME := 0.55
const SPLAT_FADE := 5.0

var direction := Vector2.RIGHT        # away from the attacker
var color := Color(0.62, 0.04, 0.05)  # arterial red
var strength := 1.0                   # 1 = a claw rake, 1.6 = an execution

func _ready() -> void:
	z_index = 3
	var spray := CPUParticles2D.new()
	spray.one_shot = true
	spray.explosiveness = 0.92
	spray.amount = int(18 * strength)
	spray.lifetime = SPRAY_TIME
	spray.direction = (direction + Vector2(0.0, -0.6)).normalized()
	spray.spread = 38.0
	spray.initial_velocity_min = 90.0 * strength
	spray.initial_velocity_max = 190.0 * strength
	spray.gravity = Vector2(0.0, 520.0)
	spray.scale_amount_min = 1.6
	spray.scale_amount_max = 3.4
	spray.color = color
	var fade := Gradient.new()
	fade.set_color(0, color.lightened(0.15))
	fade.set_color(fade.get_point_count() - 1, Color(color.darkened(0.4), 0.0))
	spray.color_ramp = fade
	spray.texture = _droplet()                  # round drops, not squares
	spray.scale_amount_min = 0.35
	spray.scale_amount_max = 0.8
	spray.position = Vector2(0.0, -16.0)       # from the body, not the feet
	add_child(spray)
	spray.emitting = true
	# the splat: a few overlapping blobs on the ground, soaking in
	var splat := Node2D.new()
	splat.z_index = -1 - z_index              # under the y-sorted pool
	splat.z_as_relative = true
	add_child(splat)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in int(5 * strength):
		var blob := Polygon2D.new()
		var r := rng.randf_range(2.0, 5.5) * strength
		var at := direction * rng.randf_range(4.0, 22.0) * strength \
			+ Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-3.0, 3.0))
		var pts := PackedVector2Array()
		for k in 9:
			var a := TAU * float(k) / 9.0
			pts.append(at + Vector2.from_angle(a) * r * Vector2(1.0, 0.55) * rng.randf_range(0.75, 1.15))
		blob.polygon = pts
		blob.color = color.darkened(0.25)
		blob.antialiased = true
		splat.add_child(blob)
	var tw := create_tween()
	tw.tween_interval(SPLAT_FADE * 0.6)
	tw.tween_property(splat, "modulate:a", 0.0, SPLAT_FADE * 0.4)
	tw.tween_callback(queue_free)

## A soft round droplet (shared): opaque core, feathered rim.
static var _drop_tex: GradientTexture2D = null

static func _droplet() -> GradientTexture2D:
	if _drop_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.55, Color(1, 1, 1, 1))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		_drop_tex = GradientTexture2D.new()
		_drop_tex.gradient = g
		_drop_tex.fill = GradientTexture2D.FILL_RADIAL
		_drop_tex.fill_from = Vector2(0.5, 0.5)
		_drop_tex.fill_to = Vector2(1.0, 0.5)
		_drop_tex.width = 10
		_drop_tex.height = 10
	return _drop_tex
