extends CharacterBody2D

class_name BaseNPC

## Base class for all town NPCs (farmers, miners, soldiers, King).
## Owns: movement (steering-seek, no nav mesh on open fields), health, the
## payload slot (resources being carried — stealable), tier level, anchors.
## Behavior: the Activity engine in BehaviorTree.gd; subclasses register
## activities in _ready. See docs/plans/2026-11-08-behavior-system-rebuild.md.

signal npc_died(npc_type: String)
signal carrying_changed(res_type: String, amount: int)

@export_group("Identity")
@export var npc_type: String = "villager"
@export var max_health: int = 50
@export_group("Movement")
@export var speed: float = 100.0
## Speed multiplier while FLEEING (BehaviorTree applies it to the escape run).
@export var flee_speed_multiplier: float = 1.0

@export_group("Tier (TTRPG levels)")
@export_range(1, 5) var npc_level: int = 1

@export_group("Dragon danger")
@export var danger_radius: float = 150.0
@export var safe_radius: float = 320.0

@export_group("Ablaze")
## All NPC actors catch fire from dragon flame (User spec 2026-11-08):
## abandon orders, run in random bursts and burn. Since the damage model
## (2026-11-14, scripts/systems/Damage.gd) the burn is plain DRAGON_FIRE
## damage — burn_damage in total over burn_duration — so a 50–60 HP
## commoner still dies to one burn, while tougher folk survive it, pat out
## the embers and get back to work.
@export var is_flammable: bool = true
@export var burn_damage: float = Damage.FIRE_PER_BURN
@export var burn_duration: float = 3.0
## Damage multipliers by type: {Damage.Type.MAGIC: 0.5}. Missing = 1.0.
var damage_taken: Dictionary = {}
var _burn_dealt: int = 0

var health: int = max_health
var is_alive: bool = true
var behavior_tree: BehaviorTree
## Escape vector refreshed by the engine while the dragon is still close.
var flee_target: Vector2 = Vector2.ZERO

## Detour waypoint (set by BehaviorTree when a body blocks the path):
## move_towards heads here first, then resumes the real target.
var _waypoint: Vector2 = Vector2.INF

## Anchors, initialized at spawn and overridden by subclasses/WorldManager.
var home_position: Vector2 = Vector2.ZERO
var town_position: Vector2 = Vector2.ZERO
var mine_position: Vector2 = Vector2.ZERO
var pig_pen_position: Vector2 = Vector2.ZERO

## Payload slot: resources currently being carried (walked to town / stealable).
var payload_res_type: String = ""
var payload_amount: int = 0

## Facing state: 1 = right, -1 = left. Mirrors the Sprite container (cheap
## left/right representation — composites mirror cleanly, see _apply_facing).
var facing: int = 1

## Flee wobble (2026-11-09): code-driven cartoon run on the Sprite container.
const FLEE_BOUNCE_HZ := 9.0
const FLEE_WOBBLE_RAD := 0.18
const FLEE_HOP_PX := 4.5
var _flee_phase := 0.0
var _flee_animating := false
var _sprite_home := Vector2.ZERO

## Burning status (see catch_fire). Guarded re-entry; killed behavior tree.
var _burning_left: float = 0.0
var _burn_move_timer: float = 0.0
var _burn_direction: Vector2 = Vector2.ONE
var _burn_debt: float = 0.0

## Fire cloak (2026-11-09 King lives): once ignited, the cloak burns off and
## blocks catch_fire for this many seconds — flame re-breaths cannot chain
## a burn right after burn-out (burn 3s inside the 5s window, sober 2s,
## then the next hit re-ignites and re-arms). 0.0 = normal, no cloak.
@export var fire_immunity_seconds: float = 0.0
var _fire_immune_left: float = 0.0

@onready var sprite: Node2D = $Sprite

## Body size (2026-11-14, user: "hero characters look larger but the rest
## should be smaller"): commoners (farmer, miner, soldier, archer) run at
## 0.8, heroes (King, wizard, adventurer) stay 1.0. Facing flips and the
## flee squash multiply by it; the feet stay planted on the node origin.
@export var visual_scale: float = 1.0

