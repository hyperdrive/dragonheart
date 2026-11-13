extends Node2D

## WorldLayoutProbe — verification for the world editor pipeline (decision
## record 2026-11-12-world-editor). Run headless:
##   Godot --headless --path . res://scenes/probes/WorldLayoutProbe.tscn
##
## Scenario:
##   1. FALLBACK: no world selected → the legacy procedural generation runs
##      (city at its default export position, no layout active).
##   2. BUILD+SAVE: a sample layout is built in code — key elements placed,
##      six masks painted (incl. the two forest densities and mountains),
##      fixed seed —
##      and saved to res://worlds/sample_world/ (this also leaves an
##      inspectable example world in the repo).
##   3. LAYOUT MODE: the game boots on that world — landmarks stand at the
##      layout positions; EVERY dense tree / sparse tree / lake / field /
##      mine sits on a bright pixel of ITS mask.
##   4. DETERMINISM: a second boot on the same layout reproduces the exact
##      same tree positions (seeded placement).
##
## Every step prints "PROBE PASS/FAIL:" and the run ends with
## "PROBE RESULT: SUCCESS|FAILURE" + exit code 0/1.

enum S { BOOT, FALLBACK_WAIT, BUILD_SAVE, LAYOUT_WAIT, LAYOUT_CHECK,
	DETERM_WAIT, DETERM_CHECK, REPORT }

const WORLD_NAME := "sample_world"
const SETTLE_FRAMES := 30

# Sample world landmarks (painted masks deliberately avoid overlapping them).
const CITY_POS := Vector2(500, 500)
const LAIR_POS := Vector2(-700, 0)
const GOBLIN_POS := Vector2(-400, -600)
const TOWER_POS := Vector2(600, -500)
const PIG_POS := Vector2(-300, 750)
const COW_POS := Vector2(300, 780)
const MINE_CENTER_POS := Vector2(-600, -600)
const SEED := 424242

# Mask regions in WORLD coordinates (x0, y0, x1, y1).
const REGIONS := {
	"fields": [Vector2(100, 100), Vector2(850, 850)],
	"mines": [Vector2(-950, -950), Vector2(-300, -300)],
	"forest_dense": [Vector2(-950, 100), Vector2(-400, 650)],
	"forest_sparse": [Vector2(300, -950), Vector2(950, -200)],
	"lakes": [Vector2(500, 500), Vector2(950, 950)],
	"mountains": [Vector2(-950, 700), Vector2(-300, 950)],
}

var state: int = S.BOOT
var frames_in_state: int = 0
var passes: Array[String] = []
var failures: Array[String] = []
var _main: Node = null
var _tree_positions: Array[Vector2] = []

@onready var session: Node = WorldSession

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _pass(msg: String) -> void:
	passes.append(msg)
	print("PROBE PASS: ", msg)

func _fail(msg: String) -> void:
	failures.append(msg)
	print("PROBE FAIL: ", msg)

func _goto(next: int) -> void:
	state = next
	frames_in_state = 0

func _frames(n: int) -> bool:
	return frames_in_state >= n

func _boot_main() -> void:
	_main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(_main)

func _drop_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null

func _world() -> WorldManager:
	return get_tree().get_first_node_in_group("world_manager") as WorldManager

func _first_in_group(group: String) -> Node2D:
	for node: Node in get_tree().get_nodes_in_group(group):
		return node as Node2D
	return null

## Trees carry no group — identify them by their scene file.
func _trees() -> Array[Node2D]:
	var found: Array[Node2D] = []
	var world := _world()
	if world == null:
		return found
	for child: Node in world.get_children():
		var body := child as Node2D
		if body != null and str(body.scene_file_path).ends_with("Tree.tscn"):
			found.append(body)
	return found

func _paint_region(img: Image, layout: WorldLayout, region: Array) -> void:
	var a := layout.world_to_mask(region[0])
	var b := layout.world_to_mask(region[1])
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			img.set_pixel(x, y, Color(1, 1, 1))

func _build_sample_layout() -> WorldLayout:
	var layout := WorldLayout.new()
	layout.seed_value = SEED
	layout.city_position = CITY_POS
	layout.lair_position = LAIR_POS
	layout.goblin_mountain_position = GOBLIN_POS
	layout.tower_position = TOWER_POS
	layout.pig_pen_position = PIG_POS
	layout.cow_pen_position = COW_POS
	layout.mine_center = MINE_CENTER_POS
	# The painted mountains band is sized for 3 rocks with full clearance
	# (150px spacing, pig-pen exclusion) — the default 5 would overflow it
	# and the overflow falls back to random scatter off-mask.
	layout.mountain_count = 3
	for category: String in WorldLayout.MASK_CATEGORIES:
		var img := layout.blank_mask_image(category)
		_paint_region(img, layout, REGIONS[category])
		layout.set_mask_texture(category, ImageTexture.create_from_image(img))
	return layout

