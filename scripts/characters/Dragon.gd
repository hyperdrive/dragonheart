extends CharacterBody2D

class_name Dragon

## Player: the dragon. Pure consumer of GameManager (per the decision record):
## reads progression levels, requests upgrades, reports theft via the
## GoldInterceptionSystem, breathes fire onto flammable fields.

signal health_changed(health: int)
signal fire_attacked
signal loot_carried(carry_total: int)
signal flame_charges_changed(charges: int, max_charges: int)
## E on a full dragon: "health" (no heal ⇒ no flames ⇒ waste) or "flames"
## (recharge clamps). HUD flashes the matching chip.
signal eat_refused(what: String)
signal shield_changed(points: int)
signal rider_upgraded

@export_group("Controls")
@export var walk_speed: float = 150.0
@export var fire_rate: float = 1.0

@export_group("Flight")
## Walking is deliberately slower than the old single speed (user spec:
## "walking will be a little more slow"); flight is the fast lane.
@export var fly_speed: float = 300.0
## Q launches a burst of flight; it auto-lands when the burst runs out.
@export var fly_duration: float = 3.0
## Full recovery after landing (user spec: "recharge over 5s"). Any landing
## — auto or early Q — pays the same 5s: cancelling wastes the burst, it
## never shortens the wait.
@export var flight_recharge: float = 5.0
## Wing-flap cadence while airborne (code-driven visuals, like the soldier
## weapon swing — the AnimationPlayer owns Sprite position/rotation, so the
## flap lives on the wing pivots only).
@export var flap_hz: float = 3.2
## How high the dragon rises over the ground while airborne.
@export var flight_lift: float = 34.0

## Flight state (2026-11-09): WALK is the default; Q bursts into FLY for
## fly_duration seconds, then lands and recharges. The HUD chip mirrors
## all three phases via flight_state_changed.
var _flying: bool = false
var _flight_left: float = 0.0
var _flight_recharge_left: float = 0.0
var _flap_phase: float = 0.0
var _lift_current: float = 0.0
var _chip_flying: Variant = null
var _chip_seconds: Variant = null

## Rider system (2026-11-11): when a sacrifice is trained and upgraded,
## the dragon gets a composite sprite and rider combat ability.
var has_rider: bool = false
## Rider arrow reach (archer-like, deliberately NOT fire_reach).
@export var rider_range: float = 260.0

## Permanent flight extension (2026-11-11 wizard item, user: "add a new
## item for longer flight time +3 seconds"): each purchase adds seconds to
## every future Q burst. Repeatable like the flame/range upgrades.
func extend_flight(seconds: float) -> void:
	fly_duration += seconds
	print("Dragon: flight bursts now last %.1fs!" % fly_duration)

signal flight_state_changed(flying: bool, seconds_left: float, charging: bool)

## Slayer attribution for the death chapter (take_damage's killer arg;
## take_damage callers pass "soldier"/"archer"/"king"/"wizard").
var _last_killer: String = ""

## Claw swing (2026-11-09, user: "give dragon claw attack animations").
## Code-driven on the ClawPivot — same pattern as the soldier pickaxe
## swing: a raised slash sweeps down to a slam, glints warm at impact,
## then eases back, with a little body lunge into the strike. Plays on
## every E-strike attempt (hit or miss — the claw swipes either way).
const CLAW_SWING_TIME := 0.26
const CLAW_RAISED_DEG := -52.0
const CLAW_SLAMMED_DEG := 26.0
var _claw_animating := false
var _claw_phase := 0.0

@export_group("Fire breath")
@export var fire_reach: float = 95.0        # ignition distance from the mouth
@export var fire_ignite_cone: float = 0.25  # facing half-plane dot threshold
## Flame economy: breaths are a resource — spent on fire, refilled by eating
## animals (pig +1, cow +2). Empty claws = a very quiet dragon.
@export var max_flame_charges: int = 4
## Wizard-shop shield: absorbs incoming damage until depleted (then gone).
## Purchasable again only once fully lost (see shield_points: 0 ⇒ free slot).
var shield_points: int = 0

var health: int = 100
var max_health: int = 100
var is_firing: bool = false
var fire_cooldown: float = 0.0
var _fire_pulse_timer: float = 0.0
var _fire_pulse_count: int = 0
var flame_charges: float = max_flame_charges
## Temporary speed boost (wizard shop): multiplier on the unmodified `speed`
## while _speed_boost_left > 0. Purchasing refreshes the duration.
var _speed_boost_left: float = 0.0
@export var speed_boost_multiplier: float = 1.6
@export var speed_boost_duration: float = 6.0
## Facing state: 1 = right, -1 = left; mirrors body AND the fire assembly.
var facing: int = 1
## Loot in the claws — banked only when delivered at the lair.
var carried_loot: Dictionary = {"gold": 0, "gems": 0}

@export_group("Loot hauling")
@export var pickup_radius: float = 70.0
@export var lair_delivery_radius: float = 150.0
## True from die() onward: blocks extra damage, input, activity re-entry.
var _dying: bool = false

## Visual base offset (2026-11-13 y-sort): the dragon's underside (Body,
## Sprite-space bottom 28) ends 23px below the node origin once Sprite's
## own −5 is added, so the Vis body rides at −23 — the ORIGIN (the y-sort
## key) sits at the ground contact, like every other object. Applied in
## _tick_flight_visual so the flight lift/bob stay relative. The FireArea
## mouth anchor rides the same −23 (2026-11-13: flame origin tracks the
## mouth, not the feet) — _apply_facing only flips its x, so the tscn y
## is the single source of truth.
const VIS_BASE_LIFT := 23.0

var game_manager: GameManager

@onready var vis: Node2D = $Vis
@onready var sprite: Node2D = $Vis/Sprite
@onready var shadow: Node2D = $Vis/Shadow
@onready var near_wing_outer: Node2D = $Vis/Sprite/NearWingPivot/NearWingOuter
@onready var far_wing_outer: Node2D = $Vis/Sprite/FarWingPivot/FarWingOuter
@onready var tail_pivot: Node2D = $Vis/Sprite/TailPivot
@onready var tail_tip_pivot: Node2D = $Vis/Sprite/TailPivot/TailTipPivot
@onready var eye: Node2D = $Vis/Sprite/NeckPivot/Eye
@onready var neck_pivot: Node2D = $Vis/Sprite/NeckPivot
@onready var near_wing_pivot: Node2D = $Vis/Sprite/NearWingPivot
@onready var far_wing_pivot: Node2D = $Vis/Sprite/FarWingPivot
## Wyvern (2026-11-13): no forelegs — the strike talon rides the near wing's
## wrist, the same joint the dragon walks on.
@onready var claw_pivot: Node2D = $Vis/Sprite/NearWingPivot/NearWingOuter/ClawPivot
@onready var near_hip: Node2D = $Vis/Sprite/NearHipPivot
@onready var far_hip: Node2D = $Vis/Sprite/FarHipPivot
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var fire_area: Area2D = $Vis/FireArea
@onready var flame: Node2D = $Vis/FireArea/Flame
@onready var fire_collision: CollisionShape2D = $Vis/FireArea/FireCollision
@onready var interception_system: GoldInterceptionSystem = $GoldInterceptionSystem


