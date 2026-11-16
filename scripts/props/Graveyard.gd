extends Node2D

## The graveyard (2026-11-16, body count: "if more than 10 people are
## killed spawn a small graveyard"). WorldManager.spawn_graveyard raises it
## near the town once the dragon's roll passes BodyCount.GRAVEYARD_AFTER;
## every name on the roll gets a headstone (set_graves), new ones with a
## fresh dark mound. The ghosts haunt its grounds (Ghost.gd, HAUNT_RADIUS).
## Drawn in code, low wall and lychgate, so it grows stone by stone.
## Walkable: no collision. No class_name (editor rescan caveat).

const HALF := Vector2(92.0, 52.0)       # the walled plot
const COLS := 7
const ROWS := 4
const HAUNT_RADIUS := 170.0

const WALL := Color(0.42, 0.40, 0.37)
const WALL_LIT := Color(0.56, 0.54, 0.50)
const WALL_DARK := Color(0.24, 0.23, 0.22)
const EARTH := Color(0.20, 0.18, 0.14)
const GRASS := Color(0.24, 0.28, 0.18)
const MOUND := Color(0.16, 0.12, 0.09)
const STONE := Color(0.62, 0.61, 0.58)
const STONE_DARK := Color(0.36, 0.35, 0.34)
const WOOD := Color(0.30, 0.20, 0.12)

var graves := 0
var _fresh := 0          # how many of the newest graves still have bare mounds
var _seed := 0

func _ready() -> void:
	add_to_group("graveyard")
	_seed = randi()

func set_graves(n: int) -> void:
	_fresh = mini(_fresh + maxi(n - graves, 0), 6)
	graves = n
	queue_redraw()

func _draw() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = _seed
	# soft shadow and the plot's ground
	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, HALF.x + 18.0, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var plot := Rect2(-HALF, HALF * 2.0)
	draw_rect(plot, GRASS)
	for i in 40:
		var p := Vector2(r.randf_range(-HALF.x, HALF.x), r.randf_range(-HALF.y, HALF.y))
		draw_circle(p, r.randf_range(2.0, 5.0), EARTH.lerp(GRASS, r.randf_range(0.2, 0.8)))
	# the graves, back row first (drawn top to bottom)
	var shown := mini(graves, COLS * ROWS)
	var cell := Vector2(HALF.x * 2.0 / COLS, (HALF.y * 2.0 - 14.0) / ROWS)
	for i in shown:
		var col := i % COLS
		var row := i / COLS
		var base := Vector2(-HALF.x + cell.x * (col + 0.5) + r.randf_range(-3, 3),
			-HALF.y + 18.0 + cell.y * row + r.randf_range(-2, 2))
		var fresh := i >= shown - _fresh
		_grave(base, r, fresh)
	# the low wall, lit on top; a lychgate in the south wall
	var gate := 16.0
	_wall(Vector2(-HALF.x, -HALF.y), Vector2(HALF.x, -HALF.y))
	_wall(Vector2(-HALF.x, -HALF.y), Vector2(-HALF.x, HALF.y))
	_wall(Vector2(HALF.x, -HALF.y), Vector2(HALF.x, HALF.y))
	_wall(Vector2(-HALF.x, HALF.y), Vector2(-gate, HALF.y))
	_wall(Vector2(gate, HALF.y), Vector2(HALF.x, HALF.y))
	for x: float in [-gate, gate]:
		draw_rect(Rect2(x - 3.0, HALF.y - 22.0, 6.0, 24.0), WOOD)
	draw_colored_polygon(PackedVector2Array([Vector2(-gate - 8, HALF.y - 20), Vector2(0, HALF.y - 32),
		Vector2(gate + 8, HALF.y - 20)]), WALL_DARK)
	draw_line(Vector2(-gate - 8, HALF.y - 20), Vector2(0, HALF.y - 32), WALL_LIT, 1.5)
	# a dead yew in the corner
	var t := Vector2(HALF.x - 18.0, -HALF.y + 10.0)
	draw_line(t, t + Vector2(-2, -34), WOOD, 4.0)
	draw_line(t + Vector2(-1, -20), t + Vector2(-14, -32), WOOD, 2.0)
	draw_line(t + Vector2(-2, -28), t + Vector2(9, -42), WOOD, 2.0)
	draw_line(t + Vector2(-14, -32), t + Vector2(-20, -36), WOOD, 1.2)

func _wall(a: Vector2, b: Vector2) -> void:
	draw_line(a + Vector2(0, 2), b + Vector2(0, 2), WALL_DARK, 6.0)
	draw_line(a, b, WALL, 5.0)
	draw_line(a + Vector2(0, -2), b + Vector2(0, -2), WALL_LIT, 1.5)

func _grave(base: Vector2, r: RandomNumberGenerator, fresh: bool) -> void:
	# the mound in front of the stone
	draw_set_transform(base + Vector2(0, 7), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 8.0, MOUND if fresh else EARTH.lerp(GRASS, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var lean := r.randf_range(-0.12, 0.12)
	draw_set_transform(base, lean, Vector2.ONE)
	if r.randf() < 0.3:
		# a cross
		draw_rect(Rect2(-1.5, -16, 3, 16), STONE)
		draw_rect(Rect2(-6, -12, 12, 3), STONE)
		draw_rect(Rect2(0.5, -16, 1, 16), STONE_DARK)
	else:
		# a round-topped headstone
		var w := r.randf_range(8.0, 11.0)
		var h := r.randf_range(10.0, 14.0)
		draw_rect(Rect2(-w / 2, -h, w, h), STONE)
		draw_circle(Vector2(0, -h), w / 2, STONE)
		draw_rect(Rect2(w / 2 - 2, -h, 2, h), STONE_DARK)
		draw_line(Vector2(-w / 4, -h + 2), Vector2(w / 4, -h + 2), STONE_DARK, 1.0)
		draw_line(Vector2(-w / 4, -h + 5), Vector2(w / 5, -h + 5), STONE_DARK, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
