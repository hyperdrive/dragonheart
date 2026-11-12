extends Node2D

## GemGoblinProbe — regression probe for the gem exchange rate and the
## goblin employment logic (user spec 2026-11-12: "The exchange rate for
## gems in the wizards tower should be 1 gem = 2gp but you can't get gems
## for gold. The reason you employ the goblins to work for gems is that
## you avoid having them steal your gold."). Run headless:
##   Godot --headless --path . res://scenes/probes/GemGoblinProbe.tscn
##
## Scenario:
##   1. BOOT → neutralize soldier/King production, stop the adventurer
##      timer, EMPLOY the tribe (set_goblin_service(true)) before any
##      goblin can meet the dragon.
##   2. RATE: buy "speed" (12g, 0 gems) from a stash of 4g/5 gems — the
##      missing 8 gold must cost exactly 4 gems (1 gem = 2gp; the old
##      10:1 rate would leave 4 gems). The purchase must never GRANT gems.
##   3. MENU: every wizard option is a priced PAYMENT (gems >= 0) — the
##      shop offers no gold→gems exchange.
##   4. TRADE CYCLE: employed (BUYING) goblins haul mine gold INTO the
##      stash and pay 1 gem per haul OUT of it — stash gold must be
##      monotonically non-decreasing (employees never steal).
##   5. HOSTILE THEFT: a tribe-refused (HOSTILE) goblin raids the LAIR,
##      rips gold out of the stash (stash drops while he carries it), is
##      visible to the GoldInterceptionSystem, hauls it to the tribe
##      mountain and keeps raiding until the hoard is dry.
##
## Every step prints "PROBE PASS/FAIL:" and the run ends with
## "PROBE RESULT: SUCCESS|FAILURE" + exit code 0/1.

enum S {
	BOOT, RATE, TRADE_WAIT, TRADE_CLEAN, THIEF_SPAWN,
	THEFT_WAIT, HOARD_WAIT, REPORT,
}

const TIMEOUT := 480.0
const RATE_GOLD := 4      # stash gold for the rate check
const RATE_GEMS := 5      # stash gems for the rate check (expects 1 left)
const TRADE_GEMS := 3     # gem funding for the employed trade cycle
const STOLEN_GOLD := 10   # stash gold for the hostile-theft test

var state: int = S.BOOT
var frames_in_state: int = 0
var elapsed: float = 0.0
var passes: Array[String] = []
var failures: Array[String] = []
var _stash_gold_last: int = 0
var _trade_gems_funded: int = 0
var _theft_baseline: int = 0
var _thief: Goblin = null

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