func _ready() -> void:
	# sync health — subclasses MUST set max_health before calling super._ready()
	health = max_health
	if sprite != null and visual_scale != 1.0:
		sprite.position *= visual_scale   # feet offset shrinks with the body
		sprite.scale = Vector2(float(facing) * visual_scale, visual_scale)
	_sprite_home = sprite.position if sprite != null else Vector2.ZERO
	home_position = global_position
	town_position = global_position + Vector2(0, 200)
	mine_position = global_position + Vector2(0, -200)
	pig_pen_position = global_position + Vector2(-200, 0)

## Burning overrides everything (the tree stops issuing intents while it
## panics); subclasses add per-frame behavior on top.
func _physics_process(delta: float) -> void:
	if not global_position.is_finite():
		# Lost-in-space watchdog (2026-11-08): a non-finite position spews
		# normalize warnings every physics tick and can never recover — snap
		# home (fallback ZERO = map centre, still walkable) and continue.
		global_position = home_position
		velocity = Vector2.ZERO
	# The cloak counts down from ignition, the burn included (documented
	# rule: "burn 3s inside the 5s window, sober 2s" — it used to start
	# only after the burn, stretching the cloak to 8s).
	if _fire_immune_left > 0.0:
		_fire_immune_left = maxf(0.0, _fire_immune_left - delta)
	if _burning_left > 0.0:
		_tick_burning(delta)
		if is_alive:
			_animate_flee(delta)  # burning panic runs wobble too (user spec)
			_animate_flames(delta)
			_tick_rig(delta)
		return
	if _flames != null:
		_flames_teardown()      # fire out (or dead): overlay goes with it
	if is_alive and behavior_tree != null:
		behavior_tree.tick(delta)
	_animate_flee(delta)
	_tick_rig(delta)

## Jointed rig (2026-11-14): NPCs whose Sprite is a HumanoidRig get a
## velocity-driven walk cycle; legacy ColorRect sprites (King) skip it.
func _tick_rig(delta: float) -> void:
	if sprite is HumanoidRig:
		(sprite as HumanoidRig).tick(delta, velocity, is_alive)
	elif sprite != null and sprite.has_method("tick"):
		sprite.call("tick", delta, velocity, is_alive)   # e.g. the slayer's SlayerRig

# --- flee wobble (2026-11-09) -------------------------------------------------

## Code-driven cartoon run (no spritesheet rig): while FLEEING with actual
## velocity, the whole Sprite container hops foot-to-foot (alternating
## bounce), leans into a wobble, and squashes on each landing. Defaults
## back to rest pose the frame it's not fleeing. All NPCs inherit it.
## Burning NPCs (catch_fire) panic-run with the SAME wobble (user spec
## 2026-11-09) via the burning branch in _physics_process.
func _animate_flee(delta: float) -> void:
	if sprite == null:
		return
	var running: bool = is_alive and velocity.length() > 5.0 \
		and (_burning_left > 0.0 or (behavior_tree != null \
			and behavior_tree.state == BehaviorTree.State.FLEEING))
	if running:
		_flee_animating = true
		_flee_phase += delta * TAU * FLEE_BOUNCE_HZ
		sprite.position = _sprite_home + Vector2(0.0,
			-absf(sin(_flee_phase)) * FLEE_HOP_PX)
		sprite.rotation = sin(_flee_phase * 0.5) * FLEE_WOBBLE_RAD
		sprite.scale.y = visual_scale * (1.0 - 0.12 * maxf(0.0, cos(_flee_phase)))
	elif _flee_animating:
		_flee_animating = false
		sprite.rotation = 0.0
		sprite.position = _sprite_home
		sprite.scale.y = visual_scale

# --- ablaze status -----------------------------------------------------------

## Flame breath hit: abandon orders (the behavior tree stops driving), panic
## in random bursts, burn at burn_damage/s, and die when the fire burns out.
func catch_fire() -> void:
	if not is_flammable or _burning_left > 0.0 or not is_alive:
		return
	if _fire_immune_left > 0.0:
		return  # cloak active: the flames slide right off
	_burning_left = burn_duration
	_burn_move_timer = 0.0
	_burn_debt = 0.0
	_burn_dealt = 0
	# grant the cloak NOW so its countdown covers the burn itself
	if fire_immunity_seconds > 0.0:
		_fire_immune_left = fire_immunity_seconds
	if behavior_tree != null:
		behavior_tree.kill()
	if sprite != null:
		sprite.modulate = Color(0.78, 0.42, 0.28)  # scorched, sooty
		_flames_spawn()
	print(npc_type + " caught fire — panicking!")
	# TTRPG story beat: the first miner torching is a chapter title
	# ("refuse to work" is the criers' version; the crate of mead is real).
	if npc_type == "miner":
		var story := get_tree().get_first_node_in_group("game_manager") as GameManager
		if story != null:
			story.notify_story("miner_burn")
	# Peasant-burn horror story (2026-11-09): first farmer fire this run
	# triggers one of five random horror stories.
	if npc_type == "farmer":
		var story := get_tree().get_first_node_in_group("game_manager") as GameManager
		if story != null:
			story.notify_peasant_burn()

