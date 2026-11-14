extends StaticBody2D

class_name HagNest

## Mother Grisla's fen cottage (2026-11-14). Walking up to the door opens
## the house story (GameManager.notify_hag_house): tea with a sweet old
## lady while the hag lives, her abandoned lair and the Lorindel book once
## she's dead. The trigger re-arms when the dragon steps away, so every
## fresh visit counts — GameManager decides whether there is anything new.

## "Entering" = stepping onto the cottage itself (2026-11-14 fix: the old
## 50px doorstep trigger sat at the stilts' foot while the drawn door is
## up on the stilts, so walking to the door you can SEE never fired it).
## The box covers the hut, its door and the ground before it.
const ENTER_BOX := Rect2(-95.0, -125.0, 190.0, 175.0)
const LEAVE_MARGIN := 45.0

var _inside := false

func _ready() -> void:
	add_to_group("hag_nest")

func door_position() -> Vector2:
	return global_position + Vector2(18.0, -48.0)   # the drawn door

func _physics_process(_delta: float) -> void:
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null:
		return
	var local := dragon.global_position - global_position
	if not _inside and ENTER_BOX.has_point(local):
		_inside = true
		var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
		if gm != null:
			gm.notify_hag_house()
	elif _inside and not ENTER_BOX.grow(LEAVE_MARGIN).has_point(local):
		_inside = false
