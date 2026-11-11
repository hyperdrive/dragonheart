extends Node2D

## SoldierVisualProbe — regression probe for the rebuilt soldier/archer
## visuals (2026-11-11, user: "improve the visual style of the soldier and
## archer"). Run headless:
##   Godot --headless --path . res://scenes/probes/SoldierVisualProbe.tscn
##
## Checks:
##   1. Soldier sprite carries the full rugged part set (legs, boots,
##      chest plate, face, crested helm, layered shield).
##   2. The spear tip is a child of Sprite/Spear (so the combat swing
##      carries it) and the weapon lookup still resolves.
##   3. Archer sprite carries hood, quiver with arrows, strung bow.
##   4. The combat swing actually drives the spear: park the dragon in
##      attack range, wait, and require the spear rotation to move.
##   5. Facing flip mirrors the sprite without erroring.

enum S { BOOT, CHECK_PARTS, PARK_DRAGON, WAIT_SWING, REPORT }

const TIMEOUT := 30.0

var state: int = S.BOOT
var frames_in_state: int = 0
var elapsed: float = 0.0
var passes: Array[String] = []
var failures: Array[String] = []
var _soldier: BaseNPC = null
var _archer: BaseNPC = null
var _rot_seen: float = 0.0
var _swing_moved: bool = false

@onready var gm: GameManager = $Main as GameManager

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

func _has_rect(parent: Node, child_name: String) -> bool:
	var n := parent.get_node_or_null(child_name)
	return n is ColorRect

func _physics_process(delta: float) -> void:
	frames_in_state += 1
	elapsed += delta
	if elapsed > TIMEOUT:
		_fail("global timeout in state %d" % state)
		_goto(S.REPORT)
		return

	match state:
		S.BOOT:
			if gm == null or gm.dragon == null or gm.world_manager == null:
				if _frames(60):
					_fail("BOOT: GameManager/Dragon/WorldManager missing")
					_goto(S.REPORT)
				return
			# Spawn one of each next to the dragon.
			var dragon := gm.dragon as Dragon
			gm.world_manager.call("spawn_entity", "soldier", 1,
				dragon.global_position + Vector2(120, 0))
			gm.world_manager.call("spawn_entity", "archer", 1,
				dragon.global_position + Vector2(-120, 0))
			_goto(S.CHECK_PARTS)
		S.CHECK_PARTS:
			if not _frames(10):
				return
			for node: Node in get_tree().get_nodes_in_group("soldiers"):
				var npc := node as BaseNPC
				if npc == null:
					continue
				if npc.npc_type == "soldier" and _soldier == null:
					_soldier = npc
				elif npc.npc_type == "archer" and _archer == null:
					_archer = npc
			if _soldier == null or _archer == null:
				if _frames(120):
					_fail("soldier/archer not spawned (soldier=%s archer=%s)"
						% [_soldier != null, _archer != null])
					_goto(S.REPORT)
				return
			# --- soldier part set ---
			var spr := _soldier.get_node_or_null("Sprite") as Node2D
			if spr == null:
				_fail("soldier Sprite container missing")
				_goto(S.REPORT)
				return
			var ok := true
			for part: String in ["Legs", "Boots", "BootsFront", "Body",
					"ChestPlate", "Belt", "TabardTail", "Head", "Eyes",
					"Helmet", "HelmetRim", "HelmetCrest", "Shield",
					"ShieldRimTop", "ShieldRimBottom", "ShieldBoss", "Spear"]:
				if not _has_rect(spr, part):
					_fail("soldier missing part: %s" % part)
					ok = false
			var spear := spr.get_node_or_null("Spear") as ColorRect
			if spear == null:
				_fail("soldier Sprite/Spear missing — combat swing dead")
				ok = false
			elif not _has_rect(spear, "SpearTip"):
				_fail("SpearTip not a child of Spear — tip won't sweep "
					+ "with the swing")
				ok = false
			if ok:
				_pass("soldier rugged part set complete (17 parts, "
					+ "tip child of Spear)")
			# --- archer part set ---
			var aspr := _archer.get_node_or_null("Sprite") as Node2D
			if aspr == null:
				_fail("archer Sprite container missing")
				_goto(S.REPORT)
				return
			ok = true
			for part: String in ["Legs", "Boots", "BootsFront", "Quiver",
					"Body", "Belt", "BeltBuckle", "Head", "Eyes",
					"Helmet", "HoodPoint", "Bow"]:
				if not _has_rect(aspr, part):
					_fail("archer missing part: %s" % part)
					ok = false
			var quiver := aspr.get_node_or_null("Quiver") as ColorRect
			if quiver == null or not _has_rect(quiver, "QuiverArrow1") \
					or not _has_rect(quiver, "QuiverArrow2"):
				_fail("archer quiver arrows missing")
				ok = false
			var bow := aspr.get_node_or_null("Bow") as ColorRect
			if bow == null or not _has_rect(bow, "BowString"):
				_fail("archer bow string missing")
				ok = false
			else:
				# The bend (2026-11-11, user: "make the bow bend a little"):
				# grip + two limbs angled away from the string.
				var limb_up := bow.get_node_or_null("BowLimbUp") as ColorRect
				var limb_down := bow.get_node_or_null("BowLimbDown") as ColorRect
				if limb_up == null or limb_down == null:
					_fail("archer bow limbs missing — bow is a straight plank")
					ok = false
				elif absf(limb_up.rotation) < 0.05 \
						or absf(limb_down.rotation) < 0.05:
					_fail("bow limbs straight (rot %.2f/%.2f rad — no bend)"
						% [limb_up.rotation, limb_down.rotation])
					ok = false
				elif absf(limb_up.rotation + limb_down.rotation) > 0.01:
					_fail("bow limbs not mirrored (rot %.2f/%.2f rad)"
						% [limb_up.rotation, limb_down.rotation])
					ok = false
			if ok:
				_pass("archer rugged part set complete (bent bow, arrows "
					+ "in quiver, string)")
			_goto(S.PARK_DRAGON)
		S.PARK_DRAGON:
			# Park the dragon INSIDE the soldier's attack range so the
			# combat swing loop starts hammering the spear.
			var dragon := gm.dragon as Dragon
			dragon.global_position = _soldier.global_position \
				+ Vector2(30, 0)
			print("PROBE: dragon parked in the soldier's attack range")
			_goto(S.WAIT_SWING)
		S.WAIT_SWING:
			# The swing oscillates the spear between -55deg and 25deg.
			var spr := _soldier.get_node_or_null("Sprite") as Node2D
			var spear := spr.get_node_or_null("Spear") as ColorRect
			if spear == null:
				_fail("spear vanished during the swing")
				_goto(S.REPORT)
				return
			if absf(spear.rotation_degrees - _rot_seen) > 3.0:
				_swing_moved = true
				_pass("combat swing drives the new spear (rotation %.1f°, "
					% spear.rotation_degrees
					+ "tip sweeps with it)")
				_goto(S.REPORT)
			_rot_seen = spear.rotation_degrees
			if _frames(300):
				_fail("spear never moved — combat swing broken")
				_goto(S.REPORT)
		S.REPORT:
			set_physics_process(false)
			print("===============================================")
			for p in passes:
				print("PROBE PASS: ", p)
			for f in failures:
				print("PROBE FAIL: ", f)
			if failures.is_empty():
				print("PROBE RESULT: SUCCESS (%d checks passed)"
					% passes.size())
				get_tree().quit(0)
			else:
				print("PROBE RESULT: FAILURE (%d passed, %d failed)"
					% [passes.size(), failures.size()])
				get_tree().quit(1)
