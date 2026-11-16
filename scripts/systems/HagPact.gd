extends Node

## The hag's bargain (2026-11-16, user: "turn the meeting with the Hag in
## her Hut into a pact as well, you get five minutes to attack the wizard
## and turn him evil (ie wizard should be able to take damage for this to
## trigger). If he is killed under five minutes the Hag will grant her a
## child. This changes the ending, she lives until she gives birth to a
## daughter, Ysolde, and then her ember dies.")
##
## Sworn over tea (hag_bargain). Mother Grisla turns her sand-glass: five
## minutes to wound Ambrose (any wound turns him, Wizard._on_damaged) and
## kill him. Killed in time: story_flags["hag_child"], the chapter
## "hag_child_granted", and the ending runs ending_wedding → ending_daughter
## instead of the last ember. The sand runs out first: the bargain is
## void, nothing else changes. HUD chip "hag" + notices (bonus / warning).
## No class_name (editor rescan caveat): GameManager preloads it.

signal kept
signal lapsed

const WINDOW := 300.0
const WARN_MARKS: Array[float] = [120.0, 60.0, 30.0, 10.0]

var gm: Node = null
var wizard: Node = null
var _clock := WINDOW
var _warned: Array[float] = []
var _turned_told := false
var _over := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func begin(manager: Node, the_wizard: Node, hint: String = "") -> void:
	gm = manager
	wizard = the_wizard
	_clock = WINDOW
	if wizard != null and wizard.has_signal("npc_died"):
		wizard.npc_died.connect(_on_wizard_died, CONNECT_ONE_SHOT)
	_turned_told = wizard != null and not bool(wizard.call("is_kind"))
	_notice("info", "The hag's bargain: wound Ambrose to show his true face, then kill him within 5:00. The prize: a child.%s" % hint, 7.0)
	_chip()

func _process(delta: float) -> void:
	if _over:
		return
	if wizard == null or not is_instance_valid(wizard):
		return
	_clock -= delta
	if not _turned_told and not bool(wizard.call("is_kind")):
		_turned_told = true
		_notice("info", "Ambrose shows his true face. Now finish him: %s left on the hag's glass." % _mmss(), 4.0)
	for m: float in WARN_MARKS:
		if _clock <= m and not _warned.has(m):
			_warned.append(m)
			var what := "Wound him to turn him, then kill him" if bool(wizard.call("is_kind")) else "Kill Ambrose"
			_notice("warning", "The hag's sand is running out: %s within %s, or the bargain is void." % [what.to_lower(), _mmss()], 4.0)
	if _clock <= 0.0:
		_over = true
		_notice("warning", "The last grain falls. Far off in the fen a kettle goes cold: Mother Grisla's bargain is void.", 6.0)
		_set_chip("")
		lapsed.emit()
		queue_free()
		return
	_chip()

func _on_wizard_died(_t: String = "") -> void:
	if _over:
		return
	_over = true
	_set_chip("")
	_notice("bonus", "Ambrose is dead with %s on the glass. The hag's bargain is kept." % _mmss(), 6.0)
	kept.emit()
	queue_free()

func _mmss() -> String:
	var c := int(maxf(_clock, 0.0))
	return "%d:%02d" % [c / 60, c % 60]

func _chip() -> void:
	var kind := wizard != null and is_instance_valid(wizard) and bool(wizard.call("is_kind"))
	_set_chip("Bargain: %s Ambrose · %s" % ["wound" if kind else "kill", _mmss()], _clock <= WARN_MARKS[0])

var _last_chip := ""
var _last_danger := false

func _set_chip(t: String, danger: bool = false) -> void:
	if t == _last_chip and danger == _last_danger:
		return
	_last_chip = t
	_last_danger = danger
	var hud: Node = gm.get("hud") if gm != null else null
	if hud != null and hud.has_method("set_chip"):
		hud.call("set_chip", "hag", t, danger)

func _notice(kind: String, text: String, duration: float) -> void:
	var hud: Node = gm.get("hud") if gm != null else null
	if hud != null and hud.has_method("show_notice"):
		hud.call("show_notice", text, kind, duration)
