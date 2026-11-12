extends Node2D

## WorldEditor — the runtime world editor (decision record
## 2026-11-12-world-editor). Run it directly:
##   Godot --path . res://scenes/editor/WorldEditor.tscn
##
## Place the key elements (city, dragon lair, goblin mountain, wizard tower,
## animal pens, mine district) with a left-click; PAINT the category masks
## (fields, mines, forest dense, forest sparse, lakes) with brush drags — the
## game then randomizes exact placement INSIDE the painted areas. Save writes
## res://worlds/<name>/ (mask PNGs + layout.tres); Play boots the game on that
## world. Eraser clears mask paint; right-click in place mode removes a mark.
##
## Wheel = zoom, right/middle-drag = pan. Masks paint at half world
## resolution (WorldLayout.MASK_SCALE); brightness doubles as the game's
## rejection-sampling weight, so soft brush edges place more rarely.

const KEY_ELEMENTS := {
	"city": {"label": "City", "radius": 120.0, "color": Color(0.55, 0.6, 0.7)},
	"lair": {"label": "Dragon Lair", "radius": 100.0, "color": Color(0.9, 0.3, 0.25)},
	"goblin_mountain": {"label": "Goblin Mtn", "radius": 80.0, "color": Color(0.6, 0.3, 0.75)},
	"tower": {"label": "Wizard Tower", "radius": 75.0, "color": Color(0.3, 0.8, 0.85)},
	"pig_pen": {"label": "Pig Pen", "radius": 85.0, "color": Color(0.95, 0.6, 0.75)},
	"cow_pen": {"label": "Cow Pen", "radius": 85.0, "color": Color(0.85, 0.55, 0.3)},
	"mine_center": {"label": "Mine District", "radius": 60.0, "color": Color(0.55, 0.45, 0.3)},
}

var world_size: Vector2 = Vector2(1920, 1920)
var key_positions: Dictionary = {}
var mask_images: Dictionary = {}       # category → Image (L8, half res)
var mask_textures: Dictionary = {}     # category → ImageTexture (overlays)
var current_place: String = "city"
var current_brush: String = ""         # "" = not painting
var brush_size: float = 60.0
var world_name := "custom_world"
var seed_value: int = 1

var _painting := false
var _erasing := false
var _panning := false
var _pan_last := Vector2.ZERO
var _dirty_masks: Dictionary = {}      # category → true (texture update pending)
var _tex_flush_timer := 0.0

var _camera: Camera2D
var _status: Label
var _name_edit: LineEdit
var _seed_box: SpinBox

func _ready() -> void:
	_seed_value_reroll()
	_build_canvas()
	_build_ui()
	_set_status("Left-click places the selected element · drag paints the "
		+ "selected mask · wheel zooms · right-drag pans")

func _seed_value_reroll() -> void:
	seed_value = randi() % 999999 + 1

