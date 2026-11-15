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
		"hunt_outlaw", 55,
		_pick_outlaw_target, attack_interval,
		0.0, _complete_attack,
		_outlaw_in_sight, _outlaw_in_sight
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
	if _defending():
		return not _squad_released_now()   # muster at the gate
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
	if _defending():
		return _squad_target() != null and _squad_released_now()
	return _swarm_released() or _is_bold()

# --- the garrison (2026-11-15, the invasion) --------------------------------------

## User: "the remaining soldiers forming a group to kill in a group".
## While the usurper's army is in the field the town's soldiers and archers
## are a garrison: they no longer hunt the dragon; they muster at the rally
## point until enough have gathered (or invaders come near the city), then
## move out TOGETHER on one shared target (WorldManager's squad brain) and
## cut it down, then the next. Subclasses that are not the town's army
## (King, invaders, the hag, heroes) never defend.
func _defending() -> bool:
	if npc_type != "soldier" and npc_type != "archer":
		return false
	if is_in_group("invaders") or _retiring:
		return false
	var world := _world_manager()
	return world != null and world.invasion_active

func _squad_target() -> Node2D:
	var world := _world_manager()
	return world.squad_target() if world != null else null

func _squad_released_now() -> bool:
	var world := _world_manager()
	return world != null and world.squad_released()

## Nearest living invader within `reach` (the garrison's melee and arrows).
func _nearest_invader_within(reach: float) -> BaseNPC:
	var best: BaseNPC = null
	var best_d := reach
	for node: Node in get_tree().get_nodes_in_group("invaders"):
		var inv := node as BaseNPC
		if inv == null or not inv.is_alive:
			continue
		var d := global_position.distance_to(inv.global_position)
		if d <= best_d:
			best_d = d
			best = inv
	return best

# --- the outlaw (2026-11-15) ------------------------------------------------------

## The smitten adventurer robs the treasury for the dragon (Adventurer.
## turn_outlaw): the King's men — soldiers and the King, not archers, the
## hag or heroes — cut him down when he comes within OUTLAW_SIGHT.
const OUTLAW_SIGHT := 380.0
## A sneaking outlaw is only seen at arm's length; and the King's men are
## town guards — they don't chase him far beyond the city.
const OUTLAW_SNEAK_SIGHT := 70.0
const OUTLAW_TOWN_RANGE := 650.0
var _outlaw_debt := 0.0

func _hunts_outlaws() -> bool:
	return (npc_type == "soldier" or npc_type == "king") and not _retiring \
		and not is_in_group("invaders") and not _defending()

func _nearest_outlaw(reach: float, sighting := true) -> BaseNPC:
	if not _hunts_outlaws():
		return null
	var world := _world_manager()
	var best: BaseNPC = null
	var best_d := reach
	for node: Node in get_tree().get_nodes_in_group("outlaws"):
		var o := node as BaseNPC
		if o == null or o == self or not o.is_alive:
			continue
		if world != null and o.global_position.distance_to(world.city_position) > OUTLAW_TOWN_RANGE:
			continue
		var d := global_position.distance_to(o.global_position)
		if sighting and o.has_method("is_sneaking") and bool(o.call("is_sneaking")):
			d += OUTLAW_SIGHT - OUTLAW_SNEAK_SIGHT   # seen only up close
		if d <= best_d:
			best_d = d
			best = o
	return best

func _outlaw_in_sight() -> bool:
	return _nearest_outlaw(OUTLAW_SIGHT) != null

func _pick_outlaw_target() -> Vector2:
	var o := _nearest_outlaw(OUTLAW_SIGHT)
	if o == null:
		return BehaviorTree.TARGET_NONE
	var side := Vector2.from_angle(float(get_instance_id() % 360) * PI / 180.0)
	return o.global_position + side * 16.0

func _outlaw_blows(delta: float) -> void:
	var o := _nearest_outlaw(attack_range, false)
	if o == null or _burning_left > 0.0 or not is_alive:
		return
	_outlaw_debt += attack_damage * delta
	var whole := int(_outlaw_debt)
	if whole > 0:
		_outlaw_debt -= float(whole)
		o.take_damage(whole, Damage.Type.WEAPON, npc_type)

# --- activity providers & completers ---------------------------------------

## During ATTACK the aggro range widens hugely: the whole swarm hunts.
## BOLD soldiers hunt too (morale) — across the WHOLE MAP (user escalation
## 2026-11-09: "attack the dragon when they are bold").
func _pick_dragon_target() -> Vector2:
	if _defending():
		var foe := _squad_target()
		if foe == null:
			return BehaviorTree.TARGET_NONE
		# close in around the target, each from his own side (a ring, not a pile)
		var side := Vector2.from_angle(float(get_instance_id() % 360) * PI / 180.0)
		return foe.global_position + side * 18.0
	var dragon := get_tree().get_first_node_in_group("dragon_threat") as Node2D
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
	if _defending():
		return _squad_target() != null
	var dragon := get_tree().get_first_node_in_group("dragon_threat") as Node2D
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
	if _defending():
		return _pick_rally_target()   # the garrison doesn't wander: it musters
	var anchor := home_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	return _cleared_trip_target(anchor, 24.0)

