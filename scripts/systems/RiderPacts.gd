extends Node

## The rider's pact (2026-11-16, user: "each character before accepting
## should ask something of the dragon, what it values, then accept on a
## condition"). Every captive who agrees to ride names a price; this node
## (a child of GameManager, built when a rider is trained) keeps the count
## and lets the rider go when the price is not paid. It also carries each
## rider's GIFT (healing, a finder's fee) — the aim and the damage gifts
## live on the Dragon (rider_fire_mult / rider_accuracy / rider_guard).
##
## The trade-offs, one row per captive (decision record
## 2026-11-16-sacrifice-pacts):
##   defiant    deadly aim   — a soldier in sight must die every 10 s
##   courageous true aim     — never kill a farmer or a miner
##   cunning    fair aim     — bank 25 gold every 5 minutes; +1 gold per soldier
##   devout     never shoots — heals 10 HP / 10 s up to 50; slay the hag before the invasion
##   brute      never shoots — takes a quarter of every blade and arrow; feed him every 3 min
##   thief      poor aim     — +1 on every loot pickup; never linger by the city
##   renegade   wretched aim — ten farmers in 5 minutes; then +2 flames, forever
##
## "answers": the captive's reply to each of the dragon's VALUES in the
## trial; it opens the pact board (GameManager.pact_reaction).
## "devoted" (the dragon named what the captive values most, in the trial)
## forgives ONE broken term: a warning, and the clock starts over.
## No class_name (editor rescan caveat): GameManager preloads it.

signal broken(personality: String)
signal kept(personality: String)

## The dragon's three answers in the trial, by choice index.
const VALUES: Array[String] = ["gold", "fire", "mine"]

