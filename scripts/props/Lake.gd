extends StaticBody2D

## Per-lake variety (2026-11-13 user: "lakes should be more complex
## shapes"): every lake shares one irregular blob artwork, so each spawn
## rotates and optionally mirrors it. The collision stays a CIRCLE, which
## makes rotation free — merge math, footprint clearances and steering
## all treat the lake as round regardless of how the art sits.
## Three lake looks (2026-11-14 user: "add two variations for the lake"):
## the enchanted lake, a crystal tarn, and a witch-bog. All share the r=62
## footprint so the collision circle and lake merging stay unchanged.
const ART: Array[Texture2D] = [
	preload("res://assets/sprites/lake.svg"),
	preload("res://assets/sprites/lake_tarn.svg"),
	preload("res://assets/sprites/lake_bog.svg"),
]

func _ready() -> void:
	var spr := get_node_or_null("Sprite") as Sprite2D
	if spr == null:
		return
	spr.texture = ART[randi() % ART.size()]
	spr.rotation = randf_range(0.0, TAU)
	if randf() < 0.5:
		spr.flip_h = true
