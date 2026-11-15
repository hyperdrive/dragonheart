extends Control

## "The Birds and the Bees" (2026-11-15, user: "animate bees and flowers,
## litterally, for the symbolic meaning"): the adventurer's courtship
## chapter fades to a meadow, and the story politely watches a bee court
## a flower instead. Drawn over the story image (StoryPopup shows it for
## stories with "animation": "bees"); runs while the world is paused.
##
## One CYCLE: the bee buzzes in on a loopy, very determined path, circles
## the shy pink flower (which leans toward it), lands, pollen bursts, the
## flower blushes, hearts float up, the bee wobbles off to sit down.

const CYCLE := 9.0
const ARRIVE := 3.6     # the bee reaches the flower
const LEAVE := 6.6      # the bee staggers off

var _t := 0.0
var _pollen: Array = []   # [pos, vel, life]
var _hearts: Array = []   # [pos, life, size]
var _burst_done := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func restart() -> void:
	_t = 0.0
	_pollen.clear()
	_hearts.clear()
	_burst_done = false

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _t >= CYCLE:
		restart()
	var p := _t
	if p >= ARRIVE and not _burst_done:
		_burst_done = true
		var at := _flower_head()
		for i in 34:
			var a := randf() * TAU
			_pollen.append([at, Vector2.from_angle(a) * randf_range(18.0, 70.0) + Vector2(0, -20), randf_range(0.8, 1.8)])
	if p > ARRIVE + 0.4 and p < LEAVE + 1.2 and randf() < delta * 3.0:
		_hearts.append([_flower_head() + Vector2(randf_range(-20.0, 20.0), -10.0), 1.8, randf_range(0.7, 1.2)])
	for i in range(_pollen.size() - 1, -1, -1):
		var d: Array = _pollen[i]
		d[1] = (d[1] as Vector2) * (1.0 - delta * 1.5) + Vector2(0, 30.0) * delta
		d[0] = (d[0] as Vector2) + (d[1] as Vector2) * delta
		d[2] = float(d[2]) - delta
		if float(d[2]) <= 0.0:
			_pollen.remove_at(i)
	for i in range(_hearts.size() - 1, -1, -1):
		var h: Array = _hearts[i]
		h[0] = (h[0] as Vector2) + Vector2(sin(_t * 3.0 + float(i)) * 12.0, -28.0) * delta
		h[1] = float(h[1]) - delta
		if float(h[1]) <= 0.0:
			_hearts.remove_at(i)
	queue_redraw()

# --- the scene --------------------------------------------------------------

func _ground() -> float:
	return size.y * 0.92

func _flower_base() -> Vector2:
	return Vector2(size.x * 0.58, _ground())

## The shy flower leans toward the bee as it nears (and after).
func _flower_lean() -> float:
	var k := smoothstep(ARRIVE - 1.6, ARRIVE, _t) * (1.0 - smoothstep(LEAVE + 0.5, CYCLE, _t))
	return -0.28 * k + 0.05 * sin(_t * 1.3)

func _flower_head() -> Vector2:
	var h := size.y * 0.5
	return _flower_base() + Vector2(0, -h).rotated(_flower_lean())

func _bee_pos() -> Vector2:
	var head := _flower_head() + Vector2(-4.0, -12.0)
	if _t < ARRIVE:
		# a loopy, very determined approach from the left
		var u := _t / ARRIVE
		var start := Vector2(-30.0, size.y * 0.3)
		var base := start.lerp(head, smoothstep(0.0, 1.0, u))
		var loop := Vector2(cos(u * TAU * 2.0), sin(u * TAU * 2.0)) * 22.0 * (1.0 - u)
		return base + loop + Vector2(0, sin(_t * 9.0) * 3.0)
	if _t < LEAVE:
		# landed: a happy little wiggle
		return head + Vector2(sin(_t * 14.0) * 1.5, absf(sin(_t * 7.0)) * -2.0)
	# staggering off to the right, rather tired
	var v := (_t - LEAVE) / (CYCLE - LEAVE)
	return head + Vector2(v * size.x * 0.5, -v * 30.0 + sin(v * 18.0) * 8.0 * v)

