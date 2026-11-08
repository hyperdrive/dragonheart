extends Node2D

class_name GoldDrop

## Loose loot a panicking miner dropped while fleeing the dragon. Grows
## "settled" after a small delay (it scatters when dropped), then waits for
## the dragon to scoop it up (Dragon._process scans this group). Decays if
## nobody takes it — loose gold doesn't sit in a field forever.

signal drop_settled

const TEXTURES := {
	"gold": preload("res://assets/gold.svg"),
	"gems": preload("res://assets/gem.svg"),
}

@export var settle_delay: float = 1.2     # the "small delay" before pickup
@export var lifetime: float = 90.0        # unclaimed drops fade away

var res_type: String = "gold"
var amount: int = 1
var settled: bool = false
var _age: float = 0.0

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	var texture: Texture2D = TEXTURES.get(res_type, TEXTURES["gold"])
	(sprite as Sprite2D).texture = texture
	# Little settle-bounce: lands hot, then becomes grabbable.
	sprite.scale = Vector2(0.2, 0.2)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.9, 0.9), 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_age += delta
	if not settled and _age >= settle_delay:
		settled = true
		drop_settled.emit()
	if _age >= lifetime:
		queue_free()