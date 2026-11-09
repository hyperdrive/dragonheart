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
## abandon orders, run in random bursts, burn, and die when the fire burns out.
@export var is_flammable: bool = true
@export var burn_damage: float = 10.0
@export var burn_duration: float = 3.0

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

@onready var sprite: Node2D = $Sprite

func _ready() -> void:
	# sync health — subclasses MUST set max_health before calling super._ready()
	health = max_health
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
	if _burning_left > 0.0:
		_tick_burning(delta)
		if is_alive:
			_animate_flee(delta)  # burning panic runs wobble too (user spec)
			_animate_flames(delta)
		return
	if _flames != null:
		_flames_teardown()      # fire out (or dead): overlay goes with it
	if is_alive and behavior_tree != null:
		behavior_tree.tick(delta)
	_animate_flee(delta)

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
		sprite.scale.y = 1.0 - 0.12 * maxf(0.0, cos(_flee_phase))
	elif _flee_animating:
		_flee_animating = false
		sprite.rotation = 0.0
		sprite.position = _sprite_home
		sprite.scale.y = 1.0

# --- ablaze status -----------------------------------------------------------

## Flame breath hit: abandon orders (the behavior tree stops driving), panic
## in random bursts, burn at burn_damage/s, and die when the fire burns out.
func catch_fire() -> void:
	if not is_flammable or _burning_left > 0.0 or not is_alive:
		return
	_burning_left = burn_duration
	_burn_move_timer = 0.0
	_burn_debt = 0.0
	if behavior_tree != null:
		behavior_tree.kill()
	if sprite != null:
		sprite.modulate = Color(1.0, 0.4, 0.1)  # scorched tint
		_flames_spawn()
	print(npc_type + " caught fire — panicking!")

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
	_burn_debt += burn_damage * delta
	var whole := int(_burn_debt)
	if whole > 0:
		_burn_debt -= float(whole)
		take_damage(whole)

# --- flame overlay (2026-11-09) -------------------------------------------------

## Burning look beyond the scorched tint: three warm flame tongues over the
## body, code-flickered (height waves, side sway, alpha pulse) — applies to
## ALL burning NPC types (user-grilled). Torn down the frame the fire is
## out or the body dies.
const FLAME_FLICKER_HZ := 14.0

var _flames: Node2D = null
var _flame_phase := 0.0

func _flames_spawn() -> void:
	if _flames != null or sprite == null:
		return
	_flames = Node2D.new()
	_flames.name = "Flames"
	_flames.z_index = 2
	sprite.add_child(_flames)
	# body-top anchors: rise from ~waist to over the head; widths narrow
	var spec := [
		{"x": -7.0, "h": 10.0, "c": Color(0.85, 0.2, 0.08)},
		{"x": 2.0, "h": 14.0, "c": Color(1.0, 0.5, 0.08)},
		{"x": -3.0, "h": 18.0, "c": Color(1.0, 0.85, 0.25)},
	]
	for i in spec.size():
		var tongue := ColorRect.new()
		tongue.name = "Tongue%d" % i
		var h: float = spec[i]["h"]
		tongue.size = Vector2(6 + i, h)
		tongue.position = Vector2(spec[i]["x"], -h + 2.0)
		tongue.color = spec[i]["c"]
		tongue.rotation = randf_range(-0.1, 0.1)
		_flames.add_child(tongue)

func _animate_flames(delta: float) -> void:
	if _flames == null:
		return
	_flame_phase += delta * FLAME_FLICKER_HZ
	for i in _flames.get_child_count():
		var tongue := _flames.get_child(i) as ColorRect
		if tongue == null:
			continue
		var w := 1.0 + 0.31 * float(i)
		# breathing height wave, differing per tongue; zero stays >= 1 scale?
		tongue.scale.y = 0.7 + 0.45 * absf(sin(_flame_phase * w + 2.1 * float(i)))
		tongue.rotation = 0.16 * sin(_flame_phase * (0.6 + 0.17 * float(i)))
		tongue.position.x = _flame_anchor_x(i) + 1.5 \
			* sin(_flame_phase * (0.9 + 0.13 * float(i)))
		tongue.modulate.a = 0.78 + 0.22 * absf(sin(_flame_phase * (1.3 + 0.09 * i)))

func _flame_anchor_x(i: int) -> float:
	var spec := [-7.0, 2.0, -3.0]
	return spec[i] if i < spec.size() else 0.0

func _flames_teardown() -> void:
	if _flames != null and is_instance_valid(_flames):
		_flames.queue_free()
	_flames = null
	if _burning_left <= 0.0:
		die()

## Panic pace — subclasses may flail faster.
func _burn_speed() -> float:
	return speed * 1.4

func take_damage(amount: int) -> void:
	if not is_alive:
		return
	health -= amount
	print(npc_type, " took ", amount, " damage, health: ", health)
	if health <= 0:
		die()

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

## Steering-seek movement toward a world-space target. When a detour waypoint
## is set (BehaviorTree stuck-detection), it is consumed first and cleared on
## arrival. Returns true when the TARGET is reached (arrival threshold 12px).
func move_towards(target: Vector2) -> bool:
	if not is_alive:
		return true
	if global_position.distance_to(target) <= 12.0:
		velocity = Vector2.ZERO
		_waypoint = Vector2.INF
		return true
	# Detour hop: steer to the waypoint until we stand on it.
	if _waypoint != Vector2.INF:
		if global_position.distance_to(_waypoint) <= 16.0:
			_waypoint = Vector2.INF  # cleared it — resume the real target
		else:
			target = _waypoint
	velocity = (target - global_position).normalized() * speed
	update_facing()
	move_and_slide()
	return false

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
		sprite.scale.x = float(facing)

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
