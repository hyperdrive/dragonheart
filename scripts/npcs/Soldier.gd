extends BaseNPC

class_name Soldier

## Town soldier: patrols the city, RALLIES at the gate when the dragon nears,
## and attacks only once the swarm is released (WorldManager.swarm_state).
## docs/plans/2026-11-08-behavior-system-rebuild.md

signal defeated(reward_gold: int)

@export_group("Combat")
@export var aggro_range: float = 300.0
@export var attack_range: float = 60.0
@export var attack_damage: float = 10.0  # DPS while the hitbox touches the dragon
@export var attack_interval: float = 0.5
@export var reward_gold: int = 25

## Contact-DPS accumulator: take_damage wants ints (10 DPS → 1 per 0.1s).
var _contact_debt: float = 0.0

func _ready() -> void:
	# Configure before super._ready() — it syncs health from max_health.
	# Stomp fix (2026-11-09): this profile previously ran UNCONDITIONALLY and
	# silently discarded the King's boss config — King._ready sets its stats
	# before super._ready(), then Soldier._ready overwrote npc_type/health/
	# speed/attack stats: every King in history ran as a 50-HP soldier-flavored
	# unit (10 DPS, npc_type "soldier"). Gate on the BaseNPC default instead:
	# a subclass (King) that already configured itself keeps its values.
	if npc_type == "villager":
		npc_type = "soldier"
		max_health = 50
		speed = 80.0
		danger_radius = 0.0  # soldiers never flee the dragon

	super._ready()
	_resolve_weapon()
	behavior_tree = BehaviorTree.new()
	add_child(behavior_tree)
	behavior_tree.setup(self)
	behavior_tree.register_activity(
		"attack_dragon", 60,
		_pick_dragon_target, attack_interval,
		0.0, _complete_attack,
		_attack_ready, _dragon_in_chase_range
	)
	behavior_tree.register_activity(
		"rally", 40,
		_pick_rally_target, 0.0,
		0.5, _complete_rally,
		_swarm_rallying
	)
	behavior_tree.register_activity(
		"patrol", 10,
		_pick_patrol_target, 0.0,
		1.0, Callable()
	)
	behavior_tree.register_activity(
		"idle", 1,
		_pick_idle_target, 1.5,
		2.0, Callable()
	)

# --- swarm state access ------------------------------------------------------

## The WorldManager owns the swarm coordination; missing manager = old-style
## independent behavior (chase on sight).
func _world_manager() -> WorldManager:
	return get_tree().get_first_node_in_group("world_manager") as WorldManager

func _swarm_rallying() -> bool:
	var world := _world_manager()
	return world != null and world.swarm_state == WorldManager.SwarmState.RALLY

func _swarm_released() -> bool:
	var world := _world_manager()
	return world == null or world.swarm_state == WorldManager.SwarmState.ATTACK

# --- morale: bold soldiers (2026-11-09, user-grilled) --------------------------

## A bold soldier ignores the calm-town aggro gate and hunts the dragon alone.
## Boldness is presence-based and NEVER sticky (re-checked every pick):
##  • leadership: the King within DOUBLE the morale radius (he is fat — his
##    presence reads farther), or
##  • phalanx: at least 2 pals within one morale radius (five body widths,
##    user spec "base distance on soldier width").
## Escalation (2026-11-09, user: "more aggressive, attack the dragon when
## they are bold"): bold sight is now the WHOLE MAP (same reach as a
## released swarm) — a bold phalanx pursues until contact no matter where
## the dragon flies; the only brake is morale decaying (pals/King leave
## the band) → the straggler finishes the current leg and goes home
## (work_check now falls back to aggro_range for a non-bold soldier).
const BODY_WIDTH := 18.0        # matches Soldier.tscn Body ColorRect width
const MORALE_WIDTHS := 5.0      # pal proximity = five soldier widths
const MORALE_KING_DOUBLE := 2.0 # King presence = doubled radius
const BOLD_HUNT_REACH := 4000.0 # whole-map pursuit (2026-11-09 escalation)

func _bold_pals_radius() -> float:
	return BODY_WIDTH * MORALE_WIDTHS

func _bold_king_radius() -> float:
	return BODY_WIDTH * MORALE_WIDTHS * MORALE_KING_DOUBLE

func _is_bold() -> bool:
	var king := get_tree().get_first_node_in_group("king") as Node2D
	if king != null and is_instance_valid(king) \
			and global_position.distance_to(king.global_position) \
				<= _bold_king_radius():
		return true
	var pals := 0
	for n: Node2D in get_tree().get_nodes_in_group("soldiers"):
		if n == self or not is_instance_valid(n):
			continue
		if global_position.distance_to(n.global_position) <= _bold_pals_radius():
			pals += 1
			if pals >= 2:
				return true
	return false

## Morale-aware chase gate: the calm swarm stays home unless bold.
func _attack_ready() -> bool:
	return _swarm_released() or _is_bold()

# --- activity providers & completers ---------------------------------------

## During ATTACK the aggro range widens hugely: the whole swarm hunts.
## BOLD soldiers hunt too (morale) — across the WHOLE MAP (user escalation
## 2026-11-09: "attack the dragon when they are bold").
func _pick_dragon_target() -> Vector2:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return BehaviorTree.TARGET_NONE
	var reach := aggro_range
	if _swarm_released() or _is_bold():
		reach = maxf(reach, BOLD_HUNT_REACH)
	if global_position.distance_to(dragon.global_position) > reach:
		return BehaviorTree.TARGET_NONE
	return dragon.global_position

