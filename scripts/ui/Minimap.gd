extends Panel
class_name MinimapPanel

## Lower-right corner dot minimap. Self-scans world groups on a timer and
## draws directly — no SubViewport, no texture churn. The dragon dot refreshes
## every frame via set_dragon() from GameHUD. World bounds resolve from the
## live WorldManager (no duplicated constant to drift when the world grows).

@export var world_size: Vector2 = Vector2(1920, 1920)  # fallback if no WorldManager

const TOOLTIP_STYLE := ""  # reserved

var _dragon_pos: Vector2 = Vector2.INF
var _refresh_timer: Timer
var _world_size_resolved := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 0.3
	_refresh_timer.autostart = true
	_refresh_timer.timeout.connect(scan_and_redraw)
	add_child(_refresh_timer)


## Pull the true world size from the WorldManager once (first draw — after
## every node is grouped), then trust it for the run.
func _resolve_world_size() -> void:
	if _world_size_resolved:
		return
	_world_size_resolved = true
	var world := get_tree().get_first_node_in_group("world_manager") as WorldManager
	if world != null and world.world_size != Vector2.ZERO:
		world_size = world.world_size


## Group-scan redraw (NPCs, mines, fields, pens, city, king).
func scan_and_redraw() -> void:
	queue_redraw()


func set_dragon(dragon_position: Vector2) -> void:
	_dragon_pos = dragon_position
	queue_redraw()


func set_entity(_entity_type: String, _position: Vector2, _remove: bool = false) -> void:
	# Positions self-refresh via the group scan; an external notify may force
	# a faster redraw, but the timer covers steady state.
	scan_and_redraw()


func _world_to_minimap(world_pos: Vector2) -> Vector2:
	# Draw space is LOCAL (position zero); get_rect().position is parent-
	# relative and offset everything off-panel — map world coords straight
	# into the local panel size.
	_resolve_world_size()
	var scale_factor: Vector2 = get_size() / world_size
	return Vector2(
		(world_pos.x + world_size.x / 2.0) * scale_factor.x,
		(world_pos.y + world_size.y / 2.0) * scale_factor.y
	)


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, get_size())  # local draw space
	draw_rect(box, Color(0.08, 0.09, 0.12, 0.85))
	draw_rect(box, Color(0.45, 0.45, 0.5, 0.9), false, 2.0)

	var city := get_tree().get_first_node_in_group("city") as Node2D
	if city != null:
		_draw_square(city.global_position, 8.0, Color(0.65, 0.4, 0.85))
	for group: String in [
		"pig_pens", "cow_pens",
	]:
		_draw_group(group, 4.0, Color(0.85, 0.55, 0.75))
	_draw_group("fields", 3.0, Color(0.35, 0.8, 0.35))
	_draw_group("mines", 4.0, Color(0.9, 0.75, 0.25))
	_draw_group("farmers", 3.0, Color(0.95, 0.9, 0.4))
	_draw_group("miners", 3.0, Color(0.6, 0.45, 0.3))
	_draw_group("soldiers", 3.0, Color(0.5, 0.7, 1.0))
	_draw_group("goblins", 3.0, Color(0.0, 0.8, 0.3))
	for king: Node in get_tree().get_nodes_in_group("king"):
		var king_node := king as Node2D
		if king_node != null and is_instance_valid(king_node):
			_draw_square(king_node.global_position, 6.0, Color(0.9, 0.1, 0.1))
	if _dragon_pos != Vector2.INF:
		_draw_dragon_dot()


func _draw_group(group: String, dot_size: float, color: Color) -> void:
	for node: Node in get_tree().get_nodes_in_group(group):
		var node2d := node as Node2D
		if node2d != null and is_instance_valid(node2d):
			_draw_square(node2d.global_position, dot_size, color)


func _draw_square(world_pos: Vector2, size: float, color: Color) -> void:
	var pos: Vector2 = _world_to_minimap(world_pos)
	draw_rect(Rect2(pos - Vector2(size, size) * 0.5, Vector2(size, size)), color)


func _draw_dragon_dot() -> void:
	var pos: Vector2 = _world_to_minimap(_dragon_pos)
	draw_rect(Rect2(pos - Vector2(4, 4), Vector2(8, 8)), Color(0.15, 1.0, 0.35))
	draw_circle(pos, 5.5, Color(0.15, 1.0, 0.35, 0.35))