func _pick_idle_target() -> Vector2:
	if _defending():
		return _pick_rally_target()
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
var _weapon: ColorRect          # legacy ColorRect weapon (the King's Sword)

## Rig soldiers (2026-11-14): an arming sword in the near hand, the shield
## braced on the far arm. The slash runs on the HumanoidRig like the
## miner's pick: wind-up over the shoulder, a fast diagonal cut at the
## dragon, a short recovery — the soldier turns to face his foe.
const SLASH_HZ := 1.5
const SLASH_ARM_RAISED := -172.0
const SLASH_ARM_CUT := -52.0
const SLASH_BLADE_RAISED := 140.0
const SLASH_BLADE_CUT := 158.0
const SWORD_REST_DEG := -26.0
var _rig: HumanoidRig
var _rig_sword: Node2D

func _resolve_weapon() -> void:
	_rig = sprite as HumanoidRig
	if _rig != null:
		_rig_sword = get_node_or_null("Sprite/ArmFront/Sword") as Node2D
		return
	_weapon = get_node_or_null("Sprite/Spear") as ColorRect
	if _weapon == null:
		_weapon = get_node_or_null("Sprite/Sword") as ColorRect

## Who this fighter is swinging at right now (null = nobody in reach).
## Soldiers fight the dragon; the adventurer also cuts down goblins.
func _combat_target() -> Node2D:
	if _defending():
		return _nearest_invader_within(attack_range)
	var dragon := get_tree().get_first_node_in_group("dragon_threat") as Node2D
	if dragon != null and is_instance_valid(dragon) \
			and global_position.distance_to(dragon.global_position) <= attack_range:
		return dragon
	return _nearest_outlaw(attack_range, false)

func _animate_combat(delta: float) -> void:
	var foe := _combat_target()
	var fighting := is_alive and _burning_left <= 0.0 and foe != null
	if _rig != null:
		_animate_rig_slash(delta, fighting, foe)
		return
	if _weapon == null:
		return
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

func _animate_rig_slash(delta: float, fighting: bool, dragon: Node2D) -> void:
	if _rig_sword == null:
		return
	if fighting:
		_swing_animating = true
		_rig.arms_override = true
		# square up to the dragon
		var want := 1 if dragon.global_position.x >= global_position.x else -1
		if want != facing:
			facing = want
			_apply_facing()
		_swing_phase = fmod(_swing_phase + delta * SLASH_HZ, 1.0)
		_apply_slash_pose(_swing_phase)
	elif _swing_animating:
		_swing_animating = false
		_rig.arms_override = false
		_rig.lean = 0.0
		_rig_sword.rotation_degrees = SWORD_REST_DEG
		_rig_sword.modulate = Color.WHITE

## One sample of the slash at cycle phase p ∈ [0,1): 0..0.55 wind-up,
## 0.55..0.68 the cut, 0.68..1 recover. The shield arm stays braced.
func _apply_slash_pose(p: float) -> void:
	var lift: float
	if p < 0.55:
		lift = smoothstep(0.0, 1.0, p / 0.55)
	elif p < 0.68:
		lift = 1.0 - pow((p - 0.55) / 0.13, 2.0)
	else:
		lift = smoothstep(0.0, 1.0, (p - 0.68) / 0.32) * 0.2
	var arm := lerpf(SLASH_ARM_CUT, SLASH_ARM_RAISED, lift)
	_rig.set_arms(arm, -58.0 + 6.0 * lift)
	_rig_sword.rotation_degrees = lerpf(SLASH_BLADE_CUT, SLASH_BLADE_RAISED, lift)
	_rig.lean = lerpf(0.3, -0.12, lift)
	_rig_sword.modulate = Color(1.0, 0.92, 0.65) if p >= 0.6 and p < 0.72 else Color.WHITE

## Soldiers spot the dragon → alarm (swarm sighting), plus contact DPS on the
## dragon. Burning status (catch_fire/_tick_burning) is inherited from BaseNPC.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _retiring:
		_tick_retire(delta)
		return
	if _defending():
		_keep_squad_order()
		_garrison_blows(delta)
		_animate_combat(delta)
		return
	_contact_damage(delta)
	_outlaw_blows(delta)
	_animate_combat(delta)
	var dragon := get_tree().get_first_node_in_group("dragon_threat") as Node2D
	if dragon != null and is_instance_valid(dragon) \
			and global_position.distance_to(dragon.global_position) < aggro_range:
		var world := _world_manager()
		if world != null:
			world.report_dragon_sighting(dragon.global_position)

