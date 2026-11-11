extends Node2D

## RiderTrainingProbe — end-to-end probe for the sacrifice → dragon-rider
## pipeline (bug fix 2026-11-11). Run headless:
##   Godot --headless --path . res://scenes/probes/RiderTrainingProbe.tscn
##
## Scenario (the REAL failing sequence, not a shortcut):
##   1. Burn a field  → the field_burn story popup opens (this is what
##      creates story_popup FIRST and — before the fix — starved the later
##      sacrifice_choice_made connection of its chance to connect).
##   2. Close it, burn 2 more fields → the 3rd burn spawns the Sacrifice.
##   3. Fly the dragon to the sacrifice → the sacrifice story popup opens.
##   4. Pick choice 1 ("Take to lair. Train as rider.")
##      → REGRESSION CHECK: GameManager.has_trainable_sacrifice() must be true.
##   5. Open the wizard menu → the "Train Dragon Rider (10g)" button must be
##      VISIBLE and ENABLED (this is the user-reported failure).
##   6. Purchase → dragon.has_rider, RiderSprite visible, vector Sprite
##      hidden, epic story "rider_upgraded" queued.
##   7. Close the menu → the epic story popup must open.
##   8. Spawn a soldier near the dragon → the rider must loose an arrow.
##
## Every step prints "PROBE PASS:" / "PROBE FAIL:" and the run ends with
## "PROBE RESULT: SUCCESS|FAILURE" + exit code 0/1.

enum S {
	BOOT, BURN_1, WAIT_STORY, BURN_REST, WAIT_SACRIFICE, APPROACH,
	WAIT_POPUP, CHOOSE, SHOP_OPEN, SHOP_BUY, WAIT_EPIC, COMBAT_WAIT, REPORT,
}

const TIMEOUT := 60.0

var state: int = S.BOOT
var frames_in_state: int = 0
var elapsed: float = 0.0
var fields_burned: int = 0
var passes: Array[String] = []
var failures: Array[String] = []
var _sacrifice: Sacrifice = null
var _soldier: BaseNPC = null
var _rider_arrow_seen: bool = false
var _rider_arrow_frame: int = 0

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

func _popup() -> StoryPopup:
	return gm.story_popup as StoryPopup if gm.story_popup != null else null

