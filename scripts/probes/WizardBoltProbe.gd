extends Node2D

## WizardBoltProbe — regression probe for the jagged lightning bolt visual
## (2026-11-11, user: "his attack is just a straight line. Lets divide it
## multiple segments and offset them to the normal of the line at random so
## it looks more like a lightning. Also add a small curve to it (sine)").
## Run headless:
##   Godot --headless --path . res://scenes/probes/WizardBoltProbe.tscn
##
## Checks:
##   1. The wizard's bolts are SEGMENTED: each "wizard_bolts" Line2D core
##      carries BOLT_SEGMENTS + 1 vertices (not 2 like the old straight
##      flash).
##   2. The endpoints are PINNED: vertex 0 sits on the wizard, the last
##      vertex near the dragon (the strike must visibly connect).
##   3. The interior vertices are OFF the straight line (normal offsets:
##      sine bow + jitter) — the max deviation must exceed the jitter
##      floor. A bolt drawn straight through all interior points FAILS.
##   4. The strike still damages the dragon (30, shield-piercing).

enum S { BOOT, SPAWN_WIZARD, WAIT_BOLT, REPORT }

const TIMEOUT := 30.0
const JITTER_FLOOR := 14.0  # curve amp (26) alone must beat any near-miss

var state: int = S.BOOT
var frames_in_state: int = 0
var elapsed: float = 0.0
var passes: Array[String] = []
var failures: Array[String] = []
var _wizard: Wizard = null
var _health_before: int = -1

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
			_health_before = int(gm.dragon.get("health"))
			# Park the dragon 200px out — well inside the 500px lightning
			# range, outside melee anything.
			var dragon := gm.dragon as Dragon
			gm.world_manager.call("spawn_entity", "wizard", 1,
				dragon.global_position + Vector2(-200, 0))
			_goto(S.SPAWN_WIZARD)
		S.SPAWN_WIZARD:
			_wizard = get_tree().get_first_node_in_group("wizard") as Wizard
			if _wizard != null:
				# Park the wizard so he can't walk (his hunt logic would
				# close the gap and re-angle the bolts mid-check).
				_wizard.set("speed", 0.0)
				print("PROBE: wizard spawned 200px from the dragon, "
					+ "frozen in place")
				_goto(S.WAIT_BOLT)
			elif _frames(120):
				_fail("wizard never spawned")
				_goto(S.REPORT)
		S.WAIT_BOLT:
			var bolts := get_tree().get_nodes_in_group("wizard_bolts")
			if bolts.is_empty():
				if _frames(300):
					_fail("no lightning bolt ever flashed within 5s")
					_goto(S.REPORT)
				return
			# Grab the freshest bolt's core line (the bright child).
			var bolt := bolts[0] as Node2D
			var core: Line2D = null
			for child in bolt.get_children():
				if child is Line2D and (child as Line2D).width <= 4.0:
					core = child
			if core == null:
				_fail("bolt assembly has no core Line2D")
				_goto(S.REPORT)
				return
			var pts := core.points
			if pts.size() < 8:
				_fail("bolt is NOT segmented: %d vertices (expected %d)"
					% [pts.size(), 11])
				_goto(S.REPORT)
				return
			_pass("bolt is SEGMENTED: %d vertices across %d segments"
				% [pts.size(), pts.size() - 1])
			# Endpoint pinning: first vertex at the wizard, last near the
			# dragon (the dragon may have drifted a few px since the cast).
			var wizard := _wizard.global_position
			var dragon := (gm.dragon as Dragon).global_position
			if pts[0].distance_to(wizard) > 4.0:
				_fail("bolt start is not pinned to the wizard (off by "
					+ "%.1f)" % pts[0].distance_to(wizard))
			else:
				_pass("bolt start pinned to the wizard")
			var end_drift := pts[pts.size() - 1].distance_to(dragon)
			if end_drift > 30.0:
				_fail("bolt end is nowhere near the dragon (off by "
					+ "%.1f)" % end_drift)
			else:
				_pass("bolt end lands on the dragon (drift %.1f)"
					% end_drift)
			# Interior deviation from the straight chord: every interior
			# vertex must sit OFF the line (sine bow + jitter). Measure
			# max distance-from-chord.
			var chord := dragon - wizard
			var chord_len := chord.length()
			var normal := chord.normalized().orthogonal()
			var max_dev := 0.0
			for i in range(1, pts.size() - 1):
				var t := float(i) / float(pts.size() - 1)
				var on_line := wizard + chord * t
				var dev := absf((pts[i] - on_line).dot(normal))
				max_dev = maxf(max_dev, dev)
			if max_dev < JITTER_FLOOR:
				_fail("bolt is essentially STRAIGHT: max normal deviation "
					+ "%.1f < %.1f (no jagged offsets)"
					% [max_dev, JITTER_FLOOR])
			else:
				_pass("bolt is JAGGED: interior vertices deviate up to "
					+ "%.1fpx off the line" % max_dev)
			_goto(S.REPORT)
		S.REPORT:
			set_physics_process(false)
			if _health_before >= 0 \
					and int(gm.dragon.get("health")) < _health_before:
				_pass("STRIKE LANDED: dragon took lightning damage "
					+ "(health %d → %d)"
					% [_health_before, int(gm.dragon.get("health"))])
			else:
				_fail("dragon took NO lightning damage "
					+ "(health before: %d)" % _health_before)
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
