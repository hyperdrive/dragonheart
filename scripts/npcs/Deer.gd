extends BaseNPC

class_name Deer

## Deer of the glade (2026-11-15, user: "spawn deers every 10s up to max 3
## which can be hunted and eaten for +2 flame recharge and +20 health").
## They graze inside the glade and bolt from the dragon — a little slower
## than a walking dragon, so a hunt is a short chase. The dragon eats one
## with E (Dragon._try_context_action). The farm girl doesn't scare them.

const MEAL_FLAMES := 2
const MEAL_HEALTH := 20

var glade_center := Vector2.ZERO
var glade_radius := 130.0

func _ready() -> void:
	npc_type = "deer"
	max_health = 20
	speed = 60.0
	danger_radius = 170.0
	safe_radius = 260.0
	flee_speed_multiplier = 2.2      # 132 px/s: a walking dragon (150) catches up
	is_flammable = false
	super._ready()
	add_to_group("deer")
	if glade_center == Vector2.ZERO:
		glade_center = global_position
	if sprite != null and sprite.has_method("set_stag"):
		sprite.call("set_stag", randf() < 0.35)
	behavior_tree = BehaviorTree.new()
	add_child(behavior_tree)
	behavior_tree.setup(self)
	behavior_tree.register_activity("graze", 10, _pick_graze_spot, randf_range(2.0, 4.0), 0.5, Callable())
	behavior_tree.register_activity("idle", 1, _pick_idle_spot, 1.5, 1.0, Callable())

func _pick_graze_spot() -> Vector2:
	var a := randf() * TAU
	return glade_center + Vector2.from_angle(a) * randf_range(0.0, glade_radius) * Vector2(1.0, 0.7)

func _pick_idle_spot() -> Vector2:
	return global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-12.0, 12.0))
