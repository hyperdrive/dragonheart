extends CanvasLayer

class_name WizardMenu

## The wizard tower upgrade overlay (decision record
## 2026-11-08-manual-eat-wizard-menu): a full-screen pick scene while the
## live world is PAUSED beneath it. Mouse + number keys 1–5; ESC/Leave closes.
## No state lives here — GameManager owns stash, prices and applying effects.

signal menu_close_requested

const OPTIONS: Array = [
	{"kind": "flame_1", "label": "+1 Flame (%d)", "desc": "More flames carried: capacity +1, arrives loaded."},
	{"kind": "flame_2", "label": "+2 Flames (%d)", "desc": "Even bigger flame pool: capacity +2, arrives loaded."},
	{"kind": "shield", "label": "Shield 10 (%d)", "desc": "Absorbs 10 damage, then gone. Cannot restack while one is active."},
	{"kind": "speed", "label": "Speed Boost (%d)", "desc": "Fast wings for 6s (x1.6)."},
	{"kind": "range", "label": "Longer Flame (%d)", "desc": "Breath reaches +20px further. Permanent."},
]

const HOTKEYS: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]

var game_manager: GameManager
var option_buttons: Array[Button] = []
var price_buttons: Dictionary = {}

@onready var stash_label: Label = $Center/Panel/VBox/StashLabel
@onready var options_box: VBoxContainer = $Center/Panel/VBox/Options
@onready var hint_label: Label = $Center/Panel/VBox/Hint

func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	for option: Dictionary in OPTIONS:
		var button := Button.new()
		button.text = option["label"] % GameManager.WIZARD_PRICES[option["kind"]]
		button.pressed.connect(_on_option_pressed.bind(option["kind"]))
		options_box.add_child(button)
		option_buttons.append(button)
		price_buttons[option["kind"]] = button

func open() -> void:
	visible = true
	_refresh()

func close() -> void:
	visible = false
	menu_close_requested.emit()

func _refresh() -> void:
	if game_manager == null:
		return
	stash_label.text = "Stash: %d gold, %d gems" % [
		int(game_manager.stash["gold"]), int(game_manager.stash["gems"])]
	var dragon_ref: Node = game_manager.dragon
	var shield_active: bool = dragon_ref != null \
		and int(dragon_ref.get("shield_points")) > 0
	for i in OPTIONS.size():
		var option: Dictionary = OPTIONS[i]
		var button := option_buttons[i]
		var affordable: bool = game_manager.stash_value() \
			>= int(GameManager.WIZARD_PRICES[option["kind"]])
		button.disabled = not affordable \
			or (option["kind"] == "shield" and shield_active)
		if option["kind"] == "shield" and shield_active:
			button.text = "Shield 10 — already active (%d)" % int(
				GameManager.WIZARD_PRICES[option["kind"]])
		else:
			button.text = option["label"] % int(
				GameManager.WIZARD_PRICES[option["kind"]])
	hint_label.text = "1–5 buy • ESC leave  •  shield ready: %s" % (
		"no" if shield_active else "yes")

func _on_option_pressed(kind: String) -> void:
	if game_manager != null and game_manager.purchase_upgrade(kind):
		_refresh()
	else:
		_flash_stash()

## Store feedback: brief red pulse on the stash row (matches the HUD chips).
func _flash_stash() -> void:
	var tween := create_tween()
	tween.tween_property(stash_label, "modulate", Color(1.0, 0.3, 0.3), 0.12)
	tween.tween_property(stash_label, "modulate", Color.WHITE, 0.25)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	for i in HOTKEYS.size():
		var key := event as InputEventKey
		if key != null and key.pressed and key.physical_keycode == HOTKEYS[i]:
			_on_option_pressed(OPTIONS[i]["kind"])
			get_viewport().set_input_as_handled()
			return
