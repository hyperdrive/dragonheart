extends Node2D

## VillagerVisualProbe — regression probe for the detailed farmer/miner
## visuals and the cart rebuild (2026-11-11, user: "improve the look of the
## farmers and miners. They should look more detailed. The cart of gold
## should look like a cart"). Run headless:
##   Godot --headless --path . res://scenes/probes/VillagerVisualProbe.tscn
##
## Checks:
##   1. Farmer sprite carries the detailed part set (overalls with straps,
##      bib + pocket, two legs/boots, rolled sleeve + bare hand, hair, eyes,
##      straw hat with crown + band + brim) — 18 parts.
##   2. Miner sprite carries the detailed part set (gear strap, belt +
##      buckle, two legs/boots, beard, eyes, helmet brim, steel pick head)
##      — 16 parts — with the head crowning the TOP of the handle and the
##      swing pivoting at the BOTTOM edge (grip fixed, head sweeps).
##   3. The gold cart reads as a CART: planked bed with seams, side rail
##      with posts, a push handle, two wheels each with rim + hub, gold
##      mound with chunks + sparkle — 15 parts.
##   4. The cart mirrors with facing: flipping the miner mirrors the cart
##      contents (handle side always toward the miner).

enum S { BOOT, SPAWN, CHECK, CHECK_CART, CHECK_MIRROR, CHECK_MIRROR_FREEZE,
	CHECK_MIRROR_WAIT, REPORT }

const TIMEOUT := 30.0

var state: int = S.BOOT
var frames_in_state: int = 0
var elapsed: float = 0.0
var passes: Array[String] = []
var failures: Array[String] = []
var _farmer: BaseNPC = null
var _miner: BaseNPC = null

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

