extends Node2D

## KingDefeatProbe — regression probe for the post-victory wizard economy
## (bug fix 2026-11-11, user: "if the king is defeated, the wizard tower
## stops to work and the wizard never appears"). Run headless:
##   Godot --headless --path . res://scenes/probes/KingDefeatProbe.tscn
##
## Scenario:
##   1. Spawn the King → close the king_emerge story.
##   2. Kill him NON-finally (a respawn life remains) → he must rise again.
##   3. Visit the wizard tower mid-run → menu must open (baseline sanity).
##   4. Kill him FINALLY → run_finished becomes true + the king_defeat
##      chapter plays.
##   5. REGRESSION CHECK: visit the tower again → menu must STILL open
##      (this failed before the fix).
##   6. REGRESSION CHECK: a purchase must go through post-victory
##      (payment gate used to refuse).
##   7. REGRESSION CHECK: the backstabbing wizard must still be ABLE to
##      emerge post-victory when his provocation lines are crossed.
##
## Every step prints "PROBE PASS/FAIL:" and the run ends with
## "PROBE RESULT: SUCCESS|FAILURE" + exit code 0/1.

enum S {
	BOOT, SPAWN_KING, WAIT_EMERGE, KILL_NONFINAL, WAIT_RESPAWN,
	APPROACH_TOWER_1, MENU_CHECK_1, CLOSE_MENU_1, KILL_FINAL,
	WAIT_VICTORY_STORY, APPROACH_TOWER_2, MENU_CHECK_2, BUY, BUY_SHIELD,
	BUY_FLIGHT, WIZARD_WAIT, REPORT,
}

const TIMEOUT := 60.0

var state: int = S.BOOT
var frames_in_state: int = 0
var elapsed: float = 0.0
var passes: Array[String] = []
var failures: Array[String] = []
var _king: King = null

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

func _world() -> WorldManager:
	return gm.world_manager as WorldManager

func _find_king() -> King:
	for node: Node in get_tree().get_nodes_in_group("king"):
		var king := node as King
		if king != null and king.is_alive:
			return king
	return null

func _close_story_if_open() -> bool:
	if gm.story_open and gm.story_popup != null:
		(gm.story_popup as StoryPopup)._on_choice_pressed(0)
		return true
	return false