const PACTS := {
	"defiant": {
		"answers": [
			"\"Gold. Of COURSE. A lizard with a coin purse.\" Brannagh rolls her eyes so hard she nearly falls off the stake.",
			"\"FIRE.\" Her grin is all teeth. \"Oh, we're going to get along horribly. For that answer I'll forgive you one slow day, firebelly. One.\"",
			"\"'What is mine,'\" she mimics. \"How sweet. Did you eat a poet?\"",
		],
		"aim": "deadly", "fire_mult": 1.5, "accuracy": 1.0,
		"loves": "fire",
		"gift": "Shoots 1.5x faster than any other rider.",
		"term": "Whenever a soldier is in sight, one must die every 10 seconds.",
		"parting": "Brannagh yawns, slides off your back and stalks away into the smoke. \"Ten seconds, lizard. I gave you TEN. I'm off to find a dragon with a pulse.\"",
		"forgive": "Brannagh: \"That was slow. That was SO slow. Once, firebelly. I forgive you once.\"",
	},
	"courageous": {
		"answers": [
			"Her face closes like a door. \"Gold doesn't bleed for you, dragon. Remember that.\"",
			"\"Fire.\" She looks past you at the burnt fields and says nothing for a long time.",
			"Her chin trembles, and for once it isn't fear. \"Then we value the same thing. Because of that answer I'll forgive you one mistake. Only one.\"",
		],
		"aim": "true", "fire_mult": 1.25, "accuracy": 0.95,
		"loves": "mine",
		"gift": "Steady, true aim.",
		"term": "Never kill a farmer or a miner while she rides.",
		"parting": "Ysolde climbs down without a word. She closes the dead one's eyes, unstraps the bow and lays it at your feet. Then she walks home, and she does not look back.",
		"forgive": "Ysolde has gone white. \"That was someone's sister. Once, dragon. Never again.\"",
	},
	"cunning": {
		"answers": [
			"\"Oh, darling.\" Vesna presses a hand to her heart. \"You had me at gold. For that answer, I'll overlook one late payment.\"",
			"\"Fire. Lovely. Fire is what happens to ledgers.\" She does not sound thrilled.",
			"\"Sentimental.\" She writes it down anyway. \"Sentiment is expensive, darling.\"",
		],
		"aim": "fair", "fire_mult": 1.0, "accuracy": 0.85,
		"loves": "gold",
		"gift": "Every soldier you or she kills pays 1 gold into the stash.",
		"term": "Bank 25 gold in the lair every 5 minutes.",
		"parting": "\"Business is business, darling.\" Vesna blows you a kiss from the cave mouth, her sleeves clinking. Twenty-two percent of your hoard leaves with her.",
		"forgive": "Vesna taps the ledger. \"Late payment, darling. I'll carry it — once. Interest is a terrible thing.\"",
		"cut": 0.22,
	},
	"devout": {
		"answers": [
			"\"Gold.\" She sighs. \"The prophecy did mention a hoard. It was not a compliment.\"",
			"\"Fire purifies,\" she offers gamely, \"in the right hands. The prophecy was vague on whether you HAVE hands.\"",
			"\"Those who are yours.\" Her eyes fill. \"Then I am yours, and the gods will give you one more chance than you deserve.\"",
		],
		"aim": "none", "fire_mult": 0.0, "accuracy": 0.0,
		"loves": "mine",
		"gift": "Mends 10 HP every 10 seconds, never above 50 HP.",
		"term": "Slay the hag before the invasion begins.",
		"parting": "Sister Aldith climbs down, lights a candle and sets off west toward the fen, alone, reciting a strongly worded psalm. \"If you will not end her, great wyrm, then I shall.\"",
		"forgive": "Sister Aldith prays very loudly in your ear. \"The gods grant you one more chance. They were quite specific: ONE.\"",
	},
	"brute": {
		"answers": [
			"\"Gold? Can't hug gold. Tried.\"",
			"\"Fire's good. Cooks things.\" He thinks about it. \"Cooks ME, if you're careless.\"",
			"Horrik's eyes go wet and he hugs your foreleg until it creaks. \"Same as me. Same as the bear. For that I'll let one hungry day slide.\"",
		],
		"aim": "none", "fire_mult": 0.0, "accuracy": 0.0,
		"loves": "mine",
		"gift": "Takes a quarter of every blade and arrow meant for you.",
		"term": "Eat a meal (pig, cow, deer) at least every 3 minutes.",
		"parting": "Horrik's stomach makes a noise like a landslide. \"Sorry, little dragon. A mountain's got to eat.\" He slides off and lumbers away toward the nearest smell of a tavern.",
		"forgive": "Horrik's belly growls like the bear. \"I'm STARVING. I'll let it go once. Once!\"",
	},
	"thief": {
		"answers": [
			"\"A dragon after my own heart!\" He shakes your claw with both hands. \"For that, partner, I'll forgive you one stroll too near the gallows.\"",
			"\"Fire. Hm. Fire makes gold run. Not my favourite.\"",
			"\"What's yours.\" He pats his pockets, guilty. \"Funny, that's exactly what I value too. For different reasons.\"",
		],
		"aim": "poor", "fire_mult": 0.7, "accuracy": 0.5,
		"loves": "gold",
		"gift": "Light fingers: +1 on every loot pickup.",
		"term": "Never linger by the city walls (more than 8 seconds).",
		"parting": "One moment Corvin is behind you, the next there is only an empty saddle, a returned ruby and a note: \"Too close to the gallows, partner. No hard feelings. Some soft ones.\"",
		"forgive": "Corvin is gripping your neck very hard. \"I saw the ROPE, partner. Once more and I'm smoke.\"",
	},
	"renegade": {
		"answers": [
			"\"Gold.\" He laughs, an ugly sound. \"They paid the priest in gold to tie me up.\"",
			"\"Fire.\" His one eye finds yours and holds. \"Good. For that answer, you get a second chance at my price, if you need one.\"",
			"\"'What's mine.' Nothing's mine, dragon. That's the whole point of me.\"",
		],
		"aim": "wretched", "fire_mult": 0.6, "accuracy": 0.3,
		"loves": "fire",
		"gift": "Pay his grudge and it feeds your fire: +2 flame capacity, and he stays for good.",
		"term": "Kill ten farmers within 5 minutes of him climbing up.",
		"parting": "Garreth spits off your flank. \"Thought so. Nobody finishes a job for me.\" He drops into the grass and starts down the road toward the village, knife in his fist.",
		"forgive": "Garreth's one eye burns. \"Not enough. Not NEARLY. I'll give you another five minutes. Only because you said fire.\"",
	},
}

