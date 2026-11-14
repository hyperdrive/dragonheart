extends Node2D

## KingVisualProbe — regression probe for the warhammer-heroic King rebuild
## and the Lightning Sword-Cloud special (2026-11-11, user: "upgrade the
## visuals of the king ... warhammer-style heroic. His special attack should
## be a cloud of swords ... moves like lightning"). Run headless:
##   Godot --headless --path . res://scenes/probes/KingVisualProbe.tscn
##
## Checks:
##   1. King sprite carries the heroic part set (caped, gold-trimmed plate,
##      heraldic emblem, pauldrons, beard, spiked crown) — 24 parts.
##   2. The magic sword is a composite (invisible container + blade/rune/
##      guard/grip/pommel children) that the combat swing can still drive.
##   3. TWO storm charges are armed at spawn; the hand-triggered cast
##      spends exactly one.
##   4. The first storm rains ~12 swords and its strike damages the dragon.
##   5. AGGRESSION (user: "use them more aggressively"): with the dragon
##      merely parked in trigger range (out of melee AND out of the damage
##      radius), the SECOND storm auto-casts within seconds — no melee
##      swing needed — draining the last charge.
##   6. The probe tops the dragon's health back up every frame and tracks
##      the low-water mark, so two full storms can't kill it mid-test.

enum S { BOOT, SPAWN_KING, WAIT_KING, CHECK_PARTS, PARK_DRAGON, TRIGGER,
	WAIT_CLOUD, WAIT_AUTOCAST, REPORT }

const TIMEOUT := 40.0

var state: int = S.BOOT
var frames_in_state: int = 0
var elapsed: float = 0.0
var passes: Array[String] = []
var failures: Array[String] = []
var _king: King = null
var _dragon_health_before: int = -1
var _dragon_health_min: int = -1
var _peak_swords: int = 0
var frames_since_peak: int = 0
var _storm_rate_original: float = 2.5

@onready var gm: GameManager = $Main as GameManager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the probe outlives every pause

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

func _find_king() -> King:
	for node: Node in get_tree().get_nodes_in_group("king"):
		var king := node as King
		if king != null and king.is_alive:
			return king
	return null

## 2026-11-14 rig pass: any CanvasItem part counts (Polygon2D/Line2D/Node2D).
func _has_rect(parent: Node, child_name: String) -> bool:
	var n := parent.get_node_or_null(child_name)
	return n is CanvasItem

