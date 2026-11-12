extends Node2D

## AdventurerProbe — regression probe for the wandering adventurer
## (user spec 2026-11-12: hero spawns at the city every 5 minutes, walks
## to the lair, kills goblins, steals ALL the lair gold; dragon fire is
## the counter). Run headless:
##   Godot --headless --path . res://scenes/probes/AdventurerProbe.tscn
##
## Scenario:
##   1. BOOT → neutralize treasury soldier purchases (huge gold cost) so
##      the deposit check is deterministic, fund the dragon stash with
##      gold, spawn the hero, verify the 5-minute timer config.
##   2. GOBLIN HUNT: the tribe must shrink (a goblin dies) before the raid.
##   3. LAIR RAID: hero payload mounts with the WHOLE stash gold, stash 0.
##   4. INTERCEPTION: the carrying hero is visible to the dragon's
##      GoldInterceptionSystem (the haul is stealable back).
##   5. HAUL HOME: the hero deposits the gold into the town treasury and
##      departs (freed node).
##   6. FIRE COUNTER: a second hero with a funded backpack catches fire →
##      burns out, dies, and spills the haul as a loose GoldDrop.
##
## Every step prints "PROBE PASS/FAIL:" and the run ends with
## "PROBE RESULT: SUCCESS|FAILURE" + exit code 0/1.

enum S {
	BOOT, SPAWN, WAIT_HERO, HUNT_WAIT, RAID_WAIT, INTERCEPT_CHECK,
	HAUL_WAIT, FIRE_SPAWN, FIRE_BURN, FIRE_SPILL, REPORT,
}

const TIMEOUT := 300.0
const FUND_GOLD := 12

var state: int = S.BOOT
var frames_in_state: int = 0
var elapsed: float = 0.0
var passes: Array[String] = []
var failures: Array[String] = []
var _hero: Adventurer = null
var _goblins_at_start: int = 0
var _min_goblins_seen: int = 999999
var _treasury_baseline: int = -1
var _goblin_killed: bool = false

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

func _close_story_if_open() -> void:
	if gm.story_open and gm.story_popup != null:
		(gm.story_popup as StoryPopup)._on_choice_pressed(0)

func _find_hero() -> Adventurer:
	for node: Node in get_tree().get_nodes_in_group("adventurers"):
		var hero := node as Adventurer
		if hero != null and hero.is_alive:
			return hero
	return null