const BLOOD_CLOCK := 10.0        # defiant: seconds a soldier in sight may live
const BLOOD_SIGHT := 420.0
const BANK_WINDOW := 300.0       # cunning
const BANK_GOLD := 25
const HEAL_EVERY := 10.0         # devout
const HEAL_AMOUNT := 10
const HEAL_CAP := 50
const HAG_GRACE := 300.0         # devout trained after the invasion began
const FEED_WINDOW := 180.0       # brute
const CITY_RADIUS := 360.0       # thief
const CITY_LINGER := 8.0
const GRUDGE_WINDOW := 300.0     # renegade
const GRUDGE_FARMERS := 10
const GRUDGE_FLAMES := 2

const SOLDIER_TYPES := ["soldier", "archer", "invader"]
const CIVILIAN_TYPES := ["farmer", "miner"]
const DRAGON_SOURCES := ["dragon", "greater_flame", "rider"]

var personality := ""
var devoted := false
var done := false                # the pact is fulfilled (devout, renegade)
var gm: Node = null
var dragon: Node2D = null

var _clock := 0.0                # counts DOWN (the term's deadline)
var _count := 0                  # banked gold / farmers
var _heal_t := 0.0
var _last_gold := 0
var _status := ""

static func pact(p: String) -> Dictionary:
	return PACTS.get(p, {})

static func loves(p: String, value_index: int) -> bool:
	return value_index >= 0 and value_index < VALUES.size() \
		and str(pact(p).get("loves", "")) == VALUES[value_index]

## One line for the outcome report and the decision: aim, gift, price.
static func summary(p: String, is_devoted: bool) -> String:
	var d := pact(p)
	if d.is_empty():
		return ""
	return "Aim: %s · %s\nPact: %s%s" % [d["aim"], d["gift"], d["term"],
		" ♥ One broken term forgiven." if is_devoted else ""]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func begin(p: String, is_devoted: bool, manager: Node, mount: Node2D) -> void:
	personality = p
	devoted = is_devoted
	gm = manager
	dragon = mount
	done = false
	_count = 0
	_heal_t = HEAL_EVERY
	_last_gold = int(gm.stash["gold"])
	_clock = _window()
	if gm.has_signal("stash_changed") and not gm.stash_changed.is_connected(_on_stash):
		gm.stash_changed.connect(_on_stash)
	if dragon.has_signal("meal_eaten") and not dragon.meal_eaten.is_connected(on_meal):
		dragon.meal_eaten.connect(on_meal)
	if dragon.has_signal("rider_gift") and not dragon.rider_gift.is_connected(_on_gift):
		dragon.rider_gift.connect(_on_gift)
	var d := pact(p)
	_notice("info", "Pact sworn: %s Gift: %s" % [d.get("term", ""), d.get("gift", "")], 6.0)
	if p == "devout":
		var wm: Node = gm.world_manager
		if wm != null and not bool(wm.get("hag_nest_spawned")) and wm.has_method("spawn_hag_nest"):
			wm.call("spawn_hag_nest")   # she knows the way to the fen
			_notice("info", "Sister Aldith points west: the hag's hut lies in the fen beyond the firs.", 5.0, "", true)
	_update_status()

func end() -> void:
	personality = ""
	_set_status("")
	queue_free()

func active() -> bool:
	return personality != "" and not done

