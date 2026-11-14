extends Node2D

class_name HagClawCloud

## Mother Grisla's "A Thousand and One Cuts" (2026-11-14). Two beats:
##   charge — a sickly green ring marks the ground, its inner ring
##            closing in over charge_time: the player's cue to get OUT;
##   strike — a storm of spectral black-and-green claw rakes slashes
##            across the circle in quick staggered flashes, then fades.
## Damage is the hag's business (Hag._cast_cuts); this node is the show.

var radius := 62.0
var charge_time := 0.5
var claw_count := 26

var _t := 0.0
var _striking := false
var _ring: Line2D
var _closing: Line2D
var _fill: Polygon2D

func _ready() -> void:
	z_index = 5
	_fill = Polygon2D.new()
	_fill.polygon = _circle(radius, 28)
	_fill.color = Color(0.35, 0.85, 0.25, 0.10)
	add_child(_fill)
	_ring = _make_ring(radius, Color(0.55, 1.0, 0.35, 0.85), 2.0)
	_closing = _make_ring(radius, Color(0.85, 1.0, 0.55, 0.9), 1.2)

func _process(delta: float) -> void:
	if _striking:
		return
	_t += delta
	var k := clampf(_t / maxf(charge_time, 0.01), 0.0, 1.0)
	# the inner ring closes from the rim to the centre: when it's gone, it bites
	_closing.scale = Vector2.ONE * (1.0 - k * 0.92)
	_fill.color.a = 0.10 + 0.22 * k
	_ring.default_color.a = 0.55 + 0.45 * absf(sin(_t * 18.0))

## Is a point inside the marked (flattened, ground-perspective) circle?
## The hit test matches exactly what the player sees.
static func covers(center: Vector2, point: Vector2, r: float) -> bool:
	var d := point - center
	return pow(d.x / r, 2.0) + pow(d.y / (r * 0.6), 2.0) <= 1.0

## The cuts land: slashes everywhere in the circle, then the cloud fades.
func strike() -> void:
	_striking = true
	_closing.visible = false
	_fill.color = Color(0.20, 0.55, 0.15, 0.35)
	for i in claw_count:
		var at := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius * Vector2(1.0, 0.6)
		_spawn_slash(at, randf() * 0.35)
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)

## One claw rake: three curved black talon-cuts edged in fen-green,
## flashing in at `delay`, slashing across, and fading.
func _spawn_slash(at: Vector2, delay: float) -> void:
	var slash := Node2D.new()
	slash.position = at
	slash.rotation = randf_range(-0.9, 0.9) + (PI if randf() < 0.5 else 0.0)
	slash.modulate.a = 0.0
	slash.scale = Vector2(0.4, 0.4)
	add_child(slash)
	for j in 3:
		var off := (float(j) - 1.0) * 4.0
		var glow := Polygon2D.new()
		glow.polygon = _crescent(off, 15.0, 2.6)
		glow.color = Color(0.55, 1.0, 0.35, 0.55)
		slash.add_child(glow)
		var cut := Polygon2D.new()
		cut.polygon = _crescent(off, 13.0, 1.2)
		cut.color = Color(0.06, 0.04, 0.05, 0.95)
		slash.add_child(cut)
	var tw := slash.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(slash, "modulate:a", 1.0, 0.04)
	tw.parallel().tween_property(slash, "scale", Vector2(1.1, 1.1), 0.08)
	tw.tween_interval(0.12)
	tw.tween_property(slash, "modulate:a", 0.0, 0.18)

func _crescent(off: float, half_len: float, thick: float) -> PackedVector2Array:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		var x := lerpf(-half_len, half_len, t)
		var bow := 4.0 * (1.0 - pow(2.0 * t - 1.0, 2.0))
		var w := thick * sin(t * PI)
		outer.append(Vector2(x, off - bow - w))
		inner.append(Vector2(x, off - bow + w))
	inner.reverse()
	return outer + inner

func _make_ring(r: float, col: Color, width: float) -> Line2D:
	var ring := Line2D.new()
	var pts := _circle(r, 32)
	pts.append(pts[0])
	ring.points = pts
	ring.width = width
	ring.default_color = col
	ring.antialiased = true
	add_child(ring)
	return ring

func _circle(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2.from_angle(TAU * float(i) / float(n)) * Vector2(r, r * 0.6))
	return pts
