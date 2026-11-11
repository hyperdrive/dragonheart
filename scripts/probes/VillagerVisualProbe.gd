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
			if fspr == null:
				_fail("farmer Sprite container missing")
				ok = false
			else:
				for part: String in ["Body", "StrapL", "StrapR", "Bib",
						"BibPocket", "Waist", "Legs", "LegsFront", "Boots",
						"BootsFront", "ArmSleeve", "Hand", "Head", "Eyes",
						"Hair", "HatCrown", "HatBand", "Hat"]:
					if not _has_rect(fspr, part):
						_fail("farmer missing part: %s" % part)
						ok = false
			if ok:
				_pass("farmer detailed part set complete (18 parts: "
					+ "overalls, straw hat, bare hand)")
			var mspr := _miner.get_node_or_null("Sprite") as Node2D
			if mspr == null:
				_fail("miner Sprite container missing")
				ok = false
			else:
				for part: String in ["Body", "Strap", "Belt", "Buckle",
						"Legs", "LegsFront", "Boots", "BootsFront", "Head",
						"Eyes", "Beard", "Helmet", "HelmetBrim", "Lamp",
						"Pick"]:
					if not _has_rect(mspr, part):
						_fail("miner missing part: %s" % part)
						ok = false
				var pick := mspr.get_node_or_null("Pick") as ColorRect
				if pick != null \
						and not _has_rect(pick, "PickHead"):
					_fail("miner pick head missing — swing loses its steel")
					ok = false
				elif pick != null:
					# The steel head crowns the TOP of the handle (the
					# sweeping end of the bottom-pivot swing) — it sat at
					# the bottom when the swing was inverted.
					var head := pick.get_node("PickHead") as ColorRect
					if head.position.y >= 0.0:
						_fail("pick head sits at the handle bottom "
							+ "(y=%.1f) — must crown the top" % head.position.y)
						ok = false
				# The swing pivots at the BOTTOM edge (grip fixed, head
				# sweeps) — was pivoted at the top, inverting the swing.
				var probe_swing: Vector2 = pick.pivot_offset
				if absf(probe_swing.y - (pick.size.y - 2.0)) > 0.5 \
						or absf(probe_swing.x - pick.size.x * 0.5) > 0.5:
					_fail("pick pivot %.1f,%.1f is not bottom-center"
						% [probe_swing.x, probe_swing.y])
					ok = false
			if ok:
				_pass("miner detailed part set complete (16 parts: gear "
					+ "strap, belt, beard, steel pick head)")
			_goto(S.CHECK_CART)
		S.CHECK_CART:
			var cart := _miner.get_node_or_null("Cart") as Node2D
			if cart == null:
				_fail("miner Cart container missing")
				_goto(S.REPORT)
				return
			var ok := true
			for part: String in ["Handle", "Bed", "BedSeam1", "BedSeam2",
					"RailTop", "RailPostL", "RailPostR", "GoldChunkL",
					"GoldChunkR", "GoldSparkle", "Wheel", "Wheel2"]:
				if not _has_rect(cart, part):
					_fail("cart missing part: %s" % part)
					ok = false
			var wheel := cart.get_node_or_null("Wheel") as ColorRect
			if wheel != null and (not _has_rect(wheel, "WheelRim")
					or not _has_rect(wheel, "WheelHub")):
				_fail("cart wheels lack rim/hub detail")
				ok = false
			if cart.get_node_or_null("GoldPile") == null:
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