## The full length of the pact's clock (seconds).
func _window() -> float:
	match personality:
		"defiant": return BLOOD_CLOCK
		"cunning": return BANK_WINDOW
		"brute": return FEED_WINDOW
		"thief": return CITY_LINGER
		"renegade": return GRUDGE_WINDOW
		"devout": return HAG_GRACE
	return 0.0

# --- events -------------------------------------------------------------------

## Every death by damage (GameManager.record_kill passes them all on).
func on_kill(npc_type: String, source: String) -> void:
	if personality == "" or not source in DRAGON_SOURCES:
		return
	match personality:
		"defiant":
			if npc_type in SOLDIER_TYPES:
				if _clock < BLOOD_CLOCK - 4.0:
					_notice("info", "Brannagh whoops. The count starts over.", 2.5, "blood_reset", false, 6.0)
				_clock = BLOOD_CLOCK
				_warned.clear()
		"courageous":
			if npc_type in CIVILIAN_TYPES:
				_breach()
		"cunning":
			if npc_type in SOLDIER_TYPES:
				gm.call("add_stolen", "gold", 1)   # finder's fee
				_fees += 1
				_notice("bonus", "+%d gold: Vesna's finder's fee" % _fees, 3.0, "fee", false, 4.0)
		"renegade":
			if not done and npc_type == "farmer":
				_count += 1
				if _count >= GRUDGE_FARMERS:
					done = true
					dragon.call("increase_flame_capacity", GRUDGE_FLAMES)
					_notice("bonus", "Garreth's grudge is paid and goes into your fire: +%d flame capacity. He stays for good." % GRUDGE_FLAMES, 6.0, "", true)
					kept.emit(personality)
				else:
					_notice("info", "Garreth marks it: %d of %d farmers." % [_count, GRUDGE_FARMERS], 2.5)
	_update_status()

func on_meal(_what: String = "") -> void:
	if personality == "brute":
		_clock = FEED_WINDOW
		_warned.clear()
		_danger = false
		_notice("info", "Horrik is fed. Next meal within 3:00.", 3.0)
		_update_status()

func _on_stash(res_type: String, total: int) -> void:
	if res_type != "gold":
		return
	if personality == "cunning" and total > _last_gold:
		_count += total - _last_gold
	_last_gold = total

## A gift that lands on the dragon itself (Dragon.rider_gift).
func _on_gift(kind: String, amount: int) -> void:
	match kind:
		"loot":
			_notice("bonus", "+%d loot: Corvin's light fingers" % amount, 2.5, "loot", false, 3.0)
		"guard":
			_notice("bonus", "Horrik takes %d of the blow for you" % amount, 2.5, "guard", false, 5.0)

# --- the clock ------------------------------------------------------------------