func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null:
		return  # a mid-run scene reload detached the probe — stop cleanly
	frames_in_state += 1
	elapsed += delta
	if elapsed > TIMEOUT:
		_fail("global timeout in state %d" % state)
		_goto(S.REPORT)
		return
	_close_story_if_open()
	# Keep the probe's dragon alive: it idles at the world centre on the
	# hero's walking route (and closed goblin stories make the tribe
	# hostile), so contact damage would kill it and the death chapter
	# reloads the scene mid-probe. A probe subject is not the test target.
	var dragon := gm.dragon as Node2D
	if dragon != null and is_instance_valid(dragon):
		var dying: Variant = dragon.get("_dying")
		if (dying == null or not bool(dying)) and dragon.get("health") is int:
			dragon.set("health", int(dragon.get("max_health")))

	match state:
		S.BOOT:
			if gm == null or gm.dragon == null or _world() == null:
				if _frames(60):
					_fail("BOOT: GameManager/Dragon/WorldManager missing")
					_goto(S.REPORT)
				return
			# Neutralize ALL soldier production so the King never rises in
			# this probe: with a huge gold cost spend_treasury("gold", …)
			# always fails, and zero gems-per-soldier stops the gem path.
			# (Gem purchases fielded the King within ~90s in the first
			# probe run — his lightning then killed the test dragon and
			# the death chapter reloaded the scene mid-probe.)
			_world().soldier_gold_cost = 999999
			_world().soldiers_per_gem = 0
			_world().king_threshold = 999999
			gm.add_stolen("gold", FUND_GOLD)  # the lair hoard to raid
			_pass("BOOT: purchases neutralized, lair stash funded with %dg"
				% FUND_GOLD)
			_goto(S.SPAWN)
		S.SPAWN:
			# Timer config check (user spec: hero spawns every 5 minutes).
			var timer := _world()._adventurer_timer as Timer
			if timer == null:
				_fail("no adventurer spawn timer on WorldManager")
				_goto(S.REPORT)
				return
			if absf(timer.wait_time - 300.0) > 0.01:
				_fail("adventurer timer is %.0fs — expected 300s (5 min)"
					% timer.wait_time)
			else:
				_pass("adventurer spawn timer runs every 300s (5 minutes)")
			_world().spawn_adventurer()
			_goblins_at_start = get_tree().get_nodes_in_group("goblins").size()
			_min_goblins_seen = _goblins_at_start
			_goto(S.WAIT_HERO)
		S.WAIT_HERO:
			_hero = _find_hero()
			if _hero != null:
				_pass("hero spawned at the city (%s), hp %d"
					% [str(_hero.global_position), _hero.health])
				_goto(S.HUNT_WAIT)
			elif _frames(60):
				_fail("spawn_adventurer produced no living hero")
				_goto(S.REPORT)
		S.HUNT_WAIT:
			# The goblin hunt comes first (user spec: "kill goblins and
			# finally steal"). The tribe shrinks at every hero kill but
			# tops back up on the 60s respawn tick — so track the MINIMUM
			# size ever seen instead of comparing snapshots.
			_min_goblins_seen = mini(_min_goblins_seen,
				get_tree().get_nodes_in_group("goblins").size())
			if _min_goblins_seen < _goblins_at_start:
				_goblin_killed = true
				_pass("hero hunting: tribe shrank %d → %d (a goblin died)"
					% [_goblins_at_start, _min_goblins_seen])
				_goto(S.RAID_WAIT)
			elif _frames(4500):  # 75s
				_fail("no goblin died within 75s of the hero setting out")
				_goto(S.REPORT)
		S.RAID_WAIT:
			_hero = _find_hero()
			if _hero == null:
				if _frames(120):
					_fail("hero vanished before the raid")
					_goto(S.REPORT)
				return
			if _hero.payload_res_type == "gold" and _hero.payload_amount > 0:
				if not _goblin_killed:
					_fail("REGRESSION: the hero raided BEFORE clearing any "
						+ "goblin — the raid must wait for the hunt")
					_goto(S.REPORT)
					return
				var hoard_left := int(gm.stash["gold"])
				if _hero.payload_amount == FUND_GOLD and hoard_left == 0:
					_pass("LAIR RAID: hero stole ALL %dg (stash drained to 0)"
						% _hero.payload_amount)
				else:
					_fail("raid partial: carried %dg, stash left %dg"
						% [_hero.payload_amount, hoard_left])
				_goto(S.INTERCEPT_CHECK)
			elif _frames(7200):  # 120s
				_fail("hero never claimed the hoard within 120s of the hunt")
				_goto(S.REPORT)
		S.INTERCEPT_CHECK:
			_hero = _find_hero()
			if _hero == null:
				_fail("hero gone before the interception check")
				_goto(S.REPORT)
				return
			var sys := get_tree() \
				.get_first_node_in_group("gold_interception_system")
			if sys == null:
				_fail("no GoldInterceptionSystem found")
				_goto(S.REPORT)
				return
			var targets: Array = sys.check_interception_opportunities(
				_hero.global_position + Vector2(60, 0))
			if targets.has(_hero):
				_pass("INTERCEPTION: the dragon sees the hero's haul as a "
					+ "steal target (carrier scan includes adventurers)")
			else:
				_fail("GoldInterceptionSystem ignores the carrying hero")
			_goto(S.HAUL_WAIT)
		S.HAUL_WAIT:
			# The haul home ends in a treasury deposit + departure
			# (queue_free — no corpse, no npc_died).
			if _treasury_baseline < 0 and _hero != null \
					and is_instance_valid(_hero) and _hero.payload_amount > 0:
				_treasury_baseline = int(gm.treasury["gold"])
			if _hero == null or not is_instance_valid(_hero):
				if _treasury_baseline < 0:
					_fail("hero never carried the loot through the haul")
					_goto(S.REPORT)
					return
				var delta_gold := int(gm.treasury["gold"]) - _treasury_baseline
				if delta_gold >= FUND_GOLD:
					_pass(("HAUL HOME: hero deposited the %dg haul into the "
						+ "town treasury and departed (treasury +%d)")
						% [FUND_GOLD, delta_gold])
				else:
					_fail("treasury delta %d after deposit — expected >= %d"
						% [delta_gold, FUND_GOLD])
				_goto(S.FIRE_SPAWN)
				return
			if _frames(9000):  # 150s
				_fail("hero never completed the haul within 150s")
				_goto(S.REPORT)
		S.FIRE_SPAWN:
			_world().spawn_adventurer()
			_goto(S.FIRE_BURN)
		S.FIRE_BURN:
			var hero2 := _find_hero()
			if hero2 == null:
				if _frames(120):
					_fail("second hero never spawned for the fire test")
					_goto(S.REPORT)
				return
			# Fund his claws, then subject him to fire (user spec: "unless
			# the dragon subject him to fire"). A full burn-out kills any
			# NPC regardless of remaining health (BaseNPC._flames_teardown).
			hero2.set_payload("gold", 7)
			hero2.catch_fire()
			_pass("fire test: hero ignited with a 7g backpack")
			_goto(S.FIRE_SPILL)
		S.FIRE_SPILL:
			var hero2 := _find_hero()
			if hero2 == null:
				var spilled := 0
				for d: Node in get_tree().get_nodes_in_group("loose_loot"):
					var drop := d as GoldDrop
					if drop != null and drop.res_type == "gold":
						spilled += drop.amount
				if spilled >= 7:
					_pass("FIRE COUNTER: burning hero died and spilled "
						+ "%dg as a loose drop" % spilled)
				else:
					_fail("burning hero died but spilled %dg — expected >= 7"
						% spilled)
				_goto(S.REPORT)
			elif _frames(900):  # 15s — burn 3s + corpse 2s is plenty
				_fail("hero survived the burn-out (15s) — fire must kill")
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
