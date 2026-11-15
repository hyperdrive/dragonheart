extends Node2D

## The living ground (2026-11-15, user: "default 'meadow with hills'.
## However each prop and building should have an influence that blends the
## environment into a suitable environment. I.e. mountains cause rocky
## ground. Fields cause flat grassland etc."). One quad under the whole
## world, painted by assets/shaders/ground.gdshader: rolling meadow hills
## everywhere, blended toward each prop's own ground through two splat maps
## (one texel per TEXEL px) that this script paints from the props'
## positions and reach:
##
##   prop                     ground it spreads
##   mountain, goblin mount   rock (reach ~2x its base)
##   the dragon's lair        rock, ash at its mouth
##   mine                     rock + trodden dirt
##   temple of the queen      rock (ruins)
##   field                    farmland (flat, mown grass)
##   city                     trodden dirt, farmland around it
##   pig/cow pen              dirt (mud), farmland around it
##   wizard tower             a dirt yard, stony ground
##   tree / fir               forest floor
##   lake                     a ring of sand, lush grass beyond
##   bog lake, hag's fen      marsh
##   glade                    lush meadow, thick with flowers
##   invader camp             trodden dirt
##   sacrifice pole           trampled dirt
##
## WorldManager calls refresh() after generation and whenever a landmark
## rises (the fen, the glade, the temple, the camp). No class_name on
## purpose (editor rescan caveat): WorldManager preloads this script.

const SHADER := preload("res://assets/shaders/ground.gdshader")
const TEXEL := 16.0
## How far past the boundary walls the ground keeps going (the camera can
## look past the edge).
const PAD := 800.0

enum Ch { ROCK, FARM, MARSH, DIRT, FOREST, LUSH, SAND, ASH }

var world_size := Vector2(1920, 1920)
var _rect: ColorRect
var _mat: ShaderMaterial
var _w := 0
var _h := 0
var _origin := Vector2.ZERO
var _layers: Array[PackedFloat32Array] = []
var _queued := false

func _ready() -> void:
	z_index = -100
	z_as_relative = false
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("seed", randf() * 10.0)
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_resize()

func _resize() -> void:
	var half := world_size * 0.5 + Vector2(PAD, PAD)
	_origin = -half
	_rect.position = -half
	_rect.size = half * 2.0
	_w = int(ceil(_rect.size.x / TEXEL))
	_h = int(ceil(_rect.size.y / TEXEL))
	_mat.set_shader_parameter("origin", _rect.position)
	_mat.set_shader_parameter("extent", _rect.size)
	_mat.set_shader_parameter("world_half", world_size * 0.5)

## Re-read every prop next frame (coalesced: several spawns in one frame
## repaint once, after queued frees have gone).
func refresh() -> void:
	if _queued:
		return
	_queued = true
	_repaint.call_deferred()

func _repaint() -> void:
	_queued = false
	if not is_inside_tree():
		return
	_layers.clear()
	for i in 8:
		var layer := PackedFloat32Array()
		layer.resize(_w * _h)
		_layers.append(layer)
	var wm := get_parent()
	if wm == null:
		return
	for child: Node in wm.get_children():
		var n := child as Node2D
		if n != null and n != self and n.is_inside_tree() and not n.is_queued_for_deletion():
			_paint_prop(n)
	_upload()

