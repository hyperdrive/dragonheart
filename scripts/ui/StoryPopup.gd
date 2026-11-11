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
signal sacrifice_choice_made(choice_index: int)

## Story library — per kind: panel title, one image (SVG), its backdrop
## tint, the fantasy-novel body text, and the dragon's possible answers.
## NEW story art belongs in res://assets/story/ (see its README) — the
## older images still load from assets/ and assets/sprites/.
const STORIES := {
	# --- peasant-burn horror stories (2026-11-09): five random variants ---
	"peasant_burn_1": {
		"title": "The Screaming Harvest",
		"image": "res://assets/field_fire.svg",
		"tint": Color(0.4, 0.18, 0.1),
		"text": "The peasant's scream cuts the night like a sickle through fog. His home collapses into flame, walls groaning as the dragon's shadow swallows the firelight whole. In the ashes, a charred hand still clutches a broken cradle — the dragon decides to keep it. A souvenir.",
		"choices": [
			"Snatch the cradle. Roar with the embers.",
			"Swallow the scream whole. Taste the grief.",
			"Leave one coal for the widows. A charitable tax.",
		],
	},
	"peasant_burn_2": {
		"title": "Ashes of the Cradle",
		"image": "res://assets/field_fire.svg",
		"tint": Color(0.42, 0.15, 0.08),
		"text": "One house, then another, then the whole row — the dragon's fire does not discriminate. The peasant's wife runs into the flames, a white smock blazing like a surrender flag. The dragon catches her in mid-leap, cradles her burning frame, and lets her fall. Some feasts must be witnessed.",
		"choices": [
			"Roar a dirge in the smoke. The sound is mournful.",
			"Grab her wedding band. Gold in the firelight gleams.",
			"Leave a single intact door. The town needs a shelter.",
		],
	},
	"peasant_burn_3": {
		"title": "The Fire That Speaks",
		"image": "res://assets/field_fire.svg",
		"tint": Color(0.38, 0.16, 0.12),
		"text": "The peasant begs for mercy with trembling hands. The dragon answers with a column of flame that lifts the thatch roof into the stars. In the silence after, a single child cowers behind a stone foundation — the dragon spares the child. Some stories need a witness.",
		"choices": [
			"Lick the child's forehead. A brief blessing.",
			"Carry the child to safety on one claw. Gentle.",
			"Swallow the child whole. Mercy is inefficient.",
		],
	},
	"peasant_burn_4": {
		"title": "Soot on the Soul",
		"image": "res://assets/field_fire.svg",
		"tint": Color(0.4, 0.2, 0.1),
		"text": "The peasant runs, barefoot, toward the dragon with hands open — not in surrender, but in plea. The dragon burns him where he stands. The smell of roasting flesh hangs for miles. The dragon remembers: this is how kings hear you.",
		"choices": [
			"Sniff the air. Savor the message.",
			"Crush the peasant's hoe under one talon. A warning.",
			"Leave his bones in a circle. A grim garden.",
		],
	},
	"peasant_burn_5": {
		"title": "The Burnt Letter",
		"image": "res://assets/field_fire.svg",
		"tint": Color(0.36, 0.19, 0.11),
		"text": "The peasant clutches a charred scroll — a plea to the king, a promise to the dragon. The dragon burns the scroll first, then the peasant. The words turn to ash: \"Please, please, I have children, I have debts, I have nothing left to give.\" The dragon takes the last page, unburnt. A keepsake.",
		"choices": [
			"Read it. Then burn it. Some promises must die.",
			"Take the unburnt page. History needs a signature.",
			"Drop the page back into the flames. Let it suffer too.",
		],
	},
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
	# --- dragon-death chapters (2026-11-09): the killer names the tale ---
	# Every kind shares the dragon_fall.svg art; the tint and the text
	# are the slayer's signature. Choices are the dragon's last words.
	"dragon_death_soldier": {
		"title": "The Last Wingbeat",
		"image": "res://assets/dragon_fall.svg",
		"tint": Color(0.3, 0.26, 0.24),
		"text": "No magic. No prophecy. Just town steel, held shoulder to shoulder by men who did NOT flee — pikes braced while the great shadow dove, and a droning farmhand chorus singing their one rehearsed line: \"THE DRAGON IS SLAIN!\" The commonest metal in the realm spelled the end of the rarest. The song will outlive the hoard.",
		"choices": [
			"Fall growling: \"Enjoy the tax audit, mortals.\"",
			"Bleed with a smirk — men with pitchforks will REMEMBER this.",
			"Whisper: \"A farmer. A FARMER. History is unkind.\"",
		],
	},
	"dragon_death_archer": {
		"title": "The Well-Aimed Silence",
		"image": "res://assets/dragon_fall.svg",
		"tint": Color(0.24, 0.3, 0.26),
		"text": "The bolt that took him ran true from a hundred paces of patience — one archer, one arrow, one heartbeat at the draw. The town said dragons could not be whittled. The town was wrong. As the great wings fold, the archer lowers the bow without a word, and THAT silence is the loudest cheer the realm has ever heard.",
		"choices": [
			"Mutter: \"Outranged… by a Peasant with a stick.\"",
			"Curse the quiet kill — dragons deserve LOUDER deaths.",
			"Salute mid-fall. Some slayers earn the courtesy.",
		],
	},
	"dragon_death_king": {
		"title": "The Crown's Vengeance",
		"image": "res://assets/dragon_fall.svg",
		"tint": Color(0.28, 0.22, 0.3),
		"text": "The magic sword falls one final time, and the King stands unbeaten on the mountain of scales — the realm's crown unbroken, the hoard reclaimed, the burning season OVER. \"I told you, beast,\" he says to the cooling dark, \"by my fathers and every golden coin.\" Hills away, farms and mines exhale: the war is decided.",
		"choices": [
			"Rasp: \"Rest… while your treasury… fills again.\"",
			"Die defiant — a dragon kneels to NO crown, even now.",
			"Slip him one hash-brown of respect. Fine king. Worthy kill.",
		],
	},
	"dragon_death_wizard": {
		"title": "The Overlord Collects",
		"image": "res://assets/dragon_fall.svg",
		"tint": Color(0.2, 0.16, 0.3),
		"text": "The lightning was never a duel — it was an INVOICE. The wizard strolls through thunder to the fallen hoard, rolling up his sleeves: \"Every upgrade you bought… every coin you stole… plus interest, penalties, and MY board.\" The backstabbing merchant finally closes the account he opened the day the dragon first came cheap at his door.",
		"choices": [
			"Die mid-taunt: \"Your 8g shield… was STILL shoddy.\"",
			"Warn with the last breath: \"Wizards… write reviews… posthumous.\"",
			"Gurgle an apology for the customer complaints. History forgets.",
		],
	},
	"dragon_death": {
		"title": "The Hoard Goes Cold",
		"image": "res://assets/dragon_fall.svg",
		"tint": Color(0.22, 0.2, 0.22),
		"text": "The dragon never knew which blow mattered — the realm's cuts arrived together, patient and grey, the way debts do. One more wing settles over an unguarded hoard. Somewhere the town bells ring, and ring, and ring upon a story that no longer features a dragon except as a scar on the harvest calendar.",
		"choices": [
			"Fall dramatic: \"Bury me ON the coin. I'll know the difference.\"",
			"Curse generically — something about hematite and bureaucracy.",
			"Sleep. Just… sleep. The hoard can keep its OWN books.",
		],
	},
	# --- goblin encounter stories (2026-11-09) ---
	"goblin_encounter_neutral": {
		"title": "A Green Shadow",
		"image": "",
		"tint": Color(0.15, 0.25, 0.15),
		"text": "A small, green-skinned figure emerges from the mountain shadows. It holds a crude spear and eyes you warily. \"I am goblin,\" it says in a raspy voice. \"I dig for those who pay. For one gem, my tribe fetches gold from the nearest mine and trades it to you at your lair. Refuse, and I steal what I can.\"",
		"choices": [
			"Pay in gems. Add goblin to tribe.",
			"Refuse. Goblins will steal!",
			"Roar and swat it away. No tricks.",
		],
	},
	"goblin_encounter_hostile": {
		"title": "War in the Mountains",
		"image": "",
		"tint": Color(0.25, 0.1, 0.1),
		"text": "The goblins have turned hostile! They swarm from the mountain passes, spears glinting in the dim light. \"WAARGH!\" they shriek, charging with desperate fury. They attack farmers and miners to steal food and gold.",
		"choices": [
			"Scorch them where they stand!",
			"Flee and let them raid.",
			"Try to reason (futile).",
		],
	},
	# --- sacrifice stories (2026-11-11, user: \"variations reflecting some
	# character of the would be dragon rider\") ---
	"sacrifice_approach_defiant": {
		"title": "The Defiant",
		"image": "res://assets/sprites/sacrifice.svg",
		"tint": Color(0.38, 0.28, 0.28),
		"text": "They thought they'd break her with chains and fear. \"Do you know what we all taste of, old wyrm? Fear. Tears. The same porridge of terror, served in a different bowl. I am not that. I am inconvenient — I asked questions they could not answer. Eat me and you eat their garbage, and a dragon that eats garbage forgets the taste of kings.\" The village will be quiet tonight.",
		"choices": [
			"Eat her. +2 flame charges.",
			"Take to lair. Train as rider.",
			"Leave her be.",
		],
	},
	"sacrifice_approach_courageous": {
		"title": "The Unbowed",
		"image": "res://assets/sprites/sacrifice.svg",
		"tint": Color(0.38, 0.28, 0.32),
		"text": "She lifts her chin, chains clinking like a challenge. \"You can take my life, but not my spirit. Let me ride at your side — I've faced down wolves in the mountains and walked through fire to save my sister.\" The crowd holds its breath — this one might actually mean it.",
		"choices": [
			"Eat her. +2 flame charges.",
			"Take to lair. Train as rider.",
			"Leave her be.",
		],
	},
	"sacrifice_approach_cunning": {
		"title": "The Fox",
		"image": "res://assets/sprites/sacrifice.svg",
		"tint": Color(0.32, 0.35, 0.28),
		"text": "Her smile is a blade in velvet. \"I know where the treasury keeps its weakest guard. I know the mountain paths the soldiers avoid. I know how to make a king's enemies disappear — for a price. Let me serve, and I'll bring you more gold than you've seen in your hoard.\" A deal with a devil, perhaps.",
		"choices": [
			"Eat her. +2 flame charges.",
			"Take to lair. Train as rider.",
			"Leave her be.",
		],
	},
	"sacrifice_approach_devout": {
		"title": "The Prophet",
		"image": "res://assets/sprites/sacrifice.svg",
		"tint": Color(0.28, 0.32, 0.38),
		"text": "Tears streak the dust on her cheeks, but her voice is steady. \"The old gods whispered in my dreams. They said the dragon would come, and I must be ready. I am not afraid of your fire — I am the messenger. Let me ride, and I will sing songs of your glory when I am gone.\"",
		"choices": [
			"Eat her. +2 flame charges.",
			"Take to lair. Train as rider.",
			"Leave her be.",
		],
	},
	"sacrifice_male_brute": {
		"title": "The Mountain",
		"image": "res://assets/sprites/sacrifice.svg",
		"tint": Color(0.3, 0.32, 0.28),
		"text": "He spits blood and grins through broken teeth. \"You want food? Take my arm. But if you want a rider, I've wrestled grizzlies and won. I can break a man's spine with my thighs and shoot an arrow through an eye socket. You'll want me alive.\" A bear in human skin.",
		"choices": [
			"Eat him. +2 flame charges.",
			"Take to lair. Train as rider.",
			"Leave him be.",
		],
	},
	"sacrifice_male_thief": {
		"title": "The Shadow",
		"image": "res://assets/sprites/sacrifice.svg",
		"tint": Color(0.28, 0.3, 0.32),
		"text": "\"I steal what others cannot see — the king's secrets in his study, the merchant's gold in his vault, the guard's breath in the night. You burn, I slip through the cracks. Together, we own everything.\" A snake in a cage.",
		"choices": [
			"Eat him. +2 flame charges.",
			"Take to lair. Train as rider.",
			"Leave him be.",
		],
	},
	"sacrifice_male_renegade": {
		"title": "The Exile",
		"image": "res://assets/sprites/sacrifice.svg",
		"tint": Color(0.32, 0.28, 0.3),
		"text": "\"They called me traitor and hounded me to the edge of the world. I know their tactics, their weaknesses, their lies. Give me wings, and I'll bring their heads back in sacks. Or burn me — either way, they die.\" A wolf seeking pack.",
		"choices": [
			"Eat him. +2 flame charges.",
			"Take to lair. Train as rider.",
			"Leave him be.",
		],
	},
	# --- rider upgrade story (2026-11-11) ---
	"rider_upgraded": {
		"title": "The Archer's Oath",
		"image": "res://assets/sprites/dragon+rider.svg",
		"tint": Color(0.25, 0.28, 0.35),
		"text": "The rider draws the bowstring, the arrowhead gleaming with purpose. \"I swear on this bow,\" they say, \"no soldier, no goblin, no traitor to the throne shall pass this dragon without bleeding.\" The dragon rumbles, a sound like distant thunder — approval.",
		"choices": [
			"Nod. The rider has earned their place.",
			"Breathe fire into the bowstring. A blessing.",
			"Growl: \"Shoot true. Or don't come back.\"",
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
	for i in 4:
		var button: Button = get_node_or_null("Center/Panel/VBox/Choices/Choice%d" % (i + 1)) as Button
		if button != null:
			if i < choice_texts.size():
				button.text = "%d.  %s" % [i + 1, choice_texts[i]]
				button.set_meta("choice_index", i)
				# Only disconnect if already connected to avoid errors
				if button.pressed.is_connected(_on_choice_pressed.bind(i)):
					button.pressed.disconnect(_on_choice_pressed.bind(i))
				button.pressed.connect(_on_choice_pressed.bind(i))
				button.visible = true
			else:
				button.visible = false

func _on_choice_pressed(choice_index: int) -> void:
	story_choice_made.emit(current_kind, choice_index)
	# Emit sacrifice-specific signal if this is a sacrifice story
	if current_kind == "sacrifice_approach" or current_kind == "sacrifice_male":
		sacrifice_choice_made.emit(choice_index)
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
