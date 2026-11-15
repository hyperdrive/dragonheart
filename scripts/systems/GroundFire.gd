extends Node2D

## A patch of Greater Flame left burning on the ground (2026-11-15, user:
## "Greater flame, that is twice as long and leave fires on the ground for
## 5s killing anyone who moves into them"). Dragon drops these along the
## breath while it has learned the spell from the Ember Tome. Each patch
## burns for LIFETIME seconds; any living NPC whose feet enter it dies —
## dragon fire, so the fireproof dragon slayer walks through unharmed. The
## dragon itself is never touched.
##
## No class_name on purpose: Dragon preloads this script (an editor that
## has not rescanned would not know a new global class).

const LIFETIME := 5.0
const RADIUS := 15.0
const CHECK_EVERY := 0.1
const KILL_DAMAGE := 9999
## Everyone who walks: the realm, the hag, the heroes, the deer, the Prince.
const VICTIM_GROUPS: Array[String] = ["farmers", "miners", "soldiers", "goblins",
	"king", "wizard", "adventurers", "hag", "invaders", "dragon_slayer",
	"prince", "deer", "wolves"]

var _age := 0.0
var _check_left := 0.0
var _seed := 0.0
var _glow: Polygon2D
var _fire_mat: ShaderMaterial
## The flames themselves: the same rising-fire shader as a burning body
## (assets/shaders/body_fire.gdshader, spread = ground patch), 2026-11-15.
const BODY_FIRE_SHADER := preload("res://assets/shaders/body_fire.gdshader")

func _ready() -> void:
	z_index = 0
	_seed = randf() * TAU
	# a scorched, glowing bed under the flames
	_glow = Polygon2D.new()
	var bed := PackedVector2Array()
	for k in 12:
		var a := TAU * float(k) / 12.0
		bed.append(Vector2.from_angle(a) * RADIUS * Vector2(1.0, 0.5) * randf_range(0.85, 1.1))
	_glow.polygon = bed
	_glow.color = Color(0.6, 0.06, 0.0, 0.75)
	add_child(_glow)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2(RADIUS * 2.6, RADIUS * 2.2)
	rect.position = Vector2(-rect.size.x * 0.5, -rect.size.y + RADIUS * 0.35)
	_fire_mat = ShaderMaterial.new()
	_fire_mat.shader = BODY_FIRE_SHADER
	_fire_mat.set_shader_parameter("seed", randf() * 10.0)
	_fire_mat.set_shader_parameter("spread", 1.0)
	_fire_mat.set_shader_parameter("intensity", 0.0)
	rect.material = _fire_mat
	add_child(rect)

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	# flares up at once, gutters over the last second
	var life := smoothstep(0.0, 0.2, _age) * clampf((LIFETIME - _age) / 1.2, 0.0, 1.0)
	_fire_mat.set_shader_parameter("intensity", life)
	_glow.color.a = (0.55 + 0.15 * sin(_age * 11.0 + _seed)) * clampf((LIFETIME - _age) / 1.0, 0.0, 1.0)
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_EVERY
	_burn_walkers()

func _burn_walkers() -> void:
	for group: String in VICTIM_GROUPS:
		for node: Node in get_tree().get_nodes_in_group(group):
			var npc := node as BaseNPC
			if npc == null or not npc.is_alive:
				continue
			var d := npc.global_position - global_position
			# feet on the ellipse of the patch
			if Vector2(d.x, d.y * 2.0).length() > RADIUS + 4.0:
				continue
			_doom(npc)

## Whoever walks in bursts into flame (2026-11-15, user: "the fire on the
## ground does indeed kill the soldiers but they need to burst into flame
## too"): they catch fire — the burning body, the panic run — and the
## Queen's fire finishes them DOOM_DELAY seconds later. Marked once, so the
## patch's 0.1 s checks don't stack timers. Actors whose fire cloak holds
## (the King after a burn) or who cannot burn still die at once.
const DOOM_DELAY := 1.1

func _doom(npc: BaseNPC) -> void:
	if npc.has_meta("greater_flame_doomed"):
		return
	npc.set_meta("greater_flame_doomed", true)
	npc.catch_fire()
	if npc._burning_left <= 0.0:
		npc.take_damage(KILL_DAMAGE, Damage.Type.DRAGON_FIRE, "greater_flame")
		return
	var timer := npc.get_tree().create_timer(DOOM_DELAY, false)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(npc) and npc.is_alive:
			npc.take_damage(KILL_DAMAGE, Damage.Type.DRAGON_FIRE, "greater_flame"))
