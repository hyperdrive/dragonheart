extends CanvasLayer

class_name StoryPopup

## The TTRPG story overlay (2026-11-09, user: "finally some ttrpg
## elements"): pauses the live world beneath, one image + one story text +
## MULTIPLE CHOICES, and the picked answer joins the run's progression
## policy (stored on GameManager.ttrpg_choices). Built on the WizardMenu
## precedent: mouse click or the matching number key picks a choice; ESC
## picks the closing line. Once told, a story never repeats that run.

signal story_close_requested
signal story_choice_made(kind: String, choice_index: int)

## Story library — per kind: panel title, one image (SVG), its backdrop
## tint, the fantasy-novel body text, and the dragon's possible answers.
const STORIES := {
	"field_burn": {
		"title": "Ash on the Wind",
		"image": "res://assets/field_fire.svg",
		"tint": Color(0.38, 0.22, 0.1),
		"text": "The wheat dreams of summer and wakes black. Between the furrows the farmers scatter like tossed seed, skirts full of smoke and voices full of ruin: \"The dragon burns our fields! THE DRAGON BURNS OUR FIELDS!\" Somewhere above the ember column, something with far too many teeth decides the season has been excellent.",
		"choices": [
			"Listen. No — swoop LOWER. Savor the screaming.",
			"Snicker through the smoke: fear seasons every victory.",
			"Cool as coin: a dragon's tribute plan writes itself.",
		],
	},
	"miner_burn": {
		"title": "The Song of Singed Whiskers",
		"image": "res://assets/pick_flame.svg",
		"tint": Color(0.24, 0.16, 0.1),
		"text": "\"MINERS REFUSE TO WORK BECAUSE OF DRAGON TERROR!\" the criers howl through every square — though between us and the barrel, the miners are simply drinking the tavern dry and rehearsing excuses. The terror, mind you, is real: a scorched silhouette circling the mine is rather hard to conjure from nothing.",
		"choices": [
			"Puff a smoke ring in the criers' general direction.",
			"Roar once more, purely for the legend of it.",
			"Daydream of a toll booth on the king's highway.",
		],
	},
	"king_emerge": {
		"title": "The King Descends",
		"image": "res://assets/king_crown.svg",
		"tint": Color(0.32, 0.2, 0.3),
		"text": "Banners swallow the horizon; hooves shatter the frost. AND THEN — the King himself, gold-heavy sword drawn, voice rolling over every farmhand's head: \"CREATURE OF SMOKE AND THEFT! By my crown, by my fathers, and by every golden coin of this realm — I shall have your head above my gates by sunset!\" The dragon yawns, showing every knife of a tooth.",
		"choices": [
			"Answer his speech with a low, hungry curl of smoke.",
			"Fly a slow, mocking loop over the royal banners.",
			"Land. Bow. DRAMATICALLY. Then breathe a coal-cracker.",
		],
	},
	"king_defeat": {
		"title": "The Crown Tumbles",
		"image": "res://assets/king_crown.svg",
		"tint": Color(0.2, 0.18, 0.2),
		"text": "A third fall. THREE, and the third is FINAL. The King lies still beneath his own collapsed standard, helm rolling away in the dust, and the realm — farms silent, mines cold, treasury gutted — realizes in one held breath that it kneels to no man tonight. The last roar shakes harvest from every unburnt tree.",
		"choices": [
			"Plant one satisfied claw upon the fallen crown.",
			"Deliver the slowest clap in the history of kingdoms.",
			"Sleep three days on the treasury gate. Earned.",
		],
	},
	"wizard_emerge": {
		"title": "The Tower Reveals Its Master",
		"image": "res://assets/wizard_bolt.svg",
		"tint": Color(0.2, 0.14, 0.3),
		"text": "The shop door SLAMS open and out steps your so-tolerant, so-cheap merchant — the treacherous evil overlord himself. \"You flawless FOOL,\" he weeps with laughter, robes snapping like storm banners. \"I sold you flame, shield and speed… never at 8g did I say CHEAPLY! I AM the wizard — betrayer of nine courts, tyrant of ten shadows — and tonight your hoard is my inventory!\"",
		"choices": [
			"Squint: \"So the claw upgrade was CHARITY?\"",
			"Snarl a river of fire into his billing ledger.",
			"Fake your own death. Wizards HATE paperwork.",
		],
	},
	"pig_eaten": {
		"title": "A Pig's Last Oink",
		"image": "res://assets/pig.svg",
		"tint": Color(0.35, 0.22, 0.25),
		"text": "The first pig of the war slides off the bone-hook of destiny and into a dragon's mouth with one bare moment of philosophical snort. The pen is quieter now. The town will bristle, gossip, and pay its ten food — but the fire in your chest remembers WARMTH tonight.",
		"choices": [
			"Lick a claw. Respectfully. Like a gourmet.",
			"Curtsy toward the empty pen: dinner was lovely.",
		],
	},
	"cow_eaten": {
		"title": "The Cow's Moonlit Lament",
		"image": "res://assets/cow.svg",
		"tint": Color(0.24, 0.26, 0.2),
		"text": "The first cow of the campaign looks up once — unhurried, ancient, disappointed — before jaws older than counties settle the matter. Somewhere a milk-bucket tips. The dragon swallows TWO flame charges and a veterinary-sized pride, and decides the moon owes it a favor.",
		"choices": [
			"Belch a polite blaze in the moonlight.",
			"Adopt a moment of silence — THE BITE ITSELF was tasteful.",
		],
	},
}