func _ready() -> void:
	add_to_group("dragon")
	
	var goblin_count := 0
	for goblin in get_tree().get_nodes_in_group("goblins"):
		goblin_count += 1
	
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	if game_manager == null:
		push_error("Dragon: GameManager not found — progression/pool reading disabled")
		return
	game_manager.upgrade_purchased.connect(_on_upgrade_purchased)
	sync_from_game_manager()
	interception_system.setup(game_manager)
	flame_charges_changed.emit(int(flame_charges), max_flame_charges)

	# Check if we have a rider and mount them accordingly
	if has_rider:
		_attach_rider()

	# Fire breath window wiring handled in fire_breath(); the idle starts on play.
	fire_area.monitoring = false  # breath window only, set in fire_breath()
	flame.visible = false
	flight_state_changed.emit(false, 0.0, false)  # initial HUD chip state

func sync_from_game_manager() -> void:
	# Armor (scales) sets max health; fire power sets breath damage per burn tick.
	max_health = 100 + (game_manager.scales_level - 1) * 25
	health = mini(health, max_health)
	health_changed.emit(health)

func _on_upgrade_purchased(kind: String, level: int) -> void:
	print("Dragon upgraded ", kind, " to level ", level)
	sync_from_game_manager()

func _physics_process(delta: float) -> void:
	if _dying:
		velocity = Vector2.ZERO
		return
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	if _speed_boost_left > 0.0:
		_speed_boost_left -= delta
	if _strike_cooldown > 0.0:
		_strike_cooldown = maxf(_strike_cooldown - delta, 0.0)
	if is_firing and Input.is_action_pressed("fire") and flame_charges >= 1.0:
		# Pulse: 0.8 s per charge, max 3 pulses (2.4 s total breath duration)
		if _fire_pulse_count < 3:
			_fire_pulse_timer += delta
			if _fire_pulse_timer >= 0.8:
				_fire_pulse_timer = 0.0
				_fire_pulse_count += 1
				fire_breath()
		else:
			# Max pulses reached — stop firing
			is_firing = false
			flame.visible = false
			fire_area.monitoring = false
			_fire_pulse_timer = 0.0
			_fire_pulse_count = 0
	if Input.is_action_just_pressed("fly"):
		_try_flight()
	if _flying:
		_flight_left -= delta
		# TERRAIN: flight never expires when over a lake — and landing
		# over open water is refused (see _try_flight), so the dragon can
		# never end up grounded inside a lake shape.
		if not _over_water() and _flight_left <= 0.0:
			land_flight()
	elif _flight_recharge_left > 0.0:
		_flight_recharge_left -= delta
		if _flight_recharge_left <= 0.0:
			_flight_recharge_left = 0.0
			print("Dragon's wings are rested — the sky awaits! (Q)")

	var input_direction := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		input_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		input_direction.x += 1
	if Input.is_action_pressed("move_up"):
		input_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		input_direction.y += 1

	if input_direction.length() > 0:
		input_direction = input_direction.normalized()

	velocity = input_direction * effective_speed()
	move_and_slide()

	_tick_flight_visual(delta)
	_tick_claw_visual(delta)

	# While the breath window is open, flammable actors/fields in the cone
	# catch fire.
	if is_firing:
		_ignite_flammables()
	
	# Face travel direction: mirrors the body and the whole fire assembly.
	if input_direction.x != 0.0:
		var new_facing := 1 if input_direction.x > 0.0 else -1
		if new_facing != facing:
			facing = new_facing
			_apply_facing()

	# Check for goblin encounter using Dragon's EncounterArea
	var encounter_area := $EncounterArea
	if encounter_area != null:
		var overlapping := encounter_area.get_overlapping_bodies() as Array[Node2D]
		for body in overlapping:
			if body != null and body.has_method("_on_dragon_encounter"):
				body._on_dragon_encounter()

	if Input.is_action_just_pressed("fire"):
		fire_breath()

## Intentional E press (decision records 2026-11-08-dragon-strikes-respawn-
## prices and 2026-11-08-soldier-strike): a CONTEXT action — the nearest
## valid target wins:
##   • pen with stock in its reach → eat one animal
##   • farmer/miner within strike_reach → deliberate strike-kill
##   • ordinary soldier within strike_reach → chance kill (recharge-gated)
## Eating stays full-health-refused with chip flashes (see
## 2026-11-08-manual-eat-wizard-menu); townsfolk kills pay +5 health and
## STEAL the payload before death. Flyover interception is steal-only.
@export_group("Strikes")
## E-kill reach for townsfolk (pens ration their own pen_radius).
@export var strike_reach: float = 100.0
## Health restored per deliberate E-kill (townsfolk only).
@export var kill_health_gain: int = 5
## Soldier strike: chance kill lottery (Brute Force raises by 5% each buy),
## with a short recharge (first Speed buy drops 0.5 → 0.2 permanently).
@export var soldier_strike_chance: float = 0.15
@export var strike_recharge: float = 0.5
const STRIKE_CHANCE_CAP := 0.35
var _strike_cooldown: float = 0.0

signal strike_missed

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("eat") and not _dying:
		_try_context_action()

func _try_context_action() -> void:
	var pen := _nearest_edible_pen()
	var victim := _nearest_strike_target()
	var soldier := _soldier_in_strike_reach()
	if pen == null and victim == null and soldier == null:
		print("Dragon: nothing to eat or strike in reach!")
		return
	var pen_dist := INF if pen == null \
		else global_position.distance_to(pen.global_position)
	var victim_dist := INF if victim == null \
		else global_position.distance_to(victim.global_position)
	var soldier_dist := INF if soldier == null \
		else global_position.distance_to(soldier.global_position)
	if pen_dist <= victim_dist and pen_dist <= soldier_dist:
		_eat_meal_from(pen)      # may refuse when full (never consumes)
	elif victim_dist <= soldier_dist:
		_strike_kill(victim)
	else:
		_strike_soldier(soldier)