## Ablaze physics: random-burst running, burn damage in int chunks, then death.
func _tick_burning(delta: float) -> void:
	_burning_left -= delta
	_burn_move_timer -= delta
	if _burn_move_timer <= 0.0:
		_burn_move_timer = randf_range(0.25, 0.45)
		_burn_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	velocity = _burn_direction * _burn_speed()
	update_facing()
	move_and_slide()
	_burn_debt += burn_damage * delta / burn_duration
	var whole := int(_burn_debt)
	if whole > 0:
		_burn_debt -= float(whole)
		_burn_dealt += whole
		take_damage(whole, Damage.Type.DRAGON_FIRE, "dragon")

# --- flame overlay (2026-11-09) -------------------------------------------------

## Burning look (2026-11-15, user: "When NPCs are alit with fire they need
## a better shader too"): a column of rising fire drawn by
## assets/shaders/body_fire.gdshader — turbulent tongues licking up the body,
## white-hot at the base, blood-red at the tips, sparks and a glow. It flares
## at ignition and gutters as the burn runs out (`intensity`); every NPC gets
## its own seed so no two fires flicker in step. The overlay is a child of
## the NPC itself, NOT of the sprite: the sprite carries the scorched tint,
## which would otherwise dull the flames. Applies to ALL burning NPC types;
## torn down the frame the fire is out or the body dies.
const BODY_FIRE_SHADER := preload("res://assets/shaders/body_fire.gdshader")
const FLAME_FLARE_TIME := 0.25   # ignition flare-up
const FLAME_GUTTER_TIME := 0.7   # dying down at the end of the burn

var _flames: Node2D = null
var _flame_mat: ShaderMaterial = null
var _flame_age := 0.0

func _flames_spawn() -> void:
	if _flames != null or sprite == null:
		return
	_flames = Node2D.new()
	_flames.name = "Flames"
	_flames.z_index = 2
	add_child(_flames)
	# Ablaze from the hips up (user: "before the NPC was ablaze from the
	# hip up which made you appreciate the running legs more"): the base of
	# the fire sits at the waist, the tongues climb past the head. Sized
	# from the body — the sprite sits at the hips — so scaled bodies (the
	# King) burn bigger, within limits.
	# (The sprite's position is already in this NPC's space — only the
	# flame's SIZE follows the sprite's scale; the waist does not.)
	var waist := absf(sprite.position.y) * 0.85
	var hip := absf(sprite.position.y) * absf(sprite.scale.y)
	var tall := clampf(hip * 1.5, 30.0, 46.0)
	var wide := clampf(hip * 1.0, 22.0, 32.0)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the candle's round base sits on the waist, the flame over the chest
	rect.position = Vector2(-wide * 0.5, -tall)
	rect.size = Vector2(wide, tall)
	_flame_mat = ShaderMaterial.new()
	_flame_mat.shader = BODY_FIRE_SHADER
	_flame_mat.set_shader_parameter("seed", randf() * 10.0)
	_flame_mat.set_shader_parameter("intensity", 0.0)
	rect.material = _flame_mat
	_flames.add_child(rect)
	_flame_age = 0.0
	_flame_waist = waist
	_flame_lean = 0.0
	_follow_body()

var _flame_waist := 20.0
var _flame_lean := 0.0

## The flame rides the body: anchored at the rig's torso (which bobs on
## every footfall and leans into the run), else at the waist.
func _follow_body() -> void:
	if _flames == null:
		return
	var rig := sprite as HumanoidRig
	var torso := rig.part("Torso") if rig != null else null
	if torso != null:
		_flames.global_position = torso.global_position + Vector2(0.0, -4.0)
	else:
		_flames.position = Vector2(0.0, -_flame_waist)