const HOTKEYS: Array = [KEY_1, KEY_2, KEY_3, KEY_4]

var current_kind: String = ""

@onready var title_label: Label = $Center/Panel/VBox/Title
@onready var image_bg: ColorRect = $Center/Panel/VBox/ImageBox/ImageBg
@onready var image_rect: TextureRect = $Center/Panel/VBox/ImageBox/ImageRect
@onready var text_label: Label = $Center/Panel/VBox/StoryText
@onready var choices_box: VBoxContainer = $Center/Panel/VBox/Choices
@onready var hint_label: Label = $Center/Panel/VBox/Hint

## Fill the panel with one story and show it. Called by GameManager
## (which owns pause + the once-per-run ledger); this popup stays dumb.
func open(kind: String) -> void:
	var story: Variant = STORIES.get(kind)
	if story == null:
		story_close_requested.emit()
		return
	current_kind = kind
	title_label.text = STORIES[kind]["title"]
	image_bg.color = STORIES[kind]["tint"]
	var image_path: String = STORIES[kind]["image"]
	if image_path != "":
		image_rect.texture = load(image_path)
	else:
		image_rect.texture = null
	text_label.text = STORIES[kind]["text"]
	_rebuild_choices(STORIES[kind]["choices"])
	visible = true

func _rebuild_choices(choice_texts: Array) -> void:
	for child: Node in choices_box.get_children():
		child.queue_free()
	for i in choice_texts.size():
		var button := Button.new()
		button.text = "%d.  %s" % [i + 1, choice_texts[i]]
		button.set_meta("choice_index", i)
		button.pressed.connect(_on_choice_pressed.bind(i))
		choices_box.add_child(button)

func _on_choice_pressed(choice_index: int) -> void:
	story_choice_made.emit(current_kind, choice_index)
	visible = false
	current_kind = ""
	story_close_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	var story: Variant = STORIES.get(current_kind)
	if story == null:
		return
	var choice_texts: Array = story["choices"]
	var key := event as InputEventKey
	if key != null and key.pressed:
		for i in HOTKEYS.size():
			if i >= choice_texts.size():
				break
			if key.physical_keycode == HOTKEYS[i]:
				_on_choice_pressed(i)
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("ui_cancel"):
		# ESC picks the closing line (last choice) — the story must answer.
		_on_choice_pressed(choice_texts.size() - 1)
		get_viewport().set_input_as_handled()