func _physics_process(delta: float) -> void:
	frames_in_state += 1
	elapsed += delta
	# Watch for a rider arrow in flight (any state — it may loom mid-test).
	if not _rider_arrow_seen:
		_find_rider_arrow(get_tree().root)
	if elapsed > TIMEOUT:
		_fail("global timeout in state %d" % state)
		_goto(S.REPORT)
		return

	match state:
		S.BOOT:
			if gm == null or gm.dragon == null:
				if _frames(60):
					_fail("BOOT: GameManager or Dragon missing")
					_goto(S.REPORT)
				return
			# 15g funds the 10g purchase WITHOUT tripping the wizard's
			# "stash > 20g" backstab trigger — keeps the probe deterministic.
			gm.add_stolen("gold", 15)
			_pass("BOOT: game running, stash funded with 15g")
			_goto(S.BURN_1)
		S.BURN_1:
			_burn_next_field()
			_goto(S.WAIT_STORY)
		S.WAIT_STORY:
			# The field_burn popup should be open NOW (paused world beneath).
			var popup := _popup()
			if popup != null and gm.story_open \
					and popup.current_kind == "field_burn":
				_pass("field_burn story opened — story_popup now pre-exists")
				popup._on_choice_pressed(0)  # close, unpause
				_goto(S.BURN_REST)
			elif _frames(120):
				_fail("field_burn story did not open after burning a field")
				_goto(S.BURN_REST)
		S.BURN_REST:
			if _frames(10):
				fields_burned += 1
				_burn_next_field()
				print("PROBE: burnt field #%d" % fields_burned)
				if fields_burned >= 3:
					_goto(S.WAIT_SACRIFICE)
		S.WAIT_SACRIFICE:
			var sacs := get_tree().get_nodes_in_group("sacrifice")
			if sacs.size() > 0:
				_sacrifice = sacs[0] as Sacrifice
				if _sacrifice != null:
					_pass("sacrifice spawned after 3 fields burnt at %s"
						% _sacrifice.global_position)
					_goto(S.APPROACH)
				else:
					_fail("sacrifice node in group but not a Sacrifice")
					_goto(S.REPORT)
			elif _frames(300):
				_fail("no sacrifice spawned after 3 fields burnt")
				_goto(S.REPORT)
		S.APPROACH:
			var dragon := gm.dragon as Dragon
			dragon.global_position = _sacrifice.global_position + Vector2(60, 0)
			print("PROBE: dragon approaching sacrifice")
			_goto(S.WAIT_POPUP)
		S.WAIT_POPUP:
			var popup := _popup()
			if popup != null and gm.story_open \
					and popup.current_kind.begins_with("sacrifice_"):
				_pass("sacrifice story popup opened ('%s')" % popup.current_kind)
				_goto(S.CHOOSE)
			elif _frames(180):
				_fail("sacrifice story popup never opened on approach")
				_goto(S.REPORT)
		S.CHOOSE:
			# THE regression: pick "Take to lair. Train as rider." (index 1).
			var popup := _popup()
			popup._on_choice_pressed(1)
			_goto(S.SHOP_OPEN)
		S.SHOP_OPEN:
			if not _frames(3):
				return
			if not gm.has_trainable_sacrifice():
				_fail("has_trainable_sacrifice() is FALSE after picking "
					+ "'Train as rider' — the choice never reached GameManager "
					+ "(the original bug)")
				_goto(S.REPORT)
				return
			_pass("trainable flag set — choice reached GameManager")
			gm.open_wizard_menu()
			_goto(S.SHOP_BUY)
		S.SHOP_BUY:
			if not _frames(3):
				return
			var menu := gm.wizard_menu as WizardMenu
			if menu == null:
				_fail("wizard menu did not open")
				_goto(S.REPORT)
				return
			menu._refresh()
			var btn := menu.rider_train_button
			if btn == null:
				_fail("rider_train_button not built by WizardMenu")
				_goto(S.REPORT)
				return
			if not btn.visible:
				_fail("USER BUG: 'Train Dragon Rider' button is INVISIBLE "
					+ "in the wizard menu")
				_goto(S.REPORT)
				return
			if btn.disabled:
				_fail("USER BUG: 'Train Dragon Rider' button is DISABLED "
					+ "(stash: %dg)" % int(gm.stash["gold"]))
				_goto(S.REPORT)
				return
			_pass("wizard menu shows ENABLED 'Train Dragon Rider' option "
				+ "(' %s')" % btn.text)
			if not gm.purchase_upgrade("rider_train"):
				_fail("purchase_upgrade('rider_train') returned false")
				_goto(S.REPORT)
				return
			var dragon := gm.dragon as Dragon
			if not dragon.has_rider:
				_fail("dragon.has_rider is false after purchase")
			else:
				_pass("dragon.has_rider set by purchase")
			var rider_pivot := (dragon.sprite as Node2D) \
				.get_node_or_null("RiderPivot") as Node2D
			if rider_pivot == null or not rider_pivot.visible:
				_fail("RiderPivot missing/hidden — rider never mounted")
			elif not dragon.sprite.visible:
				_fail("vector dragon hidden — rider must ride the ORIGINAL "
					+ "sprite (derivative, not replacement)")
			elif rider_pivot.get_child_count() < 8:
				_fail("rider composite incomplete (%d parts)"
					% rider_pivot.get_child_count())
			else:
				_pass("rider mounted ON the original vector dragon "
					+ "(%d parts, derivative style)"
					% rider_pivot.get_child_count())
			if "rider_upgraded" in gm.story_queue:
				_pass("epic story 'rider_upgraded' queued (plays on menu close)")
			else:
				_fail("epic story 'rider_upgraded' NOT queued after purchase")
			menu.close()
			_goto(S.WAIT_EPIC)
		S.WAIT_EPIC:
			var popup := _popup()
			if popup != null and popup.current_kind == "rider_upgraded":
				_pass("epic rider story popup opened after leaving the tower")
				popup._on_choice_pressed(0)  # close, unpause
				_goto(S.COMBAT_WAIT)
			elif _frames(300):
				_fail("epic 'rider_upgraded' story never opened")
				_goto(S.COMBAT_WAIT)
		S.COMBAT_WAIT:
			if _soldier == null:
				# Spawn a target 150px from the dragon (inside rider_range 260).
				var dragon := gm.dragon as Dragon
				gm.world_manager.call("spawn_entity", "soldier", 1,
					dragon.global_position + Vector2(150, 0))
				# Track the soldier NEAREST the dragon — the world already
				# fields soldiers at the rally point, and the FIRST in group
				# order is one of those, not the spawned target (the probe
				# once watched the wrong soldier and false-failed the kill).
				var best_dist := INF
				for node: Node in get_tree().get_nodes_in_group("soldiers"):
					var s := node as BaseNPC
					if s == null or not s.is_alive:
						continue
					var dist := dragon.global_position.distance_to(s.global_position)
					if dist < best_dist:
						best_dist = dist
						_soldier = s
				if _soldier != null:
					print("PROBE: soldier target at %s (health: %s, %dpx from dragon)"
						% [_soldier.global_position, str(_soldier.get("health")),
							int(best_dist)])
				return
			# Wait for the rider's 1.5s cooldown + arrow flight (~0.3s),
			# then check the effects.
			if _rider_arrow_seen:
				if _soldier != null and not _soldier.is_alive:
					_pass("rider loosed an arrow (rider_arrow mode confirmed)")
					_pass("LETHAL SHOT: rider arrow KILLED the soldier on hit")
					_goto(S.REPORT)
				elif frames_in_state > _rider_arrow_frame + 60:
					_pass("rider loosed an arrow (rider_arrow mode confirmed)")
					_fail("LETHALITY BUG: arrow flew but the soldier SURVIVED "
						+ "(health: %s — rider arrows must kill on hit)"
						% str(_soldier.get("health")))
					_goto(S.REPORT)
				# else: arrow still in flight — keep waiting
			elif _soldier != null and not _soldier.is_alive:
				_fail("soldier died but no rider arrow was seen in flight")
				_goto(S.REPORT)
			elif _frames(360):
				_fail("rider never fired at the soldier within 6s")
				_goto(S.REPORT)
		S.REPORT:
			set_physics_process(false)
			print("===============================================")
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

## Burn fields in group order; Field.burn emits field_burnt → WorldManager
## counts → every 3rd spawns the sacrifice.
func _burn_next_field() -> void:
	var fields := get_tree().get_nodes_in_group("fields")
	var burnt := 0
	for node: Node in fields:
		var field := node as Field
		if field != null:
			field.burn()
			burnt += 1
			if burnt > fields_burned:
				break

## Depth-first scan for a live Arrow in rider mode; stamps the frame it
## first appeared so the probe can budget its ~0.3s flight time.
func _find_rider_arrow(node: Node) -> void:
	if node is Arrow and (node as Arrow).rider_arrow:
		_rider_arrow_seen = true
		_rider_arrow_frame = frames_in_state
		return
	for child in node.get_children():
		_find_rider_arrow(child)