## Chase gate: bold → chase until contact (morale re-checked per pick);
## non-bold running an old leg stops when the dragon is beyond aggro_range.
func _dragon_in_chase_range() -> bool:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return false
	if _swarm_released() or _is_bold():
		return true
	return global_position.distance_to(dragon.global_position) <= aggro_range

func _complete_attack() -> void:
	pass  # contact DPS is applied in _contact_damage()

## Muster on a loose ring at the rally point (swarm cohesion before the charge).
func _pick_rally_target() -> Vector2:
	var world := _world_manager()
	if world == null:
		return BehaviorTree.TARGET_NONE
	var anchor := world.rally_point + Vector2(randf_range(-50, 50), randf_range(-50, 50))
	return world.terrain_free_target(anchor, 24.0)

func _complete_rally() -> void:
	pass  # arrival is the point; WorldManager counts heads at the gate

## Patrol targets are terrain-cleared (2026-11-09): unpinned goals used to
## land inside city walls — unreachable trips the whole remediation ladder
## could never fix (soldiers grinding in MOVING for minutes).
func _pick_patrol_target() -> Vector2:
	var anchor := home_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	return _cleared_trip_target(anchor, 24.0)

func _pick_idle_target() -> Vector2:
	var anchor := home_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
	return _cleared_trip_target(anchor, 20.0)

## Shared: route the anchor through the world's footprint rules so no trip
## goal is ever inside a registered obstacle (or the interior band edge).
func _cleared_trip_target(anchor: Vector2, radius: float) -> Vector2:
	var world := _world_manager()
	return world.terrain_free_target(anchor, radius) if world != null else anchor

# --- combat swing (2026-11-09) ------------------------------------------------

## Code-driven attack animation: while ACTIVELY fighting (dragon inside
## attack_range, alive, not burning) the carried weapon hammers an
## overhead→strike arc; the body leans into each swing. The weapon node
## differs per type (Spear/Sword) but King.tscn's Sword resolves by the
## same lookup, so the King inherits the swing through this override.
const SWORD_SWING_HZ := 2.2
const WEAPON_RAISED_DEG := -55.0
const WEAPON_STRIKED_DEG := 25.0
const COMBAT_LEAN_RAD := 0.09

var _swing_phase := 0.0
var _swing_animating := false
var _weapon: ColorRect

func _resolve_weapon() -> void:
	_weapon = get_node_or_null("Sprite/Spear") as ColorRect
	if _weapon == null:
		_weapon = get_node_or_null("Sprite/Sword") as ColorRect

func _animate_combat(delta: float) -> void:
	if _weapon == null:
		return
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	var fighting := is_alive and _burning_left <= 0.0 \
		and dragon != null and is_instance_valid(dragon) \
		and global_position.distance_to(dragon.global_position) <= attack_range
	if fighting:
		_swing_animating = true
		_swing_phase += delta * TAU * SWORD_SWING_HZ
		# 0 = fully raised overhead, 1 = strike into the dragon
		var t := 0.5 + 0.5 * sin(_swing_phase - PI / 2.0)
		# The GRIP is the fixed end (user fix 2026-11-09: "the top is fixed
		# and the bottom wriggles but a swing would look better the other
		# way around") — pivot at the BOTTOM edge so the blade tips sweep
		# overhead→strike instead of the handle flopping.
		_weapon.pivot_offset = Vector2(_weapon.size.x * 0.5,
			_weapon.size.y - 2.0)
		_weapon.rotation_degrees = lerpf(WEAPON_RAISED_DEG, WEAPON_STRIKED_DEG, t)
		# the weapon glints at the bottom of every strike
		_weapon.modulate = Color(1.0, 0.9, 0.6) if t > 0.82 else Color.WHITE
		sprite.rotation = COMBAT_LEAN_RAD * sin(_swing_phase)
	elif _swing_animating:
		_swing_animating = false
		_weapon.rotation_degrees = 0.0
		_weapon.modulate = Color.WHITE
		sprite.rotation = 0.0

## Soldiers spot the dragon → alarm (swarm sighting), plus contact DPS on the
## dragon. Burning status (catch_fire/_tick_burning) is inherited from BaseNPC.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_contact_damage(delta)
	_animate_combat(delta)
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon != null and is_instance_valid(dragon) \
			and global_position.distance_to(dragon.global_position) < aggro_range:
		var world := _world_manager()
		if world != null:
			world.report_dragon_sighting(dragon.global_position)

# --- combat: contact DPS (ablaze lives in BaseNPC) ----------------------------

## 10 DPS while the hitbox collides with the dragon (integer-chunked debt).
func _contact_damage(delta: float) -> void:
	if _burning_left > 0.0 or not is_alive:
		return
	var dragon := get_tree().get_first_node_in_group("dragon") as CharacterBody2D
	if dragon == null or not is_instance_valid(dragon):
		return
	var dragon_dying: Variant = dragon.get("_dying")
	if dragon_dying == null or bool(dragon_dying):
		return
	if global_position.distance_to(dragon.global_position) > attack_range:
		return
	_contact_debt += attack_damage * delta
	var whole := int(_contact_debt)
	if whole > 0:
		_contact_debt -= float(whole)
		dragon.take_damage(whole)

func take_damage(amount: int) -> void:
	# Soldiers take fire/dragon damage; routed into the base class.
	super.take_damage(amount)

func die() -> void:
	defeated.emit(reward_gold)
	super.die()
