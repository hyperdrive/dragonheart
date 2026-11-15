extends Node2D

## The Temple of the Dragon Queen (2026-11-15). The kindly wizard sends the
## farm girl after the Ember Tome of Lorindel's sorceress-queen; his quest
## raises these ruins near the dragon's mountain (WorldManager.
## spawn_dragon_temple). Stepping in among the columns — as the dragon or
## as the girl — opens the temple's story (GameManager.notify_temple): the
## dream she remembers, the hidden stair under the cracked slab, the tome.
## The ruins are walkable (no collision). The trigger re-arms once she
## steps away, like the hag's door.
##
## No class_name on purpose: WorldManager loads the scene by path.

const ENTER_BOX := Rect2(-95.0, -50.0, 190.0, 64.0)
const LEAVE_MARGIN := 45.0

var _inside := false
var _glow_t := 0.0
@onready var _slab_glow: Polygon2D = $SlabGlow

func _ready() -> void:
	add_to_group("dragon_temple")

func _process(delta: float) -> void:
	# the hidden stair breathes ember light through the crack
	_glow_t += delta
	if _slab_glow != null:
		_slab_glow.color.a = 0.25 + 0.2 * (0.5 + 0.5 * sin(_glow_t * 2.2))

func _physics_process(_delta: float) -> void:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null:
		return
	var local := dragon.global_position - global_position
	if not _inside and ENTER_BOX.has_point(local):
		_inside = true
		var gm := get_tree().get_first_node_in_group("game_manager")
		if gm != null and gm.has_method("notify_temple"):
			gm.call("notify_temple")
	elif _inside and not ENTER_BOX.grow(LEAVE_MARGIN).has_point(local):
		_inside = false
