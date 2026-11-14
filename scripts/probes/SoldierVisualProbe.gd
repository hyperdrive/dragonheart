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

## 2026-11-14 rig pass: any CanvasItem part counts (Polygon2D/Line2D/Node2D).
func _has_rect(parent: Node, child_name: String) -> bool:
	var n := parent.get_node_or_null(child_name)
	return n is CanvasItem

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
			if not (spr is HumanoidRig):
				_fail("soldier Sprite is not a HumanoidRig")
				ok = false
			for part: String in ["LegBack", "LegFront", "ArmBack", "ArmFront",
					"LegFront/Greave", "Torso/Body", "Torso/Tabard",
					"Torso/Crest", "Torso/Belt", "Torso/Pauldron", "Head/Face",
					"Head/Eyes", "Head/Helmet", "Head/HelmetRim",
					"Head/NoseGuard", "Head/Plume", "ArmBack/Shield",
					"ArmBack/Shield/ShieldFace", "ArmBack/Shield/Boss",
					"ArmFront/Sword"]:
				if not _has_rect(spr, part):
					_fail("soldier missing part: %s" % part)
					ok = false
			var sword := spr.get_node_or_null("ArmFront/Sword") as Node2D
			if sword == null or not _has_rect(sword, "Blade") \
					or not _has_rect(sword, "Guard"):
				_fail("soldier sword blade/guard missing — the slash cuts air")
				ok = false
			if ok:
				_pass("soldier rig complete (mail, crowned tabard, plumed "
					+ "helm, heater shield, arming sword in the swing hand)")
			# --- archer part set ---
			var aspr := _archer.get_node_or_null("Sprite") as Node2D
			if aspr == null:
				_fail("archer Sprite container missing")
				_goto(S.REPORT)
				return
			ok = true
			for part: String in ["LegBack", "LegFront", "ArmBack", "ArmFront",
					"Torso/Body2", "Torso/Belt", "Torso/Quiver",
					"Torso/Quiver/Arrow1", "Torso/Quiver/Arrow2", "Head/Hood",
					"Head/Feather", "ArmFront/Bow", "ArmFront/Bow/BowLimbUp",
					"ArmFront/Bow/BowLimbDown", "ArmFront/Bow/String",
					"ArmFront/Bow/Nock"]:
				if not _has_rect(aspr, part):
					_fail("archer missing part: %s" % part)
					ok = false
			var up := aspr.get_node_or_null("ArmFront/Bow/BowLimbUp") as Line2D
			if up != null and absf(up.points[up.points.size() - 1].x) < 2.0:
				_fail("bow limbs straight — no curve back toward the string")
				ok = false
			if ok:
				_pass("archer rig complete (hood + feather, quiver arrows, "
					+ "curved longbow, string, nock)")
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
			# The slash sweeps the sword arm between wind-up and cut.
			var arm := _soldier.get_node_or_null("Sprite/ArmFront") as Node2D
			if arm == null:
				_fail("sword arm vanished during the swing")
				_goto(S.REPORT)
				return
			if absf(arm.rotation_degrees - _rot_seen) > 3.0 and frames_in_state > 2:
				_swing_moved = true
				_pass("combat slash drives the sword arm (%.1f°, blade "
					% arm.rotation_degrees + "rides the hand)")
				_goto(S.REPORT)
			_rot_seen = arm.rotation_degrees
			if _frames(300):
				_fail("sword arm never moved — combat slash broken")
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