func _find_goblin(filter_buying: bool) -> Goblin:
	for node: Node in get_tree().get_nodes_in_group("goblins"):
		var goblin := node as Goblin
		if goblin == null or not goblin.is_alive:
			continue
		if filter_buying and goblin.service_state != Goblin.ServiceState.BUYING:
			continue
		return goblin
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
	# Keep the probe's dragon alive: a hostile goblin's contact damage (and
	# any stray hazard) would trigger the death chapter → reload_current_
	# scene → the probe loses its scene mid-run. A probe subject is not the
	# test target.
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
			# this probe (he would hunt the probe dragon — see
			# AdventurerProbe's BOOT notes).
			_world().soldier_gold_cost = 999999
			_world().soldiers_per_gem = 0
			_world().king_threshold = 999999
			# No hero raids mid-probe (a dead goblin would desync the counts).
			if _world()._adventurer_timer != null:
				_world()._adventurer_timer.stop()
			# EMPLOY the tribe BEFORE any goblin can meet the dragon: the
			# standing binds every current and future spawn (adopted in
			# _ready). Choice 0 on the story popup would REFUSE — never let
			# the popup be the decider here.
			_world().set_goblin_service(true)
			_pass("BOOT: production neutralized, tribe EMPLOYED (BUYING)")
			_goto(S.RATE)
		S.RATE:
			# Menu scan: every wizard option must map to a PRICED payment —
			# the shop sells upgrades, never gems.
			var menu_ok := true
			for option: Dictionary in WizardMenu.OPTIONS:
				var kind: String = option["kind"]
				if not gm.WIZARD_PRICES.has(kind) \
						or int(gm.WIZARD_PRICES[kind]["gems"]) < 0:
					menu_ok = false
					_fail("MENU: option '%s' is not a priced payment"
						% kind)
			if menu_ok:
				_pass(("MENU: all %d wizard options are priced payments "
					+ "(the shop cannot grant gems)")
					% WizardMenu.OPTIONS.size())
			gm.add_stolen("gold", RATE_GOLD)
			gm.add_stolen("gems", RATE_GEMS)
			var gems_before := int(gm.stash["gems"])
			if not gm.purchase_upgrade("speed"):  # 12g, 0 gems
				_fail("RATE: 'speed' (12g) unaffordable from 4g/5 gems")
				_goto(S.REPORT)
				return
			var gold_after := int(gm.stash["gold"])
			var gems_after := int(gm.stash["gems"])
			# 12g cost paid 4g + 8g missing → at 1 gem = 2gp exactly 4 gems.
			# (The old 10:1 rate would have spent only 1 gem → 4 left.)
			if gold_after == 0 and gems_after == 1:
				_pass(("RATE: 1 gem = 2gp — 12g cost left %d gems of %d ")
					% [gems_after, gems_before])
			else:
				_fail(("RATE: after a 12g purchase stash is %dg/%d gems — "
					+ "expected 0g/1 gem (2:1 top-up)")
					% [gold_after, gems_after])
			if gems_after < gems_before:
				_pass("RATE: purchase SPENT gems, never granted any "
					+ "(no gold→gems exchange exists)")
			else:
				_fail("REGRESSION: a gold purchase left gems >= before")
			_goto(S.TRADE_WAIT)
		S.TRADE_WAIT:
			if _trade_gems_funded == 0:
				# Fund the cycle: the employed tribe pays each haul's gem
				# fee OUT of the dragon's stash up-front (_can_fetch_gold
				# refuses while the hoard holds no gems).
				gm.add_stolen("gems", TRADE_GEMS)
				_trade_gems_funded = int(gm.stash["gems"])
				_stash_gold_last = int(gm.stash["gold"])
				return
			# The employed tribe's cycle: haul mine gold INTO the stash,
			# pay 1 gem per haul OUT of it. Watch the invariant that makes
			# employment worth it: the stash gold ONLY ever rises.
			var gold := int(gm.stash["gold"])
			if gold < _stash_gold_last:
				_fail(("REGRESSION: an EMPLOYED goblin drained the stash "
					+ "(%d → %d gold)") % [_stash_gold_last, gold])
				_goto(S.REPORT)
				return
			_stash_gold_last = gold
			var fees_paid := _trade_gems_funded - int(gm.stash["gems"])
			if gold >= 1 and fees_paid >= 1:
				var trader := _find_goblin(true)
				if trader != null:
					_pass(("TRADE CYCLE: employed goblin hauled %dg into "
						+ "the stash and paid %d gem%s in fees — stash "
						+ "gold never dropped")
						% [gold, fees_paid, "" if fees_paid == 1 else "s"])
					_goto(S.TRADE_CLEAN)
					return
			if _frames(10800):  # 180s — mountain→mine→lair round trip
				_fail(("no employed trade cycle completed within 180s "
					+ "(stash %dg/%d gems)")
					% [int(gm.stash["gold"]), int(gm.stash["gems"])])
				_goto(S.REPORT)
		S.TRADE_CLEAN:
			# Clear the stage for the theft test: stop further goblin
			# spawns, free every employed goblin, zero the stash so the
			# theft measurement starts from a known empty hoard (the trade
			# haul's deposited gold is real economy, not test gold).
			_world()._goblin_timer.stop()
			for node: Node in get_tree().get_nodes_in_group("goblins"):
				node.queue_free()
			gm.stash["gold"] = 0
			gm.stash["gems"] = 0
			if _frames(30):
				_goto(S.THIEF_SPAWN)
		S.THIEF_SPAWN:
			var world := _world()
			var scene: PackedScene = load("res://scenes/npcs/Goblin.tscn")
			var thief := scene.instantiate() as Goblin
			if thief == null or world.goblin_mountain == null:
				_fail("THIEF: could not instantiate a goblin")
				_goto(S.REPORT)
				return
			var angle := randf() * TAU
			var pos: Vector2 = world.goblin_mountain.global_position \
				+ Vector2(cos(angle), sin(angle)) * world.GOBLIN_SPAWN_RING
			pos = world.clamp_into_playfield(pos, 12.0)
			thief.global_position = pos
			world.add_child(thief)
			world.setup_entity("goblin", thief)
			# Refusal path: the standing already says BUYING, so the story
			# answer can't flip this one — a REFUSED tribe is HOSTILE. Set
			# it directly (what _on_service_response would have done).
			thief.service_state = Goblin.ServiceState.HOSTILE
			thief._plunder_mode = true
			_thief = thief
			_pass("THIEF: hostile goblin spawned at the tribe mountain "
				+ "(%s), plunder mode on" % str(pos))
			_goto(S.THEFT_WAIT)
		S.THEFT_WAIT:
			if _theft_baseline == 0:
				gm.add_stolen("gold", STOLEN_GOLD)
				# Baseline is the ACTUAL funded stash (the trade phase's
				# deposits were zeroed in TRADE_CLEAN, but never trust a
				# computed number when the truth is readable).
				_theft_baseline = int(gm.stash["gold"])
				return
			# NOTE: stash gold may legitimately RISE here — the idle probe
			# dragon auto-steals from miners that pass within interception
			# range (ambient noise, not goblin work). The employment
			# invariant is measured in the TRADE phase; here only the
			# thief's WITHDRAWAL matters: the stash must fall below the
			# funded baseline while he carries the gold.
			var gold := int(gm.stash["gold"])
			if gold < _theft_baseline:
				# Caught mid-act: payload mounted at the lair ring, still
				# hauling home.
				if _thief != null and is_instance_valid(_thief) \
						and _thief.payload_res_type == "gold" \
						and _thief.payload_amount > 0:
					_pass(("HOSTILE THEFT: stash %d → %d gold while the "
						+ "thief carries %dg")
						% [_theft_baseline, gold, _thief.payload_amount])
					_goto(S.HOARD_WAIT)
				else:
					_fail(("stash drained (%d → %d) but the thief is not "
						+ "carrying gold") % [_theft_baseline, gold])
					_goto(S.REPORT)
				return
			if _frames(5400):  # 90s — lair is ~200px from the mountain
				_fail("no hostile theft within 90s (stash still %dg)" % gold)
				_goto(S.REPORT)
		S.HOARD_WAIT:
			# Ambient dragon-steals from passing miners can drip +1 gold
			# into the stash (see THEFT_WAIT note) — not a goblin flow, so
			# not gated. Completion = the thief banked ALL funded gold and
			# an instant exists where the stash sits dry.
			# The dragon can steal the haul back mid-flight — that is the
			# GoldInterceptionSystem check, done once while he carries.
			if _thief != null and is_instance_valid(_thief) \
					and _thief.payload_amount > 0 and frames_in_state == 3:
				var sys := get_tree() \
					.get_first_node_in_group("gold_interception_system")
				if sys == null:
					_fail("no GoldInterceptionSystem found")
					_goto(S.REPORT)
					return
				var targets: Array = sys.check_interception_opportunities(
					_thief.global_position + Vector2(60, 0))
				if targets.has(_thief):
					_pass("INTERCEPTION: the dragon sees the thief's haul "
						+ "as a steal target (carrier scan includes goblins)")
				else:
					_fail("GoldInterceptionSystem ignores the carrying thief")
			# The tribe keeps raiding until the hoard is dry: all funded
			# gold must end up banked at the mountain.
			if _thief != null and is_instance_valid(_thief) \
					and _thief._gold_hoard >= STOLEN_GOLD \
					and int(gm.stash["gold"]) == 0:
				_pass(("HAUL HOME: the tribe banked all %dg stolen gold "
					+ "and the stash is dry") % STOLEN_GOLD)
				_goto(S.REPORT)
				return
			if _thief == null or not is_instance_valid(_thief):
				_fail("thief vanished before banking the haul")
				_goto(S.REPORT)
				return
			if _frames(10800):  # 150s for two full raid round trips
				_fail(("thief never banked the full haul within 150s "
					+ "(hoard %d, stash %dg)")
					% [_thief._gold_hoard, int(gm.stash["gold"])])
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
