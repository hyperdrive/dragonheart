extends StaticBody2D

## Per-lake variety (2026-11-13 user: "lakes should be more complex
## shapes"): every lake shares one irregular blob artwork, so each spawn
## rotates and optionally mirrors it. The collision stays a CIRCLE, which
## makes rotation free — merge math, footprint clearances and steering
## all treat the lake as round regardless of how the art sits.
func _ready() -> void:
	var spr := get_node_or_null("Sprite") as Sprite2D
	if spr == null:
		return
	spr.rotation = randf_range(0.0, TAU)
	if randf() < 0.5:
		spr.flip_h = true