func _animate_flames(delta: float) -> void:
	if _flames == null or _flame_mat == null:
		return
	_follow_body()
	# streams back from the run (eased, so turns swing the flame over)
	var run := clampf(velocity.x / 140.0, -1.0, 1.0)
	_flame_lean = lerpf(_flame_lean, run, clampf(delta * 6.0, 0.0, 1.0))
	_flame_mat.set_shader_parameter("lean", _flame_lean)
	_flame_age += delta
	var flare := smoothstep(0.0, FLAME_FLARE_TIME, _flame_age)
	var gutter := clampf(_burning_left / FLAME_GUTTER_TIME, 0.0, 1.0)
	_flame_mat.set_shader_parameter("intensity", flare * lerpf(0.35, 1.0, gutter))

func _flames_teardown() -> void:
	if _flames != null and is_instance_valid(_flames):
		_flames.queue_free()
	_flames = null
	_flame_mat = null
	if not is_alive or _burning_left > 0.0:
		return
	# The burn is over: the last of its damage lands (frame rounding), and
	# a survivor pats out the embers and goes back to work.
	var rest := int(burn_damage) - _burn_dealt
	if rest > 0:
		_burn_dealt += rest
		take_damage(rest, Damage.Type.DRAGON_FIRE, "dragon")
	if not is_alive:
		return
	if sprite != null:
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.8)
	if behavior_tree != null:
		behavior_tree.revive()
	_on_burn_survived()

## Hook: a burn ran out and this actor lived through it.
func _on_burn_survived() -> void:
	pass

## Panic pace — subclasses may flail faster.
func _burn_speed() -> float:
	return speed * 1.4

## The one way to hurt an NPC (Damage.gd): typed, scaled by damage_taken,
## fatal at 0 HP. `source` names the attacker ("dragon", "rider", …).
func take_damage(amount: int, type: Damage.Type = Damage.Type.WEAPON,
		source: String = "") -> void:
	if not is_alive:
		return
	var dealt := Damage.scaled(amount, float(damage_taken.get(type, 1.0)))
	if dealt <= 0:
		return
	health -= dealt
	print("%s took %d %s damage%s, health: %d" % [npc_type, dealt,
		Damage.type_name(type), (" from " + source) if source != "" else "", health])
	_on_damaged(dealt, type, source)
	if health <= 0:
		_burning_left = 0.0   # a body stops running once the fire has killed it
		die()

## Hook: after HP was lost (still alive or about to die).
func _on_damaged(_dealt: int, _type: Damage.Type, _source: String) -> void:
	pass


func die() -> void:
	is_alive = false
	if behavior_tree != null:
		behavior_tree.kill()
	print(npc_type, " has died")
	npc_died.emit(npc_type)
	# Remove from the tree after a short corpse delay.
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self):
		queue_free()

## Walk toward a world-space target along a planned route (NavGrid A*,
## 2026-11-14 — was a straight seek that only sidestepped after stalling).
## A detour waypoint from the stuck watchdog still wins while it is set.
## Returns true when the TARGET is reached (arrival threshold 12px) — or,
## for a target inside scenery, its nearest walkable spot.
func move_towards(target: Vector2) -> bool:
	if not is_alive:
		return true
	if global_position.distance_to(target) <= ARRIVE_PX or _arrived_at_snapped(target):
		velocity = Vector2.ZERO
		_waypoint = Vector2.INF
		return true
	steer_to(target, _move_speed())
	return false

## Movement speed for purposeful trips (subclasses: loaded miners slow).
func _move_speed() -> float:
	return speed

# --- route following -----------------------------------------------------------

const ARRIVE_PX := 12.0
const NODE_REACHED_PX := 10.0
## Replan when the goal moved this far (chasing a moving target)…
const REPLAN_MOVE_PX := 24.0
## …but at most this often per NPC (A* is cheap, not free).
const REPLAN_MIN_S := 0.25
## After "no route at all", wait this long before asking again.
const NO_ROUTE_RETRY_S := 1.0

var _route := PackedVector2Array()
var _route_i := 0
var _route_goal := Vector2.INF
var _route_age := 0.0
var _nav_world: WorldManager = null

func _nav() -> NavGrid:
	if _nav_world == null or not is_instance_valid(_nav_world):
		_nav_world = get_tree().get_first_node_in_group("world_manager") as WorldManager
	if _nav_world == null or _nav_world.nav_grid == null or not _nav_world.nav_grid.is_built:
		return null
	return _nav_world.nav_grid