func _paint_prop(n: Node2D) -> void:
	var p := n.global_position
	var path := n.scene_file_path
	match path:
		"res://scenes/props/Mountain.tscn":
			var r := float(n.call("footprint_radius")) if n.has_method("footprint_radius") else 80.0
			_paint(Ch.ROCK, p, r * 0.8, r * 2.0)
		"res://scenes/props/DragonLair.tscn":
			_paint(Ch.ROCK, p, 90.0, 220.0)
			_paint(Ch.ASH, p + Vector2(0, 30), 40.0, 130.0, 0.85)
		"res://scenes/objects/Mine.tscn":
			_paint(Ch.ROCK, p, 40.0, 125.0)
			_paint(Ch.DIRT, p + Vector2(0, 20), 25.0, 75.0, 0.9)
		"res://scenes/props/DragonTemple.tscn":
			_paint(Ch.ROCK, p, 70.0, 175.0, 0.9)
		"res://scenes/systems/Field.tscn":
			_paint(Ch.FARM, p, 75.0, 165.0)
		"res://scenes/props/City.tscn":
			_paint(Ch.DIRT, p, 120.0, 215.0)
			_paint(Ch.FARM, p, 170.0, 340.0)
		"res://scenes/props/PigPen.tscn", "res://scenes/props/CowPen.tscn":
			_paint(Ch.DIRT, p, 45.0, 105.0)
			_paint(Ch.FARM, p, 90.0, 180.0)
		"res://scenes/objects/WizardTower.tscn":
			_paint(Ch.DIRT, p + Vector2(0, 10), 35.0, 95.0, 0.85)
			_paint(Ch.ROCK, p, 40.0, 130.0, 0.55)
		"res://scenes/props/Tree.tscn":
			_paint(Ch.FOREST, p, 22.0, 80.0, 0.85)
		"res://scenes/props/FirTree.tscn":
			_paint(Ch.FOREST, p, 16.0, 62.0, 0.85)
		"res://scenes/props/Lake.tscn":
			var lr := _lake_radius(n)
			if _is_bog(n):
				_paint(Ch.MARSH, p, lr, lr + 115.0)
			else:
				_paint(Ch.SAND, p, lr * 0.85, lr + 24.0)
				_paint(Ch.LUSH, p, lr, lr + 90.0, 0.85)
		"res://scenes/props/HagNest.tscn":
			_paint(Ch.MARSH, p, 130.0, 310.0)
		"res://scenes/props/Glade.tscn":
			_paint(Ch.LUSH, p, 150.0, 270.0)
		"res://scenes/props/InvaderCamp.tscn":
			_paint(Ch.DIRT, p, 150.0, 265.0)
		"res://scenes/props/Sacrifice.tscn":
			_paint(Ch.DIRT, p, 20.0, 65.0, 0.8)

func _lake_radius(n: Node2D) -> float:
	var col := n.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null and col.shape is CircleShape2D:
		return (col.shape as CircleShape2D).radius * absf(col.global_scale.x)
	return 62.0

func _is_bog(n: Node2D) -> bool:
	var spr := n.get_node_or_null("Sprite") as Sprite2D
	return spr != null and spr.texture != null \
		and spr.texture.resource_path.ends_with("lake_bog.svg")

## Full strength inside `inner`, fading to nothing at `outer`; the
## strongest influence wins where props overlap.
func _paint(ch: int, at: Vector2, inner: float, outer: float, strength := 1.0) -> void:
	# Long, soft gradients (2026-11-15, "must blend better"): the fade
	# starts a little earlier and reaches further than the prop's own edge.
	inner *= 0.8
	outer *= 1.3
	var layer := _layers[ch]
	var c := (at - _origin) / TEXEL
	var reach := outer / TEXEL
	var x0 := maxi(int(c.x - reach), 0)
	var x1 := mini(int(c.x + reach) + 1, _w - 1)
	var y0 := maxi(int(c.y - reach), 0)
	var y1 := mini(int(c.y + reach) + 1, _h - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(float(x) + 0.5 - c.x, float(y) + 0.5 - c.y).length() * TEXEL
			if d >= outer:
				continue
			var v := strength * (1.0 - smoothstep(inner, outer, d))
			var i := y * _w + x
			if v > layer[i]:
				layer[i] = v

func _upload() -> void:
	for pair in [[0, "splat_a"], [4, "splat_b"]]:
		var base: int = pair[0]
		var bytes := PackedByteArray()
		bytes.resize(_w * _h * 4)
		for i in _w * _h:
			for k in 4:
				bytes[i * 4 + k] = int(clampf(_layers[base + k][i], 0.0, 1.0) * 255.0)
		var img := Image.create_from_data(_w, _h, false, Image.FORMAT_RGBA8, bytes)
		_mat.set_shader_parameter(pair[1], ImageTexture.create_from_image(img))
