extends Node2D

class_name DeerRig

## The glade deer's rig (2026-11-15): a springy four-legged gait, a bobbing
## head that dips to graze while standing, a flicking white tail. Lives on
## the deer's `Sprite`; BaseNPC._tick_rig calls tick() every physics frame.

const GAIT_SWING_DEG := 34.0
const PX_PER_STRIDE := 34.0

var _phase := 0.0
var _gait := 0.0
var _idle := 0.0
var _parts := {}
var _homes := {}

func _ready() -> void:
	for n: String in ["Body", "Body/LegBackFar", "Body/LegFrontFar", "Body/LegBackNear",
			"Body/LegFrontNear", "Body/Head", "Body/Tail"]:
		var node := get_node_or_null(n) as Node2D
		if node != null:
			_parts[n] = node
			_homes[n] = node.position

func set_stag(on: bool) -> void:
	var antlers := get_node_or_null("Body/Head/Antlers") as Node2D
	if antlers != null:
		antlers.visible = on

func tick(delta: float, velocity: Vector2, alive: bool = true) -> void:
	if not alive:
		return
	var speed := velocity.length()
	_gait = move_toward(_gait, clampf(speed / 70.0, 0.0, 1.0), delta * 5.0)
	_phase = fmod(_phase + delta * TAU * speed / PX_PER_STRIDE, TAU * 8.0)
	_idle += delta
	var s := sin(_phase)
	var c := cos(_phase)
	_rot("Body/LegFrontNear", s * GAIT_SWING_DEG * _gait)
	_rot("Body/LegBackFar", s * GAIT_SWING_DEG * _gait)
	_rot("Body/LegFrontFar", -s * GAIT_SWING_DEG * _gait)
	_rot("Body/LegBackNear", -s * GAIT_SWING_DEG * _gait)
	var body := part("Body")
	if body != null:
		body.position = _homes["Body"] + Vector2(0.0, -absf(c) * 2.5 * _gait)
	# Standing still: the head dips to graze, now and then looks up.
	var graze := (1.0 - _gait) * clampf(sin(_idle * 0.7) * 1.4, 0.0, 1.0)
	var head := part("Body/Head")
	if head != null:
		head.rotation = deg_to_rad(55.0 * graze + 5.0 * s * _gait)
		head.position = _homes["Body/Head"] + Vector2(2.0, 7.0) * graze
	var tail := part("Body/Tail")
	if tail != null:
		tail.rotation = deg_to_rad(-20.0 * absf(sin(_idle * 6.0)) * (0.3 + _gait))

func part(n: String) -> Node2D:
	return _parts.get(n) as Node2D

func _rot(n: String, deg: float) -> void:
	var node := part(n)
	if node != null:
		node.rotation_degrees = deg