## Forget the route: the next step plans afresh from where we stand (the
## stuck watchdog calls this — a stall is first answered with a new plan).
func invalidate_route() -> void:
	_route = PackedVector2Array()
	_route_goal = Vector2.INF

## One movement step toward `target` at `move_speed`, following the route.
func steer_to(target: Vector2, move_speed: float) -> void:
	var aim := target
	if _waypoint != Vector2.INF:
		# Watchdog detour hop: walk it, then plan again from there.
		if global_position.distance_to(_waypoint) <= 16.0:
			_waypoint = Vector2.INF
			invalidate_route()
		else:
			aim = _waypoint
	if _waypoint == Vector2.INF:
		var nav := _nav()
		if nav != null:
			_route_age += get_physics_process_delta_time()
			var stale := _route_goal == Vector2.INF \
				or (target.distance_to(_route_goal) > REPLAN_MOVE_PX and _route_age >= REPLAN_MIN_S)
			if stale and _route_age >= 0.0:
				_route = nav.route(global_position, target)
				_route_i = 0
				_route_goal = target
				_route_age = 0.0 if not _route.is_empty() else -NO_ROUTE_RETRY_S
			while _route_i < _route.size() - 1 \
					and global_position.distance_to(_route[_route_i]) <= NODE_REACHED_PX:
				_route_i += 1
			if not _route.is_empty():
				aim = _route[_route_i]
				# Last leg: home in on the live target when it is standable
				# (a chased target drifts between replans).
				if _route_i == _route.size() - 1 and nav.is_walkable(target):
					aim = target
	velocity = (aim - global_position).normalized() * move_speed
	update_facing()
	move_and_slide()

## Target inside scenery: standing on the route's (snapped) end counts.
func _arrived_at_snapped(target: Vector2) -> bool:
	if _route.is_empty() or _route_goal.distance_to(target) > 1.0:
		return false
	var nav := _nav()
	if nav == null or nav.is_walkable(target):
		return false
	return global_position.distance_to(_route[_route.size() - 1]) <= ARRIVE_PX

## Track last horizontal travel direction: 1 right, -1 left. Zero x keeps the
## current facing. Call sites: move_towards (aim walk), BehaviorTree fleeing.
func update_facing() -> void:
	if velocity.x == 0.0:
		return
	var new_facing := 1 if velocity.x > 0.0 else -1
	if new_facing != facing:
		facing = new_facing
		_apply_facing()

## Mirror the whole visual container horizontally. ColorRect composites mirror
## about the container origin, so outlines/animations stay consistent.
func _apply_facing() -> void:
	if sprite != null:
		sprite.scale.x = float(facing) * visual_scale

## Set/clear the payload being carried. Emits carrying_changed so the
## GoldInterceptionSystem sees this NPC as a steal target.
func set_payload(res_type: String, amount: int) -> void:
	payload_res_type = res_type
	payload_amount = maxi(amount, 0)
	carrying_changed.emit(payload_res_type, payload_amount)

## Remove carried payload in an interception (dragon steal).
## Returns what was actually taken; remainder stays owned by this NPC = zero.
func steal_payload() -> Dictionary:
	var stolen := {
		"res_type": payload_res_type,
		"amount": payload_amount,
	}
	set_payload("", 0)
	return stolen

## Gate hand-off exemption (2026-11-09), see BehaviorTree._tick_danger:
## loaded cargo keepers inside the town-gate handoff band finish their
## delivery even with the dragon in the flee ring — a parked dragon used
## to wedge every carrier in the panic loop forever and starve the
## treasury (zero deliveries → zero soldier purchases). Types override
## this (Miner/Farmer); the default means "no exemption".
func _handoff_stretch() -> bool:
	return false

## Explicit E-kill by the dragon (decision record 2026-11-08-dragon-attack-eat):
## guaranteed death. Burn flags are cleared so a burning target killed by
## E takes the deliberate-death path (no extra spill semantics).
func kill_by_dragon() -> void:
	if not is_alive:
		return
	_burning_left = 0.0
	die()

## Tier multiplier hook: subclasses scale yields/speed with npc_level.
func level_multiplier() -> float:
	return 1.0 + float(npc_level - 1) * 0.25

func get_health_ratio() -> float:
	return clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)
