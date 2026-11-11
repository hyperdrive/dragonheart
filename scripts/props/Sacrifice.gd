extends Node2D

class_name Sacrifice

## The sacrifice: a rugged villager tied to a wooden pole, presented to the
## dragon after every 3 fields are burnt. The dragon can eat them (+2 flames)
## or take them to the lair to train as a dragon rider. 20% chance the
## captive is a man who can be trained as a dragon rider.
##
## Visuals (2026-11-11, user: "they should look rugged"): built in code from
## ColorRects in the same flat style as the dragon and NPCs. Both gender
## variants are generated here with PER-INSTANCE raggedness — torn hems,
## frayed ropes, dirt smudges, hair strands and a leaning hand-cut pole are
## randomized, so no two captives look identical. A gentle struggle sway
## keeps them visibly alive at the stake (code-driven, pause-safe).

## Story popup state - only triggers once per sacrifice per run
var _story_triggered: bool = false

## 20% chance the captive is male (trainable as rider)
@export var is_male: bool = false

@onready var visual: Node2D = $Visual

# --- palette: earthy, dirty, matching the world's flat shading ----------------
const POLE_WOOD := Color(0.48, 0.31, 0.14)
const POLE_GRAIN := Color(0.37, 0.23, 0.1)
const ROPE := Color(0.73, 0.61, 0.42)
const ROPE_FRAY := Color(0.62, 0.5, 0.33)
const SKIN := Color(0.9, 0.76, 0.6)          # woman
const SKIN_MAN := Color(0.84, 0.67, 0.5)     # man, more field-tanned
const STUBBLE := Color(0.58, 0.45, 0.34)
const HAIR_DARK := Color(0.24, 0.16, 0.1)
const HAIR_MID := Color(0.38, 0.26, 0.14)
const DRESS_FADED := Color(0.52, 0.33, 0.36) # once-rose, sun-beaten
const TUNIC_DIRT := Color(0.44, 0.41, 0.34)  # field-hand grey
const PANTS_RAG := Color(0.3, 0.24, 0.18)
const MUD := Color(0.33, 0.26, 0.18, 0.9)
const DIRT_PATCH := Color(0.32, 0.24, 0.16, 0.85)
const SHADOW := Color(0, 0, 0, 0.25)

var _person_pivot: Node2D
var _struggle_phase: float = 0.0
const STRUGGLE_HZ := 1.6

func _ready() -> void:
	# Randomize gender: 20% male
	is_male = randf() < 0.2
	set_meta("is_male", is_male)
	_struggle_phase = randf() * TAU  # multiple captives never sway in sync
	_build_visuals()

func _build_visuals() -> void:
	# Trampled ground: shadow + dirt where the crowd stood.
	_rect(visual, -16.0, 8.0, 32.0, 5.0, SHADOW)
	_rect(visual, -12.0, 5.0, 24.0, 4.0, DIRT_PATCH)

	# The pole: hand-cut, slightly leaning, grain seams and a knot.
	var pole := Node2D.new()
	pole.name = "Pole"
	pole.rotation_degrees = randf_range(-3.0, 3.0)
	visual.add_child(pole)
	_rect(pole, -3.0, -58.0, 7.0, 66.0, POLE_WOOD)
	_rect(pole, -1.0, -58.0, 1.5, 66.0, POLE_GRAIN)     # grain seam
	_rect(pole, 1.5, -30.0, 1.5, 10.0, POLE_GRAIN)      # knot streak
	_rect(pole, -2.5, -18.0, 2.0, 6.0, POLE_GRAIN)      # knot
	# Rough crossbar at shoulder height — wrists lashed up.
	_rect(pole, -14.0, -34.0, 28.0, 5.0, POLE_WOOD)
	_rect(pole, -14.0, -34.0, 28.0, 1.5, POLE_GRAIN)
	# Rope lashings on the crossbar ends, frayed.
	_rect(pole, -13.0, -33.5, 3.0, 6.0, ROPE)
	_rect(pole, 10.0, -33.5, 3.0, 6.0, ROPE)
	_fray(pole, -12.0, -28.0, 2)
	_fray(pole, 10.5, -28.0, 2)

	# The captive, built on a pivot at ground level so the struggle sway
	# wobbles them like a held breath.
	_person_pivot = Node2D.new()
	_person_pivot.name = "PersonPivot"
	visual.add_child(_person_pivot)
	if is_male:
		_build_man()
	else:
		_build_woman()

	# Shared bindings over whichever body was built: chest + waist straps.
	_rect(_person_pivot, -8.0, -27.0, 16.0, 3.0, ROPE)
	_rect(_person_pivot, -8.0, -16.0, 16.0, 3.0, ROPE)
	_fray(_person_pivot, 7.0, -25.0, 1)
	_fray(_person_pivot, -9.0, -14.0, 1)

