extends Control

class_name GameHUD

## HUD view: rebinding to GameManager (single state hub) —
## treasury (town pool, filled by miners), food, dragon stash (stolen loot),
## dragon levels, upgrade panel, victory tally. No state is stored here.

@onready var gold_label: Label = $ResourcePanel/VBoxContainer/GoldLabel
@onready var food_label: Label = $ResourcePanel/VBoxContainer/FoodLabel
@onready var scales_label: Label = $DragonStats/VBoxContainer/ScalesLabel
@onready var fire_label: Label = $DragonStats/VBoxContainer/FireLabel
@onready var upgrade_panel: Panel = $UpgradePanel
@onready var message_label: Label = $MessageLabel
@onready var minimap: Panel = $Minimap

var game_manager: GameManager

func _ready() -> void:
	upgrade_panel.hide()
	$UpgradePanel/VBoxContainer/TowerButton.hide()  # wizard-site flow deferred
	$UpgradePanel/VBoxContainer/ScalesButton.pressed.connect(_on_upgrade_scales)
	$UpgradePanel/VBoxContainer/FireButton.pressed.connect(_on_upgrade_fire)
	$UpgradePanel/VBoxContainer/CloseButton.pressed.connect(_on_close_panel)
	# Dragon stash readout, built at runtime (keeps the scene untouched).
	var stash_label := Label.new()
	stash_label.name = "StashLabel"
	stash_label.text = "Dragon stash: 0 gold"
	stash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$ResourcePanel/VBoxContainer.add_child(stash_label)
	_update_stats()

## Called by GameManager._ready (the hub injects itself; signals up, calls down).
func bind_manager(mgr: GameManager) -> void:
	game_manager = mgr
	mgr.treasury_changed.connect(_on_pools_changed)
	mgr.stash_changed.connect(_on_pools_changed)
	mgr.food_changed.connect(_on_food_changed)
	mgr.upgrade_purchased.connect(_on_upgrade_purchased)
	mgr.victory_achieved.connect(_on_victory)
	_refresh_pools()
	_refresh_dragon_stats()

# --- reactive views ---------------------------------------------------------

func _on_pools_changed(_res_type: String, _amount: int) -> void:
	_refresh_pools()
	_refresh_upgrade_buttons()

func _on_food_changed(amount: int) -> void:
	food_label.text = "Food (support): %d" % amount

func _on_upgrade_purchased(kind: String, level: int) -> void:
	_refresh_dragon_stats()
	show_message("%s upgraded to level %d!" % [kind.capitalize(), level])

func _refresh_pools() -> void:
	if game_manager == null:
		return
	gold_label.text = "Town: %dg / %dgems" % [
		game_manager.treasury["gold"], game_manager.treasury["gems"]]
	var stash_label := $ResourcePanel/VBoxContainer/StashLabel as Label
	stash_label.text = "Dragon stash: %dg / %dgems" % [
		game_manager.stash["gold"], game_manager.stash["gems"]]

func _refresh_dragon_stats() -> void:
	if game_manager == null:
		return
	scales_label.text = "Scales: Level %d" % game_manager.scales_level
	fire_label.text = "Fire: Level %d" % game_manager.fire_power_level

# --- upgrade panel -----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("upgrade"):
		_toggle_upgrade_panel()

func _toggle_upgrade_panel() -> void:
	upgrade_panel.visible = not upgrade_panel.visible
	if upgrade_panel.visible:
		_refresh_upgrade_buttons()

func _refresh_upgrade_buttons() -> void:
	if game_manager == null:
		return
	var stash_value: int = int(game_manager.stash["gold"]) + int(game_manager.stash["gems"]) * 10
	var scales_button := $UpgradePanel/VBoxContainer/ScalesButton as Button
	var fire_button := $UpgradePanel/VBoxContainer/FireButton as Button
	var scales_cost := game_manager.scales_upgrade_cost()
	var fire_cost := game_manager.fire_upgrade_cost()
	scales_button.disabled = stash_value < scales_cost
	fire_button.disabled = stash_value < fire_cost
	scales_button.text = "Upgrade Scales (%d loot)" % scales_cost
	fire_button.text = "Upgrade Fire (%d loot)" % fire_cost

func _on_upgrade_scales() -> void:
	game_manager.upgrade_scales()
	_refresh_upgrade_buttons()

func _on_upgrade_fire() -> void:
	game_manager.upgrade_fire()
	_refresh_upgrade_buttons()

func _on_close_panel() -> void:
	upgrade_panel.visible = false

# --- messages ----------------------------------------------------------------

func show_upgrade_available() -> void:
	show_message("Upgrade Available! Press U")

func show_message(text: String, duration: float = 3.0) -> void:
	message_label.text = text
	await get_tree().create_timer(duration).timeout
	if message_label.text == text:
		_update_stats()

func _on_victory(tally: Dictionary) -> void:
	message_label.text = "VICTORY! Time %ds — stolen %dg/%dgems — fire Lv%d, scales Lv%d" % [
		int(tally["time_survived"]), tally["gold_stolen"], tally["gems_stolen"],
		tally["fire_level"], tally["scales_level"]]

func _update_stats() -> void:
	message_label.text = "Press U for Upgrades"

# --- minimap (stubs kept for GameManager connections) -------------------------

func update_minimap_entity(entity_type: String, position: Vector2, remove: bool = false) -> void:
	pass

func update_minimap_dragon(dragon_pos: Vector2) -> void:
	pass

func initialize_minimap() -> void:
	pass
