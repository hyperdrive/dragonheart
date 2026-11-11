extends Node2D

class_name SacrificeProbe

## Probe to test sacrifice story popup trigger
## This node monitors the sacrifice and reports when the story popup is triggered

@onready var sacrifice: Node2D = null
var _sacrifice_found: bool = false

func _ready() -> void:
	# Find the sacrifice in the scene
	_sacrifice_found = _find_sacrifice()
	if _sacrifice_found:
		print("SacrificeProbe: Found sacrifice at %s" % sacrifice.global_position)
	else:
		print("SacrificeProbe: No sacrifice found in scene")

func _find_sacrifice() -> bool:
	var sacrifices := get_tree().get_nodes_in_group("sacrifice")
	if sacrifices.size() > 0:
		sacrifice = sacrifices[0] as Node2D
		return true
	return false

func _process(delta: float) -> void:
	if not _sacrifice_found or sacrifice == null or not is_instance_valid(sacrifice):
		return
	
	# Check if the sacrifice has been triggered
	var story_triggered := sacrifice.get_meta("story_triggered", false)
	if story_triggered:
		print("SacrificeProbe: Story popup TRIGGERED for sacrifice at %s" % sacrifice.global_position)
		_sacrifice_found = false  # Only report once

func _physics_process(delta: float) -> void:
	if not _sacrifice_found or sacrifice == null or not is_instance_valid(sacrifice):
		return
	
	# Report the distance to the sacrifice
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null:
		return
	
	var distance := sacrifice.global_position.distance_to(dragon.global_position)
	if distance <= 150.0:  # Print when dragon is within 150px
		print("SacrificeProbe: Dragon is %dpx from sacrifice" % int(distance))
