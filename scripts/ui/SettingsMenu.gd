extends CanvasLayer

## Settings menu (2026-11-15, user: "add a way to affect godot scale and
## window fit by pressing esc to get a settings menu").
##
## ESC in play opens it (GameManager._unhandled_input) and pauses the world;
## ESC or Resume closes it. It sets the window's own knobs live:
##   Scale  — Window.content_scale_factor (project default 1.52): how big
##            the world and HUD are drawn.
##   Fit    — Window.content_scale_aspect: how the 1024×768 base view fills
##            a window of another shape (keep with bars / expand / …).
##   Stretch — Window.content_scale_mode: canvas items (crisp) or viewport
##            (pixel-scaled) or off.
##   Window — windowed / maximized / fullscreen / exclusive fullscreen.
## Saved to user://settings.cfg and applied at start (apply_saved).
## No class_name on purpose (editor rescan caveat): GameManager preloads it.

signal closed

const SAVE_PATH := "user://settings.cfg"
const DEFAULT_SCALE := 1.52

const FITS := [
	["Keep (bars)", Window.CONTENT_SCALE_ASPECT_KEEP],
	["Expand (see more)", Window.CONTENT_SCALE_ASPECT_EXPAND],
	["Keep width", Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH],
	["Keep height", Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT],
	["Stretch (ignore)", Window.CONTENT_SCALE_ASPECT_IGNORE],
]
const STRETCHES := [
	["Canvas items (crisp)", Window.CONTENT_SCALE_MODE_CANVAS_ITEMS],
	["Viewport (pixels)", Window.CONTENT_SCALE_MODE_VIEWPORT],
	["Off (project default)", Window.CONTENT_SCALE_MODE_DISABLED],
]
const MODES := [
	["Windowed", Window.MODE_WINDOWED],
	["Maximized", Window.MODE_MAXIMIZED],
	["Fullscreen", Window.MODE_FULLSCREEN],
	["Exclusive fullscreen", Window.MODE_EXCLUSIVE_FULLSCREEN],
]

var _scale_slider: HSlider
var _scale_label: Label
var _fit: OptionButton
var _stretch: OptionButton
var _mode: OptionButton
var _resume: Button

# --- saved settings, applied at start ---------------------------------------------

## Defaults = the window as project.godot launched it (scale 1.52, its
## legacy "2d" stretch — which runs as Off — maximized), captured once at
## start by apply_saved before any saved choice is laid on top.
static var _startup: Dictionary = {}

static func _capture(win: Window) -> Dictionary:
	return {
		"scale": win.content_scale_factor,
		"fit": int(win.content_scale_aspect),
		"stretch": int(win.content_scale_mode),
		"mode": int(win.mode),
	}

static func defaults(win: Window = null) -> Dictionary:
	if _startup.is_empty() and win != null:
		_startup = _capture(win)
	if not _startup.is_empty():
		return _startup.duplicate()
	return {"scale": DEFAULT_SCALE, "fit": Window.CONTENT_SCALE_ASPECT_KEEP,
		"stretch": Window.CONTENT_SCALE_MODE_DISABLED, "mode": Window.MODE_MAXIMIZED}

static func load_settings(win: Window) -> Dictionary:
	var s := defaults(win)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for k: String in s.keys():
			s[k] = cfg.get_value("display", k, s[k])
	return s

static func apply(win: Window, s: Dictionary) -> void:
	if win == null:
		return
	win.content_scale_factor = clampf(float(s["scale"]), 0.5, 4.0)
	win.content_scale_aspect = int(s["fit"]) as Window.ContentScaleAspect
	win.content_scale_mode = int(s["stretch"]) as Window.ContentScaleMode
	if DisplayServer.get_name() != "headless" and win.mode != int(s["mode"]):
		win.mode = int(s["mode"]) as Window.Mode

## Called once by GameManager._ready: the player's saved choices win over
## project.godot. Without a save file nothing changes.
static func apply_saved(win: Window) -> void:
	defaults(win)   # remember the launch state first
	if FileAccess.file_exists(SAVE_PATH):
		apply(win, load_settings(win))

func _save(s: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k: String in s.keys():
		cfg.set_value("display", k, s[k])
	cfg.save(SAVE_PATH)

# --- the menu ------------------------------------------------------------------------

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1d1a16f0")
	sb.border_color = Color("c8913f")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(340, 0)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f2c46d"))
	box.add_child(title)

	_scale_label = Label.new()
	box.add_child(_scale_label)
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.5
	_scale_slider.max_value = 3.0
	_scale_slider.step = 0.02
	_scale_slider.value_changed.connect(func(_v: float) -> void: _changed())
	box.add_child(_scale_slider)

	_fit = _option(box, "Window fit", FITS)
	_stretch = _option(box, "Stretch", STRETCHES)
	_mode = _option(box, "Window", MODES)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_resume = _button(row, "Resume", close)
	_button(row, "Defaults", _reset)
	_button(row, "Quit", func() -> void: get_tree().quit())

	var hint := Label.new()
	hint.text = "ESC: back to the game"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	box.add_child(hint)

func _option(box: VBoxContainer, label: String, items: Array) -> OptionButton:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(100, 0)
	row.add_child(l)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		ob.add_item(str(items[i][0]), i)
	ob.item_selected.connect(func(_i: int) -> void: _changed())
	row.add_child(ob)
	box.add_child(row)
	return ob

func _button(row: HBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(90, 0)
	b.pressed.connect(cb)
	row.add_child(b)
	return b

static func _index_of(items: Array, value: int) -> int:
	for i in items.size():
		if int(items[i][1]) == value:
			return i
	return 0

var _syncing := false

func _show(s: Dictionary) -> void:
	_syncing = true
	_scale_slider.value = float(s["scale"])
	_fit.select(_index_of(FITS, int(s["fit"])))
	_stretch.select(_index_of(STRETCHES, int(s["stretch"])))
	_mode.select(_index_of(MODES, int(s["mode"])))
	_scale_label.text = "Scale: %.2f×" % float(s["scale"])
	_syncing = false

func _current() -> Dictionary:
	return {
		"scale": _scale_slider.value,
		"fit": int(FITS[_fit.selected][1]),
		"stretch": int(STRETCHES[_stretch.selected][1]),
		"mode": int(MODES[_mode.selected][1]),
	}

func _changed() -> void:
	if _syncing:
		return
	var s := _current()
	_scale_label.text = "Scale: %.2f×" % float(s["scale"])
	apply(get_window(), s)
	_save(s)

func _reset() -> void:
	var s := defaults(get_window())
	_show(s)
	apply(get_window(), s)
	_save(s)

func open() -> void:
	_show(_capture(get_window()))
	visible = true
	_resume.grab_focus()

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