func _build_canvas() -> void:
	_camera = Camera2D.new()
	_camera.position = Vector2.ZERO
	var viewport_size := Vector2(get_viewport_rect().size)
	var fit_zoom: float = minf(viewport_size.x / world_size.x,
		viewport_size.y / world_size.y) * 0.95
	_camera.zoom = Vector2(fit_zoom, fit_zoom)
	add_child(_camera)
	_camera.make_current()
	for category: String in WorldLayout.MASK_CATEGORIES:
		var img := Image.create(
			int(world_size.x * WorldLayout.MASK_SCALE),
			int(world_size.y * WorldLayout.MASK_SCALE),
			false, Image.FORMAT_L8)
		img.fill(0)
		mask_images[category] = img
		var tex := ImageTexture.create_from_image(img)
		mask_textures[category] = tex
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = true
		sprite.scale = Vector2.ONE / WorldLayout.MASK_SCALE
		sprite.modulate = Color(WorldLayout.MASK_CATEGORIES[category], 0.35)
		add_child(sprite)
	queue_redraw()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8
	top.offset_right = -8
	top.offset_top = 4
	top.add_theme_constant_override("separation", 6)
	layer.add_child(top)
	var place_group := ButtonGroup.new()
	var brush_group := ButtonGroup.new()
	for key: String in KEY_ELEMENTS:
		var btn := Button.new()
		btn.text = KEY_ELEMENTS[key]["label"]
		btn.toggle_mode = true
		btn.button_group = place_group
		btn.button_pressed = key == current_place
		btn.pressed.connect(func() -> void:
			current_place = key
			current_brush = ""
			queue_redraw())
		top.add_child(btn)
	var sep := VSeparator.new()
	top.add_child(sep)
	for category: String in WorldLayout.MASK_CATEGORIES:
		var btn := Button.new()
		btn.text = category.replace("_", " ")
		btn.toggle_mode = true
		btn.button_group = brush_group
		btn.pressed.connect(func() -> void:
			current_brush = category
			queue_redraw())
		top.add_child(btn)
	var eraser := Button.new()
	eraser.text = "Eraser"
	eraser.toggle_mode = true
	eraser.button_group = brush_group
	eraser.pressed.connect(func() -> void:
		current_brush = "eraser"
		queue_redraw())
	top.add_child(eraser)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 8
	bottom.offset_right = -8
	bottom.offset_bottom = -4
	bottom.add_theme_constant_override("separation", 6)
	layer.add_child(bottom)
	var size_label := Label.new()
	size_label.text = "Brush"
	bottom.add_child(size_label)
	var size_slider := HSlider.new()
	size_slider.min_value = 20.0
	size_slider.max_value = 200.0
	size_slider.step = 5.0
	size_slider.value = brush_size
	size_slider.custom_minimum_size = Vector2(120, 20)
	size_slider.value_changed.connect(func(v: float) -> void: brush_size = v)
	bottom.add_child(size_slider)
	var name_label := Label.new()
	name_label.text = "World"
	bottom.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.text = world_name
	_name_edit.custom_minimum_size = Vector2(140, 0)
	_name_edit.text_changed.connect(func(t: String) -> void: world_name = t)
	bottom.add_child(_name_edit)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	bottom.add_child(seed_label)
	_seed_box = SpinBox.new()
	_seed_box.min_value = 1
	_seed_box.max_value = 999999
	_seed_box.value = seed_value
	_seed_box.value_changed.connect(func(v: float) -> void: seed_value = int(v))
	bottom.add_child(_seed_box)
	var reroll := Button.new()
	reroll.text = "Re-roll"
	reroll.pressed.connect(func() -> void:
		_seed_value_reroll()
		_seed_box.value = seed_value
		_set_status("New placement seed: %d" % seed_value))
	bottom.add_child(reroll)
	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_on_load_pressed)
	bottom.add_child(load_btn)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_pressed)
	bottom.add_child(save_btn)
	var play := Button.new()
	play.text = "▶ Play"
	play.pressed.connect(_on_play_pressed)
	bottom.add_child(play)
	var clear := Button.new()
	clear.text = "Clear"
	clear.pressed.connect(_on_clear_pressed)
	bottom.add_child(clear)
	_status = Label.new()
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_status.offset_top = 40
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.modulate = Color(1, 1, 0.6)
	layer.add_child(_status)

func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text

# --- input --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var world := get_global_mouse_position()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(1.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(1.0 / 1.1)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or \
				mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			_pan_last = mb.position
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if current_brush == "eraser":
				_painting = true
				_erasing = true
			elif current_brush != "":
				_painting = true
				_stamp_at(world)
			elif current_place != "":
				if _world_inside(world):
					key_positions[current_place] = world
					queue_redraw()
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		_flush_mask_textures()
		_painting = false
		_erasing = false
	if event is InputEventMouseMotion and _panning:
		var mm := event as InputEventMouseMotion
		var delta := (mm.position - _pan_last) / _camera.zoom.x
		_camera.position -= delta
		_pan_last = mm.position

func _apply_zoom(factor: float) -> void:
	var z: float = clampf(_camera.zoom.x * factor, 0.25, 2.0)
	_camera.zoom = Vector2(z, z)

func _world_inside(pos: Vector2) -> bool:
	var half := world_size * 0.5
	return absf(pos.x) <= half.x and absf(pos.y) <= half.y

