extends RefCounted

class_name NavGrid

## Walkable-area grid + A* (2026-11-14, user: "overlaying with a virtual
## gridmesh and doing A*"). Replaces "walk straight at it and sidestep once
## stuck" with real routes — measured before: in 16 game-minutes of town life
## NPCs spent 1361 s stalled and the StuckMonitor stepped in 354 times.
##
## The world is cut into CELL-px squares. A cell is SOLID when an NPC body
## (BODY_SIZE box) standing on its centre would touch blocking scenery —
## the same physics layers that stop NPC bodies (terrain 1, trees 16,
## lakes 32, boundary walls). Built once after world generation, patched
## when scenery appears later (refresh_area: the hag's nest and its firs).
##
##   route(from, to)        → world points to walk; straight [to] when the
##                            line is clear, a smoothed A* path otherwise,
##                            empty when no route exists.
##   nearest_walkable(p)    → the closest reachable spot to p (targets that
##                            sit inside a rock or beyond the walls snap
##                            here instead of being unreachable forever).
##   line_clear(a, b)       → grid line of sight for a body-wide walker.
##
## Each cell also carries a weight (AStarGrid2D weight_scale, 1.0 now) —
## the hook for the planned "ant trails" traffic heatmap.

const CELL := 16.0
## The body probe: a box covering every walking NPC's real collision shape
## (farmer 16×32 at 0,0 · soldier/hag/goblin up to 18×25 at 0,+5 · King
## 25×35 at 0,+5 → x ±12.5, y −16…+22.5) plus a little slack for standing
## between cell centres. A smaller probe let the grid call lines "clear"
## that the taller bodies scraped along (found: a soldier sliding on a
## mountain foot with a straight route).
const BODY_SIZE := Vector2(28.0, 42.0)
const BODY_OFFSET := Vector2(0.0, 3.0)
const BLOCK_MASK := 49   # terrain (1) + trees (16) + lakes (32)

var astar := AStarGrid2D.new()
var origin := Vector2.ZERO        # world position of cell (0, 0)'s corner
var size := Vector2i.ZERO
var is_built := false

var _space: PhysicsDirectSpaceState2D
var _probe := PhysicsShapeQueryParameters2D.new()

## Rasterise the world: one body-sized shape query per cell (~14k cells on
## a 1920 px world; a one-off at generation).
func build(world: Node2D, world_size: Vector2) -> void:
	_space = world.get_world_2d().direct_space_state
	var box := RectangleShape2D.new()
	box.size = BODY_SIZE
	_probe.shape = box
	_probe.collision_mask = BLOCK_MASK
	size = Vector2i(ceili(world_size.x / CELL), ceili(world_size.y / CELL))
	origin = -world_size * 0.5
	astar.region = Rect2i(Vector2i.ZERO, size)
	astar.cell_size = Vector2(CELL, CELL)
	astar.offset = origin + Vector2(CELL, CELL) * 0.5   # id → cell CENTRE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	_rasterise(Rect2i(Vector2i.ZERO, size))
	is_built = true

## Re-test the cells under a world rect (new scenery spawned there).
func refresh_area(world_rect: Rect2) -> void:
	if not is_built:
		return
	var a := _cell_of(world_rect.position)
	var b := _cell_of(world_rect.end)
	_rasterise(Rect2i(a, b - a + Vector2i.ONE).intersection(astar.region))

func _rasterise(cells: Rect2i) -> void:
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			var id := Vector2i(x, y)
			_probe.transform = Transform2D(0.0, astar.get_point_position(id) + BODY_OFFSET)
			astar.set_point_solid(id, not _space.intersect_shape(_probe, 1).is_empty())

func _cell_of(p: Vector2) -> Vector2i:
	var c := Vector2i(floori((p.x - origin.x) / CELL), floori((p.y - origin.y) / CELL))
	return c.clamp(Vector2i.ZERO, size - Vector2i.ONE)

func is_walkable(p: Vector2) -> bool:
	return is_built and not astar.is_point_solid(_cell_of(p))

## Closest walkable cell centre to p (rings outward; p itself if walkable).
func nearest_walkable(p: Vector2, max_rings: int = 24) -> Vector2:
	if not is_built:
		return p
	var c := _cell_of(p)
	if not astar.is_point_solid(c):
		return p.clamp(origin + Vector2(CELL, CELL) * 0.5,
			origin + Vector2(size) * CELL - Vector2(CELL, CELL) * 0.5)
	for r in range(1, max_rings + 1):
		var best := Vector2.INF
		var best_d := INF
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue   # ring only
				var id := c + Vector2i(dx, dy)
				if not astar.region.has_point(id) or astar.is_point_solid(id):
					continue
				var w := astar.get_point_position(id)
				var d := w.distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = w
		if best != Vector2.INF:
			return best
	return p

## Body-wide line of sight on the grid: every cell the segment crosses
## (sampled at half-cell steps) must be walkable.
func line_clear(a: Vector2, b: Vector2) -> bool:
	if not is_built:
		return true
	var steps := maxi(1, ceili(a.distance_to(b) / (CELL * 0.5)))
	for i in steps + 1:
		if astar.is_point_solid(_cell_of(a.lerp(b, float(i) / float(steps)))):
			return false
	return true

## World points to walk from `from` to `to`. The endpoint is `to` itself
## when walkable (else its nearest walkable spot). Empty = no route.
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not is_built:
		return PackedVector2Array([to])
	var goal := to if is_walkable(to) else nearest_walkable(to)
	var start := from if is_walkable(from) else nearest_walkable(from)
	if line_clear(start, goal):
		return PackedVector2Array([goal]) if start == from \
			else PackedVector2Array([start, goal])
	var cells := astar.get_id_path(_cell_of(start), _cell_of(goal))
	if cells.is_empty():
		return PackedVector2Array()
	var raw := PackedVector2Array()
	for id in cells:
		raw.append(astar.get_point_position(id))
	raw[raw.size() - 1] = goal
	if start != from:
		raw.insert(0, start)   # step back onto open ground first
	return _smooth(from, raw)

## String-pulling: from each anchor jump to the furthest point still in
## line of sight — grid zig-zags become straight legs around the corners.
func _smooth(from: Vector2, pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var anchor := from
	var i := 0
	while i < pts.size():
		var far := i
		for j in range(pts.size() - 1, i, -1):
			if line_clear(anchor, pts[j]):
				far = j
				break
		out.append(pts[far])
		anchor = pts[far]
		i = far + 1
	return out
