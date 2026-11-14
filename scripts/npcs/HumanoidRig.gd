extends Node2D

class_name HumanoidRig

## Jointed villager/soldier rig (2026-11-14 NPC art pass). Lives on an
## NPC's `Sprite` node; the art is generated with pivots at the joints:
##
##   Sprite (this)
##     LegBack   — hip pivot      (far leg, drawn first)
##     ArmBack   — shoulder pivot (far arm)
##     Torso     — body, gear, belt …
##     LegFront  — hip pivot
##     Head      — neck pivot
##     ArmFront  — shoulder pivot (near arm, tools ride the hand)
##
## BaseNPC calls tick() every physics frame. Walking is velocity-driven
## (legs swing, arms counter-swing, the upper body bobs on each footfall);
## standing still breathes. Action animations (mining, hoeing, combat,
## archery, cart pushing) take the arms over through `arms_override` and
## the body lean through `lean` — the rig keeps the legs walking under
## them. BaseNPC's flee wobble and facing flip act on this node itself, so
## they compose with everything here for free.

## World px per full stride (two steps). Lower = faster leg cadence.
const STRIDE_PX := 30.0
const LEG_SWING_DEG := 30.0
const ARM_SWING_DEG := 26.0
const BOB_PX := 1.3
## Hip-to-sole length: a leg swung by θ lifts its foot by leg_len·(1−cos θ),
## so the body drops by that much to keep the soles on the ground. Short
## folk (goblins) set their own.
@export var leg_len := 16.0

## Arms: when true the rig leaves ArmFront/ArmBack rotations alone.
var arms_override := false
## Forward lean of the upper body in radians (+ = toward facing).
var lean := 0.0
## Crouch (px): sinks the upper body over bent knees — sneaking, kneeling.
var crouch := 0.0

var _phase := 0.0
var _walk_amt := 0.0
var _breath := 0.0
var _parts := {}
var _homes := {}

func _ready() -> void:
	for n: String in ["LegBack", "LegFront", "ArmBack", "ArmFront", "Torso", "Head"]:
		var node := get_node_or_null(n) as Node2D
		if node != null:
			_parts[n] = node
			_homes[n] = node.position

func part(n: String) -> Node2D:
	return _parts.get(n) as Node2D

## Current walk cycle phase (radians) — action animations can sync to it.
func walk_phase() -> float:
	return _phase

func tick(delta: float, velocity: Vector2, alive: bool = true) -> void:
	if not alive:
		return
	var speed := velocity.length()
	_walk_amt = move_toward(_walk_amt, 1.0 if speed > 6.0 else 0.0, delta * 6.0)
	if speed > 6.0:
		_phase = fmod(_phase + delta * TAU * speed / STRIDE_PX, TAU * 16.0)
	_breath += delta
	var s := sin(_phase)
	var w := _walk_amt
	# Legs: opposite swing; the swinging leg shortens a touch (knee lift).
	_set_leg("LegFront", s * LEG_SWING_DEG * w, maxf(0.0, s) * w)
	_set_leg("LegBack", -s * LEG_SWING_DEG * w, maxf(0.0, -s) * w)
	var drop := leg_len * (1.0 - cos(deg_to_rad(absf(s) * LEG_SWING_DEG * w)))
	for leg_name: String in ["LegFront", "LegBack"]:
		var leg := part(leg_name)
		if leg != null:
			leg.position = _homes[leg_name] + Vector2(0.0, drop)
	if not arms_override:
		_rot("ArmFront", -s * ARM_SWING_DEG * w + sin(_breath * 1.6) * 2.0 * (1.0 - w))
		_rot("ArmBack", s * ARM_SWING_DEG * w - sin(_breath * 1.6) * 2.0 * (1.0 - w))
	# Upper body: bob down on each footfall (twice per stride), breathe
	# when standing, and lean as the current action asks.
	var bob := -absf(cos(_phase)) * BOB_PX * w + BOB_PX * 0.5 * w
	var breathe := sin(_breath * 1.8) * 0.35 * (1.0 - w)
	for n: String in ["Torso", "Head", "ArmFront", "ArmBack"]:
		var node := part(n)
		if node != null:
			node.position = _homes[n] + Vector2(lean * 6.0, bob + breathe + drop + crouch)
	var torso := part("Torso")
	if torso != null:
		torso.rotation = lean * 0.6
	var head := part("Head")
	if head != null:
		head.rotation = lean * 0.3

func _set_leg(n: String, deg: float, lift: float) -> void:
	var leg := part(n)
	if leg == null:
		return
	leg.rotation_degrees = deg
	leg.scale.y = 1.0 - 0.1 * lift

func _rot(n: String, deg: float) -> void:
	var node := part(n)
	if node != null:
		node.rotation_degrees = deg

## Convenience for action animations.
func set_arms(front_deg: float, back_deg: float) -> void:
	_rot("ArmFront", front_deg)
	_rot("ArmBack", back_deg)
