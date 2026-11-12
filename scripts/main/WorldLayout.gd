extends Resource

class_name WorldLayout

## A hand-authored world: key-element positions placed in the world editor,
## plus grayscale MASKS that constrain where the randomized elements (fields,
## mines, two tree densities, lakes) may land. The game consumes one layout
## via WorldSession; with none selected WorldManager falls back to its
## full-procedural generation (decision record 2026-11-12-world-editor).
##
## File layout per world (editor-written, game read-only):
##   res://worlds/<name>/layout.tres   — this resource
##   res://worlds/<name>/masks/*.png   — one grayscale PNG per category
##
## Mask coordinates: images cover the world rect (-world_size/2 … +world_size/2)
## at MASK_SCALE (0.5 → half resolution). Brightness >= BRIGHT_THRESHOLD is
## placeable; brightness is the rejection-sampling weight.

const MASK_SCALE := 0.5
const BRIGHT_THRESHOLD := 0.5

## Category → mask file name (and editor tint). Two forest densities
## (user spec) — "forest" is split into dense and sparse masks.
const MASK_CATEGORIES := {
	"fields": Color(0.2, 0.85, 0.3),
	"mines": Color(0.9, 0.75, 0.2),
	"forest_dense": Color(0.1, 0.5, 0.15),
	"forest_sparse": Color(0.4, 0.8, 0.4),
	"lakes": Color(0.25, 0.5, 0.95),
}

@export_group("World")
@export var world_size: Vector2 = Vector2(1920, 1920)
## Placement seed (editor Re-roll): same layout + same seed = identical world,
## so probes can verify a saved world (decision record).
@export var seed_value: int = 0

@export_group("Key elements")
@export var city_position: Vector2 = Vector2(0, 620)
@export var lair_position: Vector2 = Vector2(-620, 60)
@export var goblin_mountain_position: Vector2 = Vector2(-680, 250)
@export var tower_position: Vector2 = Vector2(520, -420)   # wizard tower
@export var pig_pen_position: Vector2 = Vector2(-260, 760)
@export var cow_pen_position: Vector2 = Vector2(260, 820)
@export var mine_center: Vector2 = Vector2(-480, -420)

@export_group("Counts (0 = keep WorldManager's export)")
@export var tree_dense_count: int = 7
@export var tree_sparse_count: int = 7
@export var lake_count: int = 3
@export var mountain_count: int = 5
@export var field_count: int = 6
@export var mine_count: int = 8

@export_group("Masks")
@export var fields_mask: Texture2D
@export var mines_mask: Texture2D
@export var forest_dense_mask: Texture2D
@export var forest_sparse_mask: Texture2D
@export var lakes_mask: Texture2D


static func world_dir(world_name: String) -> String:
	return "res://worlds/%s" % world_name


## Save this layout: one PNG per mask beside the .tres, texture refs re-pointed
## at the saved files so the .tres carries paths, not embedded pixels.
func save_to_world(world_name: String) -> Error:
	var dir := world_dir(world_name)
	var masks_dir := dir + "/masks"
	var err := DirAccess.make_dir_recursive_absolute(masks_dir)
	if err != OK:
		push_error("WorldLayout: cannot create %s (%d)" % [masks_dir, err])
		return err
	for category: String in MASK_CATEGORIES:
		var img := get_mask_image(category)
		var png_path := masks_dir + "/%s.png" % category
		if img.save_png(png_path) != OK:
			push_error("WorldLayout: mask save failed: %s" % png_path)
			return FAILED
		# Re-link the PNG only when it is importable (needs one --import
		# pass after a fresh save). Without it the texture stays embedded
		# in the .tres — heavier, but always loadable.
		var tex: Texture2D = load(png_path)
		if tex != null:
			set_mask_texture(category, tex)
	return ResourceSaver.save(self, dir + "/layout.tres")


## Load a saved world, or null when it does not exist.
static func load_from_world(world_name: String) -> WorldLayout:
	var path := world_dir(world_name) + "/layout.tres"
	if not ResourceLoader.exists(path):
		return null
	var layout: WorldLayout = load(path)
	return layout


## The blank half-resolution L8 mask for a category (editor canvas state).
func blank_mask_image(category: String) -> Image:
	var size := Vector2i((world_size * MASK_SCALE).round())
	var img := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	img.fill(0)
	return img


## Read access for sampling — decodes the current texture into an Image.
func get_mask_image(category: String) -> Image:
	var tex := get_mask_texture(category)
	if tex == null:
		return blank_mask_image(category)
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	return img


func get_mask_texture(category: String) -> Texture2D:
	match category:
		"fields": return fields_mask
		"mines": return mines_mask
		"forest_dense": return forest_dense_mask
		"forest_sparse": return forest_sparse_mask
		"lakes": return lakes_mask
	push_warning("WorldLayout: unknown mask category '%s'" % category)
	return null


func set_mask_texture(category: String, tex: Texture2D) -> void:
	match category:
		"fields": fields_mask = tex
		"mines": mines_mask = tex
		"forest_dense": forest_dense_mask = tex
		"forest_sparse": forest_sparse_mask = tex
		"lakes": lakes_mask = tex
		_:
			push_warning("WorldLayout: unknown mask category '%s'" % category)


# --- mask <-> world coordinate mapping ----------------------------------------

## World-space position → mask pixel (integer), clamped into the image.
func world_to_mask(pos: Vector2) -> Vector2i:
	var half := world_size * 0.5
	var px := ((pos + half) * MASK_SCALE).floor()
	var size := Vector2i((world_size * MASK_SCALE).round())
	return Vector2i(clampi(int(px.x), 0, size.x - 1),
		clampi(int(px.y), 0, size.y - 1))


## Mask pixel → world-space position (pixel center).
func mask_to_world(px: Vector2i) -> Vector2:
	var half := world_size * 0.5
	return (Vector2(px) + Vector2(0.5, 0.5)) / MASK_SCALE - half


## Mask brightness at a world position (0 = off-mask, 1 = full weight).
func sample_mask(category: String, pos: Vector2) -> float:
	var img := get_mask_image(category)
	return img.get_pixelv(world_to_mask(pos)).r
