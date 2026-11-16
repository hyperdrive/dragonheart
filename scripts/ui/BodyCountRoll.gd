extends CanvasLayer

## The roll of the dead (2026-11-16, user: "When the dragon dies they
## should be listed with their name, age and occupation"). Opened by
## GameManager._show_body_roll after the run's last chapter (a death, or
## the last ember), over the paused world; closing it starts the new run.
## Every soul on the dragon's roll, in the order they fell: name, age,
## occupation — and how. Scrolls when long. Built in code, no scene;
## no class_name (editor rescan caveat).

signal closed

const STORY_FONT := preload("res://assets/fonts/Metamorphous-Regular.ttf")
const INK := Color(0.95, 0.91, 0.85)
const FADED := Color(0.95, 0.91, 0.85, 0.6)
const EMBER := Color(0.95, 0.62, 0.3)

var _list: VBoxContainer
var _title: Label
var _sub: Label
var _button: Button

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1b1714f2")
	sb.border_color = Color("8a6a4a")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(620, 0)
	panel.add_child(box)
	_title = _label(box, 30, EMBER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub = _label(box, 18, FADED)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_button = Button.new()
	_button.add_theme_font_override("font", STORY_FONT)
	_button.add_theme_font_size_override("font_size", 20)
	_button.pressed.connect(_close)
	box.add_child(_button)

func _label(parent: Control, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", STORY_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l

func open(dead: Array) -> void:
	_title.text = "The Roll of the Dead"
	if dead.is_empty():
		_sub.text = "Not one soul. Whatever else is said of this dragon, no one was buried on her account."
		_button.text = "Rest."
	else:
		_sub.text = "%d %s fell to the dragon, her fire and her rider. Their names, so someone remembers them." \
			% [dead.size(), "soul" if dead.size() == 1 else "souls"]
		_button.text = "Let them rest."
	for i in dead.size():
		var who: Dictionary = dead[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var n := _label(row, 15, FADED)
		n.text = "%d." % (i + 1)
		n.custom_minimum_size = Vector2(38, 0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var main := _label(row, 18, INK)
		main.text = "%s, %d" % [who.get("name", "?"), int(who.get("age", 0))]
		main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var occ := _label(row, 16, FADED)
		occ.text = "%s — %s" % [who.get("occupation", ""), who.get("cause", "")]
		occ.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(10, 0)   # clear of the scrollbar
		row.add_child(gap)
		_list.add_child(row)
	visible = true
	_button.grab_focus()

func _close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_close()