func _process(delta: float) -> void:
	if _painting:
		_stamp_at(get_global_mouse_position())
	if not _dirty_masks.is_empty():
		_tex_flush_timer += delta
		if _tex_flush_timer >= 0.12:
			_flush_mask_textures()
	queue_redraw()

# --- mask painting --------------------------------------------------------------

func _stamp_at(world_pos: Vector2) -> void:
	if not _world_inside(world_pos):
		return
	var half := world_size * 0.5
	var mask_size := Vector2(world_size * WorldLayout.MASK_SCALE)
	var brush_px := brush_size * WorldLayout.MASK_SCALE
	var center := (world_pos + half) * WorldLayout.MASK_SCALE
	var categories: Array = []
	if _erasing:
		categories = WorldLayout.MASK_CATEGORIES.keys()
	else:
		categories = [current_brush]
	for category: String in categories:
		var img: Image = mask_images[category]
		var from := Vector2(maxf(center.x - brush_px, 0.0),
			maxf(center.y - brush_px, 0.0)).floor()
		var to := Vector2(minf(center.x + brush_px, mask_size.x),
			minf(center.y + brush_px, mask_size.y)).ceil()
		for y in range(int(from.y), int(to.y)):
			for x in range(int(from.x), int(to.x)):
				var dist := Vector2(x + 0.5, y + 0.5).distance_to(center)
				if dist > brush_px:
					continue
				var v := 1.0 - dist / brush_px  # soft edge = sampling weight
				var old := img.get_pixel(x, y).r
				if _erasing:
					if old > 0.0:
						img.set_pixel(x, y, Color(0, 0, 0))
				elif v > old:
					img.set_pixel(x, y, Color(v, v, v))
		_dirty_masks[category] = true

func _flush_mask_textures() -> void:
	for category: String in _dirty_masks:
		var tex: ImageTexture = mask_textures[category]
		tex.update(mask_images[category])
	_dirty_masks.clear()
	_tex_flush_timer = 0.0

# --- save / load / play ---------------------------------------------------------

func _build_layout() -> WorldLayout:
	var layout := WorldLayout.new()
	layout.world_size = world_size
	layout.seed_value = seed_value
	for key: String in KEY_ELEMENTS:
		var pos: Vector2 = key_positions.get(key, Vector2.INF)
		if pos == Vector2.INF:
			continue
		match key:
			"city": layout.city_position = pos
			"lair": layout.lair_position = pos
			"goblin_mountain": layout.goblin_mountain_position = pos
			"tower": layout.tower_position = pos
			"pig_pen": layout.pig_pen_position = pos
			"cow_pen": layout.cow_pen_position = pos
			"mine_center": layout.mine_center = pos
	for category: String in WorldLayout.MASK_CATEGORIES:
		layout.set_mask_texture(category, mask_textures[category])
	return layout

func _validate() -> String:
	var problems := ""
	var half := world_size * 0.5
	for key: String in KEY_ELEMENTS:
		var pos: Vector2 = key_positions.get(key, Vector2.INF)
		if pos == Vector2.INF:
			problems += "%s uses the default spot; " % KEY_ELEMENTS[key]["label"]
			continue
		var px := ((pos + half) * WorldLayout.MASK_SCALE).floor()
		var mask_size := Vector2i((world_size * WorldLayout.MASK_SCALE).round())
		px = Vector2(clampf(px.x, 0, mask_size.x - 1), clampf(px.y, 0, mask_size.y - 1))
		if mask_images["lakes"].get_pixel(int(px.x), int(px.y)).r \
				>= WorldLayout.BRIGHT_THRESHOLD:
			problems += "%s sits inside a painted lake; " \
				% KEY_ELEMENTS[key]["label"]
	return problems

func _on_save_pressed() -> void:
	var problems := _validate()
	var layout := _build_layout()
	var err := layout.save_to_world(world_name)
	if err != OK:
		_set_status("SAVE FAILED (%s): %s" % [world_name, error_string(err)])
	else:
		_set_status("Saved '%s' (seed %d). %s"
			% [world_name, seed_value,
				"Note: " + problems if problems != "" else ""])