func _draw() -> void:
	if size.x <= 0.0:
		return
	# background flowers swaying along the meadow
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 14:
		var x := rng.randf_range(0.03, 0.97) * size.x
		if absf(x - _flower_base().x) < 50.0:
			continue
		var h := rng.randf_range(0.18, 0.34) * size.y
		var col: Color = [Color(1.0, 0.85, 0.3), Color(1, 1, 1), Color(0.7, 0.55, 1.0), Color(1.0, 0.55, 0.7)][i % 4]
		_flower(Vector2(x, _ground() + rng.randf_range(-3.0, 3.0)), h, 0.08 * sin(_t * 1.6 + float(i)), col, 5.0, 0.0)
	# the shy flower: blushing deeper once the bee has landed
	var blush := smoothstep(ARRIVE, ARRIVE + 1.2, _t) * (1.0 - smoothstep(LEAVE + 1.0, CYCLE, _t))
	var pink := Color(1.0, 0.72, 0.82).lerp(Color(1.0, 0.32, 0.55), blush)
	_flower(_flower_base(), size.y * 0.5, _flower_lean(), pink, 11.0, blush)
	for d: Array in _pollen:
		draw_circle(d[0], 1.6, Color(1.0, 0.9, 0.3, clampf(float(d[2]), 0.0, 1.0)))
	for h: Array in _hearts:
		_heart(h[0], 7.0 * float(h[2]), Color(1.0, 0.3, 0.5, clampf(float(h[1]), 0.0, 1.0)))
	_bee(_bee_pos())

func _flower(base: Vector2, h: float, lean: float, petal: Color, r: float, blush: float) -> void:
	var head := base + Vector2(0, -h).rotated(lean)
	var mid := base.lerp(head, 0.5) + Vector2(6.0 * lean * 10.0, 0)
	draw_polyline(PackedVector2Array([base, mid, head]), Color(0.25, 0.55, 0.2), maxf(1.5, r * 0.22), true)
	draw_circle(mid + Vector2(r * 0.6, 0), r * 0.35, Color(0.3, 0.62, 0.25))   # a leaf
	for k in 6:
		var a := TAU * float(k) / 6.0 + _t * 0.15
		draw_circle(head + Vector2.from_angle(a) * r * 0.75, r * 0.55, petal)
	draw_circle(head, r * 0.45, Color(1.0, 0.8, 0.2))
	if r > 8.0:
		# a bashful face: closed eyes and rosy cheeks as it blushes
		draw_arc(head + Vector2(-2.5, -0.5), 1.4, 0.2, PI - 0.2, 6, Color(0.35, 0.2, 0.1), 1.0)
		draw_arc(head + Vector2(2.5, -0.5), 1.4, 0.2, PI - 0.2, 6, Color(0.35, 0.2, 0.1), 1.0)
		if blush > 0.05:
			draw_circle(head + Vector2(-4.0, 2.0), 1.6, Color(1.0, 0.4, 0.5, blush))
			draw_circle(head + Vector2(4.0, 2.0), 1.6, Color(1.0, 0.4, 0.5, blush))

func _bee(at: Vector2) -> void:
	var flap := sin(_t * 60.0)
	var facing := -1.0 if _t > LEAVE else 1.0
	# wings: a blur of beating
	for side in [-1.0, 1.0]:
		var wing := at + Vector2(-2.0 * facing, -6.0 - 2.0 * flap * side)
		draw_set_transform(wing, 0.4 * side * flap, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, 5.5, Color(0.9, 0.97, 1.0, 0.55))
	# striped body
	draw_set_transform(at, 0.0, Vector2(1.45, 1.0))
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.82, 0.15))
	for sx in [-2.2, 1.4]:
		draw_rect(Rect2(sx, -5.6, 1.6, 11.2), Color(0.12, 0.1, 0.08))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_circle(at + Vector2(8.5 * facing, -1.0), 3.6, Color(0.12, 0.1, 0.08))   # head
	draw_circle(at + Vector2(9.6 * facing, -2.0), 1.0, Color(1, 1, 1))           # eye
	draw_line(at + Vector2(9.0 * facing, -4.0), at + Vector2(12.0 * facing, -8.0), Color(0.12, 0.1, 0.08), 1.0)
	draw_line(at + Vector2(-8.5 * facing, 0.0), at + Vector2(-11.0 * facing, 0.5), Color(0.12, 0.1, 0.08), 1.2)

func _heart(at: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 20:
		var t := TAU * float(k) / 20.0
		pts.append(at + Vector2(16.0 * pow(sin(t), 3.0),
			-(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * s / 16.0)
	draw_colored_polygon(pts, col)
