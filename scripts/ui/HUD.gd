extends Control

class_name GameHUD

## HUD view: binds to GameManager (single state hub) —
## treasury (town pool), food, dragon stash + carried claws (the hauling loop),
## dragon levels, threat readout (soldiers/swarm/King), upgrade panel, victory
## tally. No state is stored here; every value arrives via signals.

@onready var treasury_label: Label = $TopBar/TopBarMargin/HBox/TreasuryLabel
@onready var food_label: Label = $TopBar/TopBarMargin/HBox/FoodLabel
@onready var stash_label: Label = $TopBar/TopBarMargin/HBox/StashLabel
@onready var health_label: Label = $TopBar/TopBarMargin/HBox/HealthLabel
@onready var carry_label: Label = $TopBar/TopBarMargin/HBox/CarryLabel
@onready var scales_label: Label = $TopBar/TopBarMargin/HBox/ScalesLabel
@onready var fire_label: Label = $TopBar/TopBarMargin/HBox/FireLabel
@onready var threat_label: Label = $TopBar/TopBarMargin/HBox/ThreatLabel
@onready var upgrade_panel: Panel = $UpgradePanel
@onready var message_label: Label = $MessageLabel
@onready var minimap: MinimapPanel = $Minimap

var game_manager: GameManager
## Threat readout (top-right chip): swarm state name + live soldier/King scan.
var threat_swarm: String = "calm"

func _ready() -> void:
	upgrade_panel.hide()
	$UpgradePanel/VBoxContainer/TowerButton.hide()  # wizard-site flow deferred
	$UpgradePanel/VBoxContainer/ScalesButton.pressed.connect(_on_upgrade_scales)
	$UpgradePanel/VBoxContainer/FireButton.pressed.connect(_on_upgrade_fire)
	$UpgradePanel/VBoxContainer/CloseButton.pressed.connect(_on_close_panel)

## Called by GameManager._ready (the hub injects itself; signals up, calls down).
func bind_manager(mgr: GameManager) -> void:
	game_manager = mgr
	mgr.treasury_changed.connect(_on_pools_changed)
	mgr.stash_changed.connect(_on_pools_changed)
	mgr.food_changed.connect(_on_food_changed)
	mgr.upgrade_purchased.connect(_on_upgrade_purchased)
	mgr.victory_achieved.connect(_on_victory)
	# Threat chip sources (WorldManager owns soldier/swarm facts).
	var world := mgr.world_manager
	if world != null and world.has_signal("entity_spawned"):
		world.entity_spawned.connect(_on_world_entity_spawned)
	if world != null and world.has_signal("swarm_state_changed"):
		world.swarm_state_changed.connect(_on_swarm_state_changed)
	if world != null and world.has_signal("entity_spawned"):
		pass  # soldier recount uses the same stream
	mgr.boss_battle_started.connect(_on_king_arrived)
	# Dragon health chip (take_damage/eat_food emit health_changed).
	var dragon_ref := mgr.dragon
	if dragon_ref != null and dragon_ref.has_signal("health_changed"):
		dragon_ref.health_changed.connect(_on_dragon_health)
		_on_dragon_health((dragon_ref as CharacterBody2D).get("health"))
	_refresh_pools()
	_refresh_dragon_stats()
	refresh_threat()

# --- reactive views ---------------------------------------------------------

func _on_pools_changed(_res_type: String, _amount: int) -> void:
	_refresh_pools()
	_refresh_upgrade_buttons()

func _on_food_changed(amount: int) -> void:
	food_label.text = "Food: %d" % amount

func _on_upgrade_purchased(kind: String, level: int) -> void:
	_refresh_dragon_stats()
	show_message("%s upgraded to level %d!" % [kind.capitalize(), level])

## The dragon's hauling loop — visible on the top bar at all times.
func update_carried(total: int) -> void:
	carry_label.text = "Claws: %d" % total

## Damage/eating feed the HP chip (fed/take_damage both emit health_changed).
func _on_dragon_health(health: Variant) -> void:
	if game_manager == null:
		var gm_root := get_tree().get_first_node_in_group("game_manager") as GameManager
		if gm_root != null and gm_root.dragon != null:
			health_label.text = "HP %d/%d" % [int(health), gm_root.dragon.get("max_health")]
		return
	var dragon_ref: CharacterBody2D = game_manager.dragon
	if dragon_ref != null:
		health_label.text = "HP %d/%d" % [int(health), int(dragon_ref.get("max_health"))]

func _refresh_pools() -> void:
	if game_manager == null:
		return
	treasury_label.text = "Treasury: %dg / %dgems" % [
		game_manager.treasury["gold"], game_manager.treasury["gems"]]
	stash_label.text = "Stash: %dg / %dgems" % [
		game_manager.stash["gold"], game_manager.stash["gems"]]

func _refresh_dragon_stats() -> void:
	if game_manager == null:
		return
	scales_label.text = "Scales %d" % game_manager.scales_level
	fire_label.text = "Fire %d" % game_manager.fire_power_level

# --- threat chip ------------------------------------------------------------

## WorldManager spawns soldiers and the King on the same entity stream;
## the head count is a live group scan (initial spawns happen BEFORE HUD
## bindings exist — a counter would miss them; same reason Minimap self-scans).
func _on_world_entity_spawned(entity_type: String, _position: Vector2) -> void:
	if entity_type in ["soldier", "king", "farmer"]:
		refresh_threat()

func _on_swarm_state_changed(new_state: WorldManager.SwarmState) -> void:
	threat_swarm = ["calm", "RALLY", "ATTACK"][int(new_state)]
	refresh_threat()

func _on_king_arrived(_king: Node) -> void:
	refresh_threat()

func refresh_threat() -> void:
	var soldiers := get_tree().get_nodes_in_group("soldiers").size()
	var king_here := not get_tree().get_nodes_in_group("king").is_empty()
	var text := "Soldiers: %d • %s" % [soldiers, threat_swarm]
	if king_here:
		text += " • ⚔ KING"  # the final boss is on the field
	threat_label.text = text

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

# --- minimap (MinimapPanel below; GameManager pushes per-frame dragon dots) ---

func update_minimap_entity(entity_type: String, position: Vector2, remove: bool = false) -> void:
	minimap.set_entity(entity_type, position, remove)

func update_minimap_dragon(dragon_pos: Vector2) -> void:
	minimap.set_dragon(dragon_pos)

func initialize_minimap() -> void:
	minimap.scan_and_redraw()