## 2026-11-14 rig pass: parts are Polygon2D/Line2D/Node2D on a jointed
## HumanoidRig — any CanvasItem counts (paths may cross joints).
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
			if gm == null or gm.world_manager == null:
				if _frames(60):
					_fail("BOOT: GameManager/WorldManager missing")
					_goto(S.REPORT)
				return
			_goto(S.SPAWN)
		S.SPAWN:
			# The world already fields farmers and miners at their sites —
			# just wait for one of each.
			for node: Node in get_tree().get_nodes_in_group("farmers"):
				if _farmer == null:
					_farmer = node as BaseNPC
			for node: Node in get_tree().get_nodes_in_group("miners"):
				if _miner == null:
					_miner = node as BaseNPC
			if _farmer != null and _miner != null:
				_goto(S.CHECK)
			elif _frames(180):
				_fail("no farmer/miner found in the world "
					+ "(farmer=%s miner=%s)"
					% [_farmer != null, _miner != null])
				_goto(S.REPORT)
		S.CHECK:
			var ok := true
			var fspr := _farmer.get_node_or_null("Sprite") as Node2D
			if not (fspr is HumanoidRig):
				_fail("farmer Sprite is not a HumanoidRig")
				ok = false
			else:
				for part: String in ["LegBack", "LegFront", "ArmBack", "ArmFront",
						"Torso/Body", "Torso/Bib", "Torso/BibPocket", "Torso/StrapL",
						"Torso/StrapR", "Torso/Waist", "Head/Face", "Head/Eyes",
						"Head/Hair", "Head/HatCrown", "Head/HatBand", "Head/Hat",
						"ArmFront/Hand", "ArmFront/Hoe/HoeBlade", "ArmBack/Basket"]:
					if not _has_rect(fspr, part):
						_fail("farmer missing part: %s" % part)
						ok = false
			if ok:
				_pass("farmer rig complete (jointed limbs, overalls, straw "
					+ "hat, hoe, produce basket)")
			var mspr := _miner.get_node_or_null("Sprite") as Node2D
			if not (mspr is HumanoidRig):
				_fail("miner Sprite is not a HumanoidRig")
				ok = false
			else:
				for part: String in ["LegBack", "LegFront", "ArmBack", "ArmFront",
						"Torso/Body", "Torso/Strap", "Torso/Belt", "Torso/Buckle",
						"Torso/Apron", "Head/Face", "Head/Eyes", "Head/Beard",
						"Head/Helmet", "Head/HelmetBrim", "Head/Lamp",
						"ArmFront/Pick", "ArmFront/Pick/Handle"]:
					if not _has_rect(mspr, part):
						_fail("miner missing part: %s" % part)
						ok = false
				var pick := mspr.get_node_or_null("ArmFront/Pick") as Node2D
				var head := mspr.get_node_or_null("ArmFront/Pick/PickHead") as Polygon2D
				if pick == null or head == null:
					_fail("miner pick head missing — swing loses its steel")
					ok = false
				else:
					# The steel head crowns the far end of the handle (pick
					# local -y) — the grip end sits at the Pick pivot.
					var max_y := -INF
					for v: Vector2 in head.polygon:
						max_y = maxf(max_y, v.y + head.position.y)
					if max_y >= -10.0:
						_fail("pick head is not at the far end of the "
							+ "handle (max y=%.1f)" % max_y)
						ok = false
					# The grip pivot rides the hand.
					var hand := mspr.get_node_or_null("ArmFront/Hand") as Polygon2D
					if hand != null and pick.position.distance_to(Vector2(0.2, 12.0)) > 1.0:
						_fail("pick pivot %s is not at the hand" % pick.position)
						ok = false
			if ok:
				_pass("miner rig complete (gear strap, apron, beard, lamp "
					+ "helmet, steel pick head at the far end)")
			_goto(S.CHECK_CART)
		S.CHECK_CART:
			var cart := _miner.get_node_or_null("Cart") as Node2D
			if cart == null:
				_fail("miner Cart container missing")
				_goto(S.REPORT)
				return
			var ok := true
			for part: String in ["Handle", "Bed", "BedSeam1", "BedSeam2",
					"RailTop", "RailPostL", "RailPostR",
					"Load/GoldPile/GoldChunkL", "Load/GoldPile/GoldChunkR",
					"Load/GoldPile/GoldSparkle", "Wheel", "Wheel2"]:
				if not _has_rect(cart, part):
					_fail("cart missing part: %s" % part)
					ok = false
			var wheel := cart.get_node_or_null("Wheel") as Node2D
			if wheel != null and (not _has_rect(wheel, "WheelRim")
					or not _has_rect(wheel, "WheelHub")):
				_fail("cart wheels lack rim/hub detail")
				ok = false
			if cart.get_node_or_null("Load/GoldPile") == null:
				_fail("cart gold pile missing")
				ok = false
			if ok:
				_pass("gold cart reads as a CART (15 parts: planked bed, "
					+ "railed sides, push handle, detailed wheels, gold "
					+ "mound)")
			_goto(S.CHECK_MIRROR)
		S.CHECK_MIRROR:
			# Mirror check: face the miner LEFT — the cart must move to the
			# other side AND flip its contents (handle toward the miner).
			# Freeze the miner's AI FIRST: his own movement re-derives
			# facing every frame and would overwrite the flip mid-check.
			_miner.set("speed", 0.0)
			_goto(S.CHECK_MIRROR_FREEZE)
		S.CHECK_MIRROR_FREEZE:
			if not _frames(2):
				return
			_miner.set("facing", -1)
			_goto(S.CHECK_MIRROR_WAIT)
		S.CHECK_MIRROR_WAIT:
			if not _frames(3):
				return
			var cart := _miner.get_node_or_null("Cart") as Node2D
			if cart == null:
				_fail("cart vanished during the mirror check")
				_goto(S.REPORT)
				return
			var flipped_pos: bool = cart.position.x < 0.0
			var flipped_contents: bool = cart.scale.x < 0.0
			if flipped_pos and flipped_contents:
				_pass("cart MIRRORS with facing: moved to the left flank "
					+ "and flipped its contents (handle stays toward the "
					+ "miner)")
			else:
				_fail("cart did not mirror (pos.x=%.1f scale.x=%.1f)"
					% [cart.position.x, cart.scale.x])
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