func _process(delta: float) -> void:
	if personality == "" or dragon == null or not is_instance_valid(dragon):
		return
	_danger = false
	match personality:
		"defiant":
			if _soldier_in_sight():
				_clock -= delta
				_warn_at([5.0], "Brannagh is counting out loud: %ds to kill a soldier!")
				if _clock <= 0.0:
					_breach()
		"courageous":
			_watch_civilians()
		"cunning", "brute":
			_clock -= delta
			if personality == "cunning" and _count >= BANK_GOLD:
				_count = 0
				_clock = BANK_WINDOW
				_warned.clear()
				_notice("bonus", "Vesna ticks the ledger: paid in full. The next 25 gold within 5 minutes, darling.", 4.0, "", true)
			elif _clock <= 0.0:
				_breach()
			elif personality == "cunning":
				_warn_at([60.0, 20.0], "Vesna taps the ledger: %%ds left and %d gold short, darling." % (BANK_GOLD - _count))
			else:
				_warn_at([45.0, 15.0], "Horrik's stomach rumbles like a landslide: feed him within %ds!")
		"thief":
			var city: Vector2 = gm.world_manager.get("city_position")
			if dragon.global_position.distance_to(city) <= CITY_RADIUS:
				_clock -= delta
				_warn_at([CITY_LINGER - 0.05, 3.0], "Corvin hisses: \"The gallows! Get us away from the city!\" (%ds)")
				if _clock <= 0.0:
					_breach()
			else:
				if _clock < CITY_LINGER:
					_notice("info", "Corvin breathes again.", 2.0, "city_out", false, 5.0)
				_clock = CITY_LINGER
				_warned.clear()
		"renegade":
			if not done:
				_clock -= delta
				_warn_at([90.0, 30.0], "Garreth glares: %%ds left, and %d farmers still owed." % (GRUDGE_FARMERS - _count))
				if _clock <= 0.0:
					_breach()
		"devout":
			_tick_heal(delta)
			if not done:
				var wm: Node = gm.world_manager
				if bool(wm.get("hag_nest_spawned")) and not bool(wm.call("hag_alive")):
					done = true
					_notice("bonus", "The hag is dead. Sister Aldith sings the whole way home. Her pact is kept, and she stays.", 5.0, "", true)
					kept.emit(personality)
				elif _invasion_on():
					_clock -= delta
					_warn_at([HAG_GRACE - 0.05, 120.0, 30.0], "Sister Aldith: \"The war has come and the hag still lives!\" Slay her within %ds.")
					if _clock <= 0.0:
						_breach()
				elif int(gm.get("phase")) >= 1 and not _warned.has(-1.0):
					_warned.append(-1.0)   # the aftermath: the war is near
					_notice("warning", "Sister Aldith: \"I feel the war coming. The hag must die before it does.\"", 5.0)
	_update_status()

## A warning when the clock crosses each mark (once per mark per window);
## the HUD chip turns red under the first mark. `text` takes the seconds left.
func _warn_at(marks: Array, text: String) -> void:
	if _clock <= float(marks[0]):
		_danger = true
	for m: float in marks:
		if _clock <= m and not _warned.has(m):
			_warned.append(m)
			var last := "" if devoted else " Break it and %s leaves." % RIDER_NAMES.get(personality, "the rider")
			_notice("warning", (text % ceili(_clock)) + last, 4.0)

