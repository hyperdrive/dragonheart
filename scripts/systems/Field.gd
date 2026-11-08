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
## One farmer per field (rule 2026-11-08): claim carries an auto-expiring
## lease so deaths/flees can't lock a plot forever.
var claimant_id: int = 0
var claim_expires: int = 0

@onready var crops_visual: ColorRect = $Crops
@onready var regrow_timer: Timer = $RegrowTimer

const COLOR_GROWN := Color(0.3, 0.75, 0.2, 1.0)
const COLOR_STUBBLE := Color(0.45, 0.33, 0.2, 1.0)

func _ready() -> void:
	add_to_group("fields")
	regrow_timer.timeout.connect(_on_regrow_timeout)

## Dragon fire entry point: the Dragon's breath-cone scan calls burn() on
## this node (see Dragon._ignite_flammables). Burning is instant: crops
## collapse to stubble at once. The claim stays until the lease lapses or
## the holder releases — a burnt plot is unworkable, so no one contests it.
func burn() -> void:
	if state != FieldState.GROWN:
		return
	state = FieldState.STUBBLE
	crops_visual.color = COLOR_STUBBLE
	regrow_timer.start(regrow_time)
	print("Field burnt at ", global_position)
	field_burnt.emit(self)

## City gold sows the field again (rule 2026-11-08): instant regrow, one field
## per gold delivery (WorldManager picks which).
func regrow() -> void:
	if state != FieldState.STUBBLE:
		return
	state = FieldState.GROWN
	crops_visual.color = COLOR_GROWN
	regrow_timer.stop()
	field_ready.emit(self)
	print("Field regrown (sown by city gold) at ", global_position)

## Kept for FireArea compatibility (burning here is instant, not sustained).
func stop_burning() -> void:
	pass

## Farmers query this in the activity target provider / work-abort gate.
func is_workable() -> bool:
	return state == FieldState.GROWN

# --- single-farmer claim (rule 2026-11-08) -----------------------------------

## True when another farmer currently holds the plot (lease still live).
func is_claimed_other(for_id: int) -> bool:
	return claimant_id != 0 and claimant_id != for_id \
		and Time.get_ticks_msec() < claim_expires

## Take the claim; the lease self-expires AFTER p_work window + slack, covering
## abandonment paths (flee mid-claim, death) without dangling locks.
func claim(claimant: int, lease_ms: int) -> void:
	claimant_id = claimant
	claim_expires = Time.get_ticks_msec() + lease_ms

## Hand back the plot (activity completed normally, or retire the farmer).
func release(claimant: int) -> void:
	if claimant_id == claimant:
		claimant_id = 0

func _on_regrow_timeout() -> void:
	state = FieldState.GROWN
	crops_visual.color = COLOR_GROWN
	field_ready.emit(self)
	print("Field regrown at ", global_position)
