extends RefCounted

class_name StoryEffects

## Story-choice effects (2026-11-14, user: "implement a system that can
## trigger these and other effects"). A story in StoryPopup.STORIES may
## carry an "effects" array parallel to its "choices": entry i is a
## Dictionary of effect → amount, applied when answer i is picked.
##
##   "choices": ["Roar.", "Grab the ring."],
##   "effects": [{"flames": 1}, {"gold": 1, "health": -5}],
##
## Missing entries (or {}) mean "no effect". GameManager calls apply() from
## _on_story_choice and flashes the returned report on the HUD.
##
## Effect keys (add new ones to EFFECTS and a case in _apply_one):
##   flames            ±n flame charges right now (clamped 0..max)
##   max_flames        +n flame capacity (arrives loaded)
##   health            ±n health right now (a story never kills: min 1)
##   max_health        ±n maximum health (current follows a gain)
##   gold / gems       ±n in the dragon's stolen hoard (never below 0)
##   flight_recharge   ±s permanent change to the post-landing wait (min 1s)
##   flight_duration   ±s permanent change to the flight burst (min 1s)
##   fire_reach        ±px permanent breath reach
##   spawn_soldiers    n soldiers march out of the town gate (they count
##                     toward the King's arrival like any other recruit)
##   flag              String or Array of strings → GameManager.story_flags
##                     (run memory for later story branches)
##   story             String: the story to open right after this one

const EFFECTS: Array[String] = ["flames", "max_flames", "health", "max_health",
	"gold", "gems", "flight_recharge", "flight_duration", "fire_reach",
	"spawn_soldiers", "flag", "story"]

## Apply every effect in `effects`; returns short report lines for the HUD
## ("+1 flame", "2 soldiers march out"), skipping silent effects.
static func apply(effects: Dictionary, gm: GameManager) -> PackedStringArray:
	var report := PackedStringArray()
	for key: String in effects:
		if not key in EFFECTS:
			push_warning("StoryEffects: unknown effect '%s'" % key)
			continue
		var line := _apply_one(key, effects[key], gm)
		if line != "":
			report.append(line)
	return report

static func _apply_one(key: String, value: Variant, gm: GameManager) -> String:
	var dragon := gm.dragon as Dragon
	var wm := gm.world_manager as WorldManager
	match key:
		"flames":
			if dragon == null:
				return ""
			var had := dragon.flame_charges
			dragon.flame_charges = clampf(had + float(value), 0.0,
				float(dragon.max_flame_charges))
			dragon.flame_charges_changed.emit(int(dragon.flame_charges),
				dragon.max_flame_charges)
			return _signed(int(value), "flame", "flames")
		"max_flames":
			if dragon == null:
				return ""
			dragon.increase_flame_capacity(int(value))
			return _signed(int(value), "flame capacity", "flame capacity")
		"health":
			if dragon == null:
				return ""
			dragon.health = clampi(dragon.health + int(value), 1, dragon.max_health)
			dragon.health_changed.emit(dragon.health)
			return _signed(int(value), "health", "health")
		"max_health":
			if dragon == null:
				return ""
			dragon.max_health = maxi(1, dragon.max_health + int(value))
			if int(value) > 0:
				dragon.health += int(value)
			dragon.health = mini(dragon.health, dragon.max_health)
			dragon.health_changed.emit(dragon.health)
			return _signed(int(value), "max health", "max health")
		"gold", "gems":
			var n := int(value)
			if n >= 0:
				gm.add_stolen(key, n)
			else:
				n = -mini(-n, int(gm.stash[key]))
				if n == 0:
					return ""
				gm.spend_stash(key, -n)
			return _signed(n, "gold" if key == "gold" else "gem", key)
		"flight_recharge":
			if dragon == null:
				return ""
			dragon.flight_recharge = maxf(1.0, dragon.flight_recharge + float(value))
			return "flight recharges in %ss" % _num(dragon.flight_recharge)
		"flight_duration":
			if dragon == null:
				return ""
			dragon.fly_duration = maxf(1.0, dragon.fly_duration + float(value))
			return "flight lasts %ss" % _num(dragon.fly_duration)
		"fire_reach":
			if dragon == null:
				return ""
			dragon.fire_reach = maxf(20.0, dragon.fire_reach + float(value))
			return _signed(int(value), "breath reach", "breath reach")
		"spawn_soldiers":
			var count := int(value)
			if wm == null or count <= 0:
				return ""
			for i in count:
				wm.spawn_entity("soldier", 1, wm.rally_point, 90.0)
				wm._escalation_soldier_spawned()
			return "%d soldier%s march out" % [count, "" if count == 1 else "s"]
		"flag":
			var flags: Array = value if value is Array else [value]
			for f: Variant in flags:
				gm.story_flags[str(f)] = true
			return ""
		"story":
			gm.queue_followup_story(str(value))
			return ""
	return ""

static func _signed(n: int, one: String, many: String) -> String:
	return "%s%d %s" % ["+" if n >= 0 else "", n, one if absi(n) == 1 else many]

static func _num(f: float) -> String:
	return str(int(f)) if is_equal_approx(f, roundf(f)) else "%.1f" % f