# --- retirement (2026-11-14) ---------------------------------------------------

## With no dragon in sight (the dragon walks as a farm girl) the King sends
## soldiers home one by one (WorldManager._tick_retirements). A retiree
## leaves the "soldiers" roll at once, marches back to the city and is
## gone — it is not a death: no reward, no respawn.
const RETIRE_TIMEOUT := 14.0
var _retiring := false
var _retire_to := Vector2.ZERO
var _retire_left := 0.0

func is_retiring() -> bool:
	return _retiring

func retire(to: Vector2) -> void:
	if _retiring or not is_alive:
		return
	_retiring = true
	_retire_to = to
	_retire_left = RETIRE_TIMEOUT
	remove_from_group("soldiers")
	if behavior_tree != null:
		behavior_tree.kill()
	print("A %s is sent home from the field." % npc_type)

func _tick_retire(delta: float) -> void:
	if not is_alive or _burning_left > 0.0:
		return
	_retire_left -= delta
	if move_towards(_retire_to) or _retire_left <= 0.0:
		_retiring = false   # one exit only
		is_alive = false
		velocity = Vector2.ZERO
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.8)
		tw.tween_callback(queue_free)

# --- combat: contact DPS (ablaze lives in BaseNPC) ----------------------------

## 10 DPS while the hitbox collides with the dragon or goblins
## (integer-chunked debt).
## Squad discipline, every frame: when the squad strikes, everyone drops
## what he is doing and joins; while attacking, keep aiming at the LIVE
## target (it marches on — a position snapped at pick time went stale);
## when the target falls, re-pick at once.
func _keep_squad_order() -> void:
	if behavior_tree == null:
		return
	var act := behavior_tree.current_activity
	var on_attack := act != null and str(act.id) == "attack_dragon"
	if _squad_released_now() and _squad_target() != null:
		if not on_attack:
			if behavior_tree.state != BehaviorTree.State.FLEEING:
				behavior_tree.force_repick()
			return
		var aim := _pick_dragon_target()
		if aim != BehaviorTree.TARGET_NONE:
			act.target = aim
	elif on_attack:
		behavior_tree.force_repick()   # target gone: muster again

## The garrison's blades: the nearest invader in reach, never the dragon.
var _garrison_debt := 0.0

func _garrison_blows(delta: float) -> void:
	if npc_type == "archer" or _burning_left > 0.0 or not is_alive or attack_damage <= 0.0:
		return   # archers loose arrows instead (Archer._tick_ranged_fire)
	var foe := _nearest_invader_within(attack_range)
	if foe == null:
		return
	_garrison_debt += attack_damage * delta
	var whole := int(_garrison_debt)
	if whole > 0:
		_garrison_debt -= float(whole)
		foe.take_damage(whole, Damage.Type.WEAPON, "garrison")

## Who the dragon's death chapter names if this blow is the last (the
## King's, the archer's… unknown slayers get the generic chapter).
func _killer_key() -> String:
	return npc_type

func _contact_damage(delta: float) -> void:
	if _burning_left > 0.0 or not is_alive:
		return
	
	# Attack dragon
	var dragon := get_tree().get_first_node_in_group("dragon_threat") as CharacterBody2D
	if dragon != null and is_instance_valid(dragon):
		var dragon_dying: Variant = dragon.get("_dying")
		if dragon_dying == null or bool(dragon_dying):
			dragon = null
	
	if dragon != null and global_position.distance_to(dragon.global_position) <= attack_range:
		_contact_debt += attack_damage * delta
		var whole := int(_contact_debt)
		if whole > 0:
			_contact_debt -= float(whole)
			dragon.take_damage(whole, Damage.Type.WEAPON, _killer_key())
	
	# Attack goblins
	if _contact_debt <= 0.0:
		return
	
	var goblins: Array = get_tree().get_nodes_in_group("goblins")
	for goblin_node in goblins:
		var goblin := goblin_node as BaseNPC
		if goblin == null or not goblin.is_alive:
			continue
		if global_position.distance_to(goblin.global_position) <= attack_range:
			_contact_debt += attack_damage * delta
			var whole := int(_contact_debt)
			if whole > 0:
				_contact_debt -= float(whole)
				goblin.take_damage(whole)
				break

func take_damage(amount: int, type: Damage.Type = Damage.Type.WEAPON,
		source: String = "") -> void:
	super.take_damage(amount, type, source)

func die() -> void:
	defeated.emit(reward_gold)
	super.die()