## True when EVERY node in `nodes` sits on a bright pixel of its category.
func _all_on_mask(category: String, nodes: Array[Node2D]) -> Dictionary:
	var world := _world()
	var layout := world.active_layout
	var off: Array[String] = []
	for node: Node2D in nodes:
		if layout.sample_mask(category, node.global_position) \
				< WorldLayout.BRIGHT_THRESHOLD:
			off.append(str(node.global_position))
	return {"ok": off.is_empty(), "off": off}

func _physics_process(_delta: float) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	frames_in_state += 1
	# Keep any probe dragon alive: a death chapter would reload the scene
	# mid-probe (see AdventurerProbe).
	if _main != null and is_instance_valid(_main):
		var dragon: Node2D = _first_in_group("dragon")
		if dragon != null and is_instance_valid(dragon):
			var dying: Variant = dragon.get("_dying")
			if (dying == null or not bool(dying)) \
					and dragon.get("health") is int:
				dragon.set("health", int(dragon.get("max_health")))

	match state:
		S.BOOT:
			session.pending_world = ""  # phase 1: legacy procedural world
			_boot_main()
			_goto(S.FALLBACK_WAIT)
		S.FALLBACK_WAIT:
			if _frames(SETTLE_FRAMES):
				var world := _world()
				var city := _first_in_group("city")
				if world == null or city == null:
					_fail("FALLBACK: Main/city missing")
					_goto(S.REPORT)
					return
				if world.active_layout != null:
					_fail("REGRESSION: a layout is active with no world "
						+ "selected")
					_goto(S.REPORT)
					return
				if city.global_position.distance_to(Vector2(0, 620)) > 1.0:
					_fail("procedural city drifted: %s (expected ~(0, 620))"
						% str(city.global_position))
					_goto(S.REPORT)
					return
				_pass("FALLBACK: no world selected → procedural city at %s"
					% str(city.global_position))
				_drop_main()
				_goto(S.BUILD_SAVE)
		S.BUILD_SAVE:
			var layout := _build_sample_layout()
			var err: Error = layout.save_to_world(WORLD_NAME)
			if err != OK:
				_fail("layout save failed: %s" % error_string(err))
				_goto(S.REPORT)
				return
			var msg := "BUILD+SAVE: sample world written to res://worlds/%s/ (seed %d)" % [WORLD_NAME, SEED]
			_pass(msg)
			session.pending_world = WORLD_NAME
			_boot_main()
			_goto(S.LAYOUT_WAIT)
		S.LAYOUT_WAIT:
			if _frames(SETTLE_FRAMES):
				var world := _world()
				if world == null or world.active_layout == null:
					_fail("LAYOUT MODE: layout not applied on boot")
					_goto(S.REPORT)
					return
				_goto(S.LAYOUT_CHECK)
		S.LAYOUT_CHECK:
			var world := _world()
			var layout := world.active_layout
			# Landmarks stand where the editor placed them.
			var checks := {
				"city": ["city", CITY_POS],
				"dragon lair": ["dragon_lair", LAIR_POS],
				"wizard tower": ["wizard_tower", TOWER_POS],
			}
			var landmark_fail := ""
			for label: String in checks:
				var node := _first_in_group(checks[label][0])
				if node == null:
					landmark_fail += "no %s; " % label
				elif node.global_position.distance_to(checks[label][1]) > 1.0:
					landmark_fail += "%s at %s (expected %s); " % [label,
						str(node.global_position), str(checks[label][1])]
			var goblin_rock := false
			for mountain: Node in get_tree().get_nodes_in_group("mountains"):
				var m := mountain as Node2D
				if m != null and m.global_position.distance_to(GOBLIN_POS) <= 1.0:
					goblin_rock = true
			if not goblin_rock:
				landmark_fail += "no goblin mountain at %s; " % str(GOBLIN_POS)
			if landmark_fail != "":
				_fail("LAYOUT MODE: %s" % landmark_fail)
				_goto(S.REPORT)
				return
			_pass("LAYOUT MODE: landmarks at their placed positions "
				+ "(city %s, lair %s, goblin mountain %s, tower %s)"
				% [str(CITY_POS), str(LAIR_POS), str(GOBLIN_POS),
					str(TOWER_POS)])
			# Forest discipline: every tree sits on a bright pixel of at
			# least ONE forest mask (dense or sparse — the two densities).
			var bad := ""
			var stray := 0
			for tree: Node2D in _trees():
				var in_dense := layout.sample_mask("forest_dense",
					tree.global_position) >= WorldLayout.BRIGHT_THRESHOLD
				var in_sparse := layout.sample_mask("forest_sparse",
					tree.global_position) >= WorldLayout.BRIGHT_THRESHOLD
				if not (in_dense or in_sparse):
					stray += 1
					bad += str(tree.global_position) + "; "
			if stray == 0:
				var forest_msg := "FOREST: all %d trees sit inside a painted forest mask (dense or sparse)" % _trees().size()
				_pass(forest_msg)
			else:
				_fail("REGRESSION: %d trees off both forest masks: %s"
					% [stray, bad])
				_goto(S.REPORT)
				return
			var lakes: Array[Node2D] = []
			for lake: Node in get_tree().get_nodes_in_group("water"):
				var l := lake as Node2D
				if l != null:
					lakes.append(l)
			var lake_check := _all_on_mask("lakes", lakes)
			if lake_check["ok"]:
				_pass("LAKES: all %d lakes inside the lakes mask"
					% lakes.size())
			else:
				_fail("REGRESSION: lakes off the lakes mask: %s"
					% str(lake_check["off"]))
				_goto(S.REPORT)
				return
			var fields: Array[Node2D] = []
			for f: Node in get_tree().get_nodes_in_group("fields"):
				var field := f as Node2D
				if field != null:
					fields.append(field)
			var field_check := _all_on_mask("fields", fields)
			if field_check["ok"]:
				_pass("FIELDS: all %d fields inside the fields mask"
					% fields.size())
			else:
				_fail("REGRESSION: fields off the fields mask: %s"
					% str(field_check["off"]))
				_goto(S.REPORT)
				return
			var mines: Array[Node2D] = []
			for m: Node in get_tree().get_nodes_in_group("mines"):
				var mine := m as Node2D
				if mine != null:
					mines.append(mine)
			var mine_check := _all_on_mask("mines", mines)
			if mine_check["ok"]:
				var mines_msg := "MINES: all %d mines inside the mines mask" % mines.size()
				_pass(mines_msg)
			else:
				_fail("REGRESSION: mines off the mines mask: %s"
					% str(mine_check["off"]))
				_goto(S.REPORT)
				return
			# Scattered mountains sit on the mountains mask; the goblin
			# rock is a PLACED landmark (GOBLIN_POS), not mask-scattered.
			var scattered: Array[Node2D] = []
			for m: Node in get_tree().get_nodes_in_group("mountains"):
				var mountain := m as Node2D
				if mountain != null \
						and mountain.global_position.distance_to(GOBLIN_POS) > 1.0:
					scattered.append(mountain)
			var mountain_check := _all_on_mask("mountains", scattered)
			if mountain_check["ok"]:
				var mountains_msg := "MOUNTAINS: all %d scattered mountains inside the mountains mask" % scattered.size()
				_pass(mountains_msg)
			else:
				_fail("REGRESSION: mountains off the mountains mask: %s"
					% str(mountain_check["off"]))
				_goto(S.REPORT)
				return
			_tree_positions.clear()
			for tree: Node2D in _trees():
				_tree_positions.append(tree.global_position)
			_tree_positions.sort()
			_drop_main()
			_goto(S.DETERM_WAIT)
		S.DETERM_WAIT:
			if _frames(10):  # let Main#2's queue_free fully settle
				_boot_main()
				_goto(S.DETERM_CHECK)
		S.DETERM_CHECK:
			if _frames(SETTLE_FRAMES):
				var again: Array[Vector2] = []
				for tree: Node2D in _trees():
					again.append(tree.global_position)
				again.sort()
				if again == _tree_positions:
					var det_msg := "DETERMINISM: second boot reproduced all %d tree positions (seeded placement)" % again.size()
					_pass(det_msg)
				else:
					_fail("REGRESSION: re-boot placements differ "
						+ "(%d vs %d trees; seed not honored)"
						% [_tree_positions.size(), again.size()])
				_drop_main()
				session.pending_world = ""
				_goto(S.REPORT)
		S.REPORT:
			set_physics_process(false)
			for p in passes:
				print("PROBE PASS: ", p)
			for f in failures:
				print("PROBE FAIL: ", f)
			if failures.is_empty():
				print("PROBE RESULT: SUCCESS (%d checks passed)" % passes.size())
				get_tree().quit(0)
			else:
				print("PROBE RESULT: FAILURE (%d passed, %d failed)"
					% [passes.size(), failures.size()])
				get_tree().quit(1)
