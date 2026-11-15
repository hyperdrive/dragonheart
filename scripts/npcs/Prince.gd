extends BaseNPC

class_name Prince

## Prince Aurel (2026-11-15): the slain King's son, met in the glade that
## blooms where the crown fell. To the dragon he is just another fleeing
## human; to the farm girl he is… something else. Walking into him as the
## girl opens the courtship chapters (GameManager.notify_prince_meeting);
## after each meeting that does not end in a kiss he goes back to the city
## (WorldManager.relocate_prince) and strolls by the gate road.
##
## Story-critical, so: no fire, no claws (not in any strike group), and he
## flees the dragon instead of fighting it.

var _cape: Node2D = null
var _sway_t := 0.0

func _ready() -> void:
	npc_type = "prince"
	max_health = 9999
	speed = 52.0
	danger_radius = 160.0
	safe_radius = 280.0
	flee_speed_multiplier = 2.0
	is_flammable = false
	visual_scale = 1.3   # a head taller than the farm girl (drawn at 1.4× a small rig)
	super._ready()
	add_to_group("prince")
	_cape = get_node_or_null("Sprite/Cape") as Node2D
	behavior_tree = BehaviorTree.new()
	add_child(behavior_tree)
	behavior_tree.setup(self)
	behavior_tree.register_activity("stroll", 10, _pick_stroll, randf_range(2.0, 4.0), 1.0, Callable())
	behavior_tree.register_activity("idle", 1, _pick_idle, 2.0, 1.0, Callable())

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# The cape streams back with speed and breathes when he stands.
	_sway_t += delta
	if _cape != null:
		var flow := clampf(velocity.length() / 120.0, 0.0, 1.0)
		_cape.rotation = 0.38 * flow + 0.05 * sin(_sway_t * 2.2)

func _pick_stroll() -> Vector2:
	return home_position + Vector2(randf_range(-110.0, 110.0), randf_range(-70.0, 70.0))

func _pick_idle() -> Vector2:
	return global_position + Vector2(randf_range(-16.0, 16.0), randf_range(-10.0, 10.0))

## Back to a new home (the city road after a meeting).
func relocate(to: Vector2) -> void:
	global_position = to
	home_position = to
	velocity = Vector2.ZERO
	invalidate_route()
	if behavior_tree != null:
		behavior_tree.force_repick()
