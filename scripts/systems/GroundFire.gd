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
	"prince", "deer"]

var _age := 0.0
var _check_left := 0.0
var _seed := 0.0
var _tongues: Array[Polygon2D] = []
var _glow: Polygon2D

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
	_glow.color = Color(0.55, 0.12, 0.02, 0.75)
	add_child(_glow)
	# a few licking tongues of fire
	for i in 4:
		var tongue := Polygon2D.new()
		tongue.position = Vector2(randf_range(-RADIUS * 0.6, RADIUS * 0.6), randf_range(-2.0, 3.0))
		tongue.color = [Color(1.0, 0.42, 0.05, 0.9), Color(1.0, 0.68, 0.12, 0.95),
			Color(1.0, 0.92, 0.55, 1.0)][i % 3]
		add_child(tongue)
		_tongues.append(tongue)
	_shape_tongues()

func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	# the last second: the fire gutters and dies down
	var fade := clampf((LIFETIME - _age) / 1.0, 0.0, 1.0)
	modulate.a = fade
	_shape_tongues()
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = CHECK_EVERY
	_burn_walkers()

func _shape_tongues() -> void:
	var t := _age * 9.0 + _seed
	for i in _tongues.size():
		var h := (9.0 + 5.0 * sin(t + float(i) * 1.7)) * (1.0 - 0.25 * float(i % 3))
		var w := 4.2 - float(i % 3)
		var sway := 2.0 * sin(t * 0.7 + float(i))
		_tongues[i].polygon = PackedVector2Array([
			Vector2(-w, 0.0), Vector2(-w * 0.4, -h * 0.55),
			Vector2(sway, -h), Vector2(w * 0.4, -h * 0.5), Vector2(w, 0.0)])
	_glow.color.a = 0.6 + 0.15 * sin(t * 1.3)

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
			npc.take_damage(KILL_DAMAGE, Damage.Type.DRAGON_FIRE, "greater_flame")