## Keep the test subject alive through two full storms: top the dragon's
## health back up every frame and remember the low-water mark, so the
## REPORT can still prove the strikes landed.
func _top_up_dragon() -> void:
	var dragon := gm.dragon as Dragon
	var hp := int(dragon.get("health"))
	if hp < _dragon_health_min or _dragon_health_min < 0:
		_dragon_health_min = hp
	if hp < _dragon_health_before:
		dragon.set("health", _dragon_health_before)

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
			_goto(S.SPAWN_KING)
		S.SPAWN_KING:
			gm.world_manager.call("spawn_king")
			_goto(S.WAIT_KING)
		S.WAIT_KING:
			_king = _find_king()
			if _king != null:
				_pass("King arrived on the field")
				_goto(S.CHECK_PARTS)
			elif _frames(180):
				_fail("King never spawned")
				_goto(S.REPORT)
		S.CHECK_PARTS:
			# TWO storm charges armed at spawn (user: "2 sword storms").
			var charges := int(_king.get("_storm_charges"))
			if charges != 2:
				_fail("expected 2 armed storm charges at spawn, got %d"
					% charges)
			else:
				_pass("TWO sword storms armed at spawn")
			var spr := _king.get_node_or_null("Sprite") as Node2D
			if spr == null:
				_fail("King Sprite container missing")
				_goto(S.REPORT)
				return
			var ok := true
			if not (spr is HumanoidRig):
				_fail("King Sprite is not a HumanoidRig")
				ok = false
			for part: String in ["Cape/CapeCloth", "Cape/CapeTrim", "Cape/CapeCollar",
					"LegBack/Greave", "LegFront/Sabaton", "Torso/Cuirass",
					"Torso/CuirassTrim", "Torso/Sunburst", "Torso/SunCore",
					"Torso/Tabard", "Torso/Belt", "Torso/BeltBuckle",
					"Torso/RuneSeam1", "ArmBack/Pauldron", "ArmFront/Pauldron",
					"ArmFront/Gauntlet", "Head/Helm", "Head/Visor", "Head/VisorGlow",
					"Head/Beard", "Head/Crown", "Head/CrownPoint1", "Head/CrownPoint2",
					"Head/CrownPoint3", "Head/CrownJewel", "Head/Plume"]:
				if not _has_rect(spr, part):
					_fail("King missing heroic part: %s" % part)
					ok = false
			# The magic sword must be a swingable composite riding the sword
			# hand (combat-swing lookup Sprite/ArmFront/Sword), blade parts
			# and spectral flame as children.
			var sword := spr.get_node_or_null("ArmFront/Sword") as Node2D
			if sword == null:
				_fail("King Sprite/ArmFront/Sword missing — combat swing dead")
				ok = false
			else:
				for part: String in ["Blade", "Rune1", "Rune4", "Guard",
						"Grip", "Pommel", "BladeFlame", "BladeFlameCore"]:
					if not _has_rect(sword, part):
						_fail("King sword missing blade part: %s" % part)
						ok = false
			if ok:
				_pass("King heroic part set complete (blazing plate, crowned "
					+ "great helm, ermine cape, flaming runeblade)")
			_goto(S.PARK_DRAGON)
		S.PARK_DRAGON:
			# Freeze the King so he can't close into contact range, and park
			# the dragon at 75px: INSIDE the 80px special radius, OUTSIDE
			# the 70px attack range (no contact DPS during the storm).
			_king.set("speed", 0.0)
			# Suppress the aggressive auto-caster for the SCRIPTED storm #1:
			# at 2.5 rolls/s it would fire during the pre-trigger wait and
			# race the manual cast for the charges. Re-enabled at the slide.
			_storm_rate_original = float(_king.get("storm_trigger_rate"))
			_king.set("storm_trigger_rate", 0.0)
			var dragon := gm.dragon as Dragon
			dragon.global_position = _king.global_position + Vector2(75, 0)
			print("PROBE: dragon parked at 75px (in special radius, "
				+ "out of attack range), King frozen, auto-cast suppressed")
			_goto(S.TRIGGER)
		S.TRIGGER:
			if not _frames(10):
				return
			_dragon_health_before = int(gm.dragon.get("health"))
			# Follow the real caller contract: spend the charge, then cast.
			_king.set("_storm_charges",
				int(_king.get("_storm_charges")) - 1)
			_king.call("_perform_special_attack")
			# Deterministic: the auto-caster is locked out while the storm
			# runs (_casting_storm), so the count is stable right now.
			if int(_king.get("_storm_charges")) == 1:
				_pass("one storm charge spent by the cast (1 left)")
			else:
				_fail("charge bookkeeping off after the cast: %d "
					% int(_king.get("_storm_charges")) + "(expected 1)")
			print("PROBE: storm #1 triggered by hand")
			_goto(S.WAIT_CLOUD)
		S.WAIT_CLOUD:
			_top_up_dragon()
			# Track the storm's peak while the swords rain and linger. Wait
			# for the storm to SETTLE (no new peak for ~0.75s) before
			# judging, so the count reflects the whole cloud, not a slice.
			var count := get_tree().get_nodes_in_group("king_swords").size()
			if count > _peak_swords:
				_peak_swords = count
				frames_since_peak = 0
			else:
				frames_since_peak += 1
			if frames_since_peak > 45 or _frames(300):
				if _peak_swords >= 8:
					_pass("LIGHTNING SWORD-CLOUD: %d spectral greatswords "
						% _peak_swords + "rained down around the King")
				else:
					_fail("sword cloud never formed (peak: %d)"
						% _peak_swords)
				# Slide the dragon OUT of the 80px damage radius but keep
				# it INSIDE the 112px trigger range: storm #2 must still
				# fire (aggression), and the top-up keeps it alive either
				# way. Auto-casting re-armed for the aggression check.
				_king.set("storm_trigger_rate", _storm_rate_original)
				var dragon := gm.dragon as Dragon
				dragon.global_position = _king.global_position + Vector2(105, 0)
				_peak_swords = 0
				frames_since_peak = 0
				print("PROBE: dragon slid to 105px — in trigger range, "
					+ "out of damage radius")
				_goto(S.WAIT_AUTOCAST)
		S.WAIT_AUTOCAST:
			_top_up_dragon()
			# AGGRESSION CHECK: the dragon is parked in trigger range but
			# the King never gets a melee swing (frozen, out of attack
			# range) — the second storm must fire by itself.
			var count := get_tree().get_nodes_in_group("king_swords").size()
			if count > _peak_swords:
				_peak_swords = count
			var charges := int(_king.get("_storm_charges"))
			if charges <= 0:
				_pass("AGGRESSIVE: the second storm auto-cast with the "
					+ "dragon merely in range (2 storms dumped, "
					+ "storm-2 peak swords %d)" % _peak_swords)
				_goto(S.REPORT)
			elif _frames(480):
				_fail("second storm never auto-cast within 8s "
					+ "(charges left: %d)" % charges)
				_goto(S.REPORT)
		S.REPORT:
			set_physics_process(false)
			# The strike check rides along in REPORT (before anything else
			# can heal/hurt the dragon): the low-water mark proves the
			# 1.5 x 50 sword-cloud hit connected.
			if _dragon_health_min >= 0 \
					and _dragon_health_min < _dragon_health_before:
				_pass("STRIKE LANDED: dragon took the sword-cloud hit "
					+ "(health low-water %d, top-up baseline %d)"
					% [_dragon_health_min, _dragon_health_before])
			else:
				_fail("dragon took NO damage from the storms "
					+ "(low-water: %d, baseline: %d)"
					% [_dragon_health_min, _dragon_health_before])
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
