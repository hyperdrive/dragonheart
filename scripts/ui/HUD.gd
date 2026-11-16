extends Control

class_name GameHUD

const SETTINGS_KEYS := preload("res://scripts/ui/SettingsMenu.gd")   # bound-key names

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
	# the scene's opening hint becomes the log's first line
	_log(message_label.text, Color.WHITE, 8.0)

## Called by GameManager._ready (the hub injects itself; signals up, calls down).
var _dead_label: Label

func _on_body_count(n: int) -> void:
	if _dead_label != null:
		_dead_label.text = "Dead: %d" % n

## Pact chips (2026-11-16): the rider's pact (RiderPacts.gd) and the
## hag's bargain (HagPact.gd), each with its term and clock, after the body
## count. A chip is hidden while its pact is not running; red = in danger.
var _pact_label: Label            # the rider's chip
var _chips := {}                  # id → Label

func set_pact_text(text: String, danger: bool = false) -> void:
	set_chip("rider", text, danger)

func set_chip(id: String, text: String, danger: bool = false) -> void:
	var chip: Label = _chips.get(id)
	if chip == null:
		if _dead_label == null or text == "":
			return
		chip = Label.new()
		chip.add_theme_font_size_override("font_size", 15)
		var after: Node = _dead_label
		for other: Label in _chips.values():
			after = other
		after.add_sibling(chip)
		_chips[id] = chip
		if id == "rider":
			_pact_label = chip
	chip.text = text
	chip.visible = text != ""
	chip.add_theme_color_override("font_color",
		NOTICE_COLORS["warning"] if danger else Color(0.95, 0.78, 0.45))

## Pact notices (2026-11-16, user: "If you are granted a bonus, show it in
## a notice. If you are close to breaking the pact - show it as a warning"):
## a line in the notice's colour; a warning also pulses the pact chips.
## Plain show_message lines are white.
const NOTICE_COLORS := {
	"bonus": Color(0.62, 1.0, 0.55),
	"warning": Color(1.0, 0.42, 0.3),
	"info": Color(0.98, 0.86, 0.6),
}

func show_notice(text: String, kind: String = "info", duration: float = 3.5) -> void:
	_log(text, NOTICE_COLORS.get(kind, Color.WHITE), duration)
	if kind == "warning":
		for chip: Label in _chips.values():
			if chip.visible:
				var tween := create_tween()
				tween.tween_property(chip, "scale", Vector2(1.15, 1.15), 0.12)
				tween.tween_property(chip, "scale", Vector2.ONE, 0.25)

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
	# The body count (2026-11-16): the dragon's dead, after the wings chip.
	_dead_label = Label.new()
	_dead_label.add_theme_font_size_override("font_size", 15)
	_dead_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.62))
	wings_label.add_sibling(_dead_label)
	mgr.body_count_changed.connect(_on_body_count)
	_on_body_count(mgr.body_count.size())
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
			maxi(int(health), 0), int(dragon_ref.get("max_health")), shield_text]
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
		wings_label.text = "Wings: ready (%s)" % SETTINGS_KEYS.key_name("fly")
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
	_log(text, Color.WHITE, duration)

## The rolling message window (2026-11-16, user: "make the notifications
## into a rolling window so that we see the last 4 notices"): the newest
## line at the bottom, older ones above it, fading with age; each line
## leaves when its own time is up, and a fifth pushes the oldest out. The
## same text again just refreshes its line. Replaces the single
## MessageLabel (hidden; its spot and style are kept).
const LOG_LINES := 4
const LOG_AGE_ALPHA: Array[float] = [1.0, 0.86, 0.74, 0.62]   # newest → oldest
var _log_box: VBoxContainer

