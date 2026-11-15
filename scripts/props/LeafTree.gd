extends StaticBody2D

## Leaf-tree variety (2026-11-15, user: "we need to work on the leaf trees.
## Make a few variations, and stem needs to be more brownish"): four looks
## share the old tree's 64x64 frame and footprint — a broad oak, a tall elm,
## an old gnarled tree, an autumn-touched rowan — all with brown, tapered
## trunks. Each spawn picks one, mirrors it half the time and varies its size
## a little; the collision box stays the scene's.
##
## No class_name on purpose (editor rescan caveat).

const ART: Array[Texture2D] = [
	preload("res://assets/sprites/tree_oak.svg"),
	preload("res://assets/sprites/tree_elm.svg"),
	preload("res://assets/sprites/tree_old.svg"),
	preload("res://assets/sprites/tree_rowan.svg"),
]
const WEIGHTS: Array[float] = [0.35, 0.3, 0.15, 0.2]

func _ready() -> void:
	var spr := get_node_or_null("Sprite") as Sprite2D
	if spr == null:
		return
	var roll := randf()
	var pick := 0
	for i in WEIGHTS.size():
		roll -= WEIGHTS[i]
		if roll <= 0.0:
			pick = i
			break
	spr.texture = ART[pick]
	var s := randf_range(0.9, 1.12)
	spr.scale = Vector2(0.7, 0.7) * s   # art imported at 2x
	# keep the trunk's foot on the same ground line whatever the size
	spr.position.y = -27.0 * s
	spr.flip_h = randf() < 0.5
	# a soft round shadow under the crown, not the old flat grey slab
	var old := get_node_or_null("TrunkShadow") as CanvasItem
	if old != null:
		old.visible = false
	var shade := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 20:
		var a := TAU * float(k) / 20.0
		pts.append(Vector2(cos(a) * 17.0 * s, sin(a) * 5.0 * s + 2.0))
	shade.polygon = pts
	shade.color = Color(0.05, 0.04, 0.03, 0.32)
	shade.z_index = -1
	shade.z_as_relative = true
	add_child(shade)
	move_child(shade, 0)
