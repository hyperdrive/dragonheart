extends Area2D

class_name Field

## A burnable crop field — the vehicle for the economy-only dragon-consequence
## loop (docs/decisions/2026-11-08-behavior-system.md):
##   dragon fire → burn() → workable for NOBODY → RegrowTimer (slow) → ready again
## Farmers see it through the "fields" group (is_workable() + global_position).

signal field_burnt(field: Field)
signal field_ready(field: Field)

enum FieldState { GROWN, STUBBLE }

@export_group("Consequence tuning")
@export var regrow_time: float = 30.0

var state: FieldState = FieldState.GROWN

@onready var crops_visual: ColorRect = $Crops
@onready var regrow_timer: Timer = $RegrowTimer

const COLOR_GROWN := Color(0.3, 0.75, 0.2, 1.0)
const COLOR_STUBBLE := Color(0.45, 0.33, 0.2, 1.0)

func _ready() -> void:
	add_to_group("fields")
	regrow_timer.timeout.connect(_on_regrow_timeout)

## Dragon fire entry point (Dragon.tscn FireArea calls burn() on group
## "flammable" members). Burning is instant: crops collapse to stubble at once.
func burn() -> void:
	if state != FieldState.GROWN:
		return
	state = FieldState.STUBBLE
	crops_visual.color = COLOR_STUBBLE
	regrow_timer.start(regrow_time)
	print("Field burnt at ", global_position)
	field_burnt.emit(self)

## Kept for FireArea compatibility (burning here is instant, not sustained).
func stop_burning() -> void:
	pass

## Farmers query this in the activity target provider / work-abort gate.
func is_workable() -> bool:
	return state == FieldState.GROWN

func _on_regrow_timeout() -> void:
	state = FieldState.GROWN
	crops_visual.color = COLOR_GROWN
	field_ready.emit(self)
	print("Field regrown at ", global_position)
