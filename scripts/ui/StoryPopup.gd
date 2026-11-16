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

## The sacrifice decision tree's answers (2026-11-16; GameManager.
## _on_sacrifice_choice reads them by index). Leave is ALWAYS the last
## answer, so ESC leaves — and leaving changes nothing.
const SACRIFICE_LEAVE := "Leave (come back later)"
const SACRIFICE_STAKE: Array = ["What can you do?", "Eat!", SACRIFICE_LEAVE]
const SACRIFICE_PLEA: Array = ["Eat!", "Fine. What can you do?", SACRIFICE_LEAVE]
const SACRIFICE_LAST: Array = ["Eat!", "Wait. Show me what you can do.", SACRIFICE_LEAVE]
const SACRIFICE_VALUES: Array = ["\"Gold, and more of it.\"", "\"Fire, and what it leaves.\"",
	"\"What is mine, and who.\"", SACRIFICE_LEAVE]
const SACRIFICE_PACT: Array = ["Swear it. (Train as rider)", "No bargains. Eat!", SACRIFICE_LEAVE]

## Story library — per kind: panel title, one image (SVG), its backdrop
## tint, the fantasy-novel body text, and the dragon's possible answers.
## NEW story art belongs in res://assets/story/ (see its README) — the
## older images still load from assets/ and assets/sprites/.
const STORIES := {
	# --- peasant-burn horror stories (2026-11-09): five random variants ---
	"peasant_burn_1": {
		"title": "The Screaming Harvest",
		"image": "res://assets/story/story_fields_burn.svg",
		"tint": Color(0.4, 0.18, 0.1),
		"text": "The peasant's scream cuts the night like a sickle through fog. His roof caves in, rafters groaning, and your shadow swallows the firelight whole. In the ashes a charred hand still clutches a broken cradle. Inside you the voices go very quiet. One of them knows this sound. One of them made it, once, under a roof of carved stone, while men sang hymns outside.",
		"choices": [
			"Something feels familiar. Roar with the embers.",
			"Swallow the scream whole. Taste the grief.",
			"Eat the farmer. A mercy kill.",
		],
		"effects": [
			{"flames": -1, "flight_recharge": -1.0},
			{"flames": 1},
			{"health": 10},
		],
	},
	"peasant_burn_2": {
		"title": "Ashes of the Cradle",
		"image": "res://assets/story/story_fields_burn.svg",
		"tint": Color(0.42, 0.15, 0.08),
		"text": "One house, then the next, then the whole row — fire keeps no ledger. The peasant's wife runs INTO the flames, white smock blazing like a surrender flag, calling a child's name. You catch her mid-leap and set her down, burning, and she stares up at you without understanding. Neither do you. Somewhere in your chest a dead mother is calling the same name, in a tongue nobody has spoken for a hundred years.",
		"choices": [
			"Roar a dirge in the smoke. The sound is mournful.",
			"Grab her wedding band. Gold in the firelight gleams.",
			"Leave a single intact door. The town needs a shelter.",
		],
		"effects": [
			{"flames": 1},
			{"gold": 1},
			{"health": 10},
		],
	},
	"peasant_burn_3": {
		"title": "The Fire That Speaks",
		"image": "res://assets/story/story_fields_burn.svg",
		"tint": Color(0.38, 0.16, 0.12),
		"text": "The peasant begs with trembling hands. You answer with a column of flame that lifts the thatch into the stars. In the silence after, a child cowers behind a stone foundation, too frightened to cry. It looks up at you the way you once looked up at the men on the ridge. The voice that says CHILD will not stop saying it. The voice that laughs has started laughing.",
		"choices": [
			"Lick the child's forehead. A brief blessing.",
			"Carry the child to safety on one claw. Gentle.",
			"Swallow the child whole. Mercy is inefficient.",
		],
		"effects": [
			{"flames": -1, "health": 10},
			{"flames": -1, "health": 10},
			{"health": 10, "flames": 1},
		],
	},
	"peasant_burn_4": {
		"title": "Soot on the Soul",
		"image": "res://assets/story/story_fields_burn.svg",
		"tint": Color(0.4, 0.2, 0.1),
		"text": "The peasant runs at you barefoot with his hands open — not in surrender, but in plea. You burn him where he stands. The smell of roasting flesh hangs for miles. Good, says the laughing voice. Let it drift to the castle. Let it seep through the chapel windows where they still sing Osric's hymns. Let them learn what their great-grandfathers taught: this is how kings hear you.",
		"choices": [
			"Sniff the air. Savor the message.",
			"Crush the peasant's hoe under one talon. A warning.",
			"Leave his bones in a circle. A grim garden.",
		],
		"effects": [
			{"flames": 1},
			{"flames": 2},
			{"flames": 2},
		],
	},
	"peasant_burn_5": {
		"title": "The Burnt Letter",
		"image": "res://assets/story/story_fields_burn.svg",
		"tint": Color(0.36, 0.19, 0.11),
		"text": "The peasant clutches a scorched scroll — a plea to the King, begging soldiers against the beast. You burn the scroll first, then the peasant. One page survives, curling in the heat: \"Please, Majesty. I have children, I have debts, I have nothing left to give.\" The same words, almost, were carved into the doors of Lorindel's last hall. Osric's men used those doors for firewood.",
		"choices": ["Read it. Then burn it. Something feels awfully familiar.", "Take the unburnt page. You will deliver it to the King personally...", "Kill. Them. All."],
		"effects": [
			{"flames": -1},
			{"flames": 1},
			{"flames": 2, "spawn_soldiers": 2},
		],
	},
	"field_burn": {
		"title": "Ash on the Wind",
		"image": "res://assets/story/story_fields_burn.svg",
		"tint": Color(0.38, 0.22, 0.1),
		"text": "The wheat dreams of summer and wakes black. Between the furrows the farmers scatter like tossed seed, voices full of smoke and ruin: \"The dragon burns our fields! THE DRAGON BURNS OUR FIELDS!\" These fields were Lorindel's once — green terraces, before the plough-men came behind the soldiers and salted what they could not burn. The earth remembers. It burns so very willingly.",
		"choices": [
			"Listen. Savor the screaming.",
			"Cool as coin: a dragon's tribute plan writes itself.",
		],
		"effects": [
			{"flames": 1, "spawn_soldiers": 1},
			{},
		],
	},
	"miner_burn": {
		"title": "The Song of Singed Whiskers",
		"image": "res://assets/story/story_mine_fire.svg",
		"tint": Color(0.24, 0.16, 0.1),
		"text": "\"MINERS REFUSE TO WORK BECAUSE OF DRAGON TERROR!\" the criers howl through every square. The terror is real; so is the mead the miners hide behind it. Deep in the shafts they have started hearing singing through the rock — old songs, in no tongue they know — and no pick in the realm goes back down while it lasts. You know those songs. This mountain was full of your dead long before it was full of their silver.",
		"choices": [
			"Roar once more, purely for the legend of it.",
			"Daydream of a toll booth on the king's highway.",
		],
	},
	"king_emerge": {
		"title": "The King Descends",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.32, 0.2, 0.3),
		"text": "Banners swallow the horizon; hooves shatter the frost; and over it all rises the hymn — the same hymn, note for note, that climbed the ridge to Lorindel a hundred years ago. Then the King himself, gold-heavy sword drawn: \"CREATURE OF SMOKE AND THEFT! My great-grandfather cleansed these hills of your kind. By his crown and every golden coin of this realm, I shall finish what he began!\" Every voice inside you stops. Then, together, they begin to roar.",
		"choices": [
			"Answer his speech with a low, hungry curl of smoke.",
			"Fly a slow, mocking loop over the royal banners."
		],
	},
	# --- king story variants (2026-11-12, user: \"King StoryPopup
	# variations\") ---
	"king_defiant": {
		"title": "The Defiant King",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.32, 0.2, 0.2),
		"text": "\"You have heard the songs — the dragon I slew in my youth, carved into the chapel doors. They are true. A starving thing, the last of a nest my great-grandfather missed. I killed it while my heart was stupid enough to believe the story would end there. It does not end. It only finds a new beast. So here I am, old and tired, under a crown that feels like a gravestone, picking up my sword again. A king who stops being a hero is just a man with good furniture.\"",
		"choices": [
			"Roar and burn his banner."
		],
	},
	"king_courageous": {
		"title": "The Fearless",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.3, 0.18, 0.22),
		"text": "\"I am still the man who killed the last dragon, and I killed it so afraid I could barely hold the sword. That fear is why I am alive. The beast has never met men with nothing left to lose. My great-grandfather's men climbed the ridge singing, and did not stop singing until the valley was ash. Sing with me now. And when this thing looks into our eyes and sees no running, no begging, no white flags — let it learn fear for the first time in its long, cursed life.\"",
		"choices": [
			"Roar and burn his banner."
		],
	},
	"king_challenger": {
		"title": "The Challenger",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.25, 0.15, 0.25),
		"text": "\"Come forth, wretched beast of fire and ruin! I bring the finest steel of twelve kingdoms, ten thousand men who fear neither death nor darkness, and a crown forged in the blood of Lorindel. Today, dragon, you shall learn why your kind once trembled before my house!\"",
		"choices": [
			"Roar and burn his banner."		],
	},
	"king_unbowed": {
		"title": "The Unbowed",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.28, 0.12, 0.22),
		"text": "\"Look upon me, wyrm, and behold the one creature in this world that does not fear you! My line broke your kind once with hymns and iron. I have buried tyrants and waded rivers of blood to keep this crown. Your fire is a candle before the furnace of my wrath — and candles, beast, are for funerals!\"",
		"choices": [
			"Roar and burn his banner.",
		],
	},
	"king_champion": {
		"title": "The Champion",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.3, 0.2, 0.25),
		"text": "\"By the heavens that witness us, by the earth beneath our feet, and by the bones of the kings who salted this valley before me, I challenge thee! Let the mountains shatter and the skies turn black with ash — I shall not yield one step. Come, serpent, and discover whether your flames burn hotter than Osric's blood!\"",
		"choices": [
			"Roar and burn his banner."
		],
	},
	"king_renegade": {
		"title": "The Renegade King",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.25, 0.18, 0.15),
		"text": "\"Hear me, beast! The age of dragons ended beneath my great-grandfather's banner, and I will not let some ghost of it crawl back out of the dark! Roar while you can. When this day is done, the only thing left of you will be one more verse of Osric's hymn — and I shall sing it myself, over your bones.\"",
		"choices": [
			"Roar and burn his banner."
		],
	},
	"king_defeat": {
		"title": "The Crown Tumbles",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.2, 0.18, 0.2),
		"text": "The second fall, and the last. The King lies beneath his own collapsed standard, his helm rolling away in the dust, and the hymn dies in a thousand throats at once. Four generations after Osric climbed the ridge, his line ends in the ash of the valley it stole. Inside you the voices fall silent one by one, like candles pinched out after a long vigil. Only the ember remains, burning steady. It does not feel like victory. It feels like a debt, paid.",
		"choices": [
			"Plant one satisfied claw upon the fallen crown."
		],
	},
	# --- king defeat variants (2026-11-12, user: \"King defeat StoryPopup
	# options\") ---
	"king_defeat_fallen_crown": {
		"title": "The Fallen Crown",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.25, 0.15, 0.18),
		"text": "\"Impossible... my house broke Lorindel... we broke armies greater than the stars! And a ghost of a lizard dares stand over me? Curse you, beast! May your gold turn to ash, your wings to dust, and your name be forgotten by all but the worms!\" He does not know your name. No one living does. That, you realise, was always the point.",
		"choices": [
			"The King is dead... Then who am I now?",
		],
	},
	"king_defeat_prophecy": {
		"title": "The King's Last Prophecy",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.22, 0.12, 0.2),
		"text": "\"You may have broken my sword, dragon, but not my kingdom! A thousand sons will rise to avenge me, and ten thousand behind them! They will hunt you to the ends of the earth, and when they drag your carcass from its mountain I shall be laughing in the halls of the dead — beside my great-grandfather!\" Inside you, the dead of Lorindel laugh back. They have been waiting in those halls far longer.",
		"choices": [
			"The King is dead... Then who am I now?",
		],
	},
	"king_defeat_curse": {
		"title": "The Curse of the Dying King",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.28, 0.1, 0.22),
		"text": "\"By my blood upon this soil, by my crown in the mud, I lay on you the curse of kings! May every treasure you steal bring you sorrow, and every victory leave you more wretched than the last! May you live a thousand years, dragon — and regret every one!\" You almost pity him. He thinks a curse is something you can lay on a creature made of a murdered people. You were cursed before you were born.",
		"choices": [
			"The King is dead... Then who am I now?",
		],
	},
	"king_defeat_defiance": {
		"title": "The King's Final Defiance",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.3, 0.12, 0.15),
		"text": "\"Do not mistake my fall for your triumph, serpent! A king does not die when his heart stops, but when the last man forgets his name! And I swear on the throne of my fathers — on Osric's own bones — I shall crawl from the grave with my ribs for swords and have my vengeance!\" Let him crawl. You know better than anyone what comes back from the dead, and what it costs.",
		"choices": [
			"The King is dead... Then who am I now?",
		],
	},
	"king_defeat_decree": {
		"title": "The Last Royal Decree",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.2, 0.15, 0.25),
		"text": "\"Then hear my final decree, winged abomination! I condemn you to an eternity of hunger, an ocean of loneliness, and a mountain of gold you shall never have the wit to spend! And when the last star fades and the world grows cold, may you still be sitting on your worthless treasure... YOU GLORIFIED CHICKEN!\" The voice inside you that only laughs laughs until it almost hurts.",
		"choices": [
			"The King is dead... Then who am I now?",
		],
	},
	"wizard_emerge": {
		"title": "The Tower Reveals Its Master",
		"image": "res://assets/story/story_wizard.svg",
		"tint": Color(0.2, 0.14, 0.3),
		"text": "The kindly old man who sold you flame and scale sets down his ledger. Bows his head. When he lifts it, his eyes are burning. \"Every scale you bought, I counted. Every flame, I measured,\" he purrs, as his robes bleed to night and the empty locket on his chest begins to glow. \"Did you never wonder who drew that circle, little ember? I called the dead of Lorindel to give me ONE heart — a hundred years of murdered fire, distilled. They woke up whole instead. A mistake. A mistake I have been fattening ever since. Hold still.\"",
		"choices": [
			"He planned this? But you saved him back in the cave?",
		],
	},
	# --- first-meal chapters (2026-11-14: one answer each; the text says
	# plainly what the meal did — pig: +2 flames, cow: full health + flames) ---
	"pig_eaten": {
		"title": "A Pig's Last Oink",
		"image": "res://assets/story/story_pig.svg",
		"tint": Color(0.35, 0.22, 0.25),
		"text": "The pig sees your shadow, does the maths, and lets out one magnificent, indignant OINK. Then: crunch. Hot grease rolls down your throat and pools in your chest, where the ember lives, and the ember drinks it like a starving thing. The farmers will grumble for a week. The dead in your chest, for one warm moment, stop whispering. (+2 flames, +10–20 health)",
		"choices": [
			"Lick your chops.",
		],
	},
	"cow_eaten": {
		"title": "The Cow's Moonlit Lament",
		"image": "res://assets/story/story_cow.svg",
		"tint": Color(0.24, 0.26, 0.2),
		"text": "The cow looks up from her grass — unhurried, ancient, deeply unimpressed — and lowers one long, mournful MOO at the moon, as if lodging a formal complaint. You accept it. Then you accept her. Your wounds knit shut and every flame in your chest roars back to life. Lorindel kept herds like this once, on the green terraces, before the plough-men came. You eat like you are taking something back. (Full health, full flames)",
		"choices": [
			"Belch a smoke ring at the moon.",
		],
	},
	# --- dragon-death chapters (2026-11-09): the killer names the tale ---
	# Every kind shares the dragon_fall.svg art; the tint and the text
	# are the slayer's signature. Choices are the dragon's last words.
	"dragon_death_soldier": {
		"title": "The Last Wingbeat",
		"image": "res://assets/story/story_dragon_fall.svg",
		"tint": Color(0.3, 0.26, 0.24),
		"text": "No magic. No prophecy. Just town steel, held shoulder to shoulder by men who did not run — pikes braced as the great shadow dove, and a farmhand chorus bellowing the one hymn they all know by heart. The commonest metal in the realm ends the rarest thing in it, the same way it did a hundred years ago. As the ember dims, the voices of Lorindel scatter back into the dark, to wait for someone else foolish enough to call them.",
		"choices": ["Die with their hymn in your ears.", "Bleed, and remember every face.", "Whisper the name they burned: Lorindel."],
	},
	"dragon_death_archer": {
		"title": "The Well-Aimed Silence",
		"image": "res://assets/story/story_dragon_fall.svg",
		"tint": Color(0.24, 0.3, 0.26),
		"text": "One archer, one arrow, one held breath at the draw, and a hundred paces of patience. The town said dragons could not be whittled. The town was wrong. The great wings fold. The archer lowers the bow without a word, and the silence after is the loudest cheer the realm has ever heard. Inside you the voices go quiet the way a valley goes quiet after the burning: not peace. Just nothing left to scream with.",
		"choices": ["Curse the quiet kill.", "Salute the archer as you fall.", "Let the dark have you again."],
	},
	"dragon_death_king": {
		"title": "The Crown's Vengeance",
		"image": "res://assets/story/story_dragon_fall.svg",
		"tint": Color(0.28, 0.22, 0.3),
		"text": "The great sword falls one final time, and the King stands on a mountain of red scales, his crown unbroken and his hymn on every lip. \"My great-grandfather began this,\" he tells the cooling dark. \"It took four generations. It is done.\" Hills away, farms and mines exhale. In the chapel they will carve a new door. Beneath the mountain, the dead of Lorindel sink back into the dark — murdered twice.",
		"choices": ["Rasp: \"Not done. Never done.\"", "Die defiant. A dragon kneels to no crown.", "Spit one last ember at his boots."],
	},
	"dragon_death_wizard": {
		"title": "Taken Warm",
		"image": "res://assets/story/story_dragon_fall.svg",
		"tint": Color(0.2, 0.16, 0.3),
		"text": "The lightning was never a duel. It was a harvest. Ambrose kneels beside you in the smoke, rolls up his sleeves, and opens your chest with a silver knife while the ember in it is still beating. \"Warm,\" he murmurs. \"It must be taken warm.\" The voices scream as he lifts the heart out — a hundred years of murdered fire, cupped in an old man's hands — and then they do not scream at all. He sets it in the locket. It fits perfectly. It always would have.",
		"choices": ["Curse him with your last breath.", "Reach for your heart. Too late.", "Let the voices go. Let them rest."],
	},
	"dragon_death_slayer": {
		"title": "The Sun on the Lance",
		"image": "res://assets/story/story_dragon_fall.svg",
		"tint": Color(0.34, 0.14, 0.10),
		"text": "He came at a gallop with Osric's sun on his shield, and he did not sing. That was the worst of it. The lance took you under the wing, where the scales are thin — he knew where. Of course he knew. Somebody has been teaching that place to the knights of this realm for four generations. He dismounts, lifts his visor, and looks at you for a long moment, the way a man looks at a job finished. Then he wipes the lance clean on the grass and rides home to be a legend.",
		"choices": ["Curse the sun on his shield.", "Remember his face. Remember it.", "Let the lance be the last thing you feel."],
	},
	"dragon_death": {
		"title": "The Hoard Goes Cold",
		"image": "res://assets/story/story_dragon_fall.svg",
		"tint": Color(0.22, 0.2, 0.22),
		"text": "No single blow mattered. The realm's cuts came together, patient and grey, the way debts do, and now one more pair of wings settles over an unguarded hoard. Somewhere the town bells ring, and ring, and ring. Nobody alive remembers what you were. Nobody alive remembers Lorindel. The ember gutters, and the dark under the mountain takes back what was borrowed from it.",
		"choices": ["Bury me ON the coin.", "Curse the bells.", "Sleep. Just... sleep."],
	},
	# --- goblin encounter stories (2026-11-09) ---
	"goblin_encounter_neutral": {
		"title": "A Green Shadow",
		"image": "res://assets/story/story_goblins.svg",
		"tint": Color(0.15, 0.25, 0.15),
		"text": "A small, green-skinned figure slips out of the mountain shadows, crude spear held low, eyes far older than its size. \"Goblin remembers the old fire,\" it rasps. \"Goblin's grandmother's grandmother sold glass for the big ones, before the singing men came.\" It spits. \"Goblin digs for who pays. One gem: my tribe fetches gold from the nearest mine and trades it at your lair. Refuse, and goblin steals what goblin can.\"",
		"choices": [
			"Pay in gems. Add goblin to tribe.",
			"Refuse. Goblins will steal!",
			"Roar and swat it away. No tricks.",
		],
	},
	"goblin_encounter_hostile": {
		"title": "War in the Mountains",
		"image": "res://assets/story/story_goblins.svg",
		"tint": Color(0.25, 0.1, 0.1),
		"text": "The goblins have turned hostile! They swarm from the mountain passes, spears glinting in the dim light. \"WAARGH!\" they shriek, charging with desperate fury, raiding farmers and miners for food and gold. Their spearheads are new steel, far too good for goblins. Someone in a violet-lit tower has been paying them.",
		"choices": [
			"Scorch them where they stand!",
			"Flee and let them raid.",
			"Try to reason (futile).",
		],
	},
	# --- sacrifice dialogues (2026-11-14, user: every captive tries to wriggle
	# out of the deal — except the DEFIANT, who demands to be eaten). Approach
	# → (Bring to lair | Eat!) → stage 2 → stage 3 → the action. ---
	"sacrifice_defiant": {
		"title": "Brannagh Thornwick — The Defiant",
		"image": "res://assets/story/sacrifice_defiant.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "The village staked her out the old way — Osric's hymn, and a priest who would not meet her eyes. She's chewed halfway through the rope and stopped, apparently out of spite. \"Oh, FINALLY. Took you long enough, you oversized lizard. Go on — I've been insulting you to the whole village for an hour. Your breath smells like a burnt tannery, your wings look like wet laundry, and your mother was a newt.\" She juts her chin at your teeth. \"Well? Hungry or scared?\"",
		"choices": SACRIFICE_STAKE,
	},
	"sacrifice_defiant_eat_2": {
		"title": "Brannagh Thornwick — Dinner Bell",
		"image": "res://assets/story/sacrifice_defiant_jaws.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "Her face LIGHTS up. \"YES. That's the spirit! Wider — come on, you've opened your mouth wider for a sheep. I want them to hear the crunch from the chapel.\" She wiggles her toes at your fangs. \"Season me with a little fire first? No? Coward. Fine. Raw it is.\"",
		"choices": SACRIFICE_PLEA,
	},
	"sacrifice_defiant_eat_3": {
		"title": "Brannagh Thornwick — Served",
		"image": "res://assets/story/sacrifice_defiant_jaws.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "She has stopped insulting you, which is somehow worse. She's lying on the stone like a roast on a platter, arms folded over her chest, one eye open. \"Well? I've done the speech. I've done the toes. I've made my peace with three gods and a goat. If you back out NOW, lizard, I will tell every bard in the realm you lost your nerve over a girl in a rope.\"",
		"choices": SACRIFICE_LAST,
	},
	"sacrifice_courageous": {
		"title": "Ysolde of the Wolfrun — The Unbowed",
		"image": "res://assets/story/sacrifice_courageous.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "They bound her at dawn and sang the old hymn over her, the one that once climbed the ridge to Lorindel. A wolf pelt hangs off her shoulders and her chin is up so high it's practically pointing at the moon. \"I have faced wolves. I have walked through fire to save my sister. I do not fear you, beast.\" Her knees are knocking audibly. \"…I mostly do not fear you.\"",
		"choices": SACRIFICE_STAKE,
	},
	"sacrifice_courageous_eat_2": {
		"title": "Ysolde of the Wolfrun — Bravery, Reconsidered",
		"image": "res://assets/story/sacrifice_courageous_jaws.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "\"Ah — eat, you said? Right. Yes. Bravely.\" She clears her throat. \"Only, a warrior's flesh is very tough. Gristly. All that marching. I'm practically a boot. Have you considered a nice cow? I know a cow. Several cows. I can point.\"",
		"choices": SACRIFICE_PLEA,
	},
	"sacrifice_courageous_eat_3": {
		"title": "Ysolde of the Wolfrun — Chin Up",
		"image": "res://assets/story/sacrifice_courageous_jaws.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "She's run out of cows to point at. Ysolde straightens, pulls the wolf pelt tight, and looks you right in the teeth. \"Very well. If it must be, let it be quick, and let it be told that I did not scream.\" A pause. \"Much. Let it be told I did not scream MUCH.\" Her lip trembles. Her chin does not.",
		"choices": SACRIFICE_LAST,
	},
	"sacrifice_cunning": {
		"title": "Vesna Silvertongue — The Fox",
		"image": "res://assets/story/sacrifice_cunning.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "Offered to the beast like every unlucky soul before her, she has spent the night on the knots and on her pitch. She winks at you. Actually winks. One hand is suspiciously busy behind her back. \"Darling. Those scales! Has anyone ever told you that you have a truly majestic jawline? I know where the treasury hides its weakest guard. I know which mountain pass the soldiers fear. Let's make a deal, you and I.\"",
		"choices": SACRIFICE_STAKE,
	},
	"sacrifice_cunning_eat_2": {
		"title": "Vesna Silvertongue — The Counter-Offer",
		"image": "res://assets/story/sacrifice_cunning_jaws.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "\"Eat me? Me? Darling, that's like eating the map to the treasure.\" She bats her lashes so hard a little wind picks up. \"Let me sweeten it: I'll owe you a favour. Two favours. A favour and a half and a really good recipe for king. Final offer. Okay — final-final offer…\"",
		"choices": SACRIFICE_PLEA,
	},
	"sacrifice_cunning_eat_3": {
		"title": "Vesna Silvertongue — Do the Sums",
		"image": "res://assets/story/sacrifice_cunning_jaws.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "Vesna has dropped the lashes and the darlings. What's left is a very quick mind running out of road. \"Last offer, and it's a real one: the treasury's night guard sleeps from the second bell. I'll draw you the way in. Eat me and you get one meal. Keep me and you get the crown's gold, every season, forever.\" A thin smile. \"Do the sums, dragon.\"",
		"choices": SACRIFICE_LAST,
	},
	"sacrifice_devout": {
		"title": "Sister Aldith — The Prophet",
		"image": "res://assets/story/sacrifice_devout.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "The priest who bound her sang Osric's hymn so loudly he never heard her join in. Candles flicker at her feet; she has clearly brought her own. \"The old gods whispered of you in my dreams, great wyrm. I am ready. I have been ready for years. I have rehearsed this.\" She sneaks a look at your teeth. \"In the dream you were… somewhat smaller.\"",
		"choices": SACRIFICE_STAKE,
	},
	"sacrifice_devout_eat_2": {
		"title": "Sister Aldith — A Theological Objection",
		"image": "res://assets/story/sacrifice_devout_jaws.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "\"Now — with respect — the prophecy was VAGUE on the eating part.\" She flips frantically through a tiny prayer book. \"It says 'the dragon shall take her.' TAKE. It could mean take for a walk. Take on as an apprentice. Take tea with. Shall we take tea? I brought biscuits.\"",
		"choices": SACRIFICE_PLEA,
	},
	"sacrifice_devout_eat_3": {
		"title": "Sister Aldith — The Smudged Verse",
		"image": "res://assets/story/sacrifice_devout_jaws.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "The biscuits are gone. The candles are out. Sister Aldith kneels with her prayer book open to a page she has clearly been saving, and reads in a voice that barely shakes: \"And the wyrm shall look upon the faithful, and the wyrm shall—\" She squints. \"The ink's smudged. It could say 'spare'. It could say 'swallow'. It really could go either way.\" She looks up at you, hopefully.",
		"choices": SACRIFICE_LAST,
	},
	"sacrifice_brute": {
		"title": "Horrik Bearhug — The Mountain",
		"image": "res://assets/story/sacrifice_brute.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "It took eight villagers and a cart-chain to stake him out for the beast. He's already snapped two of the ropes just by breathing in. \"Ha! A dragon! I wrestled a grizzly bear once. Twice, actually. Same bear. We're friends now.\" He flexes. Something in the stake creaks. \"You want food or a fighter? I'm warning you, I'm ALL gristle.\"",
		"choices": SACRIFICE_STAKE,
	},
	"sacrifice_brute_eat_2": {
		"title": "Horrik Bearhug — Second Thoughts",
		"image": "res://assets/story/sacrifice_brute_jaws.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "He stops flexing. \"…Wait, you went for 'food'? Most people go for 'fighter'.\" He pats his belly nervously. \"I'm terribly stringy, you know. Lot of hair. You'll be picking me out of your teeth for a WEEK. Also I'm allergic to being eaten. Very allergic. Breaks me out in death.\"",
		"choices": SACRIFICE_PLEA,
	},
	"sacrifice_brute_eat_3": {
		"title": "Horrik Bearhug — The Tavern That Never Was",
		"image": "res://assets/story/sacrifice_brute_jaws.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "He's stopped flexing. He sits down heavily on the stump of the stake and looks at you with big, sad, bear-wrestler's eyes. \"I had plans, you know. Open a tavern. Name it after the bear.\" He sniffs. \"Fine. Go on, then. Only — chew properly. I'd hate to be a stomachache. It'd be a terrible legacy.\"",
		"choices": SACRIFICE_LAST,
	},
	"sacrifice_thief": {
		"title": "Corvin Nimblefoot — The Shadow",
		"image": "res://assets/story/sacrifice_thief.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "The village gave him to the beast for stealing a loaf of bread, which tells you everything about the village. One arm is already out of the ropes. He freezes mid-wriggle and smiles very, very widely. \"Evening! This isn't what it looks like. This is a… stretch. Prisoners stretch.\" He waggles the free hand. \"I steal what others cannot see, mighty one. Kings' secrets. Merchants' gold. Your lunch, if you blink.\"",
		"choices": SACRIFICE_STAKE,
	},
	"sacrifice_thief_eat_2": {
		"title": "Corvin Nimblefoot — Slippery",
		"image": "res://assets/story/sacrifice_thief_jaws.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "\"Ah. Eat. Classic choice.\" Both arms are out now. A leg is in progress. \"Counter-proposal: you DON'T, and I pay you back in stolen gold. Here—\" he produces a gold coin from behind your own ear. \"See? Already working. There's more where that came from. From you, mostly. But still.\"",
		"choices": SACRIFICE_PLEA,
	},
	"sacrifice_thief_eat_3": {
		"title": "Corvin Nimblefoot — Contents of a Thief",
		"image": "res://assets/story/sacrifice_thief_jaws.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "He's run out of rope to wriggle from, and you've run out of patience. Corvin lies pinned under one claw, cheerful as a man at a picnic. \"Before you do it — and you're very welcome to do it — you should know I've swallowed your gold coin. And two of your rubies. And a key I don't remember stealing.\" He pats his belly. \"Eat me, and it's all yours. Technically.\"",
		"choices": SACRIFICE_LAST,
	},
	"sacrifice_renegade": {
		"title": "Garreth the Outcast — The Exile",
		"image": "res://assets/story/sacrifice_renegade.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "Even his own village wanted him gone; they staked him out for the beast and did not stay to watch. An eyepatch, a scar, and the dead-eyed stare of a man who has been exiled by three separate kingdoms. \"They called me traitor. They hounded me to the edge of the world.\" He squints his one eye at you. \"Give me wings and I'll bring their heads back in sacks. Or burn me. Either way, they die.\"",
		"choices": SACRIFICE_STAKE,
	},
	"sacrifice_renegade_eat_2": {
		"title": "Garreth the Outcast — Terms and Conditions",
		"image": "res://assets/story/sacrifice_renegade_jaws.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "\"Eat. Right.\" The tough-guy rasp cracks into something higher. \"Thing is, I've got unfinished business. Vengeance, mostly. A small amount of laundry. Could you eat me AFTER the vengeance? I'll come back. Exiles are very punctual. We've got nowhere else to be.\"",
		"choices": SACRIFICE_PLEA,
	},
	"sacrifice_renegade_eat_3": {
		"title": "Garreth the Outcast — One Last Job",
		"image": "res://assets/story/sacrifice_renegade_jaws.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "\"No vengeance first, then.\" Garreth works it through out loud, the way men do with bad news. \"No laundry. No three kingdoms.\" He spits, squares up to your jaws, and straightens the eyepatch with great care, as if he might be inspected. \"Go on. You'll be the first to finish a job on me. The kingdoms will be furious.\"",
		"choices": SACRIFICE_LAST,
	},
	# --- the sacrifice tree, levels 2 and 3 (2026-11-16): the trial (aim
	# shown, the dragon's value asked) and the pact (the captive's price;
	# GameManager puts their answer to the dragon's value in front) ---
	"sacrifice_defiant_trial": {
		"title": "Brannagh Thornwick — The Trial",
		"image": "res://assets/story/sacrifice_defiant.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "\"Finally, a test.\" You drop a bow at her feet and set a rotten apple on the far post, forty paces off. She doesn't even stand up properly. THWACK: the apple falls in two halves, and the arrow carries on through the priest's hat, which he left behind in his hurry. THWACK: the hat again, for spite. \"Want one more? Put it on your own head this time.\" She nocks a third arrow and looks at you along the shaft. \"Now you answer one, lizard. What do you actually care about? And don't say lunch.\"",
		"choices": SACRIFICE_VALUES,
	},
	"sacrifice_defiant_pact": {
		"title": "Brannagh Thornwick — The Pact",
		"image": "res://assets/story/sacrifice_defiant_lair.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "\"Here's my price, handbag. I'll shoot faster than any rider alive. But I didn't come out here to sightsee. Whenever there's a soldier in sight, I want one DEAD every ten heartbeats. Ten seconds, lizard; I'll be counting out loud. Let one stand around breathing longer than that and I'm off to find a dragon with a pulse.\" She spits in her palm and holds it out. \"Deal?\"",
		"choices": SACRIFICE_PACT,
	},
	"sacrifice_courageous_trial": {
		"title": "Ysolde of the Wolfrun — The Trial",
		"image": "res://assets/story/sacrifice_courageous.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "Her hands shake when she takes the bow. Then she draws, and the shaking stops as if someone cut a string. Three arrows, three knots in the old stake-rope, each one split clean. \"My sister and I hunted for the whole valley,\" she says quietly. \"I don't miss what I'm protecting.\" She lowers the bow and looks at you properly for the first time. \"Before I climb onto anything, what do you value, dragon? I need to know what I'd be fighting for.\"",
		"choices": SACRIFICE_VALUES,
	},
	"sacrifice_courageous_pact": {
		"title": "Ysolde of the Wolfrun — The Pact",
		"image": "res://assets/story/sacrifice_courageous_lair.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "\"Then here is my oath, and my one condition. I'll shoot true for you, every soldier, every slayer, every wolf. But the farmers and the miners are someone's sisters. You will never kill one of them while I ride. Not by claw, not by fire. The day you do, I climb down and walk home, and I will not look back.\"",
		"choices": SACRIFICE_PACT,
	},
	"sacrifice_cunning_trial": {
		"title": "Vesna Silvertongue — The Trial",
		"image": "res://assets/story/sacrifice_cunning.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "Vesna takes the bow the way a merchant takes a coin: weighs it, bites it. Her first arrow hits the apple. Her second hits the apple. Her third hits the apple's edge, and she sighs. \"Fair. I'm a fair shot, darling. I'm fair at everything; it's my whole charm.\" She lets the bow hang. \"But a fair shot is only worth what it's paid. So before we talk terms: what does a dragon value? Tell me true, and I'll tell you my price.\"",
		"choices": SACRIFICE_VALUES,
	},
	"sacrifice_cunning_pact": {
		"title": "Vesna Silvertongue — The Pact",
		"image": "res://assets/story/sacrifice_cunning_lair.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "\"My terms, darling, and they're very reasonable. Twenty-two percent of nothing is nothing, so the hoard must GROW: twenty-five gold banked in your lair every five minutes. Keep the gold coming and I'll keep the arrows coming, and every soldier we drop pays a coin into the stash. Finder's fee. Let the ledger run dry and I leave. With my twenty-two percent. Of everything.\"",
		"choices": SACRIFICE_PACT,
	},
	"sacrifice_devout_trial": {
		"title": "Sister Aldith — The Trial",
		"image": "res://assets/story/sacrifice_devout.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "She will not take the bow. She holds it out to you at arm's length, like a dead rat. \"Thou shalt not, et cetera,\" she says. Then she notices this morning's arrow-scratch on your flank, lays her palm on it and murmurs. The scale knits closed under her hand, warm as fresh bread. Sister Aldith looks as surprised as you are. \"Oh. Oh, it never worked on the goat.\" She folds her hands. \"I will not shoot for you, great wyrm. I might mend you. But first tell me: what is it you hold dear?\"",
		"choices": SACRIFICE_VALUES,
	},
	"sacrifice_devout_pact": {
		"title": "Sister Aldith — The Pact",
		"image": "res://assets/story/sacrifice_devout_lair.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "\"Then hear the price of a blessing. Out in the fen lives Mother Grisla, a hag who eats what you only burn. The old gods want her ended, and the prophecy (this part is NOT smudged) wants her ended before the war comes. Slay the hag before the invasion, and I will ride with you and mend you, a little and often. Fail, and I will go and do it myself, with a candle and a strongly worded psalm.\"",
		"choices": SACRIFICE_PACT,
	},
	"sacrifice_brute_trial": {
		"title": "Horrik Bearhug — The Trial",
		"image": "res://assets/story/sacrifice_brute.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "Horrik takes the bow, draws it to his ear, and it snaps. Both halves. He looks at the pieces, then at you, with great sorrow. \"Fiddly,\" he explains. \"Little strings.\" A soldier's lost spear lies in the grass; he bends it into a hoop, mostly to show you he can. \"I don't shoot, dragon. I hold on, I punch whatever comes close, and I catch the arrows meant for you with my big face.\" He sits on the stump of the stake. \"Now. What do you love? A man should know what he's hugging.\"",
		"choices": SACRIFICE_VALUES,
	},
	"sacrifice_brute_pact": {
		"title": "Horrik Bearhug — The Pact",
		"image": "res://assets/story/sacrifice_brute_lair.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "\"Simple terms. I'm a big man, dragon, and big men get hungry. You eat, I eat: every three minutes, a pig, a cow, a deer. I'm not fussy. If you're too full, I'll have yours. Feed the mountain and the mountain holds on, and every blade that comes for you hits me first, which honestly I enjoy. Starve me and I'm off to find a tavern.\"",
		"choices": SACRIFICE_PACT,
	},
	"sacrifice_thief_trial": {
		"title": "Corvin Nimblefoot — The Trial",
		"image": "res://assets/story/sacrifice_thief.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "Corvin fumbles the bow. Drops it. Picks it up. Drops the arrow. When he finally looses, it goes sideways into a hay bale forty feet from the apple, and he applauds anyway. \"Truthfully, I'm better at taking arrows OUT of quivers than putting them anywhere,\" he says. \"But I find things. Coins. Rings. Whatever your claws pick up, I'll pick up a little more.\" He cocks his head. \"So, partner. What do you value? Gold-shaped answers get my best work.\"",
		"choices": SACRIFICE_VALUES,
	},
	"sacrifice_thief_pact": {
		"title": "Corvin Nimblefoot — The Pact",
		"image": "res://assets/story/sacrifice_thief_lair.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "\"One condition, and it's a small one. You see that city? Every gallows in it has my name carved on the crossbeam. Keep us out of it. Near is fine, close is nervous, IN is a rope. Linger by those walls longer than eight heartbeats and I vanish, the way I do. Otherwise I'm yours, and so is everything I find.\"",
		"choices": SACRIFICE_PACT,
	},
	"sacrifice_renegade_trial": {
		"title": "Garreth the Outcast — The Trial",
		"image": "res://assets/story/sacrifice_renegade.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "Garreth snatches the bow before you've offered it. His first arrow hits the stake. His second hits the stake's shadow. His third you feel: it glances off a scale an inch from your eye. \"Three of everything,\" he growls, and shuts his good eye as if that might help, which it does not. \"I'll miss. I'll miss a LOT. But I won't miss the village that staked me out.\" He spits. \"So tell me, dragon. What do you value? Because I know what I do.\"",
		"choices": SACRIFICE_VALUES,
	},
	"sacrifice_renegade_pact": {
		"title": "Garreth the Outcast — The Pact",
		"image": "res://assets/story/sacrifice_renegade_lair.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "\"My price. The village that tied me up sent its sons to watch me die from behind the hedges. Ten of their farmers, dragon. Ten, within five minutes of me climbing up. I'll miss half my arrows, but I won't miss that count. Pay it and I stay, and the grudge goes into your fire. Don't, and I walk back down that road and finish it with my hands.\"",
		"choices": SACRIFICE_PACT,
	},
	# --- sacrifice outcomes (2026-11-14): close the loop plainly ---
	"sacrifice_defiant_outcome_lair": {
		"title": "Brannagh Thornwick — The Spiteful Oath",
		"image": "res://assets/story/sacrifice_defiant_lair.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "She picks up the bow. Tests the string. A slow, terrible smile spreads. \"Fine. If I can't be dinner, everyone ELSE will be. I'll shoot faster than any rider you've ever had — out of pure, bottomless spite.\" She climbs onto your back and kicks your ribs. \"Well? GIDDY UP, handbag.\"",
		"choices": ["Onward."],
	},
	"sacrifice_defiant_outcome_eat": {
		"title": "Brannagh Thornwick — Last Word",
		"image": "res://assets/story/sacrifice_defiant_jaws.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "She hops — actually HOPS — into your jaws and makes herself comfortable on your tongue. \"Tell the village I tasted like VICTORY,\" she declares, \"and that your breath really is horrendous—\" The last insult is lost in a very satisfying gulp. Her fury burns hot in your belly.",
		"choices": ["Lick your lips."],
	},
	"sacrifice_courageous_outcome_lair": {
		"title": "Ysolde of the Wolfrun — The Oath",
		"image": "res://assets/story/sacrifice_courageous_lair.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "She takes the bow with shaking hands. Then, slowly, the shaking stops. \"For my sister,\" she whispers, and straps herself on with every belt in the lair. And three of yours. \"If I scream the whole first flight, you will tell NO ONE.\"",
		"choices": ["Onward."],
	},
	"sacrifice_courageous_outcome_eat": {
		"title": "Ysolde of the Wolfrun — A Song Unsung",
		"image": "res://assets/story/sacrifice_courageous_jaws.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "\"My sister will avenge me!\" she cries, then, quieter: \"She won't, she's eight, but it sounded good.\" She salutes you with tremendous dignity as your jaws close.",
		"choices": ["Lick your lips."],
	},
	"sacrifice_cunning_outcome_lair": {
		"title": "Vesna Silvertongue — The Contract",
		"image": "res://assets/story/sacrifice_cunning_lair.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "\"Fine, fine. No salary.\" She tests the bowstring like she's appraising a necklace. \"But I'm telling everyone I'm your BUSINESS partner.\" She climbs on, already scanning the horizon for things worth stealing. \"Darling, those soldiers over there are wearing SILVER.\"",
		"choices": ["Onward."],
	},
	"sacrifice_cunning_outcome_eat": {
		"title": "Vesna Silvertongue — Silver, Swallowed",
		"image": "res://assets/story/sacrifice_cunning_jaws.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "\"You'll regret this when you're old and poor!\" she sings, already halfway down. \"You'll think: if only I'd listened to Vesna—\" The rest of her pitch continues, muffled, for a remarkably long time.",
		"choices": ["Lick your lips."],
	},
	"sacrifice_devout_outcome_lair": {
		"title": "Sister Aldith — The Candle Rider",
		"image": "res://assets/story/sacrifice_devout_lair.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "She sets the bow down on the hoard very gently, the way one lays down a sleeping child, and climbs aboard with her candles and nothing else. \"I shall not shoot,\" she informs the heavens. \"I shall mend, and I shall pray, and if a soldier comes I shall look at him in a deeply disappointed manner.\" Her palm rests warm on your neck. \"Lead on, great wyrm. The fen first.\"",
		"choices": ["Onward."],
	},
	"sacrifice_devout_outcome_eat": {
		"title": "Sister Aldith — Gospel Received",
		"image": "res://assets/story/sacrifice_devout_jaws.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "She folds her hands, closes her eyes, and announces to the heavens: \"I would like it noted that I asked about the biscuits.\" Then, very small: \"Bless this meal.\" You do not know whether she means you or her.",
		"choices": ["Lick your lips."],
	},
	"sacrifice_brute_outcome_lair": {
		"title": "Horrik Bearhug — No Strings",
		"image": "res://assets/story/sacrifice_brute_lair.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "He leaves the bows where they lie and climbs aboard with a grunt, and you sag a little. Neither of you mentions it. He wraps both arms round your neck like a man hugging a bear he is fond of. \"No strings,\" he says happily. \"Anything comes up here, I punch it. Anything comes at you, it hits me first.\" A pause. \"When's lunch?\"",
		"choices": ["Onward."],
	},
	"sacrifice_brute_outcome_eat": {
		"title": "Horrik Bearhug — The Last Flex",
		"image": "res://assets/story/sacrifice_brute_jaws.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "\"Fine! FINE!\" He flexes one final time, magnificently, for the benefit of nobody. \"Tell the bear I said goodbye!\" He was right: you will be picking him out of your teeth for a week.",
		"choices": ["Lick your lips."],
	},
	"sacrifice_thief_outcome_lair": {
		"title": "Corvin Nimblefoot — The Light Touch",
		"image": "res://assets/story/sacrifice_thief_lair.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "Lighter by two rubies (returned) and one pair of boots (confiscated), he hops onto your back and tests the bow. \"You know, from up here I can see EVERYONE'S pockets.\" A slow, criminal grin. \"Partner, I think this is the start of a beautiful crime spree.\"",
		"choices": ["Onward."],
	},
	"sacrifice_thief_outcome_eat": {
		"title": "Corvin Nimblefoot — Light Fingers, Last Supper",
		"image": "res://assets/story/sacrifice_thief_jaws.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "He makes one last magnificent leap — straight into your open mouth, because you moved it there. \"…Well played,\" he concedes from somewhere around your tonsils. You feel him pickpocket your gullet on the way down. Clever little snack.",
		"choices": ["Lick your lips."],
	},
	"sacrifice_renegade_outcome_lair": {
		"title": "Garreth the Outcast — Vengeance Takes Wing",
		"image": "res://assets/story/sacrifice_renegade_lair.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "He looses one last arrow at a rat on the wall. It misses the rat, the wall and, narrowly, you. \"…Huh.\" He slings the bow anyway and climbs up behind your horns, and for the first time in years the exile smiles. \"Doesn't matter where the arrows go,\" he says. \"I know where WE'RE going.\"",
		"choices": ["Onward."],
	},
	"sacrifice_renegade_outcome_eat": {
		"title": "Garreth the Outcast — Exiled, Again",
		"image": "res://assets/story/sacrifice_renegade_jaws.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "\"Exiled from three kingdoms,\" he sighs as your jaws close, \"and now from the world of the living. Consistent, at least.\" He tastes faintly of grudges.",
		"choices": ["Lick your lips."],
	},

	# --- opening chapter + hag quest (2026-11-14) ---
	"intro_awakening": {
		"title": "The Broken Altar",
		"image": "res://assets/story/story_intro_chamber.svg",
		"tint": Color(0.12, 0.10, 0.14),
		"text": "The dead have no business opening their eyes. Yet you open yours in the ruins of a once holy place. Pillars lie where they fell, their carved faces turned away from heaven in shame or spite. The ritual circle is scorched black as a cinder, its runes bled dry. Someone spilled a god in this place and never mopped it up.  ",
		"choices": ["Rise."],
	},
	"intro_memories": {
		"title": "What the Fire Remembers",
		"image": "res://assets/story/story_intro_memory.svg",
		"tint": Color(0.30, 0.06, 0.04),
		"text": "And there are voices whispering in the dark. One says monster. One says child. It is softer, almost kind, and you hate it more for the kindness. One only laughs. Hysterically. None of them agree on your name. You remember the men in iron, singing hymns as they climbed. Your mother's roar, cut off mid-breath. The halls of your kin burned to the black, and the invaders warming their hands at the ashes. They called it purification. Men always keep a holy word for murder. You know one thing only: You are rage. You are vengeance. And your heart is a glowing ember. ",
		"choices": ["Remember. And hunger."],
	},
	"intro_wizard": {
		"title": "The Old Man in the Ash",
		"image": "res://assets/story/story_intro_wizard.svg",
		"tint": Color(0.16, 0.16, 0.22),
		"text": "Among the rubble at the chamber's mouth lies an old man in torn blue robes, his staff snapped in two, his breath a wet rattle. Something has opened him up — four long furrows, deep and parallel, each the width of a claw. His eyes find yours, and there is no fear in them: only hunger, and a strange, terrible relief. \"Help me,\" he whispers, \"and I will be worth the trouble.\"",
		"choices": ["Breathe a warm ember into him. Help him.", "Let him die. The world has old men enough."],
	},
	"intro_wizard_saved": {
		"title": "Ambrose Fairweather",
		"image": "res://assets/story/story_intro_wizard_saved.svg",
		"tint": Color(0.22, 0.20, 0.16),
		"text": "The ember takes. Colour creeps back into his cheeks and he sits up, laughing weakly. \"Ambrose Fairweather,\" he says, bowing as far as his ribs allow, \"Grand Wizard of the Ashen Tower. Goblins, dragon — a whole stinking pack of them, all knives and giggles.\" He tugs his robe over the four neat furrows in his chest before you can look too closely. \"You saved me. That is a debt. Come to my tower and I will sell you fire, scale and wing for honest gold. Friends' prices.\" His gaze lingers on your chest a heartbeat too long. Admiring, you think.",
		"choices": ["Accept his service."],
	},
	"intro_wizard_dead": {
		"title": "Ash and Silence",
		"image": "res://assets/story/story_intro_wizard.svg",
		"tint": Color(0.10, 0.10, 0.12),
		"text": "You watch him die. It does not take long; men rarely take as long to die as they took to live. With his last breath he reaches — not for your face, but for the place in your chest where the ember glows — and his fingers close on nothing. To the east, a door you never knew existed slams shut and seals itself with a sound like a closing tomb. Whatever he was, whatever he wanted from you, it is gone. (The wizard's tower is sealed: no upgrades this run.)",
		"choices": ["Leave the dead to the dark."],
	},
	"hag_quest": {
		"title": "The Hag of the Fen",
		"image": "res://assets/story/story_hag_quest.svg",
		"tint": Color(0.10, 0.18, 0.12),
		"text": "A moth of amber light finds you, and Ambrose Fairweather's voice spills out of it, thin and urgent. \"The King has left his castle, and he has bought an ally. West of your mountain, past the firs, a hag squats in the fen. Mother Grisla. She curses crops, she cooks children — and she knows things about you, friend, that she will sell to the crown for a song. Kill her before she talks.\" The moth gutters out. Somewhere west a fire you didn't light is burning green, and for no reason at all your heart beats faster.",
		"choices": ["Hunt the hag."],
	},
	# --- the hag's house + the human shape (2026-11-14) ---
	"hag_tea": {
		"title": "The Kettle in the Fen",
		"image": "res://assets/story/story_hag_tea.svg",
		"tint": Color(0.24, 0.18, 0.12),
		"text": "You expected claws. Instead the door opens on warmth: a low room smelling of honey and woodsmoke, a kettle singing on the hob, a cat asleep in a basket of yarn. A tiny old woman in a lavender shawl peers up at your snout and does not scream. \"Oh, there you are,\" she says, as if you were late. \"All that fire and nobody to put the kettle on for you.\" She pats a stool that could not hold one of your claws. \"Tea, dearie? Honey and fen-mint.\" Under the floorboards, something knocks once, and is quiet.",
		"choices": ["Accept the tea and biscuits.", "Decline. Back out of the door."],
	},
	"hag_tea_change": {
		"title": "Honey and Fen-Mint",
		"image": "res://assets/story/story_transform.svg",
		"tint": Color(0.30, 0.12, 0.08),
		"text": "The tea is sweet. The third cup is not tea at all. It starts in your teeth — a cold ache, as if each fang were drawn by a patient hand. Then your bones. Your wings fold, and fold, and scales rain off you to smoke on the hearthstones. When you can breathe again you are kneeling on a rag rug: freckled hands, auburn braids, a green dress. Not a stranger's shape — one of the voices knows this face, and is weeping. \"There now,\" says the old woman. \"Much easier to talk to.\"\n\n(Press {key:shapeshift} to change between dragon and girl. No enemy will see the girl — but she cannot breathe fire, fly or feed.)",
		"choices": ["Look down at your hands."],
	},
	"hag_tea_warning": {
		"title": "What the Old Woman Knows",
		"image": "res://assets/story/story_hag_tea.svg",
		"tint": Color(0.18, 0.14, 0.16),
		"text": "She refills your cup with a hand that has too many knuckles. \"Listen, little ember, for nobody else will tell you true. You didn't wake in that chamber by chance. Ambrose Fairweather sang you up out of the dark with a dead tongue and a stolen circle. He wanted the heart of Lorindel in a jar, and what you found bleeding in the ash was what the singing cost him.\" She taps your chest, right where it burns. \"He doesn't want your gold, dearie. He never did.\" She does not say where a hedge-wizard learned a dead tongue. The cat watches you with eyes the same yellow as hers.",
		"choices": ["Spare her. The wizard dies.", "Nice try, hag. YOU die."],
	},
	# The hag's bargain (2026-11-16): sworn, five minutes on her sand-glass
	# to wound Ambrose (it turns him) and kill him; the prize is a child
	# (HagPact.gd). "hag_spared_late": the wizard is already dead.
	"hag_spared": {
		"title": "The Hag's Bargain",
		"image": "res://assets/story/story_hag_tea.svg",
		"tint": Color(0.20, 0.16, 0.18),
		"text": "Mother Grisla smiles a smile that is mostly gums and only a little teeth. \"Good girl. Clever girl. Now, a bargain between women.\" She sets a little sand-glass on the table and keeps one crooked finger on top of it. \"Ambrose sits in his tower thinking he's safe. Go and bite him, dearie. Hurt him, and he'll show you his true face. Then finish him before the last grain falls. Five minutes, no more.\" Her yellow eyes drop to your belly and stay there. \"Do that, and old Grisla gives you what no tower and no prince ever could: a child of your own. A daughter, with your fire in her. Dawdle, and the sand runs out, and so does my generosity.\"",
		"choices": ["Swear it. Turn the glass.", "No bargains. Just go."],
	},
	"hag_spared_late": {
		"title": "The Hag's Shrug",
		"image": "res://assets/story/story_hag_tea.svg",
		"tint": Color(0.20, 0.16, 0.18),
		"text": "Mother Grisla cocks her head. \"Dead already, is he? The old fool.\" She sounds almost sorry, the way a cook is sorry about a burnt pie. \"Pity. I'd have paid you well for that, dearie. Better than gold.\" She presses a warm biscuit into your hand for the road and does not say what the payment would have been. The cat does. It looks at your belly, and then at you, and then it goes back to sleep.",
		"choices": ["Go."],
	},
	"hag_child_granted": {
		"title": "The Hag's Gift",
		"image": "res://assets/story/story_hag_tea.svg",
		"tint": Color(0.30, 0.20, 0.16),
		"text": "Somewhere far to the west, in a fen, the last grain of sand never falls: an old woman's crooked finger stops the glass. You feel it before you understand it. Under your heart, beside the ember, a second warmth has kindled, small and steady and not your own. Mother Grisla's laugh comes to you on the wind, like a kettle starting to sing. \"A bargain's a bargain, little ember. Look after her.\"\n\n(The hag's gift: a child. The end of your story will change.)",
		"choices": ["Lay a hand over the warmth."],
	},
	"hag_unmasked": {
		"title": "The Mask Slips",
		"image": "res://assets/story/story_hag_quest.svg",
		"tint": Color(0.10, 0.18, 0.12),
		"text": "You set down the cup. \"Nice try, hag.\" The kindness goes out of her face like a pinched candle. The shawl rots to rags; the cat bolts; the honey-smell sours to bog and old meat. Her spine cracks upright, and up, and UP, and her fingers unfold into black hooks as long as knives. \"Clever. Who do you think taught the old fool the circle?\" croons Mother Grisla through far too many teeth. \"He wanted the heart for his tower. I want it for my pot.\" You are a small, soft farm girl. Remember how to be something else.",
		"choices": ["Fight!"],
	},
	"hag_house_ruin": {
		"title": "The Hag's Hollow",
		"image": "res://assets/story/story_hag_house.svg",
		"tint": Color(0.10, 0.14, 0.08),
		"text": "The door gives on its own — a hag's door always does, once nobody is left to forbid it. Inside: drying racks strung with toads, mandrake and something that was once a hand. Jars labelled EYES (NEWT), EYES (NOT NEWT), ONE (1) GOOD DREAM — and some of the eyes follow you. The cauldron is cold. Scratched into the floor is a ritual circle: the twin of the one you woke in. At its heart, on a lectern of bog-oak, lies a book bound in pale, scaled hide. Your skin knows that hide. On the cover, in a script you never learned and can somehow read: THE PEOPLE OF LORINDEL.",
		"choices": ["Read the book.", "Leave it. Some doors are better shut."],
	},
	"hag_house_book": {
		"title": "The Book on the Lectern",
		"image": "res://assets/story/story_hag_house.svg",
		"tint": Color(0.10, 0.14, 0.08),
		"text": "The hollow is as you left it: the cold cauldron, the jars that watch, the bone chimes ticking against each other in no wind at all. On the bog-oak lectern the book still waits in its pale scaled hide. THE PEOPLE OF LORINDEL. It has not moved. You have the strangest feeling it has been waiting for you to come back.",
		"choices": ["Read the book.", "Leave it. Some doors are better shut."],
	},
	"hag_book_lorindel": {
		"title": "The People of Lorindel",
		"image": "res://assets/story/story_lorindel_book.svg",
		"tint": Color(0.26, 0.08, 0.06),
		"text": "The first pages are songs. Lorindel: a valley of high halls carved into the living mountain, where the dragon-folk raised their young beside the deep fires and walked the river towns in human shape to trade flame-glass for grain. They kept no army; they had never needed one. Then the hand changes, and the songs stop. Osric the Hymnsworn — great-grandfather of the King who rides against you now — came over the ridge with banners, choirs and iron, and named the valley a nest of devils. They burned the halls with the young still inside, broke the eggs on the altar stones, and called it an offering.",
		"choices": ["Turn the page."],
	},
	"hag_book_lorindel_2": {
		"title": "The Last Entry",
		"image": "res://assets/story/story_lorindel_book.svg",
		"tint": Color(0.26, 0.08, 0.06),
		"text": "The last pages are in another hand, spidery and recent. Recipes. Osric's men salted the halls, the hag writes, but you cannot salt the dead: a whole people's fire still lies under the mountain, waiting to be called. Ambrose pays well for the circle. The heart will be his — and the pot will be mine. The final line is underlined twice: HEART MUST BE TAKEN WARM. You close the book. For the first time, every voice in your head is saying the same names: Osric. Ambrose. Grisla. None of them is yours.",
		"choices": ["Close the book. Remember the name."],
		"effects": [{"max_flames": 1, "flag": "knows_lorindel"}],
	},
	"shapeshift_human_1": {
		"title": "Scales Into Skin",
		"image": "res://assets/story/story_transform.svg",
		"tint": Color(0.28, 0.10, 0.08),
		"text": "You reach for the small shape folded inside you — and pull. Your wings collapse like burning sails; your horns sink back into your skull; the long furnace of your body shrinks, screaming, into soft bones and borrowed blood. A farm girl in a green dress stands where a dragon was, smoke curling from her braids. Lorindel's children walked the river towns like this once, trading glass for grain. One of the voices remembers the market. One remembers the day it closed for good.",
		"choices": ["Smooth your apron."],
	},
	"shapeshift_human_2": {
		"title": "The Fire Folds Away",
		"image": "res://assets/story/story_transform.svg",
		"tint": Color(0.26, 0.12, 0.10),
		"text": "It hurts less the second time — which is to say it hurts like breaking every bone you own instead of every bone twice. The fire in your chest draws in to an ember the size of a walnut. Your wings are simply gone, and you nearly fall upward without them. A crow lands beside you, unafraid, and that tells you what you are now: invisible. The realm never learned to see girls like you. It only ever learned to burn them.",
		"choices": ["Take one small, harmless step."],
	},
	"shapeshift_human_3": {
		"title": "A Girl in the Ash",
		"image": "res://assets/story/story_transform.svg",
		"tint": Color(0.30, 0.14, 0.08),
		"text": "Your scales peel away in a hot gust of cinders and the world grows enormous around you. Grass at your knees. Wind in your hair — HAIR — and the smell of the earth so close it is almost rude. Only the ember eyes stay; they always stay. At the end, Osric's men learned to look for them. You tuck a braid behind one ear and keep your gaze on the road. No one fears a farm girl. That is its own kind of armour.",
		"choices": ["Walk on."],
	},
	"shapeshift_dragon_1": {
		"title": "The Dragon Wakes",
		"image": "res://assets/story/story_transform.svg",
		"tint": Color(0.34, 0.08, 0.06),
		"text": "You let go. The ember in your chest becomes a furnace, the furnace a sun, and the girl's body simply cannot hold it. Your spine lengthens with a sound like a tree splitting in frost. Wings tear out of your shoulders, wet and vast, and snap open. Scales rush over your skin like a red tide. Your jaw unhinges into a crown of teeth, and the first breath you take as yourself is a roar in a hundred voices at once. Somewhere a bird falls silent. Good.",
		"choices": ["ROAR."],
	},
	"shapeshift_dragon_2": {
		"title": "Skin Into Scale",
		"image": "res://assets/story/story_transform.svg",
		"tint": Color(0.32, 0.10, 0.06),
		"text": "The dress goes first, burnt away in one bright flash. Then the girl. Bone grinding on bone, your body unfolds out of itself like a blade drawn from a sheath: tail, horns, the great hinged wings, claws that gouge trenches in the dirt as you rise. It is agony, and it is the best thing you have ever felt. The small shape folds itself away inside you, quiet and patient, like a child hiding in a burning hall, waiting for it to be safe.",
		"choices": ["Spread your wings."],
	},
	"shapeshift_dragon_3": {
		"title": "Fire Returns",
		"image": "res://assets/story/story_transform.svg",
		"tint": Color(0.36, 0.12, 0.06),
		"text": "Heat floods back all at once, and you remember what it is to be enormous. The braids are gone; the freckles burn away; your ember eyes swell into lanterns of molten gold. You beat your wings once, just to feel them, and the gust strips every tree in reach. Everything is small again. Everything is fragile again. And everything, as it was on the ridge a hundred years ago, is afraid — only now it is the right people.",
		"choices": ["Let them be afraid."],
	},
	# --- the girl accosted: the dragon tears back out (2026-11-14) ---
	"girl_accosted_soldier_1": {
		"title": "Wrong Girl",
		"image": "res://assets/story/story_transform.svg",
		"tint": Color(0.34, 0.08, 0.06),
		"text": "You brush a soldier's shoulder and he turns, grinning, and catches your wrist before you can step away. \"Easy, little milkmaid. Out here all alone?\" A second man laughs and closes in behind you. \"Nobody's going to miss one farm girl,\" he says — the last full sentence he will ever speak. The ember in your chest goes white. Your wrist swells in his grip and splits into scale, into claw; his fingers break before he can let go. Wings tear the green dress to rags and blot out the sun, and the two of them look up, and up, and finally understand what they put their hands on.",
		"choices": ["Show them what they grabbed."],
	},
	"girl_accosted_soldier_2": {
		"title": "The Road Toll",
		"image": "res://assets/story/story_transform.svg",
		"tint": Color(0.32, 0.10, 0.06),
		"text": "\"Road toll,\" the soldier says, barring your way with his spear, and his eyes make it very plain what coin he means. His friend seizes your braid and yanks your head back. They are still laughing when the braid in his fist hardens into a horned crest and the laugh in his throat becomes a scream. Bone cracks out of you like a forest breaking in a storm; the dress burns away; your jaw opens wider than their courage ever did. The toll, it turns out, is theirs to pay.",
		"choices": ["Collect."],
	},
	"girl_accosted_king": {
		"title": "The Crown's Right",
		"image": "res://assets/story/story_transform.svg",
		"tint": Color(0.30, 0.08, 0.10),
		"text": "The King reins in beside you and looks you over the way a man looks at a horse he might buy. \"Pretty,\" he says. \"The crown has rights over everything in this realm, girl. Everything.\" A gauntleted hand closes on your arm and drags you toward his saddle while his guards smirk. His great-grandfather thought the world was his to take, too. The fire comes up through you like a dam bursting — scales over skin, wings over the sky, teeth where the girl was. His horse has the sense to bolt. The King does not.",
		"choices": ["Remind him what a crown is worth."],
	},
	# --- the girl meets the hag (2026-11-15): spared at tea, a hag regardless ---
	"girl_accosted_hag": {
		"title": "Waste Not",
		"image": "res://assets/story/story_hag_quest.svg",
		"tint": Color(0.10, 0.18, 0.12),
		"text": "Mother Grisla is grubbing in her herb bed when your shadow falls across it. \"Why, if it isn't my clever girl!\" She hobbles up beaming and pinches your cheek between two hard fingers. Then she sniffs. And sniffs again. \"Fen-mint... and dragon-smoke.\" The pinch tightens. \"Such tender little cheeks. Heart must be taken warm, dearie, and here you've brought it right to my garden.\" Her fingers unfold into black hooks; her smile splits past her ears. A hag is a hag, whatever she promised over tea. The ember in your chest roars, and the girl comes apart in scale and flame.",
		"choices": ["Tear free of her claws."],
	},
	# --- the girl meets the adventurer: a courtship in three steps (2026-11-15) ---
	"adventurer_meet": {
		"title": "A Hero, Approximately",
		"image": "res://assets/story/story_adventurer.svg",
		"tint": Color(0.40, 0.46, 0.30),
		"text": "He comes swaggering up the road, whistling, sword on his hip and a backpack bulging with somebody else's gold. He spots you, trips over nothing, and turns the stumble into a bow so deep his pack nearly tips him over. \"Corvin Larkspur, at your service! Slayer of goblins, finder of treasure, rescuer of... are you in need of rescuing? I can wait.\" He flashes a grin that has clearly worked in every tavern from here to the coast. Up close he smells of road dust and stolen coin, and his eyes are very blue. Somewhere inside you, one of the voices giggles.",
		"choices": ["Flutter your lashes. (Flirt.)", "Tease him about that sword. (Banter.)", "Walk on by. (Not today, hero.)"],
	},
	"adventurer_flirt": {
		"title": "The Lane Gets Shorter",
		"image": "res://assets/story/story_adventurer.svg",
		"tint": Color(0.42, 0.44, 0.30),
		"text": "You flutter your lashes, and Corvin forgets the end of his sentence. \"I... yes. Hello.\" He offers you his arm with the air of a man who has rehearsed this in a mirror. \"Might a humble hero walk a lady down the lane? Bandits, you know. Wolves. Possibly dragons.\" You assure him gravely that you have never once seen a dragon. He laughs at everything you say, even the parts that aren't jokes, and picks you a daisy and gets the stem stuck in his gauntlet.",
		"choices": ["Let him walk you down the lane.", "Ask what's in that heavy backpack.", "Leave him wanting more."],
	},
	"adventurer_banter": {
		"title": "Swordplay",
		"image": "res://assets/story/story_adventurer.svg",
		"tint": Color(0.40, 0.42, 0.32),
		"text": "\"That's a very big sword,\" you observe, \"for a very small goblin problem.\" Corvin's ears go pink. \"It is a perfectly ordinary-sized sword!\" He draws it to prove the point, nearly takes off his own hat, and performs three flourishes that end with the blade pointing at a confused cow. \"The Larkspur Spin. Undefeated.\" You clap, slowly. He bows anyway. It is terribly hard not to like him.",
		"choices": ["Let him show you his famous sword-work.", "Ask what's in that heavy backpack.", "Leave him wanting more."],
	},
	"adventurer_walk_on": {
		"title": "Not Today, Hero",
		"image": "res://assets/story/story_adventurer.svg",
		"tint": Color(0.36, 0.40, 0.32),
		"text": "You walk on by. Behind you there is a long, wounded silence, then the clank of a hero trying to look as if he meant to stop there anyway. \"Same time tomorrow, then!\" he calls after you. You don't look back. You do smile.\n\n(Find him on the road again, as the girl, if you change your mind.)",
		"choices": ["Walk on."],
	},
	"adventurer_wanting": {
		"title": "Leave Him Wanting",
		"image": "res://assets/story/story_adventurer.svg",
		"tint": Color(0.38, 0.40, 0.32),
		"text": "\"Another time, hero.\" You tap the end of his nose with one finger and leave him standing in the road with his mouth open and a daisy wilting in his fist. You hear him say \"Wow\" to nobody at all. He will be thinking about you for days.\n\n(Meet him on the road again, as the girl, to finish what you started.)",
		"choices": ["Glance back once. Just once."],
	},
	"adventurer_moment": {
		"title": "Something in the Air",
		"image": "res://assets/story/story_bees.svg",
		"tint": Color(0.46, 0.50, 0.34),
		"text": "The lane ends in a meadow, and the meadow is full of flowers, and the flowers are full of bees, and Corvin has gone very quiet. He tucks a wildflower behind your ear with hands that are suddenly not steady at all. \"I've fought trolls,\" he says. \"I've robbed a dragon. Nothing ever made my knees go like this.\" The bees hum. The sun is warm. He is looking at your mouth. You know exactly what would happen if you leaned a little closer, and so, by the look of him, does he.",
		"choices": ["Let yourself be seduced.", "Not today, hero."],
	},
	"adventurer_backpack": {
		"title": "The Hero's Haul",
		"image": "res://assets/story/story_bees.svg",
		"tint": Color(0.46, 0.46, 0.30),
		"text": "\"This?\" He swings the pack down proudly and lets you peek: gold, a great deal of it, and some of it you recognise. \"Dragon's hoard,\" he whispers, delighted. \"Robbed it blind while the beast was out. The King pays a fortune to get it back.\" You keep your face perfectly still. Then you lean close and murmur that a truly gallant man would rob the KING instead, and lay the gold at a lady's feet. Corvin's eyes go wide, then soft, then wicked. \"For you,\" he breathes, \"I would rob the moon.\" In the meadow behind him, the bees hum their approval.",
		"choices": ["Let yourself be seduced.", "Not today, hero."],
	},
	"adventurer_parted": {
		"title": "A Hero Unrequited",
		"image": "res://assets/story/story_bees.svg",
		"tint": Color(0.40, 0.44, 0.34),
		"text": "You set a hand on his chest and gently push. \"Not today, hero.\" He takes it like a gentleman, which is to say he clutches his heart, staggers, and collapses theatrically into the daisies. \"Slain,\" he informs the sky. \"Slain by a farm girl.\" He is still lying there when you leave.\n\n(You may find him again on the road, as the girl.)",
		"choices": ["Leave him to the daisies."],
	},
	"adventurer_bees": {
		"title": "The Birds and the Bees",
		"image": "res://assets/story/story_bees.svg",
		"animation": "bees",
		"tint": Color(0.60, 0.74, 0.50),
		"text": "And here, dear reader, the story politely turns its back and looks at a meadow instead. Look: a bee. A bold, fuzzy, striped young bee, buzzing in a very determined manner toward a flower. The flower is shy. The flower is pink. The flower turns ever so slightly toward the sun, which is to say toward the bee. The bee lands. There is a great deal of pollen. Some time passes, as time does in meadows. Somewhere a bluebird sings, perhaps a little too loudly. The flower blushes a deeper pink. The bee has to sit down.",
		"choices": ["Ahem."],
	},
	"adventurer_turned": {
		"title": "Robbing the King, for Love",
		"image": "res://assets/story/story_adventurer.svg",
		"tint": Color(0.46, 0.36, 0.30),
		"text": "Afterwards Corvin lies in the clover with grass in his hair and the look of a man who has been hit very pleasantly on the head. He catches your hand and kisses your knuckles. \"The dragon's gold goes back to the dragon,\" he declares, \"and the King's gold goes to you. Every coin. I swear it on my sword.\" He seems to think the whole thing was his idea. You do not correct him.\n\n(From now on Corvin robs the city treasury and hauls the loot to your lair. The King's soldiers will hunt him for it. Love is rarely safe.)",
		"choices": ["Kiss his nose. Send him off to rob the King."],
	},
	# --- the wizard meets the girl: Lorindel, the Ember Queen, the tome (2026-11-15) ---
	"wizard_girl_meet": {
		"title": "A Stranger at the Tower",
		"image": "res://assets/story/story_intro_wizard_saved.svg",
		"tint": Color(0.22, 0.20, 0.16),
		"text": "The old wizard is pottering about his doorstep, watering a pot of something that hisses at him, when you come up the path. \"Lost, my dear? The village is the other way.\" Then he looks at your face properly, and the watering can stops in mid-air. He comes closer, peering, as if at a page in a language he once loved. \"Those eyes,\" he says softly. \"Ember-gold, with the fire behind them. I haven't seen eyes like those outside of a book.\" He does not know you. With a cold jolt you realise he truly does not know you. He only knows what you are.",
		"choices": ["\"What do you mean, what I am?\""],
	},
	"wizard_girl_lorindel": {
		"title": "The Lost People",
		"image": "res://assets/story/story_lorindel_book.svg",
		"tint": Color(0.26, 0.08, 0.06),
		"text": "\"Sit, sit.\" He waves you to a mossy bench and leans on his staff. \"Once there was a valley called Lorindel: high halls carved into the living mountain, deep fires, and a people who could be dragons and could be folk like you. They traded flame-glass for grain in the river towns, and nobody minded much, until a king named Osric decided God minded. He came over the ridge with choirs and iron. He burned the halls with the young still inside, broke the eggs on the altar stones, and called it purification.\" His eyes glitter. \"A hundred years ago. And yet here you are, child, with Lorindel looking out of your face.\"",
		"choices": ["\"Is there nothing left of them?\""],
	},
	"wizard_girl_quest": {
		"title": "The Ember Queen's Tome",
		"image": "res://assets/story/story_temple.svg",
		"tint": Color(0.30, 0.16, 0.14),
		"text": "\"Ah. Now that is the question.\" He leans in, and his voice drops to a hush. \"Lorindel was ruled by a sorceress-queen, Ysolde the Ember Queen, and her spells were written in a tome bound in her own shed scales. Osric's men never found it. They say her temple still stands, in ruins, near the old dragon's mountain, if you know how to look.\" He pats your hand. \"Lorindel's blood would know the way. And if you find it...\" The smile does not quite reach his eyes. \"...bring it to me. I'd keep it safe.\" On his chest, the empty locket catches the light.",
		"choices": ["Promise to look for the temple."],
	},
	"temple_enter": {
		"title": "The Temple of the Dragon Queen",
		"image": "res://assets/story/story_temple.svg",
		"tint": Color(0.30, 0.16, 0.18),
		"text": "You have been here before. Not in this life: in the dream that has come every night since the broken altar, the one with the columns, and the coiled dragon on the wall, and a woman's voice singing in a tongue you never learned. Ivy hangs where banners hung. The braziers still smoulder after a hundred years, which is impossible, and yet. In the dream you always walked to the centre of the floor and knelt. Your feet are already moving.",
		"choices": ["Walk to where the dream always ends."],
	},
	"temple_secret": {
		"title": "The Hidden Stair",
		"image": "res://assets/story/story_tome.svg",
		"tint": Color(0.16, 0.08, 0.08),
		"text": "You kneel where you knelt in the dream. The slab under your hands is cracked, and through the crack breathes a faint, warm ember light. You press your palm to the dragon in the roundel above it, its red stone eye level with yours, and the stone sighs and sinks. The slab grinds aside. A stair winds down beneath the ruins, swept clean, as if someone has been waiting. At the bottom, on an altar between two carved dragon skulls, a book glows like a coal.",
		"choices": ["Descend."],
	},
	"temple_tome": {
		"title": "The Ember Tome",
		"image": "res://assets/story/story_tome.svg",
		"tint": Color(0.22, 0.08, 0.06),
		"text": "It is bound in red scales and warm to the touch, and when you lift it the voices in your chest do something they have never done before: they kneel. The first page bears a seal, a crowned dragon, and a line in a script you can somehow read: FOR MY DAUGHTERS, WHEN THEY COME HOME. Queen Ysolde's tome. Most of it will not open yet; the pages are hot and stubborn as a sleeping fire. But it settles against your heart as if it has finally found where it belongs.\n\n(Keep the tome until the invasion's second wave, and its fire will wake.)",
		"choices": ["Hold it close. Keep it secret."],
	},
	"wizard_tome_offer": {
		"title": "The Wizard's Price",
		"image": "res://assets/story/story_intro_wizard_saved.svg",
		"tint": Color(0.22, 0.18, 0.20),
		"text": "Ambrose sees the tome before he sees you. He goes very still, the way a cat goes still. \"You found it.\" His voice is a whisper, hungry and reverent. \"Queen Ysolde's own hand.\" He holds out both palms, trembling ever so slightly. \"Give it here, child. It isn't safe with someone who doesn't understand it. I'll keep it for you. I'll keep it for Lorindel.\" Under his robe, the empty locket has begun, very faintly, to glow.",
		"choices": ["Give him the tome.", "Keep it. Tell him you found nothing."],
	},
	"wizard_tome_betrayal": {
		"title": "The Hand That Grasps",
		"image": "res://assets/story/story_wizard.svg",
		"tint": Color(0.24, 0.14, 0.30),
		"text": "You hold out the tome. His fingers close on it, and the book bites. Ember-light flares across the cover and Ambrose screams, snatching back a hand blistered to the bone. The tome stays in yours; it will open for no one but Lorindel's blood. When he looks up, the kindly old man is gone. \"Then I'll take it from your ashes,\" he hisses, and his robes bleed violet-black, his eyes ignite, and the empty locket burns like a hungry heart. He knows you now. Perhaps he always did. The dragon tears up out of you to meet him.",
		"choices": ["Burn him."],
	},
	"wizard_tome_kept": {
		"title": "A Secret Kept",
		"image": "res://assets/story/story_intro_wizard_saved.svg",
		"tint": Color(0.20, 0.18, 0.16),
		"text": "\"Found it? Gracious, no.\" You let your shoulders droop. \"Just rubble and owls.\" Ambrose studies you for a long moment, and the tome weighs against your heart like a second one. Then he smiles, all twinkle again. \"Pity. Keep looking, my dear. Keep looking.\" He watches you all the way down the path.\n\n(Keep the tome until the invasion's second wave, and Queen Ysolde's fire will be yours.)",
		"choices": ["Walk away. Don't look back."],
	},
	"greater_flame": {
		"title": "Greater Flame",
		"image": "res://assets/story/story_greater_flame.svg",
		"tint": Color(0.34, 0.08, 0.04),
		"text": "The second wave is marching when the tome you retrieved from the temple begins to burn against your heart. It falls open on its own, pages flipping in a wind that isn't there, and stops at a spell written in a hand like flame: GREATER FLAME. Queen Ysolde's voice fills your head, clear as a bell after a hundred years of silence. \"They came with choirs and iron, daughter. Answer them as I could not.\" Your breath catches fire. It leaves you twice as far as ever before, and where it touches the earth, the earth keeps burning.\n\n(Gained Greater Flame. Anyone who walks into it dies.)",
		"choices": ["Answer them."],
	},
	# --- the aftermath: glade, deer, the Prince; the invasion + endings (2026-11-15) ---
	"glade_blooms": {
		"title": "Where the Crown Fell",
		"image": "res://assets/story/story_glade.svg",
		"tint": Color(0.30, 0.40, 0.24),
		"text": "Something happens the morning after the King's last fall. In a hollow where nothing has grown since the salting, grass breaks through the ash overnight — then flowers, then birches, then a spring that tastes of iron and honey. Deer come down from hills that had no deer. The voices in your chest go soft and strange; one of them is humming. It is the first green thing Lorindel's earth has offered in a hundred years. And walking through it, as if he owned it — which, since yesterday, he does — is a young man in a blue cape.",
		"choices": ["Go and see."],
	},
	"deer_eaten": {
		"title": "The Hart of the Glade",
		"image": "res://assets/story/story_glade.svg",
		"tint": Color(0.34, 0.30, 0.18),
		"text": "The deer is fast, and you are faster. It is over in a heartbeat, and the meat is sweet in a way nothing in this salted realm has been sweet before — as if the glade grew it for you. Warmth floods your chest; the ember drinks it and burns higher. Somewhere in the birches, a second deer watches, then goes back to grazing. The glade keeps its own counsel. (+2 flames, +20 health)",
		"choices": ["Lick the honey-sweet blood from your teeth."],
	},
	"prince_meet_1": {
		"title": "Once Upon a Glade",
		"image": "res://assets/story/story_prince.svg",
		"tint": Color(0.40, 0.30, 0.28),
		"text": "He is standing in a sunbeam. Of course he is. Gold circlet, blue cape, a robin on one gloved finger. He sees you, startles, and bows so low his circlet slips. \"Forgive me! I'm Aurel. Prince, since yesterday. A dragon killed my father.\" He has no idea what you are. He sees a girl with ember eyes, and he is plainly, hopelessly charmed. And you? Something warm stirs in your chest that has nothing to do with fire. You could let it.",
		"choices": ["Flirt with him. (You like him.)", "Play hard to get. (Keep him guessing.)", "Reject him. (You walk alone.)"],
	},
	"prince_meet_1_flirt": {
		"title": "A Duet, Nearly",
		"image": "res://assets/story/story_prince.svg",
		"tint": Color(0.40, 0.30, 0.28),
		"text": "\"Do you always rescue girls who don't need rescuing?\" He laughs, a real one, startled out of him. \"Only on Tuesdays.\" You walk the glade's edge together; he names the stars, you pretend not to know older names for them. Then a horn calls from the city, his mourning council, and he looks wretched about it. \"Will I see you again?\" You hear yourself say yes.\n\n(He returns to the city. Find him on the city road, as the girl, to meet again.)",
		"choices": ["Watch him go. Smile."],
	},
	"prince_meet_1_coy": {
		"title": "The Prince Retreats",
		"image": "res://assets/story/story_prince.svg",
		"tint": Color(0.36, 0.30, 0.30),
		"text": "You play it cool. Too cool. You study the flowers; he studies the flowers; the silence grows roots. He decides you don't care for him, and he's far too well brought up to stay where he isn't wanted. \"Forgive me. The council.\" He bows to a birch by mistake and hurries off, very red.\n\n(He hasn't given up. Find him on the city road, as the girl, to try again.)",
		"choices": ["Pick a flower anyway."],
	},
	"prince_meet_1_spurn": {
		"title": "Alone, as Asked",
		"image": "res://assets/story/story_prince.svg",
		"tint": Color(0.32, 0.28, 0.30),
		"text": "\"I walk alone, princeling.\" He takes it like a blow he expected. \"Of course.\" A crooked, honest smile. \"For what it's worth, so do I. Since yesterday.\" He bows and walks back toward the city, and you feel, unaccountably, that you have kicked a puppy that only wanted to give you its stick.\n\n(If you change your mind, find him on the city road, as the girl.)",
		"choices": ["Let him go."],
	},
	"prince_meet_2": {
		"title": "Twice Upon a Time",
		"image": "res://assets/story/story_prince.svg",
		"tint": Color(0.42, 0.28, 0.30),
		"text": "He is by the old well on the city road, as if he had waited there all day. He has. \"You came back,\" he says, as if it were a miracle. He has made you a crown of wildflowers, slightly crushed, very sincere. \"I can't stop thinking about you. Tell me you feel it too.\" He leans in, and the ember in your chest flutters. This is the moment. Kiss him, and you choose him, and everything that will come for him.",
		"choices": ["Kiss him. (Choose him.)", "Reject him. (Not yet.)"],
	},
	"prince_meet_2_wary": {
		"title": "Second Chances",
		"image": "res://assets/story/story_prince.svg",
		"tint": Color(0.38, 0.28, 0.32),
		"text": "He is by the old well on the city road, and he sees you first. For a moment he looks ready to bolt; then he squares his shoulders like a man facing a dragon. \"You said you walk alone. I haven't stopped thinking that nobody should have to.\" He holds out a crown of wildflowers. \"Tell me to go and I'll go. Or stay.\" This is the moment. Kiss him, and you choose him, and everything that will come for him.",
		"choices": ["Kiss him. (Choose him.)", "Reject him. (Not yet.)"],
	},
	"prince_rejected": {
		"title": "The Well Road",
		"image": "res://assets/story/story_prince.svg",
		"tint": Color(0.30, 0.28, 0.32),
		"text": "\"Not yet,\" you say, and you mean more than he can know. He looks at you for a long moment. \"Then I'll wait,\" he says simply, and lays the flower crown on the well's edge, and goes back into the city without looking round. You do not pick up the crown. You do not leave without it, either.\n\n(He stays near the city. Find him again, as the girl, when you're ready.)",
		"choices": ["Take the crown."],
	},
	"prince_kiss": {
		"title": "True Love's First Kiss",
		"image": "res://assets/story/story_prince.svg",
		"tint": Color(0.48, 0.26, 0.30),
		"text": "He kisses you like the last note of a song. For one breath the voices inside you fall utterly silent, all of them listening. Then the ember flares so bright he gasps, and in the gold of your eyes he sees the slit pupils, and for a heartbeat he understands everything. He does not let go of your hands. Far away, on the ridge Osric once climbed, a war-horn sounds. Then another. Then two hundred.",
		"choices": ["Hold his hands. Listen to the horns."],
	},
	"invasion_begins": {
		"title": "The Second Purification",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.30, 0.12, 0.10),
		"text": "Overnight a war camp rises beyond the far ridge: palisades, crimson tents, Osric's sun on every banner. The dead King's cousin has taken the crown, and the old word with it: purification. His army will march out in waves for the Prince, the farmers and the miners. And the town's own soldiers, kingless now, gather at the gate with their spears pointed the other way. For once, they stand with you.\n\nKeep the Prince alive. Bring down the usurper when he rides out with the last wave.",
		"choices": ["Wake the dragon."],
	},
	"ending_cycle": {
		"title": "The Wheel Turns",
		"image": "res://assets/story/story_dragon_fall.svg",
		"tint": Color(0.22, 0.12, 0.12),
		"text": "The last farm burns. The last mine falls silent. The hymn rises over the valley exactly as it rose over Lorindel a hundred years ago, and the men in iron warm their hands at the ashes and call it purification. Somewhere under the mountain, someone is already drawing a new circle. The wheel turns. You were the fire that was meant to break it. You were not enough.",
		"choices": ["Let the dark take you."],
	},
	# --- the finale: the usurper, the wizard, the wedding, the last ember (2026-11-15) ---
	"usurper_falls": {
		"title": "The Usurper Falls",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.24, 0.16, 0.26),
		"text": "The usurper goes down in the mud of his own march, and his army breaks like a dam, running for the camp. The town bells ring, for the first time in a hundred years without a hymn in them. Then the sky to the east turns violet. Ambrose Fairweather rides the storm out of his tower, the empty locket blazing on his chest. \"Finished playing house, little ember? The heart, if you please. I have waited long enough.\"",
		"choices": ["End him."],
	},
	"usurper_falls_quiet": {
		"title": "The Usurper Falls",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.26, 0.20, 0.20),
		"text": "The usurper goes down in the mud of his own march, and his army breaks like a dam, running for the camp. The town bells ring, for the first time in a hundred years without a hymn in them. No violet storm comes from the east: the man who woke you is already dust, and whatever he wanted died with him. For the first time since the broken altar, there is nothing left to fight.",
		"choices": ["Go to him."],
	},
	# After the wizard's death and five silent seconds (2026-11-16): every
	# threat gone, the wedding declared; → ending_wedding.
	"ending_peace": {
		"title": "A Wedding Is Declared",
		"image": "res://assets/story/story_glade.svg",
		"tint": Color(0.30, 0.30, 0.26),
		"text": "The smoke drifts off toward the hills, and nothing comes out of it. No storm. No hymn. No marching feet.\n\nThe old King lies in his tomb and the usurper in the mud of his own march. The wizard who woke you is scattered ash on the wind, and his tower stands dark and empty. The soldiers have laid down their spears; the goblins have gone back under the mountain; the wolves keep to the wild edges. For the first time in a hundred years, nothing in the realm is hunting anything.\n\nThen the town bells ring, one after another, all the way down the valley. A herald climbs the well in the market square and reads it out twice, because nobody believes it the first time: Prince Aurel will be married in the glade, and the whole realm is invited. Even the dragon. Especially the dragon.",
		"choices": ["Go to the glade."],
	},
	"ending_wedding": {
		"title": "The Wedding",
		"image": "res://assets/story/story_glade.svg",
		"tint": Color(0.40, 0.34, 0.24),
		"text": "They hold it in the glade, under the birches, with deer at the edge of the crowd and fireflies for candles. The people who once fled your shadow come with flowers in their hands. Aurel waits in his blue cape, grinning like a fool, and when you reach him he forgets every word of his vows and simply says, \"You.\" The voices in your chest are quiet. Then, all together, softly, they say yes. And slowly, the ember in your chest begins to dim.",
		"choices": ["Say yes."],
	},
	"ending_last_ember": {
		"title": "The Last Ember",
		"image": "res://assets/story/story_heart.svg",
		"tint": Color(0.44, 0.32, 0.20),
		"text": "With its purpose fulfilled, the dragon’s inner fire fades. Its enormous body crumbles to dust, leaving only a single dragon heart behind.\n\nA tragic end? Not quite.\nThe land prospers, peace endures, and for a hundred years no new monsters are born.",
		"choices": ["Rest."],
	},
	# The hag's gift kept (2026-11-16): after the wedding she lives until
	# her daughter is born, then the ember dies (replaces ending_last_ember).
	"ending_daughter": {
		"title": "Ysolde",
		"image": "res://assets/story/story_glade.svg",
		"tint": Color(0.44, 0.34, 0.22),
		"text": "The ember dims, but it does not go out. It holds on, the way the hag promised, through a winter and a spring, low and stubborn beside the second warmth under your heart.\n\nOn the first warm night of summer, in the glade under the birches, you give birth to a daughter with Aurel's grin and your eyes: gold, with a slit of black. You name her Ysolde, after the queen whose voice woke in the tome.\n\nYou hold her until morning. Then your ember goes out, gently, like a candle that has finished its work. Aurel keeps your heart in a box of birchwood. Ysolde keeps your fire.",
		"choices": ["Hold her until morning."],
	},
	"ending_prince_falls": {
		"title": "The Prince Falls",
		"image": "res://assets/story/story_dragon_fall.svg",
		"tint": Color(0.24, 0.10, 0.12),
		"text": "He dies on the city road with a usurper's spear in him and a name on his lips: the name he gave you, because you never told him your real one. The hymn rises over the town. You burn them, every one, and it changes nothing; the thing you were fighting for is lying in the dust. Under the mountain, someone is already drawing a new circle. The wheel turns.",
		"choices": ["Let the dark take you."],
	},
	# --- rider upgrade story (2026-11-11) ---
	# The rider's fall (2026-11-16): the rider takes the boss's killing
	# blow; the dragon lives, +2 flames, vengeful (Dragon._rider_takes_the_hit).
	# GameManager appends the rider's own last words as the note.
	# The pact unpaid (2026-11-16): the rider leaves; GameManager appends
	# the rider's own parting words (RiderPacts.PACTS[...]["parting"]).
	"rider_pact_broken": {
		"title": "The Broken Pact",
		"image": "res://assets/story/story_rider.svg",
		"tint": Color(0.22, 0.2, 0.26),
		"text": "A pact is only words until the day it is not kept. Then it is the weight of a saddle with no one in it.",
		"choices": ["Let them go."],
	},
	"rider_fall_wizard": {
		"title": "The Empty Saddle",
		"image": "res://assets/story/story_rider.svg",
		"tint": Color(0.18, 0.2, 0.32),
		"text": "The bolt that should have stopped your heart never reaches it. Your rider stands up in the saddle, arms wide, bow flung away, and the lightning finds steel and leather and a beating heart instead of scale. For one instant the rider burns white against the sky. Then they slide from your back into the ash, and the wizard's laugh dies in his throat.\n\nYour heart hammers on. Something in it has turned to iron. Two new fires kindle in your chest, and both of them are hungry for him.",
		"choices": [
			"Roar the rider's name until the tower shakes.",
			"Say nothing. Turn. Burn him.",
		],
	},
	"rider_fall_king": {
		"title": "The Empty Saddle",
		"image": "res://assets/story/story_rider.svg",
		"tint": Color(0.3, 0.18, 0.16),
		"text": "The storm of swords breaks over you, and over the rider first. They throw themselves flat across your neck, shield-arm raised, and take every falling blade that was meant for your heart. When the steel stops raining, the saddle is empty. Your rider lies in the dust with the King's swords standing around them like a fence.\n\nYou live. The King raises his blade for another storm. Two new fires kindle in your chest, and every one of them has his name on it.",
		"choices": [
			"Roar the rider's name over the battlefield.",
			"Say nothing. Turn. Burn him.",
		],
	},
	"rider_upgraded": {
		"title": "The Archer's Oath",
		"image": "res://assets/story/story_rider.svg",
		"tint": Color(0.25, 0.28, 0.35),
		"text": "The rider draws the bowstring, the arrowhead gleaming with purpose. \"I swear on this bow,\" they say, \"no King's man, no goblin, no wizard shall come near this dragon without bleeding.\" The dragon rumbles, a sound like distant thunder. And somewhere inside it, a voice that has been alone for a hundred years is, for one moment, not alone.",
		"choices": [
			"Nod. The rider has earned their place.",
			"Growl: \"Shoot true. Or don't come back.\"",
		],
		"effects": [
			{"health": 10},
			{"flames": 1},
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
## `note` joins the text as a closing paragraph (outcome reports say what
## the deed actually did — the flame gained, who waits in the lair).
const SETTINGS_KEYS := preload("res://scripts/ui/SettingsMenu.gd")   # {key:action} → bound key

func open(kind: String, note: String = "", lead: String = "") -> void:
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
	_show_animation(str(STORIES[kind].get("animation", "")))
	text_label.text = SETTINGS_KEYS.with_keys((lead + "\n\n" if lead != "" else "")
		+ STORIES[kind]["text"] + ("\n\n" + note if note != "" else ""))
	_rebuild_choices(STORIES[kind]["choices"])
	# One-answer chapters (meals, outcome reports) just continue.
	var count: int = STORIES[kind]["choices"].size()
	hint_label.text = "Press 1 or ESC to continue" if count == 1 \
		else "Pick an answer (1-%d • ESC for the last line)" % count
	visible = true

## Animated story art (2026-11-15): "animation": "bees" plays the bee and
## the shy flower over the story image (BeesAndFlowers.gd).
const BEES_SCRIPT := preload("res://scripts/ui/BeesAndFlowers.gd")
var _bees: Control = null

func _show_animation(which: String) -> void:
	if which == "bees":
		if _bees == null:
			_bees = BEES_SCRIPT.new() as Control
			_bees.name = "Bees"
			$Center/Panel/VBox/ImageBox.add_child(_bees)
		_bees.call("restart")
		_bees.visible = true
	elif _bees != null:
		_bees.visible = false

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
	if not visible:
		return   # closed: ESC belongs to the settings menu (SettingsMenu.gd)
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
				# handled FIRST: the choice can take this popup out of the
				# tree (a scene reload), and then there is no viewport
				get_viewport().set_input_as_handled()
				_on_choice_pressed(i)
				return
	if event.is_action_pressed("ui_cancel"):
		# ESC picks the closing line (last choice) — the story must answer.
		get_viewport().set_input_as_handled()
		_on_choice_pressed(choice_texts.size() - 1)
