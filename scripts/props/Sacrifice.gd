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
	
	# Store the current sacrifice in popup meta
	game_manager.story_open = true
	game_manager.get_tree().paused = true
	
	# Create popup if needed
	if game_manager.story_popup == null:
		print("GameManager: Creating new story_popup...")
		game_manager.story_popup = preload("res://scenes/ui/StoryPopup.tscn").instantiate()
		game_manager.story_popup.process_mode = Node.PROCESS_MODE_ALWAYS
		game_manager.story_popup.story_close_requested.connect(game_manager._on_story_closed)
		game_manager.story_popup.story_choice_made.connect(game_manager._on_story_choice)
		game_manager.story_popup.sacrifice_choice_made.connect(game_manager._on_sacrifice_choice_from_popup)
		game_manager.add_child(game_manager.story_popup)
	
	# Store the sacrifice in popup meta BEFORE calling open
	print("Sacrifice: Storing meta on popup before open()")
	print("Sacrifice: self = %s" % str(self))
	print("Sacrifice: popup = %s" % str(game_manager.story_popup))
	
	# Set meta on the popup node directly
	game_manager.story_popup.set_meta("current_sacrifice", self)
	game_manager.story_popup.set_meta("sacrifice_is_male", get_meta("is_male", false))
	
	# Verify the meta was set
	if game_manager.story_popup.has_meta("current_sacrifice"):
		print("Sacrifice: popup has current_sacrifice meta")
	else:
		print("Sacrifice: WARNING - popup does NOT have current_sacrifice meta!")
	
	# Show the popup
	print("GameManager: Calling story_popup.open()...")
	game_manager.story_popup.open(story_kind)

func remove_sacrifice() -> void:
	# Called when the story answer is processed
	print("Sacrifice: Removing itself from the scene")
	queue_free()