func _physics_process(delta: float) -> void:
	frames_in_state += 1
	elapsed += delta
	if elapsed > TIMEOUT:
		_fail("global timeout in state %d" % state)
		_goto(S.REPORT)
		return

	match state:
		S.BOOT:
			if gm == null or gm.dragon == null or _world() == null:
				if _frames(60):
					_fail("BOOT: GameManager/Dragon/WorldManager missing")
					_goto(S.REPORT)
				return
			gm.add_stolen("gold", 15)  # stays under the wizard's 20g
			# greedy trigger during the King phase — funding more HERE
			# spawns the wizard early and its lightning (with a
			# storm-chewed dragon) kills the test subject mid-flow.
			_pass("BOOT: game running, stash funded with 15g")
			_goto(S.SPAWN_KING)
		S.SPAWN_KING:
			_world().spawn_king()
			_goto(S.WAIT_EMERGE)
		S.WAIT_EMERGE:
			# spawn_king → _materialize_king → notify_story("king_emerge").
			var popup := gm.story_popup as StoryPopup
			if popup != null and gm.story_open \
					and popup.current_kind == "king_emerge":
				_pass("King arrived, 'king_emerge' chapter plays")
				_close_story_if_open()
				_goto(S.KILL_NONFINAL)
			elif _frames(180):
				_fail("king_emerge story never opened after spawn_king")
				_goto(S.REPORT)
		S.KILL_NONFINAL:
			_king = _find_king()
			if _king == null:
				if _frames(60):
					_fail("no living King found after spawn")
					_goto(S.REPORT)
				return
			# One respawn life left: this defeat is NOT the final one.
			_world().set("king_respawns_left", 1)
			_king.die()
			_pass("King struck down non-finally (respawn scheduled)")
			_goto(S.WAIT_RESPAWN)
		S.WAIT_RESPAWN:
			# Respawn timer is 3s; the corpse lingers ~2s before freeing.
			if _frames(240):
				var risen := _find_king()
				if risen != null:
					_pass("the King rises again after his first fall")
					_goto(S.APPROACH_TOWER_1)
				else:
					_fail("King did not respawn from a non-final defeat")
					_goto(S.REPORT)
		S.APPROACH_TOWER_1:
			var dragon := gm.dragon as Dragon
			dragon.global_position = _world().tower_position + Vector2(0, 30)
			print("PROBE: dragon entering the tower (mid-run visit)")
			_goto(S.MENU_CHECK_1)
		S.MENU_CHECK_1:
			if gm.wizard_menu != null and gm.wizard_menu.visible:
				_pass("baseline: wizard menu opens mid-run")
				_goto(S.CLOSE_MENU_1)
			elif _frames(60):
				_fail("wizard menu did not open on a mid-run tower visit")
				_goto(S.REPORT)
		S.CLOSE_MENU_1:
			(gm.wizard_menu as WizardMenu).close()
			# Fly AWAY from the tower before the final strike — the fight
			# happens at the city in real play, and the tower's
			# _dragon_inside guard only resets on exit (a parked dragon
			# would never re-trigger body_entered, probe artifact).
			var dragon := gm.dragon as Dragon
			dragon.global_position = _world().city_position + Vector2(0, 60)
			_goto(S.KILL_FINAL)
		S.KILL_FINAL:
			if not _frames(5):
				return
			_king = _find_king()
			if _king == null:
				_fail("no living King for the final strike")
				_goto(S.REPORT)
				return
			# No respawn life left: this defeat is THE final one.
			_world().set("king_respawns_left", 0)
			_king.die()
			_goto(S.WAIT_VICTORY_STORY)
		S.WAIT_VICTORY_STORY:
			var popup := gm.story_popup as StoryPopup
			if popup != null and gm.story_open \
					and popup.current_kind == "king_defeat":
				_pass("'king_defeat' chapter plays")
				_close_story_if_open()
				_goto(S.APPROACH_TOWER_2)
			elif _frames(180):
				_fail("king_defeat story never opened on the final fall")
				_goto(S.REPORT)
		S.APPROACH_TOWER_2:
			if not (gm.run_finished and not gm.story_open):
				if _frames(120):
					_fail("victory state not settled (run_finished=%s)"
						% gm.run_finished)
					_goto(S.REPORT)
				return
			var dragon := gm.dragon as Dragon
			# Top the test subject up (the King's respawn storm chewed it
			# down to ~25) AND fund the shopping trip now — crossing the
			# wizard's 20g greedy trigger here is intended: the wizard
			# emerges for the WIZARD_WAIT check, and the menu PAUSES the
			# world so his bolts can't interrupt the purchases.
			dragon.set("health", int(dragon.get("max_health")))
			gm.add_stolen("gold", 20)
			dragon.global_position = _world().tower_position + Vector2(0, 30)
			print("PROBE: dragon entering the tower AFTER the King's final fall")
			_goto(S.MENU_CHECK_2)
		S.MENU_CHECK_2:
			# The greedy gold fund may pop the wizard_emerge story BEFORE
			# the dragon's teleport registers: the paused story freezes
			# physics, so the tower Area can't fire body_entered until the
			# story closes. Close any open story first, then judge.
			if gm.story_open:
				_close_story_if_open()
				return
			# THE user bug: the tower used to go silent post-victory.
			if gm.wizard_menu != null and gm.wizard_menu.visible:
				_pass("USER BUG FIXED: wizard tower still works after "
					+ "the King's defeat")
				_goto(S.BUY)
			elif _frames(60):
				_fail("USER BUG: wizard tower dead after the King's defeat")
				_goto(S.REPORT)
		S.BUY:
			if not gm.purchase_upgrade("flame_1"):
				_fail("USER BUG: purchase refused post-victory "
					+ "(stash: %dg)" % int(gm.stash["gold"]))
				_goto(S.REPORT)
				return
			_pass("USER BUG FIXED: purchases work post-victory "
				+ "(stash now %dg)" % int(gm.stash["gold"]))
			_goto(S.BUY_SHIELD)
		S.BUY_SHIELD:
			# Shield offer improved (2026-11-11, user: "40 points of
			# consumable absorption") — was 10.
			if not gm.purchase_upgrade("shield"):
				_fail("shield purchase refused (stash: %dg)"
					% int(gm.stash["gold"]))
				_goto(S.REPORT)
				return
			var points := int(gm.dragon.get("shield_points"))
			if points != 40:
				_fail("shield grant is %d points — expected 40" % points)
			else:
				_pass("IMPROVED SHIELD: wizard grants a 40-point "
					+ "consumable absorption")
			_goto(S.BUY_FLIGHT)
		S.BUY_FLIGHT:
			# New item (2026-11-11, user: "add a new item for longer
			# flight time +3 seconds") — permanent fly_duration extension.
			var before := float(gm.dragon.get("fly_duration"))
			if not gm.purchase_upgrade("flight"):
				_fail("flight purchase refused (stash: %dg)"
					% int(gm.stash["gold"]))
				_goto(S.REPORT)
				return
			var after := float(gm.dragon.get("fly_duration"))
			if absf(after - (before + 3.0)) > 0.01:
				_fail("fly_duration %.1f → %.1f — expected +3s"
					% [before, after])
			else:
				_pass("NEW ITEM 'Longer Flight': Q bursts now last "
					+ "%.1fs (+3s, permanent)" % after)
			(gm.wizard_menu as WizardMenu).close()
			_goto(S.WIZARD_WAIT)
		S.WIZARD_WAIT:
			# Cross BOTH provocation lines by hand (4+ purchases AND >3
			# visits) and let WorldManager._process do the rest. The wizard
			# spawn used to be gated off after the run finished.
			gm.upgrade_purchases = 4
			gm.tower_visits = 5
			if bool(_world().get("wizard_spawned")):
				_pass("USER BUG FIXED: the wizard can still emerge "
					+ "after the King's defeat")
				_goto(S.REPORT)
			elif _frames(120):
				_fail("USER BUG: wizard never appears post-victory")
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
