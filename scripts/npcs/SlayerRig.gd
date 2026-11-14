extends Node2D

class_name SlayerRig

## The dragon slayer's mounted rig (2026-11-14): a white charger in a
## crimson caparison carrying a knight in plate with a long lance. Lives on
## the slayer's `Sprite` node; BaseNPC._tick_rig calls tick() every
## physics frame (any Sprite with a tick() gets one).
##
##   Sprite (this)
##     Horse        — bobs with the gait
##       LegBackFar / LegFrontFar   (hip/shoulder pivots, drawn first)
##       Tail, Body, Caparison, Neck, HorseHead
##       LegBackNear / LegFrontNear
##     Rider        — rides the horse's bob, a beat late
##       … Torso, Helm, Shield …
##       LancePivot — the couch at the shoulder: raised at rest,
##                    levelled for the charge (lance_couch 0 → 1)

const LANCE_REST_DEG := -58.0
const LANCE_COUCH_DEG := 4.0
const GAIT_SWING_DEG := 30.0
const GAIT_PX_PER_STRIDE := 55.0   # world px per full gallop stride

## 0 = lance raised, 1 = couched level for the charge (DragonSlayer sets it).
var lance_couch := 0.0
## Extra forward lean of the rider (the charge).
var rider_lean := 0.0

var _phase := 0.0
var _gait := 0.0
var _idle := 0.0
var _parts := {}
var _homes := {}

func _ready() -> void:
	for n: String in ["Horse", "Rider", "Horse/LegBackFar", "Horse/LegFrontFar",
			"Horse/LegBackNear", "Horse/LegFrontNear", "Horse/Tail",
			"Horse/HorseHead", "Rider/LancePivot"]:
		var node := get_node_or_null(n) as Node2D
		if node != null:
			_parts[n] = node
			_homes[n] = node.position

func part(n: String) -> Node2D:
	return _parts.get(n) as Node2D

func tick(delta: float, velocity: Vector2, alive: bool = true) -> void:
	if not alive:
		return
	var speed := velocity.length()
	_gait = move_toward(_gait, clampf(speed / 90.0, 0.0, 1.0), delta * 4.0)
	_phase = fmod(_phase + delta * TAU * speed / GAIT_PX_PER_STRIDE, TAU * 8.0)
	_idle += delta
	var s := sin(_phase)
	var c := cos(_phase)
	# A rocking gallop: the diagonal pairs swing out of step.
	_rot("Horse/LegFrontNear", s * GAIT_SWING_DEG * _gait)
	_rot("Horse/LegBackFar", s * GAIT_SWING_DEG * _gait * 0.8)
	_rot("Horse/LegFrontFar", -c * GAIT_SWING_DEG * _gait)
	_rot("Horse/LegBackNear", -c * GAIT_SWING_DEG * _gait * 0.8)
	var bob := -absf(s) * 3.0 * _gait
	var horse := part("Horse")
	if horse != null:
		horse.position = _homes["Horse"] + Vector2(0.0, bob)
		horse.rotation = 0.05 * c * _gait
	var rider := part("Rider")
	if rider != null:
		rider.position = _homes["Rider"] + Vector2(0.0, -absf(sin(_phase - 0.5)) * 3.0 * _gait)
		rider.rotation = rider_lean * 0.25
	# Standing: the horse tosses its head and swishes its tail.
	var head := part("Horse/HorseHead")
	if head != null:
		head.rotation = deg_to_rad(4.0 * sin(_idle * 1.3) * (1.0 - _gait) + 6.0 * s * _gait)
	var tail := part("Horse/Tail")
	if tail != null:
		tail.rotation = deg_to_rad(8.0 * sin(_idle * 2.1) + 14.0 * _gait)
	_rot("Rider/LancePivot", lerpf(LANCE_REST_DEG, LANCE_COUCH_DEG, lance_couch)
		+ 3.0 * s * _gait * (1.0 - lance_couch))

func _rot(n: String, deg: float) -> void:
	var node := part(n)
	if node != null:
		node.rotation_degrees = deg
