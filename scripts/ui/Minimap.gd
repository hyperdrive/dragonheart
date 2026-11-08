extends Panel

signal entity_position_updated(entity_type, position)

@onready var minimap_texture = $MinimapTexture
var entities = {}
var world_size = Vector2(2000, 2000)
var minimap_size = Vector2(200, 200)

func _ready():
	# Create a drawing surface for the minimap
	var image = Image.create(minimap_size.x, minimap_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.1, 0.1, 1))  # Dark background
	var texture = ImageTexture.create_from_image(image)
	minimap_texture.texture = texture
	
	# Draw world boundaries
	_draw_world_boundaries()

func update_entity_position(entity_type: String, position: Vector2, remove: bool = false):
	print("Minimap: update_entity_position called for %s at %s (remove: %s)" % [entity_type, str(position), str(remove)])
	
	if remove:
		if entities.has(entity_type):
			entities.erase(entity_type)
	else:
		entities[entity_type] = position
	
	# Redraw the minimap
	_draw_minimap()

func _draw_world_boundaries():
	var image = minimap_texture.texture.get_image()
	
	# Draw world boundaries as a border
	var border_width = 2
	image.fill_rect(Rect2(0, 0, minimap_size.x, border_width), Color(0.5, 0.5, 0.5))  # Top
	image.fill_rect(Rect2(0, minimap_size.y - border_width, minimap_size.x, border_width), Color(0.5, 0.5, 0.5))  # Bottom
	image.fill_rect(Rect2(0, 0, border_width, minimap_size.y), Color(0.5, 0.5, 0.5))  # Left
	image.fill_rect(Rect2(minimap_size.x - border_width, 0, border_width, minimap_size.y), Color(0.5, 0.5, 0.5))  # Right
	
	minimap_texture.texture.set_image(image)

func _draw_minimap():
	var image = minimap_texture.texture.get_image()
	
	# Redraw world boundaries
	_draw_world_boundaries()
	
	# Draw entities
	for entity_type in entities:
		var world_pos = entities[entity_type]
		var minimap_pos = _world_to_minimap(world_pos)
		
		# Different colors for different entity types
		var color = Color.WHITE
		match entity_type:
			"farmer":
				color = Color.GREEN
			"miner":
				color = Color.BROWN
			"mine":
				color = Color.GOLD
			"soldier":
				color = Color.RED
			"boss":
				color = Color.MAROON
			"tower":
				color = Color.BLUE
			"pig":
				color = Color.PINK
			"cow":
				color = Color.BROWN
			_:
				color = Color.WHITE
		
		# Draw entity as a small square
		var size = 4
		image.fill_rect(Rect2(minimap_pos.x - size/2, minimap_pos.y - size/2, size, size), color)
	
	minimap_texture.texture.set_image(image)

func _world_to_minimap(world_pos: Vector2) -> Vector2:
	# Convert world coordinates (centered) to minimap coordinates (top-left)
	var minimap_x = (world_pos.x + world_size.x/2) / world_size.x * minimap_size.x
	var minimap_y = (world_pos.y + world_size.y/2) / world_size.y * minimap_size.y
	return Vector2(minimap_x, minimap_y)

func update_dragon_position(dragon_pos: Vector2):
	print("Minimap: update_dragon_position called for dragon at %s" % str(dragon_pos))
	
	# Draw dragon position on minimap
	var image = minimap_texture.texture.get_image()
	var minimap_pos = _world_to_minimap(dragon_pos)
	
	# Redraw world boundaries and entities first
	_draw_minimap()
	
	# Draw dragon as a distinctive symbol
	var size = 6
	image.fill_rect(Rect2(minimap_pos.x - size/2, minimap_pos.y - size/2, size, size), Color.CYAN)
	
	# Draw a small triangle pointing up to indicate direction
	var points = [
		Vector2(minimap_pos.x, minimap_pos.y - size),
		Vector2(minimap_pos.x - size/2, minimap_pos.y + size/2),
		Vector2(minimap_pos.x + size/2, minimap_pos.y + size/2)
	]
	var polygon = PackedVector2Array(points)
	image.draw_polygon(polygon, [Color.CYAN])
	
	minimap_texture.texture.set_image(image)