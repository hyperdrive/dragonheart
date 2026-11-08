extends Area2D

class_name WizardTower

## The wizard tower where the dragon spends stolen loot.
## Requirement: the tower eventually becomes the mandatory upgrade site —
## deferred (docs/decisions/2026-11-08-behavior-system.md, Open / deferred).
## For this pass it is a passive landmark; purchases happen anywhere via the
## HUD (U key).

func _ready() -> void:
	monitoring = true