## The woman: faded rose dress with a torn, muddy hem; long messy hair.
func _build_woman() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Kneeling dress: main panel + flare toward the ground.
	_rect(_person_pivot, -7.0, -30.0, 14.0, 22.0, DRESS_FADED)
	_rect(_person_pivot, -9.0, -12.0, 18.0, 9.0, DRESS_FADED)
	# Mud smudges where she was dragged.
	_rect(_person_pivot,
		rng.randf_range(-7.0, -2.0), rng.randf_range(-24.0, -18.0),
		rng.randf_range(3.0, 5.0), 3.0, MUD)
	_rect(_person_pivot,
		rng.randf_range(1.0, 5.0), rng.randf_range(-14.0, -10.0),
		rng.randf_range(3.0, 5.0), 3.0, MUD)
	# Torn hem: jagged patches along the bottom edge.
	_torn_hem(-9.0, 18.0, -3.0, DRESS_FADED)
	# Head: eyes downcast, hair falling in uneven strands.
	_rect(_person_pivot, -4.5, -38.0, 9.0, 8.0, SKIN)
	_rect(_person_pivot, -5.5, -40.0, 11.0, 4.0, HAIR_DARK)
	var strand_len := rng.randf_range(7.0, 12.0)
	_rect(_person_pivot, -7.0, -36.0, 2.0, strand_len, HAIR_DARK)
	_rect(_person_pivot, 5.0, -36.0, 2.0, strand_len - rng.randf_range(0.0, 4.0),
		HAIR_MID)
	# A ribbon in the hair — the one thing she kept tidy.
	_rect(_person_pivot, -5.0, -37.5, 10.0, 1.5, Color(0.6, 0.2, 0.25))

## The man: dirt-grey field tunic, ragged pants, stubble, close-cropped mess.
func _build_man() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Kneeling: tunic torso + folded shins under it.
	_rect(_person_pivot, -6.0, -30.0, 12.0, 18.0, TUNIC_DIRT)
	_rect(_person_pivot, -6.0, -12.0, 12.0, 9.0, PANTS_RAG)
	# Knees pressed into the dirt.
	_rect(_person_pivot, -8.0, -5.0, 4.0, 3.0, SKIN_MAN)
	_rect(_person_pivot, 4.0, -5.0, 4.0, 3.0, SKIN_MAN)
	# Mud smudges on the tunic.
	_rect(_person_pivot,
		rng.randf_range(-6.0, -2.0), rng.randf_range(-26.0, -20.0),
		rng.randf_range(3.0, 5.0), 3.0, MUD)
	_rect(_person_pivot,
		rng.randf_range(0.0, 4.0), rng.randf_range(-15.0, -12.0),
		rng.randf_range(2.0, 4.0), 3.0, MUD)
	# Torn hem on the tunic.
	_torn_hem(-6.0, 12.0, -12.0, TUNIC_DIRT)
	# Head: tanned, stubbled jaw, short messy hair.
	_rect(_person_pivot, -4.0, -38.0, 8.0, 8.0, SKIN_MAN)
	_rect(_person_pivot, -3.5, -33.5, 7.0, 2.5, STUBBLE)
	_rect(_person_pivot, -5.0, -40.0, 10.0, 4.0, HAIR_MID)
	_rect(_person_pivot, rng.randf_range(-4.0, 2.0), -41.0, 3.0, 2.0, HAIR_MID)

## Jagged tear along a hem: 3 irregular patches dropping below the edge.
func _torn_hem(x: float, w: float, y: float, col: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var cursor := x
	while cursor < x + w - 2.0:
		var chunk := rng.randf_range(2.0, 5.0)
		_rect(_person_pivot, cursor, y,
			chunk, rng.randf_range(2.0, 4.5), col)
		cursor += chunk

## Frayed rope ends: tiny strands sticking off a lashing.
func _fray(parent: Node, x: float, y: float, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		_rect(parent, x + rng.randf_range(-1.0, 1.0),
			y + rng.randf_range(-1.0, 1.0),
			1.0, rng.randf_range(2.5, 4.5), ROPE_FRAY,
			rng.randf_range(-25.0, 25.0))

## One flat ColorRect in the world-art style.
func _rect(parent: Node, x: float, y: float, w: float, h: float,
		col: Color, rot_deg: float = 0.0) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = Vector2(x, y)
	rect.size = Vector2(w, h)
	rect.color = col
	if rot_deg != 0.0:
		rect.rotation_degrees = rot_deg
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

## The struggle sway: a slow, exhausted lean side to side with a small sink
## into the knees. Subtle — they have been standing there a while.
func _tick_struggle(delta: float) -> void:
	if _person_pivot == null:
		return
	_struggle_phase += delta * STRUGGLE_HZ
	_person_pivot.rotation_degrees = sin(_struggle_phase * TAU) * 2.2
	_person_pivot.position.y = absf(sin(_struggle_phase * TAU * 0.5)) * 1.5

func _physics_process(delta: float) -> void:
	_tick_struggle(delta)
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