func _ensure_log() -> void:
	if _log_box != null:
		return
	_log_box = VBoxContainer.new()
	_log_box.name = "MessageLog"
	_log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_box.alignment = BoxContainer.ALIGNMENT_END
	_log_box.add_theme_constant_override("separation", 2)
	add_child(_log_box)
	_log_box.anchor_left = 0.0
	_log_box.anchor_right = 1.0
	_log_box.anchor_top = 1.0
	_log_box.anchor_bottom = 1.0
	_log_box.offset_left = message_label.offset_left
	_log_box.offset_right = message_label.offset_right
	_log_box.offset_bottom = message_label.offset_bottom
	_log_box.offset_top = message_label.offset_bottom - 30.0 * LOG_LINES
	_log_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	message_label.visible = false

func _log(text: String, color: Color, duration: float) -> void:
	if text == "":
		return
	_ensure_log()
	var line: Label = null
	var count := _log_box.get_child_count()
	if count > 0:
		var newest := _log_box.get_child(count - 1) as Label
		if newest.text == text and not newest.is_queued_for_deletion():
			line = newest   # the same news again: refresh it
	if line == null:
		line = Label.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_font_size_override("font_size", 17)
		line.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		line.add_theme_constant_override("shadow_offset_x", 1)
		line.add_theme_constant_override("shadow_offset_y", 2)
		line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var back := StyleBoxFlat.new()   # a faint backing: readable over the map
		back.bg_color = Color(0.05, 0.04, 0.03, 0.6)
		back.set_corner_radius_all(4)
		back.content_margin_left = 8
		back.content_margin_right = 8
		back.content_margin_top = 1
		back.content_margin_bottom = 1
		line.add_theme_stylebox_override("normal", back)
		line.text = text
		_log_box.add_child(line)
		while _log_box.get_child_count() > LOG_LINES:
			var oldest := _log_box.get_child(0)
			_log_box.remove_child(oldest)
			oldest.queue_free()
	line.add_theme_color_override("font_color", color)
	if line.has_meta("fade"):
		var fading := line.get_meta("fade") as Tween
		if fading != null and fading.is_valid():
			fading.kill()   # refreshed while leaving: it stays
		line.remove_meta("fade")
	message_label.text = text          # the newest line (probes and old callers read it)
	var stamp := Time.get_ticks_msec()
	line.set_meta("stamp", stamp)
	_restyle_log()
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(line) and int(line.get_meta("stamp", 0)) == stamp and line.get_parent() == _log_box:
		var tw := line.create_tween()
		line.set_meta("fade", tw)
		tw.tween_property(line, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func() -> void:
			if is_instance_valid(line) and int(line.get_meta("stamp", 0)) == stamp:
				line.queue_free()
				_restyle_log.call_deferred())

## Older lines fade back so the newest reads first.
func _restyle_log() -> void:
	if _log_box == null:
		return
	var lines := _log_box.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	for k in lines.size():
		var age := lines.size() - 1 - k
		(lines[k] as Label).modulate.a = LOG_AGE_ALPHA[mini(age, LOG_AGE_ALPHA.size() - 1)]

## Every line still on screen, oldest first (probes).
func log_lines() -> Array:
	var out: Array = []
	if _log_box != null:
		for n: Node in _log_box.get_children():
			if not n.is_queued_for_deletion():
				out.append((n as Label).text)
	return out

func _on_victory(tally: Dictionary) -> void:
	show_notice("VICTORY! Time %ds — stolen %dg/%dgems — fire Lv%d, scales Lv%d" % [
		int(tally["time_survived"]), tally["gold_stolen"], tally["gems_stolen"],
		tally["fire_level"], tally["scales_level"]], "bonus", 12.0)

# --- minimap (MinimapPanel below; GameManager pushes per-frame dragon dots) ---

func update_minimap_entity(entity_type: String, position: Vector2, remove: bool = false) -> void:
	minimap.set_entity(entity_type, position, remove)

func update_minimap_dragon(dragon_pos: Vector2) -> void:
	minimap.set_dragon(dragon_pos)

func initialize_minimap() -> void:
	minimap.scan_and_redraw()