func _on_load_pressed() -> void:
	var layout := WorldLayout.load_from_world(world_name)
	if layout == null:
		_set_status("No saved world named '%s'" % world_name)
		return
	world_size = layout.world_size
	seed_value = layout.seed_value
	_seed_box.value = seed_value
	for key: String in KEY_ELEMENTS:
		match key:
			"city": key_positions[key] = layout.city_position
			"lair": key_positions[key] = layout.lair_position
			"goblin_mountain": key_positions[key] = layout.goblin_mountain_position
			"tower": key_positions[key] = layout.tower_position
			"pig_pen": key_positions[key] = layout.pig_pen_position
			"cow_pen": key_positions[key] = layout.cow_pen_position
			"mine_center": key_positions[key] = layout.mine_center
	for category: String in WorldLayout.MASK_CATEGORIES:
		var img := layout.get_mask_image(category)
		if img.get_size() == mask_images[category].get_size():
			mask_images[category].blit_rect(img, Rect2i(Vector2i.ZERO,
				img.get_size()), Vector2i.ZERO)
		else:
			# world size changed on disk — rebuild image AND overlay texture
			mask_images[category] = img
			var tex := ImageTexture.create_from_image(img)
			mask_textures[category] = tex
		_dirty_masks[category] = true
	_flush_mask_textures()
	queue_redraw()
	_set_status("Loaded '%s' (seed %d)" % [world_name, seed_value])

func _on_play_pressed() -> void:
	var problems := _validate()
	if problems != "":
		_set_status("Played with notes: " + problems)
	var layout := _build_layout()
	var err := layout.save_to_world(world_name)
	if err != OK:
		_set_status("Cannot play: save failed (%s)" % error_string(err))
		return
	WorldSession.pending_world = world_name
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")

func _on_clear_pressed() -> void:
	key_positions.clear()
	for category: String in WorldLayout.MASK_CATEGORIES:
		mask_images[category].fill(0)
		_dirty_masks[category] = true
	_flush_mask_textures()
	queue_redraw()
	_set_status("Canvas cleared")

# --- drawing ------------------------------------------------------------------

func _draw() -> void:
	var half := world_size * 0.5
	var ground := Rect2(-half, world_size)
	draw_rect(ground, Color(0.33, 0.5, 0.25))
	# grid
	var grid_color := Color(0, 0, 0, 0.12)
	var step := 120.0
	var x := -half.x
	while x <= half.x:
		draw_line(Vector2(x, -half.y), Vector2(x, half.y), grid_color)
		x += step
	var y := -half.y
	while y <= half.y:
		draw_line(Vector2(-half.x, y), Vector2(half.x, y), grid_color)
		y += step
	draw_rect(ground, Color(0.1, 0.1, 0.1), false, 4.0)
	# placed key elements
	var font := ThemeDB.fallback_font
	for key: String in KEY_ELEMENTS:
		var pos: Vector2 = key_positions.get(key, Vector2.INF)
		if pos == Vector2.INF:
			continue
		var info: Dictionary = KEY_ELEMENTS[key]
		var color: Color = info["color"]
		draw_circle(pos, 14.0, color)
		draw_arc(pos, float(info["radius"]), 0, TAU, 48,
			Color(color, 0.5), 2.0)
		draw_string(font, pos + Vector2(-34, -20), info["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.9))
	# ghost
	var mouse := get_global_mouse_position()
	if _world_inside(mouse):
		if current_brush != "":
			var tint: Color = Color(1, 1, 1, 0.3) \
				if current_brush == "eraser" \
				else Color(WorldLayout.MASK_CATEGORIES[current_brush], 0.4)
			draw_circle(mouse, brush_size, tint)
		elif current_place != "":
			var info2: Dictionary = KEY_ELEMENTS[current_place]
			draw_arc(mouse, float(info2["radius"]), 0, TAU, 48,
				Color(info2["color"], 0.6), 2.0)
			draw_circle(mouse, 10.0, Color(info2["color"], 0.7))
