extends Area2D

class_name WizardTower

## The wizard tower — THE upgrade site (satisfies the deferred requirement in
## behavior-system). The dragon entering opens the WizardMenu overlay
## (world paused; purchases via GameManager). Once per entry — the guard
## resets on exit so stepping out and back reopens deliberately.

var _dragon_inside: bool = false

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if _dragon_inside or not body.is_in_group("dragon"):
		return
	_dragon_inside = true
	var manager := get_tree().get_first_node_in_group("game_manager") as GameManager
	if manager == null:
		return
	# Every door opening counts — the wizard inside is tallying (the
	# backstab trigger: purchases >= 3 AND visits > 3, OR 30g stash).
	manager.tower_visits += 1
	print("The wizard opens the tower doors… (visit #%d)" % manager.tower_visits)
	manager.open_wizard_menu()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("dragon"):
		_dragon_inside = false