## Nearest pen (either species) with stock within its own reach, else null.
func _nearest_edible_pen() -> AnimalPen:
	var best: AnimalPen = null
	var best_dist := INF
	for group: String in ["pig_pens", "cow_pens"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var pen := node as AnimalPen
			if pen == null or pen.animal_count() == 0:
				continue
			var dist := global_position.distance_to(pen.global_position)
			if dist <= pen.pen_radius and dist < best_dist:
				best_dist = dist
				best = pen
	return best

## Nearest alive farmer/miner within strike_reach, else null.
func _nearest_strike_target() -> BaseNPC:
	var best: BaseNPC = null
	var best_dist := INF
	for group: String in ["farmers", "miners"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var npc := node as BaseNPC
			if npc == null or not npc.is_alive:
				continue
			var dist := global_position.distance_to(npc.global_position)
			if dist <= strike_reach and dist < best_dist:
				best_dist = dist
				best = npc
	return best

## Nearest ordinary soldier (or encountered goblin) within strike reach —
## while the strike is recharging soldiers are NOT valid targets (cooldown
## keeps E on other candidates), and the King is excluded (his own battle
## rules). Goblins fight like soldiers (Goblin.gd design note) and join the
## same chance-strike pool — but only AFTER their first-encounter popup:
## story before combat, so an unreached goblin is not E-strikeable.
func _soldier_in_strike_reach() -> BaseNPC:
	if _strike_cooldown > 0.0:
		return null
	var best: BaseNPC = null
	var best_dist := INF
	for group: String in ["soldiers", "goblins"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var npc := node as BaseNPC
			if npc == null or not npc.is_alive or npc.is_in_group("king"):
				continue
			if npc.npc_type == "goblin" \
					and int(npc.service_state) == Goblin.ServiceState.UNINITIALIZED:
				continue  # not encountered yet: popup must come first
			var dist := global_position.distance_to(npc.global_position)
			if dist <= strike_reach and dist < best_dist:
				best_dist = dist
				best = npc
	return best

## Soldier strike: spends the recharge FIRST, then rolls the kill lottery.
## A miss flashes the threat chip via strike_missed (decision record).
func _strike_soldier(soldier: BaseNPC) -> void:
	_strike_cooldown = strike_recharge
	_play_claw_swing()
	var odds := int(soldier_strike_chance * 100.0)
	if randf() >= soldier_strike_chance:
		strike_missed.emit()
		print("Dragon's claw swipes past the %s! (%d%% odds)" % [soldier.npc_type, odds])
		return
	soldier.kill_by_dragon()
	print("Dragon mauled the %s! (%d%% odds paid off)" % [soldier.npc_type, odds])

## Deliberate kill: steal payload BEFORE death so an E-killed loaded miner
## banks the cart into the claws; +5 health after regardless.
func _strike_kill(npc: BaseNPC) -> void:
	_play_claw_swing()
	var loot := npc.steal_payload()
	if int(loot["amount"]) > 0 and str(loot["res_type"]) != "":
		take_loot(str(loot["res_type"]), int(loot["amount"]))
		print("Dragon ripped %d %s from the %s!" % [
			int(loot["amount"]), loot["res_type"], npc.npc_type])
	npc.kill_by_dragon()
	health = mini(health + kill_health_gain, max_health)
	health_changed.emit(health)
	print("Dragon struck down the %s! (+%d health)" % [npc.npc_type, kill_health_gain])

## The pen-meal half of the context action (see
## 2026-11-08-manual-eat-wizard-menu for the refusal rules; meal payoffs
## re-specced 2026-11-10: cow = FULL health + full flames, pig = 2 flames).
func _eat_meal_from(pen: AnimalPen) -> void:
	var full_restore := pen.full_restore
	# Refusals (a meal the dragon cannot benefit from is never spent). A
	# meal is wasted only when NOTHING it gives can land (2026-11-14: pigs
	# now heal 10-20 as well as +2 flames — eat one at full health and it
	# still refills flames, at full flames it still heals).
	var health_full := health >= max_health
	var flames_full := flame_charges >= max_flame_charges
	var heals := full_restore or pen.heal_amount > 0
	var fuels := full_restore or pen.flame_recharge > 0
	var health_gain := heals and not health_full
	var flame_gain := fuels and not flames_full
	if not health_gain and not flame_gain:
		if heals:
			eat_refused.emit("health")
		if fuels:
			eat_refused.emit("flames")
		print("Dragon: full — the %s would be wasted!" % pen.animal_name)
		return
	var meal := pen.take_animal_for_dragon(self)
	if meal.is_empty():
		return
	# TTRPG first-meal chapters (once per run each): the pig and the cow
	# both earned their own story before becoming calories.
	var meal_kind := "pig_eaten" if pen.animal_name == "pig" else "cow_eaten"
	if game_manager != null:
		game_manager.notify_story(meal_kind)
	if full_restore:
		# The prize meal: complete reset, both meters topped in one bite.
		health = max_health
		health_changed.emit(health)
		flame_charges = float(max_flame_charges)
		flame_charges_changed.emit(int(flame_charges), max_flame_charges)
	else:
		var healed := mini(int(meal["heal"]), max_health - health)
		health += healed
		health_changed.emit(health)
		var had := flame_charges
		flame_charges = minf(
			flame_charges + float(int(meal["flame"])), float(max_flame_charges))
		if flame_charges != had:
			flame_charges_changed.emit(int(flame_charges), max_flame_charges)
		if flame_charges >= max_flame_charges:
			eat_refused.emit("flames")  # heal happened, but the recharge clamped

## Mirror the visual body AND the fire assembly to the facing side. Done with
## explicit component mirroring — no negative scale on the physics Area2D.
## The rider needs no special case: it lives INSIDE Vis/Sprite, so the
## sprite.scale.x flip mirrors it along with the body.
# scripts/characters/Dragon.gd
func _apply_facing() -> void:
	sprite.scale.x = float(facing)
	fire_area.position.x = 63.0 * float(facing)   # mouth tip (Sprite-space ~64)
	fire_collision.position.x = 27.0 * float(facing)  # adjust hitbox offset too
	flame.scale.x = float(facing)

## Everything flammable caught in the breath cone ignites: farmers, miners,
## soldiers, goblins (+ the King), and crop fields (Field.burn → stubble →
## slow regrow). Goblins only AFTER their first encounter (popup honored —
## story before combat, user spec).
## The wyvern redesign (2026-11-13) moved the mouth 21px further forward
## (Sprite x 42 → 63). The breath cone is measured from this shifted point
## so the ignition zone still matches the drawn flame — measuring from the
## body origin left the far third of the visible flame harmless (the
## "fire no longer kills farmers" regression, 2026-11-14).
const MOUTH_SHIFT := 21.0

func _fire_origin() -> Vector2:
	return global_position + Vector2(MOUTH_SHIFT * float(facing), 0.0)

## Everything flammable in the breath cone ignites. EVERY actor burns
## (2026-11-14 user: "fire should kill all the actors, but the wizard who
## survives two blasts" — Wizard.catch_fire counts the blasts).
const FLAMMABLE_GROUPS: Array[String] = ["farmers", "miners", "soldiers",
	"goblins", "king", "wizard", "adventurers", "fields"]

func _ignite_flammables() -> void:
	var facing_vec := Vector2(float(facing), 0.0)
	var origin := _fire_origin()
	for group: String in FLAMMABLE_GROUPS:
		for node: Node in get_tree().get_nodes_in_group(group):
			# Fields are not BaseNPC subclasses, so handle them first
			if node is Field:
				var field := node as Field
				var to_target := field.global_position - origin
				if to_target.length() <= fire_reach and \
				   to_target.normalized().dot(facing_vec) >= fire_ignite_cone:
					field.burn()
				continue
			
			# Now handle BaseNPC subclasses (farmers, miners, soldiers, goblins, king)
			var base := node as BaseNPC
			if base == null:
				continue
			if base.npc_type == "goblin" \
					and int((node as Goblin).service_state) == Goblin.ServiceState.UNINITIALIZED:
				continue  # never encountered: the dragon cannot ignite it yet
			var target_pos: Vector2 = base.global_position
			var to_target := target_pos - origin
			if to_target.length() <= fire_reach and \
			   to_target.normalized().dot(facing_vec) >= fire_ignite_cone:
				base.catch_fire()

func _process(delta: float) -> void:
	# Auto-theft: the core loop. When a payload carrier is in range and
	# cooldown allows, attempt an interception. (Dead dragons steal nothing.)
	if _dying:
		return
	if interception_system == null or game_manager == null:
		return
	var opportunities := interception_system.check_interception_opportunities(global_position)
	if opportunities.size() > 0:
		interception_system.attempt_interception(self, opportunities[0])
	_scoop_loose_loot()
	_deliver_carried_loot()
	
	# Rider combat: shoot at soldiers and goblins if rider is active
	if has_rider and not _dying:
		_rider_shoot_at_enemies(delta)

# --- loot hauling: scoop → claws → lair ---------------------------------------

## Loose drops (miner panic-drops) become collectible after their settle delay.
## One scoop per frame keeps the pocketing readable.
func _scoop_loose_loot() -> void:
	for drop: Node in get_tree().get_nodes_in_group("loose_loot"):
		var gold_drop := drop as GoldDrop
		if gold_drop == null or not gold_drop.settled:
			continue
		if global_position.distance_to(gold_drop.global_position) > pickup_radius:
			continue
		take_loot(gold_drop.res_type, gold_drop.amount)
		print("Dragon collected %d %s — %d loot carried, deliver to the lair!" % [
			gold_drop.amount, gold_drop.res_type, carried_total()])
		gold_drop.queue_free()
		return  # one pickup per frame

## Stash only grows at the lair: carried loot banks inside the cave radius.
func _deliver_carried_loot() -> void:
	var carry := carried_total()
	if carry == 0:
		return
	var lair := get_tree().get_first_node_in_group("dragon_lair") as Node2D
	if lair == null:
		return
	if global_position.distance_to(lair.global_position) > lair_delivery_radius:
		return
	for res_type: String in carried_loot:
		var amount: int = carried_loot[res_type]
		if amount > 0:
			game_manager.add_stolen(res_type, amount)
			print("Dragon banked %d %s at the lair" % [amount, res_type])
			carried_loot[res_type] = 0
	loot_carried.emit(0)

## Everything (drops, interception, mine landing) funnels through here.
func take_loot(res_type: String, amount: int) -> void:
	if not carried_loot.has(res_type):
		carried_loot[res_type] = 0
	carried_loot[res_type] += amount
	loot_carried.emit(carried_total())

func carried_total() -> int:
	var total := 0
	for amount: int in carried_loot.values():
		total += amount
	return total

## Pulsed fire breath — builds up sharply, then disperses into smaller embers.
## While the fire key is held and charges are available, the animation cycles,
## spending 1 charge per 0.8 s pulse.
func fire_breath() -> void:
	if _dying or is_firing or fire_cooldown > 0.0:
		return
	if flame_charges < 1.0:
		print("Dragon: flame spent — eat a pig (+1) or a cow (+2) to recharge!")
		return
	flame_charges -= 1.0
	flame_charges_changed.emit(int(flame_charges), max_flame_charges)
	is_firing = true
	fire_area.monitoring = true   # breath window: ignites flammable fields
	flame.visible = true          # visual breath (collision window matches)
	animation_player.play("fire_breath_pulsed")
	fire_attacked.emit()
	# Wait for the current pulse to finish (0.8 s) before re-spending a charge
	await animation_player.animation_finished
	is_firing = false
	flame.visible = false
	fire_area.monitoring = false
	# dispersion pieces (embers) fade out via animation; they're left visible
	# briefly then become invisible — no cleanup needed
	if animation_player.has_animation("idle"):
		animation_player.play("idle")

func take_damage(amount: int, bypass_shield: bool = false,
		killer: String = "") -> void:
	if _dying:
		return
	# Who came for the dragon's last hoard? The death chapter names the
	# slayer (2026-11-09 user: "take into account which NPC killed it").
	if killer != "":
		_last_killer = killer
	var damage_reduction := 0
	if game_manager != null:
		damage_reduction = (game_manager.scales_level - 1) * 2
	var incoming := maxi(1, amount - damage_reduction)
	# Wizard shield pool absorbs first (and is lost with use, decision record).
	if shield_points > 0 and not bypass_shield:
		var absorbed := mini(shield_points, incoming)
		shield_points -= absorbed
		incoming -= absorbed
		shield_changed.emit(shield_points)
		print("Shield absorbed %d damage (%d shield left)!" % [
			absorbed, shield_points])
	health -= incoming
	health_changed.emit(health)
	if health <= 0:
		die()

# --- flight (2026-11-09, user spec: Q, 3s fast flight, 5s recharge) ------------

## Q toggles: ground+ready → take off; airborne → deliberate early landing
## (refund: unused burst seconds shorten the recharge); recharging → refused
## with the wait printed. Landing over open water is refused (2026-11-13:
## lakes block the grounded dragon again) — otherwise the dragon would
## touch down INSIDE a lake shape and be trapped by it.
func _try_flight() -> void:
	if _dying:
		return
	if _flying:
		if _over_water():
			print("Too much water below to land — glide to a shore! (Q)")
			return
		land_flight()
		return
	if _flight_recharge_left > 0.0:
		print("Wing muscles still aching — airborne again in %ds!"
			% ceili(_flight_recharge_left))
		return
	_flying = true
	_flight_left = fly_duration
	# ALOFT: treeline AND lakes are beneath the wings (trees, layer 5 /
	# value 16; lakes, layer 6 / value 32) — mountains and boundary walls
	# (layer 1) still block the flight lane. z_index 100 lifts the dragon
	# ABOVE the whole y-sorted scene (2026-11-13: flying = top of the world).
	set_collision_mask_value(5, false)
	set_collision_mask_value(6, false)
	z_index = 100
	print("Your wings snap wide — AIRBORNE! (%.0fx speed for %ds)" % [
		fly_speed / walk_speed, int(fly_duration)])
	_emit_flight_chip(true)

## Touch down: the recharge always pays in full (spec: "recharge over 5s").
## An early Q costs the unused burst — it never buys back wait time.
func land_flight() -> void:
	_flying = false
	_flight_left = 0.0
	_flight_recharge_left = flight_recharge
	# Grounded again: trees AND lakes block the dragon's lane exactly as
	# for walkers (2026-11-13: walking across a lake is NOT allowed).
	set_collision_mask_value(5, true)
	set_collision_mask_value(6, true)
	z_index = 0
	print("Dragon folds back to the ground — wings tire (%ds till ready)."
		% ceili(_flight_recharge_left))
	_emit_flight_chip(true)

## True while the dragon's center sits over lake water (used to keep the
## flight burst alive over lakes and to refuse landing there). Reach
## follows the lake's ACTUAL shape radius — merged lakes (2026-11-13)
## grow past the default 62px, so a fixed offset would miss their shores.
func _over_water() -> bool:
	for water_node in get_tree().get_nodes_in_group("water"):
		var lake := water_node as StaticBody2D
		if lake == null:
			continue
		var reach := 70.0
		var col := lake.get_node_or_null("CollisionShape2D") \
			as CollisionShape2D
		if col != null and col.shape is CircleShape2D:
			reach = (col.shape as CircleShape2D).radius + 20.0
		if lake.global_position.distance_to(global_position) < reach:
			return true
	return false

## One visual state machine: lift/bob on the Vis wrapper (the AnimationPlayer
## animates Sprite itself — Vis keeps code and tracks from fighting), wing
## pivots flap while airborne, and the detached Shadow stays on the ground,
## shrinking + fading with altitude.
func _tick_flight_visual(delta: float) -> void:
	if _dying:
		return
	if _flying:
		_flap_phase += delta * flap_hz
	var lift_target: float = flight_lift if _flying else 0.0
	_lift_current = move_toward(_lift_current, lift_target, flight_lift * 5.0 * delta)
	var lift_ratio: float = _lift_current / flight_lift
	# Body rides the stroke: the downstroke pushes it up, the recovery lets
	# it settle — lift peaks just after the wings bottom out.
	var bob: float = 0.0
	if _flying:
		bob = sin((_flap_phase - 0.12) * TAU) * 3.5 * lift_ratio
	# VIS_BASE_LIFT puts the ground contact at the node origin (y-sort base);
	# the flight lift/bob ride on top of it.
	vis.position.y = -_lift_current + bob * 0.4 - VIS_BASE_LIFT + _walk_bob()
	_pose_limbs(delta)
	# Shadow stays on the ground under the lifted Vis, shrinking + fading.
	shadow.position.y = _shadow_ground_y + _lift_current - bob * 0.4
	shadow.scale = Vector2(1.0 - lift_ratio * 0.28, 1.0 - lift_ratio * 0.1)
	shadow.modulate.a = 1.0 - lift_ratio * 0.5
	_tick_idle_life(delta)
	_emit_flight_chip()

# --- wing / tail / eye art (2026-11-13 dragon redesign) -----------------------

## Wing poses are expressed in the wing's own pointing-UP frame:
##   elev  — scale.y foreshortening: 1 = raised high, 0 = edge-on toward the
##           camera, negative = swung below (on the ground the wing is
##           flipped fully down so the arm becomes a front leg).
##   sweep — shoulder rotation in degrees.
##   fold  — wrist rotation in degrees (the hand + outer membrane).
##   chord — outer membrane width (1 = spread, <1 = partly furled).
##   inner — inner membrane width (the arm-to-flank web furls when folded).
##   tint  — 0..1 warm underside light (flight only).
##   hand  — hand scale.y: -1 on the ground un-flips the folded hand so its
##           fingers rise up along the flank while the arm points down.
## Wyvern ground stance: the arm reaches down to the wrist talon planted on
## the ground; the hand folds back up along the flank like a tent.
const WING_GROUND := {"elev": -1.0, "sweep": -27.0, "fold": -52.0,
	"chord": 0.36, "inner": 0.55, "tint": 0.0, "hand": -1.35}
## Walk cycle: each limb spends STANCE of its cycle planted, sweeping from
## its forward reach to its back reach, then lifts and swings forward.
## Lateral-sequence gait: near hind → near wing → far hind → far wing.
const STANCE := 0.62
const WING_STEP_FWD := -44.0
const WING_STEP_BACK := -12.0
const LEG_STEP_FWD := -24.0
const LEG_STEP_BACK := 20.0
## World px the dragon travels per full walk cycle (feet slip a little at
## the boost speeds — readable beats exact).
const WALK_STRIDE_PX := 62.0
## Fraction of the flap cycle spent on the (fast, powerful) downstroke; the
## rest is the slower recovery upstroke.
const DOWNSTROKE := 0.42
## Span multipliers on the authored wing geometry (the far wing is also
## drawn smaller in the tscn for perspective).
const NEAR_WING_SCALE := 1.8
const FAR_WING_SCALE := 1.7
var _wing_blend: float = 0.0  # 0 = ground stance, 1 = full flight stroke
var _walk_phase: float = 0.0
var _walk_amt: float = 0.0    # 0 = standing, 1 = full walk cycle
var _shadow_ground_y: float = 23.5
var _idle_time: float = 0.0
var _blink_left: float = 0.0
var _next_blink: float = 3.0

## One flap-cycle sample at phase p ∈ [0,1): a quick downstroke with the
## wing fully spread, then an upstroke where the wrist flexes and the hand
## trails (the wingtip lags the arm), unfurling again at the top.
func _flap_pose(p: float) -> Dictionary:
	var elev: float
	var fold: float
	var chord: float
	var sweep: float
	if p < DOWNSTROKE:
		var t := p / DOWNSTROKE
		var e := smoothstep(0.0, 1.0, t)
		elev = lerpf(1.0, -0.82, e)
		# hand snaps open at the top and stays braced through the stroke
		fold = lerpf(-14.0, 6.0, minf(t * 2.5, 1.0))
		chord = lerpf(0.9, 1.05, minf(t * 3.0, 1.0))
		sweep = lerpf(-14.0, -6.0, e)
	else:
		var t := (p - DOWNSTROKE) / (1.0 - DOWNSTROKE)
		var e := smoothstep(0.0, 1.0, t)
		elev = lerpf(-0.82, 1.0, e)
		# wrist flexes on recovery: the hand trails behind, then flicks up
		var flex := sin(t * PI)
		fold = lerpf(6.0, -14.0, smoothstep(0.7, 1.0, t)) - flex * 46.0
		chord = lerpf(1.05, 0.9, t) - flex * 0.3
		sweep = lerpf(-6.0, -14.0, e) - flex * 12.0
	# Never fully edge-on — keeps a sliver of membrane visible mid-stroke.
	if absf(elev) < 0.14:
		elev = 0.14 * (signf(elev) if elev != 0.0 else 1.0)
	return {"elev": elev, "sweep": sweep, "fold": fold, "chord": chord,
		"inner": 1.0, "tint": clampf(-elev, 0.0, 1.0), "hand": 1.0}

## Wing-as-foreleg step at limb phase p (0 = touch-down).
func _wing_step_pose(p: float) -> Dictionary:
	var pose: Dictionary = WING_GROUND.duplicate()
	if p < STANCE:
		pose["sweep"] = lerpf(WING_STEP_FWD, WING_STEP_BACK, p / STANCE)
	else:
		var t := (p - STANCE) / (1.0 - STANCE)
		pose["sweep"] = lerpf(WING_STEP_BACK, WING_STEP_FWD, smoothstep(0.0, 1.0, t))
		# lift the wrist clear of the ground: shorten the reach mid-swing
		pose["elev"] = -1.0 + sin(t * PI) * 0.16
		pose["fold"] += sin(t * PI) * 10.0
	return pose

## Hind leg step at limb phase p: hip rotation plus a lift on the swing.
func _pose_hind_leg(hip: Node2D, p: float, amt: float) -> void:
	var rot: float
	var lift := 0.0
	if p < STANCE:
		rot = lerpf(LEG_STEP_FWD, LEG_STEP_BACK, p / STANCE)
	else:
		var t := (p - STANCE) / (1.0 - STANCE)
		rot = lerpf(LEG_STEP_BACK, LEG_STEP_FWD, smoothstep(0.0, 1.0, t))
		lift = sin(t * PI) * 0.15
	# In flight the legs trail back, talons tucked.
	hip.rotation_degrees = lerpf(rot * amt, 38.0, _wing_blend)
	hip.scale.y = 1.0 - lerpf(lift * amt, 0.12, _wing_blend)

## Wing-talon strike (E): the near wing rears up forward and slams down,
## driven by the shared claw-swing clock (_claw_phase).
func _strike_pose(base: Dictionary) -> Dictionary:
	var pose: Dictionary = base.duplicate()
	var reach := 1.0
	if _claw_phase < 0.45:
		reach = smoothstep(0.0, 1.0, _claw_phase / 0.45)
	pose["sweep"] = lerpf(-128.0, -22.0, reach)
	pose["elev"] = -1.0
	pose["fold"] = lerpf(-20.0, WING_GROUND["fold"], reach)
	var w := 1.0 - smoothstep(0.6, 1.0, _claw_phase)
	return _blend_pose(base, pose, w)

func _apply_wing(pivot: Node2D, outer: Node2D, pose: Dictionary, base_scale: float) -> void:
	pivot.rotation_degrees = pose["sweep"]
	pivot.scale = Vector2(base_scale * pose["inner"], base_scale * pose["elev"])
	outer.rotation_degrees = pose["fold"]
	outer.scale = Vector2(pose["chord"], pose["hand"])
	# Underside catches warm light when the wing swings below in flight.
	var tint := Color(1.0, 1.0, 1.0).lerp(Color(1.18, 0.95, 0.78), pose["tint"])
	if pivot == far_wing_pivot:
		tint = tint * Color(0.62, 0.55, 0.58)
	pivot.modulate = tint

func _blend_pose(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var r := {}
	for k: String in a:
		r[k] = lerpf(a[k], b[k], t)
	return r

## All limbs, every physics frame: ground stance / walk cycle / strike on
## the ground, blended into the flap cycle by _wing_blend.
func _pose_limbs(delta: float) -> void:
	_wing_blend = move_toward(_wing_blend, 1.0 if _flying else 0.0, delta * 4.0)
	var speed := velocity.length() if not _flying else 0.0
	_walk_amt = move_toward(_walk_amt, 1.0 if speed > 10.0 else 0.0, delta * 5.0)
	if speed > 10.0:
		_walk_phase += delta * speed / WALK_STRIDE_PX
	var stand: Dictionary = WING_GROUND.duplicate()
	stand["fold"] += sin(_idle_time * 1.7) * 3.0   # breathing
	var w := fposmod(_walk_phase, 1.0)
	var near_pose := _blend_pose(stand, _wing_step_pose(fposmod(w + 0.25, 1.0)), _walk_amt)
	var far_pose := _blend_pose(stand, _wing_step_pose(fposmod(w + 0.75, 1.0)), _walk_amt)
	if _claw_animating:
		near_pose = _strike_pose(near_pose)
	if _wing_blend > 0.0:
		var p := fposmod(_flap_phase, 1.0)
		# Both wings beat together; the far one trails by a hair (depth read).
		near_pose = _blend_pose(near_pose, _flap_pose(p), _wing_blend)
		far_pose = _blend_pose(far_pose, _flap_pose(fposmod(p - 0.04, 1.0)), _wing_blend)
	_apply_wing(near_wing_pivot, near_wing_outer, near_pose, NEAR_WING_SCALE)
	_apply_wing(far_wing_pivot, far_wing_outer, far_pose, FAR_WING_SCALE)
	_pose_hind_leg(near_hip, w, _walk_amt)
	_pose_hind_leg(far_hip, fposmod(w + 0.5, 1.0), _walk_amt)

## Body rise/fall on the walk: lowest as each limb plants (4 footfalls per
## cycle, but hind plants are heavier).
func _walk_bob() -> float:
	var t := _walk_phase * TAU
	return (sin(t * 2.0) * 0.9 + sin(t * 4.0) * 0.3) * _walk_amt

## Tail sway (lazy on the ground, streaming + whipping in flight) and an
## occasional blink. Purely cosmetic; never touches the AnimationPlayer's
## Sprite tracks.
func _tick_idle_life(delta: float) -> void:
	_idle_time += delta
	if _flying:
		var p := _flap_phase * TAU
		tail_pivot.rotation_degrees = -6.0 + sin(p - 1.2) * 5.0
		tail_tip_pivot.rotation_degrees = sin(p - 2.2) * 12.0
	else:
		tail_pivot.rotation_degrees = sin(_idle_time * 1.3) * 4.0
		tail_tip_pivot.rotation_degrees = sin(_idle_time * 1.3 - 1.1) * 10.0
	if _blink_left > 0.0:
		_blink_left -= delta
		eye.scale.y = 0.15 if _blink_left > 0.0 else 1.0
	else:
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink_left = 0.13
			_next_blink = randf_range(2.5, 5.5)

## Push chip updates on phase changes AND at each whole-second boundary so
## the HUD shows a readable countdown without a per-frame signal storm.
func _emit_flight_chip(force: bool = false) -> void:
	var seconds := ceili(_flight_left) if _flying else ceili(_flight_recharge_left)
	if force or seconds != _chip_seconds or _flying != _chip_flying:
		_chip_flying = _flying
		_chip_seconds = seconds
		flight_state_changed.emit(_flying, float(seconds), _flight_recharge_left > 0.0)

# --- claw swing (2026-11-09) ---------------------------------------------------

## Arm the one-shot swing: raised → slam → ease home, glint at impact.
## Called on every E-strike attempt, hit or miss.
func _play_claw_swing() -> void:
	if claw_pivot == null or _dying:
		return
	_claw_animating = true
	_claw_phase = 0.0

## One-shot progress in _physics_process (synchronous state, no coroutines).
func _tick_claw_visual(delta: float) -> void:
	if not _claw_animating:
		return
	_claw_phase = minf(_claw_phase + delta / CLAW_SWING_TIME, 1.0)
	var deg: float
	if _claw_phase < 0.45:      # raise high → slam down
		deg = lerpf(CLAW_RAISED_DEG, CLAW_SLAMMED_DEG,
			minf(_claw_phase / 0.45, 1.0))
	else:                        # slam → ease back to resting stride
		deg = lerpf(CLAW_SLAMMED_DEG, 0.0,
			(_claw_phase - 0.45) / 0.55)
	claw_pivot.rotation_degrees = deg
	# warm metal glint right at impact
	var glint: bool = _claw_phase > 0.32 and _claw_phase < 0.58
	(claw_pivot.get_node("Claw") as CanvasItem).modulate = \
		Color(1.0, 0.82, 0.5) if glint else Color.WHITE
	# body lunge into the strike (flight only owns vis.y — x is free)
	vis.position.x = sin(_claw_phase * PI) * 7.0
	if _claw_phase >= 1.0:
		_claw_animating = false
		claw_pivot.rotation_degrees = 0.0
		(claw_pivot.get_node("Claw") as CanvasItem).modulate = Color.WHITE
		vis.position.x = 0.0

# --- wizard-shop upgrades (purchased via GameManager.prices) -------------------

## Flame capacity +n (max). The purchased charges arrive loaded — a bought
## flame you cannot breathe immediately is a store complaint, not a feature.
func increase_flame_capacity(amount: int) -> void:
	max_flame_charges += amount
	flame_charges = minf(flame_charges + float(amount), float(max_flame_charges))
	flame_charges_changed.emit(int(flame_charges), max_flame_charges)
	print("Dragon flame capacity +%d (max %d)!" % [amount, max_flame_charges])

## Breath reach +px, permanent.
func increase_flame_range(add_px: float) -> void:
	fire_reach += add_px
	print("Dragon flame range +%dpx (reach %0.0f)!" % [int(add_px), fire_reach])

## Shield restock: refused while any shield remains (non-stackable pool).
func add_shield(points: int) -> bool:
	if shield_points > 0:
		return false
	shield_points = points
	shield_changed.emit(shield_points)
	print("Dragon shielded for %d points!" % shield_points)
	return true

## Speed boost: activates OR refreshes (non-stacking multiplier, decision
## record). Countdown runs in _physics_process.
func activate_speed_boost() -> void:
	_speed_boost_left = speed_boost_duration
	print("Dragon feels fast! (%.0fx for %ds)" % [
		speed_boost_multiplier, speed_boost_duration])

## First Speed purchase EVER unlocks the fast strike cadence permanently
## (decision 2026-11-08-soldier-strike); later buys are a no-op here.
func unlock_fast_strike() -> void:
	if strike_recharge <= 0.2:
		return
	strike_recharge = 0.2
	print("Dragon strikes flow faster now (0.2s recharge)!")

## Brute Force purchase: raise the soldier kill lottery (+5% per buy).
## Returns false while capped — the caller must refuse payment then.
func can_add_strike() -> bool:
	return soldier_strike_chance < STRIKE_CHANCE_CAP

func add_strike_chance(add: float) -> bool:
	if not can_add_strike():
		return false
	soldier_strike_chance = minf(soldier_strike_chance + add, STRIKE_CHANCE_CAP)
	print("Dragon strike chance now %d%%!" % int(soldier_strike_chance * 100.0))
	return true

## Effective move speed in _physics_process — the flight lane replaces the
## old single `speed` (walking slowed, flying fast); boost stacks on both.
func effective_speed() -> float:
	var base := fly_speed if _flying else walk_speed
	return base * (speed_boost_multiplier if _speed_boost_left > 0.0 else 1.0)

func die() -> void:
	# Re-entry guard: several attacks can land during the death animation;
	# each call would await animation_finished and try to reload the scene.
	if _dying:
		return
	_dying = true
	# A falling-dying dragon lands HARD: reset every flight visual so the
	# death animation plays from the ground pose.
	_flying = false
	_flight_left = 0.0
	_flight_recharge_left = 0.0
	_lift_current = 0.0
	# Base lift, not 0 — zero sank the corpse 23px into the ground.
	vis.position.y = -VIS_BASE_LIFT
	vis.position.x = 0.0
	_wing_blend = 0.0
	_walk_amt = 0.0
	_apply_wing(near_wing_pivot, near_wing_outer, WING_GROUND, NEAR_WING_SCALE)
	_apply_wing(far_wing_pivot, far_wing_outer, WING_GROUND, FAR_WING_SCALE)
	_pose_hind_leg(near_hip, 0.0, 0.0)
	_pose_hind_leg(far_hip, 0.0, 0.0)
	shadow.position.y = _shadow_ground_y
	_claw_animating = false
	claw_pivot.rotation_degrees = 0.0
	(claw_pivot.get_node("Claw") as CanvasItem).modulate = Color.WHITE
	shadow.scale = Vector2.ONE
	shadow.modulate.a = 1.0
	await _play_death()
	# After the await the scene may already be torn down (double reload) or
	# the node detached — the death CHAPTER must play while we are still in
	# a live tree, so hand the run's end to the story system: GameManager
	# opens the killer-named chapter and reloads when it closes.
	if not (is_inside_tree() and get_tree() != null):
		return
	if game_manager != null:
		game_manager.notify_dragon_death(_last_killer)
	else:
		get_tree().reload_current_scene()

# --- death (2026-11-14, user: "the dragon still has a really bad death
# animation") -----------------------------------------------------------------

## The fall of the wyvern, code-driven on the rig (the old track just slid
## the sprite down and tilted it). One timeline, keyed at:
##   0.00 standing
##   0.14 REARS — head thrown back, wings flare wide, a last roar
##   0.34 STAGGERS — the flare fails, knees give, the head drops
##   0.62 COLLAPSES — belly to the earth, wings sprawl, neck slumps
##   1.00 STILL — a final breath of smoke curls from the nostrils as the
##        eye closes and the scales lose their fire.
const DEATH_TIME := 2.8
const _DK := [0.0, 0.14, 0.34, 0.62, 1.0]
const _D_SPRITE_ROT := [0.0, -0.24, 0.06, 0.1, 0.1]
const _D_SPRITE_Y := [0.0, -4.0, 2.0, 9.0, 10.0]
const _D_NECK_ROT := [0.0, -0.45, 0.12, 0.52, 0.6]
const _D_HIP_ROT := [0.0, -14.0, 22.0, 58.0, 62.0]
const _D_HIP_SY := [1.0, 1.0, 0.85, 0.55, 0.5]
const _D_TAIL := [0.0, -10.0, 6.0, 9.0, 10.0]
const _D_TAIL_TIP := [0.0, -18.0, 12.0, 6.0, 4.0]
const WING_FLARE := {"elev": 1.0, "sweep": -10.0, "fold": -8.0,
	"chord": 1.05, "inner": 1.0, "tint": 0.0, "hand": 1.0}
const WING_FAILING := {"elev": 0.35, "sweep": -48.0, "fold": 18.0,
	"chord": 0.9, "inner": 0.9, "tint": 0.0, "hand": 1.0}
const WING_DRAPED := {"elev": 0.9, "sweep": -96.0, "fold": -10.0,
	"chord": 1.1, "inner": 1.0, "tint": 0.0, "hand": 1.0}  # sprawled open on the earth
var _death_smoked := false

func _play_death() -> void:
	animation_player.stop()
	_death_smoked = false
	var tw := create_tween()
	tw.tween_method(_death_pose, 0.0, 1.0, DEATH_TIME)
	tw.tween_interval(0.7)
	await tw.finished

## Piecewise-smooth keyframe sample.
func _dkf(vals: Array, t: float) -> float:
	for i in range(_DK.size() - 1):
		if t <= _DK[i + 1]:
			var u: float = (t - _DK[i]) / (_DK[i + 1] - _DK[i])
			return lerpf(vals[i], vals[i + 1], smoothstep(0.0, 1.0, u))
	return vals[vals.size() - 1]

func _death_pose(t: float) -> void:
	sprite.rotation = _dkf(_D_SPRITE_ROT, t)
	sprite.position.y = -5.0 + _dkf(_D_SPRITE_Y, t)
	if neck_pivot != null:
		neck_pivot.rotation = _dkf(_D_NECK_ROT, t)
	for hip: Node2D in [near_hip, far_hip]:
		hip.rotation_degrees = _dkf(_D_HIP_ROT, t)
		hip.scale.y = _dkf(_D_HIP_SY, t)
	tail_pivot.rotation_degrees = _dkf(_D_TAIL, t)
	tail_tip_pivot.rotation_degrees = _dkf(_D_TAIL_TIP, t)
	# Wings: ground stance → flare → failing → draped on the earth.
	var pose: Dictionary
	if t < _DK[1]:
		pose = _blend_pose(WING_GROUND, WING_FLARE, smoothstep(0.0, 1.0, t / _DK[1]))
	elif t < _DK[2]:
		pose = _blend_pose(WING_FLARE, WING_FAILING, smoothstep(0.0, 1.0, (t - _DK[1]) / (_DK[2] - _DK[1])))
	else:
		pose = _blend_pose(WING_FAILING, WING_DRAPED, smoothstep(0.0, 1.0, minf((t - _DK[2]) / (_DK[3] - _DK[2]), 1.0)))
	_apply_wing(near_wing_pivot, near_wing_outer, pose, NEAR_WING_SCALE)
	var far_pose := pose.duplicate()
	far_pose["sweep"] = pose["sweep"] + 8.0
	_apply_wing(far_wing_pivot, far_wing_outer, far_pose, FAR_WING_SCALE)
	# The eye closes, the fire leaves the scales, a last breath of smoke.
	eye.scale.y = lerpf(1.0, 0.12, smoothstep(0.78, 0.9, t))
	var dim := smoothstep(0.55, 1.0, t)
	vis.modulate = Color(1, 1, 1).lerp(Color(0.66, 0.6, 0.62), dim)
	if t >= 0.8 and not _death_smoked:
		_death_smoked = true
		_last_breath_smoke()

func _last_breath_smoke() -> void:
	if neck_pivot == null:
		return
	var nostril := neck_pivot.get_node_or_null("Nostril") as Polygon2D
	if nostril == null:
		return
	# Nostril polygon is drawn around its own points; sample its first one.
	var poly := nostril.polygon
	var origin := nostril.to_global(poly[0] if poly.size() > 0 else Vector2.ZERO)
	for i in 5:
		var puff := Polygon2D.new()
		var pts := PackedVector2Array()
		for k in 10:
			var a := TAU * float(k) / 10.0
			pts.append(Vector2(cos(a), sin(a)) * 2.4)
		puff.polygon = pts
		puff.color = Color(0.55, 0.53, 0.56, 0.0)
		puff.z_index = 5
		get_parent().add_child(puff)
		puff.global_position = origin
		var drift := Vector2(randf_range(4.0, 10.0) * float(facing), randf_range(-22.0, -14.0))
		var tw := puff.create_tween()
		tw.tween_interval(float(i) * 0.12)
		tw.tween_property(puff, "color:a", 0.6, 0.15)
		tw.parallel().tween_property(puff, "global_position", origin + drift, 1.2)
		tw.parallel().tween_property(puff, "scale", Vector2.ONE * randf_range(1.8, 2.6), 1.2)
		tw.tween_property(puff, "color:a", 0.0, 0.5)
		tw.tween_callback(puff.queue_free)

# Animations (idle, fire_breath) live in Dragon.tscn's AnimationPlayer
# library — do not recreate them in code.

## Loose resources grabbed straight off a mine (landing on the entrance) —
## goes into the claws like everything else; banking happens at the lair.
func collect_resources(resources: Dictionary) -> void:
	if resources.has("gold"):
		take_loot("gold", resources["gold"])
	if resources.has("gems"):
		take_loot("gems", resources["gems"])
	if resources.has("food"):
		eat_food(resources["food"])

func eat_food(food_value: int) -> void:
	health = mini(health + food_value, max_health)
	health_changed.emit(health)

## Upgrade the rider (called by GameManager.purchase_upgrade("rider_train")).
## The trainable gate lives in GameManager; reaching here means it's paid.
func upgrade_rider() -> void:
	if has_rider:
		return  # one rider per dragon — a re-purchase is a no-op
	has_rider = true
	print("Dragon: Upgrading rider with combat capabilities")
	_attach_rider()
	print("Dragon: Rider upgraded — combat enabled")
	rider_upgraded.emit()

## Rider combat: shoot arrows at soldiers and goblins (never farmers/miners,
## never the King — decision record 2026-11-10-sacrifice-system). Ranges
## like an archer, NOT like the breath cone (fire_reach is for fire only).
var _rider_shoot_cooldown: float = 0.0
const RIDER_SHOOT_INTERVAL := 1.5  # seconds between shots
## Per-rider fire rate (2026-11-14): Brannagh the Defiant shoots 1.5x
## faster than any other rider (set by GameManager when she is trained).
var rider_fire_mult: float = 1.0
const RIDER_ARROW_SCENE := preload("res://scenes/objects/Arrow.tscn")

func _rider_shoot_at_enemies(delta: float) -> void:
	if _rider_shoot_cooldown > 0.0:
		_rider_shoot_cooldown -= delta
		return
	# Nearest live soldier/goblin within rider range. is_alive is a PROPERTY
	# on BaseNPC (bug fix 2026-11-11: has_method("is_alive") never matched,
	# so the old scan found zero targets and never fired).
	var nearest_enemy: Node2D = null
	var nearest_dist: float = INF
	for group: String in ["soldiers", "goblins"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var npc := node as BaseNPC
			if npc == null or not npc.is_alive or npc.is_in_group("king"):
				continue
			var dist := global_position.distance_to(npc.global_position)
			if dist <= rider_range and dist < nearest_dist:
				nearest_dist = dist
				nearest_enemy = npc
	if nearest_enemy != null:
		_rider_shoot_at(nearest_enemy)
		_rider_shoot_cooldown = RIDER_SHOOT_INTERVAL / maxf(rider_fire_mult, 0.1)

## Loose one rider arrow. Arrow.launch aims it; rider_arrow=true makes the
## arrow hunt soldiers/goblins instead of the DRAGON (bug fix 2026-11-11:
## the old set_direction() call didn't exist, and stock arrows home on the
## dragon — the rider would have shot her own mount).
func _rider_shoot_at(target: Node2D) -> void:
	var arrow := RIDER_ARROW_SCENE.instantiate() as Arrow
	if arrow == null:
		push_warning("DragonRider: Arrow scene failed to instantiate")
		return
	arrow.global_position = global_position + Vector2(0.0, -14.0)  # from the saddle
	arrow.rider_arrow = true
	get_tree().root.add_child(arrow)
	arrow.launch(target.global_position, 500.0)
	print("DragonRider: Arrow loosed at the %s" % target.name)

## Mount the rider ON the original vector dragon (2026-11-11, user: "the
## dragon rider version of the dragon sprite should look like a derivative
## of the original dragon sprite"). Revisits the decision record's
## "replace sprite entirely" row toward its composite alternative: the
## ColorRect dragon stays EXACTLY as-is, and the rider is built from
## ColorRects in the same flat side-view style on its back. Parented under
## Vis/Sprite, so the body bob animation, the facing mirror (scale.x flip)
## and the claw-strike lunge all carry the rider along for free.
const RIDER_LEATHER := Color(0.45, 0.3, 0.18)   # armor — echoes the belly tan
const RIDER_DARK := Color(0.25, 0.17, 0.12)     # pants — echoes the dark reds
const RIDER_STEEL := Color(0.55, 0.56, 0.6)     # helm — horn-bone family
const RIDER_SKIN := Color(0.92, 0.78, 0.62)
const RIDER_CAPE := Color(0.55, 0.12, 0.1)      # same red family as the body
const RIDER_WOOD := Color(0.4, 0.26, 0.12)      # bow

func _attach_rider() -> void:
	if sprite == null or not is_instance_valid(sprite):
		push_warning("Dragon: Sprite node is null or invalid")
		return
	if sprite.get_node_or_null("RiderPivot") != null:
		return  # already mounted
	var pivot := Node2D.new()
	pivot.name = "RiderPivot"
	# Seated on the back, just ahead of the wing roots, behind the neck.
	pivot.position = Vector2(11.0, -2.0)
	sprite.add_child(pivot)
	# Cape first (drawn behind), flowing back — ties the rider into the
	# dragon's red palette.
	_rider_rect(pivot, -7.0, -9.0, -2.0, 3.0, RIDER_CAPE, 0.18)
	# Quiver on the back, two arrow shafts peeking over the shoulder.
	_rider_rect(pivot, -5.0, -6.0, -2.0, 3.0, RIDER_DARK)
	_rider_rect(pivot, -4.7, -10.0, -4.1, -5.5, Color(0.75, 0.65, 0.45))
	_rider_rect(pivot, -3.4, -9.0, -2.8, -4.5, Color(0.75, 0.65, 0.45))
	# Leg gripping the body flank + boot (side view: one leg reads cleanest).
	_rider_rect(pivot, -1.0, 2.0, 4.0, 12.0, RIDER_DARK)
	_rider_rect(pivot, -1.0, 10.0, 4.0, 13.5, Color(0.12, 0.08, 0.06))
	# Torso in leather armor, matching the flat-shaded body style.
	_rider_rect(pivot, -2.0, -8.0, 6.0, 4.0, RIDER_LEATHER)
	# Forward arm reaching to the bow (toward the dragon's neck).
	_rider_rect(pivot, 5.0, -6.0, 12.0, -3.0, RIDER_LEATHER)
	# Head + steel helm (color family of the horns).
	_rider_rect(pivot, 0.0, -15.0, 6.0, -9.0, RIDER_SKIN)
	_rider_rect(pivot, -1.0, -17.0, 7.0, -13.0, RIDER_STEEL)
	# Bow held vertical in front, near the neck, with a drawn string.
	_rider_rect(pivot, 11.0, -15.0, 12.5, -2.0, RIDER_WOOD, -0.12)
	_rider_rect(pivot, 11.6, -14.0, 11.9, -3.0, Color(0.92, 0.9, 0.82, 0.85))
	print("Dragon: Rider mounted on the dragon's back")

## One flat ColorRect in the dragon-art style, added to the rider pivot.
func _rider_rect(parent: Node, l: float, t: float, r: float, b: float,
		col: Color, rot_deg: float = 0.0) -> ColorRect:
	var rect := ColorRect.new()
	rect.offset_left = l
	rect.offset_top = t
	rect.offset_right = r
	rect.offset_bottom = b
	rect.color = col
	if rot_deg != 0.0:
		rect.rotation_degrees = rot_deg
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect
