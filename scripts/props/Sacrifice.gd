extends Node2D

class_name Sacrifice

## The sacrifice: a woman tied to a pole, presented to the dragon after every
## 3 fields are burnt. The dragon can choose to eat her (+2 flames) or bring
## her to the lair to train as a dragon rider. 20% chance the virgin is a man
## who can be trained as a dragon rider.

## Story popup state - only triggers once per sacrifice per run
var _story_triggered: bool = false

## 20% chance the virgin is male (trainable as rider)
@export var is_male: bool = false

func _ready() -> void:
	# Randomize gender: 20% male
	is_male = randf() < 0.2
	set_meta("is_male", is_male)

func _physics_process(delta: float) -> void:
	# Always check for Dragon proximity (not dependent on behavior tree)
	_check_dragon_encounter()

func _check_dragon_encounter() -> void:
	# Check if Dragon is close enough to trigger encounter popup
	# Only triggers once per sacrifice per run (before popup is shown)
	if _story_triggered:
		return
	
	var dragon := get_tree().get_first_node_in_group("dragon") as Node2D
	if dragon == null or not is_instance_valid(dragon):
		return
	
	var distance := global_position.distance_to(dragon.global_position)
	if distance <= 100.0:  # 100px detection radius
		_story_triggered = true
		_trigger_story()

func _trigger_story() -> void:
	print("Sacrifice: Dragon approached, triggering story popup")

	# Get the game manager to show the story
	var game_manager := get_tree().get_first_node_in_group("game_manager")
	if game_manager == null:
		print("Sacrifice: GameManager not found!")
		return

	# Determine which story to show
	var story_kind := "sacrifice_approach"
	if is_male:
		story_kind = "sacrifice_male"

	print("Sacrifice: Showing story '%s'" % story_kind)

	# Bug fix (2026-11-11): open through GameManager's canonical path. The
	# old code duplicated popup creation here and connected
	# sacrifice_choice_made ONLY when IT created the popup — but the popup
	# already existed (the first field burn created it), so the "train as
	# rider" answer fired into the void and the wizard option never unlocked.
	# Choice routing now flows through story_choice_made →
	# GameManager._on_story_choice → _on_sacrifice_choice_from_popup.
	game_manager.call("open_sacrifice_story", story_kind)

func remove_sacrifice() -> void:
	# Called when the story answer is processed
	print("Sacrifice: Removing itself from the scene")
	queue_free()
