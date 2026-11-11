extends CanvasLayer

class_name WizardMenu

## The wizard tower upgrade overlay (decision record
## 2026-11-08-manual-eat-wizard-menu): a full-screen pick scene while the
## live world is PAUSED beneath it. Mouse + number keys 1–5; ESC/Leave closes.
## No state lives here — GameManager owns stash, prices and applying effects.

signal menu_close_requested

const OPTIONS: Array = [
	{"kind": "flame_1", "label": "+1 Flame (%s)", "desc": "More flames carried: capacity +1, arrives loaded."},
	{"kind": "flame_2", "label": "+2 Flames (%s)", "desc": "Even bigger flame pool: capacity +2, arrives loaded."},
	{"kind": "shield", "label": "Shield 10 (%s)", "desc": "Absorbs 10 damage, then gone. Cannot restack while one is active."},
	{"kind": "speed", "label": "Speed Boost (%s)", "desc": "Fast wings for 6s (x1.6). Also unlocks the 0.2s strike recharge."},
	{"kind": "range", "label": "Longer Flame (%s)", "desc": "Breath reaches +20px further. Permanent."},
	{"kind": "brute", "label": "Brute Force +5%% (%s)", "desc": "Soldier E-strike kill odds +5%. Repeatable, capped at 35%."},
	{"kind": "rider_train", "label": "Train Dragon Rider (%s)", "desc": "Train the sacrifice as a dragon rider. Costs 10g. Enables rider combat."},
]

const HOTKEYS: Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]

var game_manager: GameManager
var option_buttons: Array[Button] = []
var price_buttons: Dictionary = {}
var rider_train_button: Button = null

@onready var stash_label: Label = $Center/Panel/VBox/StashLabel
@onready var options_box: VBoxContainer = $Center/Panel/VBox/Options
@onready var hint_label: Label = $Center/Panel/VBox/Hint

func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	for i in OPTIONS.size():
		var option: Dictionary = OPTIONS[i]
		var button := Button.new()
		button.text = option["label"] % ""  # real text on open()
		button.pressed.connect(_on_option_pressed.bind(option["kind"]))
		options_box.add_child(button)
		option_buttons.append(button)
		price_buttons[option["kind"]] = button
		if option["kind"] == "rider_train":
			rider_train_button = button
			rider_train_button.visible = false  # hidden until sacrifice is trained

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
		var kind: String = option["kind"]
		
		# Special case for rider training
		if kind == "rider_train":
			var has_trainable_sacrifice := game_manager.has_trainable_sacrifice()
			var button := option_buttons[i]
			if has_trainable_sacrifice:
				button.visible = true
				var cost: Dictionary = GameManager.WIZARD_PRICES[kind]
				var price_text: String = "%dg" % int(cost["gold"])
				button.text = option["label"] % price_text
				button.disabled = not game_manager.can_afford_wizard(kind)
			else:
				button.visible = false
			continue
		
		var cost: Dictionary = GameManager.WIZARD_PRICES[kind]
		var gems := int(cost["gems"])
		var price_text: String = "%dg" % int(cost["gold"])
		if gems > 0:
			price_text += " + %d gem%s" % [gems, "" if gems == 1 else "s"]
		var button := option_buttons[i]
		var affordable: bool = game_manager.can_afford_wizard(kind)
		if option["kind"] == "shield" and shield_active:
			button.text = "Shield 10 — already active (15g)"
			button.disabled = true
		elif option["kind"] == "brute" and dragon_ref != null:
			var chance: float = float(dragon_ref.get("soldier_strike_chance"))
			var capped: bool = not bool(dragon_ref.call("can_add_strike"))
			button.text = "Brute Force — %d%% kill odds (%s)" % [chance * 100.0, price_text]
			if capped:
				button.text = "Brute Force — %d%% kill odds (MAXED)" % [chance * 100.0]
			button.disabled = not affordable or capped
		else:
			button.text = option["label"] % price_text
			button.disabled = not affordable
	hint_label.text = "1–7 buy • ESC leave  •  shield ready: %s" % (
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
