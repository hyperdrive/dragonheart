extends Control

class_name GameHUD

## HUD view: binds to GameManager (single state hub) —
## treasury (town pool), food, dragon stash + carried claws (the hauling loop),
## dragon levels, threat readout (soldiers/swarm/King), victory
## tally. No state is stored here; every value arrives via signals.

@onready var treasury_label: Label = $TopBar/TopBarMargin/HBox/TreasuryLabel
@onready var food_label: Label = $TopBar/TopBarMargin/HBox/FoodLabel
@onready var stash_label: Label = $TopBar/TopBarMargin/HBox/StashLabel
@onready var health_label: Label = $TopBar/TopBarMargin/HBox/HealthLabel
@onready var carry_label: Label = $TopBar/TopBarMargin/HBox/CarryLabel
@onready var scales_label: Label = $TopBar/TopBarMargin/HBox/ScalesLabel
@onready var fire_label: Label = $TopBar/TopBarMargin/HBox/FireLabel
@onready var wings_label: Label = $TopBar/TopBarMargin/HBox/WingsLabel
@onready var threat_label: Label = $TopBar/TopBarMargin/HBox/ThreatLabel
@onready var message_label: Label = $MessageLabel
@onready var minimap: MinimapPanel = $Minimap

var game_manager: GameManager
## Threat readout (top-right chip): swarm state name + live soldier/King scan.
var threat_swarm: String = "calm"

func _ready() -> void:
	# The old U-key upgrade panel is retired: purchases now happen ONLY at
	# the wizard tower (decision record 2026-11-08-manual-eat-wizard-menu).
	$UpgradePanel.visible = false
	$UpgradePanel.process_mode = Node.PROCESS_MODE_DISABLED

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
	# Dragon health/flame/shield chips (take_damage/_try_eat_at_pen emit).
	var dragon_ref := mgr.dragon
	if dragon_ref != null and dragon_ref.has_signal("health_changed"):
		dragon_ref.health_changed.connect(_on_dragon_health)
		_on_dragon_health((dragon_ref as CharacterBody2D).get("health"))
	if dragon_ref != null and dragon_ref.has_signal("flame_charges_changed"):
		dragon_ref.flame_charges_changed.connect(_on_flame_charges)
		_on_flame_charges(
			int((dragon_ref as CharacterBody2D).get("flame_charges")),
			int((dragon_ref as CharacterBody2D).get("max_flame_charges")))
	if dragon_ref != null and dragon_ref.has_signal("eat_refused"):
		dragon_ref.eat_refused.connect(_on_eat_refused)
		if dragon_ref.has_signal("strike_missed"):
			dragon_ref.strike_missed.connect(_on_strike_missed)
		if dragon_ref.has_signal("shield_changed"):
			dragon_ref.shield_changed.connect(_on_dragon_shield)
			_on_dragon_shield(int((dragon_ref as CharacterBody2D).get("shield_points")))
		if dragon_ref.has_signal("flight_state_changed"):
			dragon_ref.flight_state_changed.connect(_on_flight_state)
	_refresh_pools()
	_refresh_dragon_stats()
	refresh_threat()

# --- reactive views ---------------------------------------------------------

func _on_pools_changed(_res_type: String, _amount: int) -> void:
	_refresh_pools()

func _on_food_changed(amount: int) -> void:
	food_label.text = "Food: %d" % amount

func _on_upgrade_purchased(kind: String, price: int) -> void:
	_refresh_dragon_stats()
	show_message("The wizard casts %s! (paid %d gold)" % [
		kind.replace("_", " ").capitalize(), price])

## The dragon's hauling loop — visible on the top bar at all times.
func update_carried(total: int) -> void:
	carry_label.text = "Claws: %d" % total

## Damage/eating feed the HP chip (fed/take_damage both emit health_changed).
## An active wizard shield shows as an absorb suffix on the HP chip.
func _on_dragon_health(health: Variant) -> void:
	var dragon_ref: CharacterBody2D = null
	if game_manager != null:
		dragon_ref = game_manager.dragon
	elif get_tree() != null:
		dragon_ref = get_tree().get_first_node_in_group("dragon") as CharacterBody2D
	if dragon_ref != null:
		var shield: int = int(dragon_ref.get("shield_points"))
		var shield_text: String = "" if shield <= 0 else " (+%d shield)" % shield
		health_label.text = "HP %d/%d%s" % [
			int(health), int(dragon_ref.get("max_health")), shield_text]
	else:
		health_label.text = "HP %d" % int(health)

## Flame economy readout: breaths left of the eaten-fuel pool.
func _on_flame_charges(charges: int, max_charges: int) -> void:
	fire_label.text = "Fire %d • %d/%d" % [
		game_manager.fire_power_level if game_manager != null else 1,
		charges, max_charges]

## Flight chip (2026-11-09): FLYING shows the burst seconds left, then the
## grounded recharge countdown, then "ready". Dragon pushes on phase edge
## + whole second (no per-frame spam).
func _on_flight_state(flying: bool, seconds_left: float, charging: bool) -> void:
	if flying:
		wings_label.text = "✈ %ds" % ceili(seconds_left)
		wings_label.modulate = Color(0.75, 1.0, 0.9)
	elif charging:
		wings_label.text = "Wings %ds" % ceili(seconds_left)
		wings_label.modulate = Color(1.0, 0.85, 0.6)
	else:
		wings_label.text = "Wings: ready (Q)"
		wings_label.modulate = Color.WHITE

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

# --- eat feedback + shield chip --------------------------------------------------------------

func _on_dragon_shield(points: int) -> void:
	# Folded into the HP chip suffix; re-run the current health format.
	var dragon_ref := get_tree().get_first_node_in_group("dragon") as CharacterBody2D
	if dragon_ref != null:
		_on_dragon_health(int(dragon_ref.get("health")))
	if points > 0:
		show_message("Shield active: absorbs 10 damage!")

## Wasted-E feedback (Dragon refuses to eat when there is nothing to gain).
## The offending chip pulses red, then returns to white.
func _on_eat_refused(what: String) -> void:
	var chip := health_label if what == "health" else fire_label
	var tween := create_tween()
	tween.tween_property(chip, "modulate", Color(1.0, 0.25, 0.25), 0.12)
	tween.tween_property(chip, "modulate", Color.WHITE, 0.3)

## Failed soldier strike (dice miss): the threat chip pulses red so the
## miss reads as feedback, not lag (decision 2026-11-08-soldier-strike).
func _on_strike_missed() -> void:
	var tween := create_tween()
	tween.tween_property(threat_label, "modulate", Color(1.0, 0.25, 0.25), 0.12)
	tween.tween_property(threat_label, "modulate", Color.WHITE, 0.3)

# --- messages ----------------------------------------------------------------

func show_upgrade_available() -> void:
	show_message("Upgrades: visit the wizard's tower!")

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
	message_label.text = ""

# --- minimap (MinimapPanel below; GameManager pushes per-frame dragon dots) ---

func update_minimap_entity(entity_type: String, position: Vector2, remove: bool = false) -> void:
	minimap.set_entity(entity_type, position, remove)

func update_minimap_dragon(dragon_pos: Vector2) -> void:
	minimap.set_dragon(dragon_pos)

func initialize_minimap() -> void:
	minimap.scan_and_redraw()
