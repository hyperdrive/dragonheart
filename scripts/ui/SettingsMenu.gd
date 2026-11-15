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
## Keys tab (2026-11-15, user: "add a keymapper to the settings menu"): one
## binding per game action (REMAPPABLE); click it, press a key or mouse
## button. A key another action uses swaps over to the old binding. ESC
## (ui_cancel) is not remappable — it is how you get back here.
## Saved to user://settings.cfg ([display], [keys]) and applied at start
## (apply_saved). key_name()/with_keys() let hints show the bound key.
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
	_remember_default_keys()
	if FileAccess.file_exists(SAVE_PATH):
		apply(win, load_settings(win))
		_load_keys()

# --- key bindings --------------------------------------------------------------------

## The actions a player may rebind, in menu order: [action, label].
const REMAPPABLE := [
	["move_up", "Move up"],
	["move_down", "Move down"],
	["move_left", "Move left"],
	["move_right", "Move right"],
	["fire", "Breathe fire"],
	["eat", "Eat / act"],
	["fly", "Fly"],
	["shapeshift", "Dragon / girl"],
	["palette", "Cycle palette"],
]

static var _default_keys: Dictionary = {}

static func _remember_default_keys() -> void:
	if not _default_keys.is_empty():
		return
	for a: Array in REMAPPABLE:
		if InputMap.has_action(a[0]):
			_default_keys[a[0]] = InputMap.action_get_events(a[0]).duplicate()

## A binding as one int: a physical keycode, or -button for the mouse.
static func _code_of(ev: InputEvent) -> int:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return int(k.physical_keycode) if k.physical_keycode != KEY_NONE else int(k.keycode)
	if ev is InputEventMouseButton:
		return -int((ev as InputEventMouseButton).button_index)
	return 0

static func _event_of(code: int) -> InputEvent:
	if code < 0:
		var m := InputEventMouseButton.new()
		m.button_index = (-code) as MouseButton
		return m
	var k := InputEventKey.new()
	k.physical_keycode = code as Key
	return k

static func _code(action: String) -> int:
	if not InputMap.has_action(action):
		return 0
	for ev: InputEvent in InputMap.action_get_events(action):
		var c := _code_of(ev)
		if c != 0:
			return c
	return 0

static func _bind(action: String, code: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	if code != 0:
		InputMap.action_add_event(action, _event_of(code))

static func _load_keys() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK or not cfg.has_section("keys"):
		return
	for a: Array in REMAPPABLE:
		if cfg.has_section_key("keys", a[0]):
			_bind(a[0], int(cfg.get_value("keys", a[0])))

static func _save_keys() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	for a: Array in REMAPPABLE:
		cfg.set_value("keys", a[0], _code(a[0]))
	cfg.save(SAVE_PATH)

## The name of the key bound to `action`, as printed on the keyboard
## ("Q", "Space", "Mouse 1"); "?" when unbound.
static func key_name(action: String) -> String:
	var c := _code(action)
	if c < 0:
		match -c:
			MOUSE_BUTTON_LEFT: return "Left mouse"
			MOUSE_BUTTON_RIGHT: return "Right mouse"
			MOUSE_BUTTON_MIDDLE: return "Middle mouse"
		return "Mouse %d" % -c
	if c == 0:
		return "?"
	var label: Key = KEY_NONE   # the key's name on this keyboard layout
	if DisplayServer.get_name() != "headless":
		label = DisplayServer.keyboard_get_keycode_from_physical(c as Key)
	return OS.get_keycode_string(label if label != KEY_NONE else (c as Key))

## Text with {key:action} tokens replaced by the bound key's name.
static func with_keys(text: String) -> String:
	if not "{key:" in text:
		return text
	for a: Array in REMAPPABLE:
		text = text.replace("{key:%s}" % a[0], key_name(a[0]))
	return text

func _save(s: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)   # keep the other section
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

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(360, 0)
	box.add_child(tabs)
	var disp := VBoxContainer.new()
	disp.name = "Display"
	disp.add_theme_constant_override("separation", 10)
	tabs.add_child(disp)
	_build_keys(tabs)

	_scale_label = Label.new()
	disp.add_child(_scale_label)
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.5
	_scale_slider.max_value = 3.0
	_scale_slider.step = 0.02
	_scale_slider.value_changed.connect(func(_v: float) -> void: _changed())
	disp.add_child(_scale_slider)

	_fit = _option(disp, "Window fit", FITS)
	_stretch = _option(disp, "Stretch", STRETCHES)
	_mode = _option(disp, "Window", MODES)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	_resume = _button(row, "Resume", close)
	_button(row, "Defaults", _reset).tooltip_text = "Display and keys back to how the game starts"
	_button(row, "Quit", func() -> void: get_tree().quit())

	var hint := Label.new()
	hint.text = "ESC: back to the game"
	_hint = hint
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	box.add_child(hint)

var _key_buttons: Dictionary = {}   # action → Button
var _listening := ""                # the action waiting for a key
var _hint: Label

func _build_keys(tabs: TabContainer) -> void:
	var keys := VBoxContainer.new()
	keys.name = "Keys"
	keys.add_theme_constant_override("separation", 4)
	tabs.add_child(keys)
	for a: Array in REMAPPABLE:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = a[1]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 0)
		b.pressed.connect(_listen.bind(a[0]))
		row.add_child(b)
		_key_buttons[a[0]] = b
		keys.add_child(row)
	var note := Label.new()
	note.text = "Click a binding, then press a key or mouse button."
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	keys.add_child(note)

func _show_keys() -> void:
	for action: String in _key_buttons:
		(_key_buttons[action] as Button).text = \
			"press a key…" if action == _listening else key_name(action)

func _listen(action: String) -> void:
	_listening = action
	_hint.text = "ESC: cancel"
	_show_keys()

## While listening, the next key or mouse button is the new binding.
func _input(event: InputEvent) -> void:
	if not visible or _listening == "":
		return
	var code := 0
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE \
				or event.is_action("ui_cancel"):
			_stop_listening()
			get_viewport().set_input_as_handled()
			return
		code = _code_of(event)
	elif event is InputEventMouseButton and event.pressed:
		var bi := (event as InputEventMouseButton).button_index
		if bi in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
				MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return
		code = _code_of(event)
	if code == 0:
		return
	get_viewport().set_input_as_handled()
	# a key another action already uses swaps over to the old binding
	var old := _code(_listening)
	for a: Array in REMAPPABLE:
		if a[0] != _listening and _code(a[0]) == code:
			_bind(a[0], old)
	_bind(_listening, code)
	_save_keys()
	_stop_listening()

func _stop_listening() -> void:
	_listening = ""
	_hint.text = "ESC: back to the game"
	_show_keys()

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
	for action: String in _default_keys:
		InputMap.action_erase_events(action)
		for ev: InputEvent in _default_keys[action]:
			InputMap.action_add_event(action, ev)
	_save_keys()
	_stop_listening()

func open() -> void:
	_show(_capture(get_window()))
	_stop_listening()
	visible = true
	_resume.grab_focus()

func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and _listening == "" and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
