extends StaticBody2D

class_name Mountain

## Mountain variety (2026-11-13 user: "add a variation to the mountain so we
## pick from three different in three different sizes"). Each spawn picks
## one of three artworks and one of three sizes.
##
## BLOCKING (user: "a blocking collision ... prevented any walking actor to
## cross lakes or walk right through mountains"): the collider is a convex
## FOOTPRINT hugging the visible base of the art — walkers can pass BEHIND
## the peak (y-sort hides them) but never across the base. The old fixed
## circle (r=54) was narrower than the art and sat in front of it after the
## sprite was raised, so actors clipped straight through the slopes.

const ART: Array[Texture2D] = [
	preload("res://assets/sprites/mountain.svg"),    # crag, twin peak
	preload("res://assets/sprites/mountain_b.svg"),  # broad massif + falls
	preload("res://assets/sprites/mountain_c.svg"),  # tall needle spires
]
## Half-width of each artwork's base, in SVG units (canvas 128, center 64).
const BASE_HALF_SVG: Array[float] = [60.0, 63.0, 44.0]
## Small / medium / large.
const SIZES: Array[float] = [0.7, 1.0, 1.35]
## World px per SVG unit at size 1.0 (the art imports at 2x, sprite 0.75).
const SVG_TO_WORLD := 1.5
## The art's base line sits at SVG y=120 on a 128 canvas: 56 units below
## the sprite center → raise the sprite so the base lands on the origin.
const BASE_BELOW_CENTER_SVG := 56.0

## -1 = roll at random (WorldManager rolls with its seeded RNG first).
@export_range(-1, 2) var variant: int = -1
@export_range(-1, 2) var size_index: int = -1

## Pick variant/size (unless preset). Returns the placement footprint
## radius so the spawner can clear space for THIS mountain's real size.
func roll(rng: RandomNumberGenerator = null) -> float:
	if variant < 0:
		variant = rng.randi_range(0, 2) if rng != null else randi_range(0, 2)
	if size_index < 0:
		size_index = rng.randi_range(0, 2) if rng != null else randi_range(0, 2)
	return footprint_radius()

## Visual half-width of the base (world px) — used for placement spacing.
func footprint_radius() -> float:
	return BASE_HALF_SVG[maxi(variant, 0)] * SVG_TO_WORLD * SIZES[maxi(size_index, 0)]

func _ready() -> void:
	if variant < 0 or size_index < 0:
		roll()
	var s: float = SIZES[size_index]
	var spr := $Sprite as Sprite2D
	spr.texture = ART[variant]
	spr.scale = Vector2.ONE * 0.75 * s
	spr.position = Vector2(0.0, -BASE_BELOW_CENTER_SVG * SVG_TO_WORLD * s)
	if randf() < 0.5:
		spr.flip_h = true
	_build_base_blocker(s)

## Convex half-ellipse-ish footprint: wide along the base line, shallow in
## depth, reaching slightly in front of the base (feet stop at the rock).
func _build_base_blocker(s: float) -> void:
	var half_w: float = BASE_HALF_SVG[variant] * SVG_TO_WORLD * s * 0.9
	var back: float = 30.0 * s   # how far "into" the mountain the band reaches
	var front: float = 6.0       # just in front of the visible base
	var pts := PackedVector2Array()
	var n := 14
	for i in n:
		var a := PI + TAU * float(i) / float(n)
		var x := cos(a) * half_w
		var y := sin(a)
		pts.append(Vector2(x, y * back if y < 0.0 else y * front))
	var poly := ConvexPolygonShape2D.new()
	poly.points = pts
	var col := $CollisionShape2D as CollisionShape2D
	col.shape = poly
	col.position = Vector2.ZERO
