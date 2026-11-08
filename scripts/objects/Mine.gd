extends Area2D

class_name Mine

signal gold_collected(amount)
signal gems_collected(amount)

@export var gold_amount: int = 50
@export var gems_amount: int = 5
@export var respawn_time: float = 10.0

var is_active: bool = true
var respawn_timer: float = 0.0

func get_gold_sprite():
	# Handle instantiated scene naming patterns
	var gold_node = get_node_or_null("Sprite/Gold")
	if gold_node == null:
		gold_node = get_node_or_null("Sprite#Gold")
	if gold_node == null:
		gold_node = get_node_or_null("Mine_Sprite#Gold")
	return gold_node

func get_gems_sprite():
	# Handle instantiated scene naming patterns
	var gems_node = get_node_or_null("Sprite/Gems")
	if gems_node == null:
		gems_node = get_node_or_null("Sprite#Gems")
	if gems_node == null:
		gems_node = get_node_or_null("Mine_Sprite#Gems")
	return gems_node

func _ready():
	var gold_sprite = get_gold_sprite()
	var gems_sprite = get_gems_sprite()
	
	if gold_sprite and not is_active:
		gold_sprite.hide()
	if gems_sprite and not is_active:
		gems_sprite.hide()

func _process(delta):
	if not is_active:
		respawn_timer -= delta
		if respawn_timer <= 0:
			activate()

func activate():
	is_active = true
	var gold_sprite = get_gold_sprite()
	var gems_sprite = get_gems_sprite()
	
	if gold_sprite:
		gold_sprite.show()
	if gems_sprite:
		gems_sprite.show()

func deactivate():
	is_active = false
	respawn_timer = respawn_time
	var gold_sprite = get_gold_sprite()
	var gems_sprite = get_gems_sprite()
	
	if gold_sprite:
		gold_sprite.hide()
	if gems_sprite:
		gems_sprite.hide()

func collect_resources() -> Dictionary:
	if not is_active:
		return {"gold": 0, "gems": 0}
	
	var collected_gold = min(gold_amount, randi_range(20, 40))
	var collected_gems = min(gems_amount, randi_range(1, 3))
	
	gold_amount -= collected_gold
	gems_amount -= collected_gems
	
	if gold_amount <= 0 and gems_amount <= 0:
		deactivate()
	
	emit_signal("gold_collected", collected_gold)
	emit_signal("gems_collected", collected_gems)
	
	return {"gold": collected_gold, "gems": collected_gems}

func _on_body_entered(body):
	if body.is_in_group("dragon") and is_active:
		var resources = collect_resources()
		if body.has_method("collect_resources"):
			body.collect_resources(resources)

func _on_gold_area_entered(area):
	# Handle when dragon collects gold
	if area.is_in_group("dragon") and is_active:
		var resources = collect_resources()
		if area.get_parent().has_method("collect_resources"):
			area.get_parent().collect_resources(resources)

func _on_gem_area_entered(area):
	# Handle when dragon collects gems
	if area.is_in_group("dragon") and is_active:
		var resources = collect_resources()
		if area.get_parent().has_method("collect_resources"):
			area.get_parent().collect_resources(resources)