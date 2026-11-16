extends Node2D

## A haunting ghost (2026-11-16, user: "For every 3rd person that is an
## adventurer, farmer or miner killed spawn a haunting ghost. It can't be
## killed but moves slowly and in the vicinity of the graveyard. It will
## however suck all the flames out of the dragon if she comes in contact
## with it.")
##
## Not a BaseNPC and in no damage group: claws, breath, ground fire and
## arrows never find it. It drifts at DRIFT_SPEED among the graves, never
## farther than Graveyard.HAUNT_RADIUS from home. Touching the dragon (any
## shape but the farm girl's) it drinks every flame she carries; the fire
## streams into it and it glows ember-orange for a moment. It wears the
## name of the dead whose death raised it (WorldManager.spawn_ghost).
## No class_name (editor rescan caveat).

const DRIFT_SPEED := 18.0
const HAUNT_RADIUS := 170.0
const TOUCH := 32.0
const DRAIN_COOLDOWN := 2.5

var home := Vector2.ZERO
var ghost_of := ""          # "Ewan Thatcher, farmer"
var _target := Vector2.ZERO
var _retarget := 0.0
var _t := 0.0
var _cooldown := 0.0
var _glow := 0.0            # 1 right after a drain, fades
var _facing := 1.0

func _ready() -> void:
	add_to_group("ghosts")
	z_index = 30
	_t = randf() * TAU
	if home == Vector2.ZERO:
		home = global_position
	_pick_target()

func _pick_target() -> void:
	_target = home + Vector2.from_angle(randf() * TAU) * randf_range(20.0, HAUNT_RADIUS) * Vector2(1.0, 0.7)
	_retarget = randf_range(5.0, 9.0)

func _process(delta: float) -> void:
	_t += delta
	_retarget -= delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_glow = maxf(_glow - delta * 0.7, 0.0)
	var to := _target - global_position
	if to.length() < 6.0 or _retarget <= 0.0:
		_pick_target()
	else:
		global_position += to.normalized() * DRIFT_SPEED * delta
		if absf(to.x) > 2.0:
			_facing = signf(to.x)
	_haunt()
	queue_redraw()

## Contact with the dragon: every flame she carries streams into the ghost.
func _haunt() -> void:
	if _cooldown > 0.0:
		return
	var d := get_tree().get_first_node_in_group("dragon") as Node2D
	if d == null or bool(d.get("human_form")) or bool(d.get("_dying")):
		return
	if global_position.distance_to(d.global_position) > TOUCH:
		return
	var drunk := int(d.call("drain_flames")) if d.has_method("drain_flames") else 0
	if drunk <= 0:
		return
	_cooldown = DRAIN_COOLDOWN
	_glow = 1.0
	_stream_from(d.global_position, drunk)
	var who := ("The ghost of " + ghost_of) if ghost_of != "" else "A ghost"
	print("%s drinks the dragon's fire — %d flame(s) gone!" % [who, drunk])
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm != null and gm.has_method("_hud_message"):
		gm.call("_hud_message", "%s drinks your fire! All %d flames gone." % [who, drunk], 3.5)

## The stolen fire: embers fly from the dragon into the ghost.
func _stream_from(from: Vector2, n: int) -> void:
	for i in clampi(n * 4, 6, 24):
		var e := Polygon2D.new()
		var s := randf_range(2.0, 4.0)
		e.polygon = PackedVector2Array([Vector2(0, -s), Vector2(s * 0.7, 0), Vector2(0, s), Vector2(-s * 0.7, 0)])
		e.color = [Color(1.0, 0.55, 0.15), Color(1.0, 0.8, 0.3), Color(1.0, 0.35, 0.1)][i % 3]
		e.z_index = 31
		get_parent().add_child(e)
		e.global_position = from + Vector2(randf_range(-14, 14), randf_range(-18, 4))
		var tw := e.create_tween()
		tw.tween_interval(i * 0.03)
		tw.tween_property(e, "global_position", global_position + Vector2(0, -12), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(e, "scale", Vector2(0.3, 0.3), 0.45)
		tw.tween_callback(e.queue_free)

func _draw() -> void:
	var bob := sin(_t * 1.6) * 3.0
	var pale := Color(0.82, 0.9, 1.0).lerp(Color(1.0, 0.62, 0.3), _glow)
	var body := Color(pale, 0.62)
	# a faint shadow below — it floats
	draw_set_transform(Vector2(0, 16), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2(0, bob - 12.0), 0.0, Vector2(_facing, 1.0))
	draw_circle(Vector2.ZERO, 20.0, Color(pale, 0.12 + 0.25 * _glow))
	# the sheet: a round head, sides falling to a ragged, rippling hem
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * 10.0)
	var hem := 6
	for i in hem + 1:
		var x := 11.0 - 22.0 * float(i) / float(hem)
		var y := 20.0 + (4.0 if i % 2 == 0 else -1.0) + sin(_t * 4.0 + i) * 1.5
		pts.append(Vector2(x + sin(_t * 2.0 + i) * 1.2, y))
	draw_colored_polygon(pts, body)
	# eyes and the long mouth
	draw_circle(Vector2(-3.5, -1.0), 2.0, Color(0.05, 0.05, 0.12, 0.85))
	draw_circle(Vector2(3.5, -1.0), 2.0, Color(0.05, 0.05, 0.12, 0.85))
	draw_set_transform(Vector2(0, bob - 12.0 + 6.0), 0.0, Vector2(_facing * 1.0, 1.6))
	draw_circle(Vector2.ZERO, 1.8, Color(0.05, 0.05, 0.12, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