## Ysolde: a farmer or miner under the dragon's claws gets a warning.
func _watch_civilians() -> void:
	for group: String in ["farmers", "miners"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var npc := node as Node2D
			if npc != null and bool(npc.get("is_alive")) \
					and npc.global_position.distance_to(dragon.global_position) <= CIVILIAN_NEAR:
				_danger = true
				_notice("warning", "Ysolde grips your neck: \"Careful. That's someone's sister.\" Kill no farmer or miner.", 3.5, "civilian", false, 20.0)
				return

func _invasion_on() -> bool:
	var ph := int(gm.get("phase"))
	return ph >= 2   # GameManager.Phase.INVASION and after

## Aldith mends: +10 HP every 10 s while the dragon is under 50.
func _tick_heal(delta: float) -> void:
	_heal_t -= delta
	if _heal_t > 0.0:
		return
	_heal_t = HEAL_EVERY
	var hp := int(dragon.get("health"))
	var cap := mini(HEAL_CAP, int(dragon.get("max_health")))
	if hp <= 0 or hp >= cap or bool(dragon.get("_dying")):
		return
	dragon.set("health", mini(hp + HEAL_AMOUNT, cap))
	dragon.emit_signal("health_changed", int(dragon.get("health")))
	var healed := int(dragon.get("health")) - hp
	print("RiderPacts: Sister Aldith mends the dragon (+%d HP)" % healed)
	_notice("bonus", "Sister Aldith mends you: +%d HP" % healed, 2.5)

func _soldier_in_sight() -> bool:
	for group: String in ["soldiers", "invaders"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			var npc := node as Node2D
			if npc == null or not bool(npc.get("is_alive")) or npc.is_in_group("king"):
				continue
			if npc.global_position.distance_to(dragon.global_position) <= BLOOD_SIGHT:
				return true
	return false

## A term is broken. Devotion forgives it once; otherwise the rider goes.
func _breach() -> void:
	var d := pact(personality)
	if devoted:
		devoted = false
		_notice("warning", str(d.get("forgive", "")) + " (Forgiven once. Next time, %s leaves.)" % RIDER_NAMES.get(personality, "the rider"), 6.0, "", true)
		_clock = _window()
		_warned.clear()
		if personality in ["cunning", "renegade"]:
			_count = 0
		return
	var p := personality
	personality = ""
	_set_status("")
	broken.emit(p)

# --- the HUD: chip and notices ---------------------------------------------------------

const CIVILIAN_NEAR := 70.0
const RIDER_NAMES := {"defiant": "Brannagh", "courageous": "Ysolde", "cunning": "Vesna",
	"devout": "Aldith", "brute": "Horrik", "thief": "Corvin", "renegade": "Garreth"}
## Bonus/info notices yield to a fresh warning for this long (ms).
const WARNING_HOLD_MS := 2500

var _warned: Array = []          # warning marks already given this window
var _danger := false             # the chip shows red
var _fees := 0                   # Vesna's fees, summed per notice
var _last_notice := {}           # key → ticks (throttle)
var _warning_at := -100000

## One notice line on the HUD. kind: "bonus" | "warning" | "info". A `key`
## with a `cooldown` (s) throttles repeats; bonuses and info wait out a
## fresh warning unless `force`.
func _notice(kind: String, text: String, duration: float = 3.5, key: String = "",
		force: bool = false, cooldown: float = 0.0) -> void:
	if text == "" or gm == null:
		return
	var now := Time.get_ticks_msec()
	if key != "" and now - int(_last_notice.get(key, -1000000)) < int(cooldown * 1000.0):
		return
	if kind != "warning" and not force and now - _warning_at < WARNING_HOLD_MS:
		return
	if key != "":
		_last_notice[key] = now
	if key == "fee":
		_fees = 0
	if kind == "warning":
		_warning_at = now
	var hud: Node = gm.get("hud")
	if hud != null and hud.has_method("show_notice"):
		hud.call("show_notice", text, kind, duration)
	elif gm.has_method("_hud_message"):
		gm.call("_hud_message", text, duration)

func _update_status() -> void:
	var t := ""
	var mmss := "%d:%02d" % [int(maxf(_clock, 0.0)) / 60, int(maxf(_clock, 0.0)) % 60]
	match personality:
		"defiant":
			t = "Pact: blood in %ds" % ceili(_clock) if _soldier_in_sight() else "Pact: blood (no soldier in sight)"
		"courageous":
			t = "Pact: spare the folk"
		"cunning":
			t = "Pact: bank %d/%dg · %s" % [mini(_count, BANK_GOLD), BANK_GOLD, mmss]
		"devout":
			if done:
				t = "Pact kept: Aldith mends"
			elif _invasion_on():
				t = "Pact: slay the hag · %s" % mmss
			else:
				t = "Pact: slay the hag before the invasion"
		"brute":
			t = "Pact: feed Horrik · %s" % mmss
		"thief":
			t = "Pact: TOO CLOSE TO THE CITY %ds" % ceili(_clock) if _clock < CITY_LINGER \
				else "Pact: keep clear of the city"
		"renegade":
			t = "Pact kept: the grudge is paid" if done \
				else "Pact: farmers %d/%d · %s" % [_count, GRUDGE_FARMERS, mmss]
	if devoted and t != "" and not done:
		t += " ♥"
	_set_status(t, _danger and not done)

var _status_danger := false

func _set_status(t: String, danger: bool = false) -> void:
	if t == _status and danger == _status_danger:
		return
	_status = t
	_status_danger = danger
	var hud: Node = gm.get("hud") if gm != null else null
	if hud != null and hud.has_method("set_pact_text"):
		hud.call("set_pact_text", t, danger)
