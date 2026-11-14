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
		"image": "res://assets/story/story_fields_burn.svg",
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
		"image": "res://assets/story/story_fields_burn.svg",
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
		"image": "res://assets/story/story_fields_burn.svg",
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
		"image": "res://assets/story/story_fields_burn.svg",
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
		"image": "res://assets/story/story_fields_burn.svg",
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
		"image": "res://assets/story/story_fields_burn.svg",
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
		"image": "res://assets/story/story_mine_fire.svg",
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
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.32, 0.2, 0.3),
		"text": "Banners swallow the horizon; hooves shatter the frost. AND THEN — the King himself, gold-heavy sword drawn, voice rolling over every farmhand's head: \"CREATURE OF SMOKE AND THEFT! By my crown, by my fathers, and by every golden coin of this realm — I shall have your head above my gates by sunset!\" The dragon yawns, showing every knife of a tooth.",
		"choices": [
			"Answer his speech with a low, hungry curl of smoke.",
			"Fly a slow, mocking loop over the royal banners.",
			"Land. Bow. DRAMATICALLY. Then breathe a coal-cracker.",
		],
	},
	# --- king story variants (2026-11-12, user: \"King StoryPopup
	# variations\") ---
	"king_defiant": {
		"title": "The Defiant King",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.32, 0.2, 0.2),
		"text": "You have heard the songs — the old songs, the ones about the dragon I slew in my youth, the one they carved into the chapel doors. It was true. I was that man. I killed that beast while my hands were young and my heart was stupid enough to believe the stories would end there. But the stories do not end. They just find a new beast to be about. So here I am, old, slow, tired, wearing a crown that feels like a gravestone — and I am going to pick up my sword again. Not because I want to. Because a king who stops being a hero is just a man with good furniture, and I refuse to die that way.",
		"choices": [
			"Roar and burn his banner.",
			"Land. Bow. DRAMATICALLY. Then breathe a coal-cracker.",
			"Snarl: \"You talk too much for a king.\"",
		],
	},
	"king_courageous": {
		"title": "The Fearless",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.3, 0.18, 0.22),
		"text": "I am still the king. I am still the man who killed the last dragon, and I killed it while I was so afraid I could barely hold my sword — and that fear is the only reason I am alive. The dragon does not feel fear. It has never needed to. It has never met a man who had nothing left to lose, a man who would rather die on his feet than live on his knees. Today, you are that man. Today, we are all that man. And I promise you: when the beast looks into our eyes and sees no running, no begging, no white flags — it will know fear for the first time in its long, stupid life.",
		"choices": [
			"Roar and burn his banner.",
			"Land. Bow. DRAMATICALLY. Then breathe a coal-cracker.",
			"Snarl: \"You talk too much for a king.\"",
		],
	},
	"king_challenger": {
		"title": "The Challenger",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.25, 0.15, 0.25),
		"text": "Come forth, you wretched beast of fire and ruin! I have brought you the finest steel of twelve kingdoms, ten thousand men who fear neither death nor darkness, and a crown forged in the blood of conquerors. Today, dragon, you shall learn why even gods once trembled before kings!",
		"choices": [
			"Roar and burn his banner.",
			"Land. Bow. DRAMATICALLY. Then breathe a coal-cracker.",
			"Snarl: \"You talk too much for a king.\"",
		],
	},
	"king_unbowed": {
		"title": "The Unbowed",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.28, 0.12, 0.22),
		"text": "Look upon me, wyrm, and behold the one creature in this world that does not fear you! I have broken empires, buried tyrants, and walked through rivers of blood to claim this crown. Your fire is but a candle before the furnace of my wrath!",
		"choices": [
			"Roar and burn his banner.",
			"Land. Bow. DRAMATICALLY. Then breathe a coal-cracker.",
			"Snarl: \"You talk too much for a king.\"",
		],
	},
	"king_champion": {
		"title": "The Champion",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.3, 0.2, 0.25),
		"text": "By the heavens that witness us, by the earth that bears our feet, and by the ancient kings whose bones lie beneath these hills, I challenge thee! Let the mountains shatter and the skies turn black with ash, for I shall not yield one step. Come, serpent, and discover whether your flames burn hotter than the fury of a king!",
		"choices": [
			"Roar and burn his banner.",
			"Land. Bow. DRAMATICALLY. Then breathe a coal-cracker.",
			"Snarl: \"You talk too much for a king.\"",
		],
	},
	"king_renegade": {
		"title": "The Renegade King",
		"image": "res://assets/story/story_king.svg",
		"tint": Color(0.25, 0.18, 0.15),
		"text": "Hear me, beast! The age of dragons ends beneath my banner, and from your ashes shall rise an age of men! Let your roar shake the heavens one final time, for when this day is done, the only thing left of your legend shall be the songs they sing of me!",
		"choices": [
			"Roar and burn his banner.",
			"Land. Bow. DRAMATICALLY. Then breathe a coal-cracker.",
			"Snarl: \"You talk too much for a king.\"",
		],
	},
	"king_defeat": {
		"title": "The Crown Tumbles",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.2, 0.18, 0.2),
		"text": "A third fall. THREE, and the third is FINAL. The King lies still beneath his own collapsed standard, helm rolling away in the dust, and the realm — farms silent, mines cold, treasury gutted — realizes in one held breath that it kneels to no man tonight. The last roar shakes harvest from every unburnt tree.",
		"choices": [
			"Plant one satisfied claw upon the fallen crown.",
			"Deliver the slowest clap in the history of kingdoms.",
			"Sleep three days on the treasury gate. Earned.",
		],
	},
	# --- king defeat variants (2026-11-12, user: \"King defeat StoryPopup
	# options\") ---
	"king_defeat_fallen_crown": {
		"title": "The Fallen Crown",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.25, 0.15, 0.18),
		"text": "\"Impossible... I have brought empires to their knees... I have broken armies greater than the stars in heaven! And yet... a miserable, overgrown lizard dares to stand above me? Curse you, beast! May your gold turn to ashes, your wings to dust, and your name be forgotten by all but the worms!\"",
		"choices": [
			"Roar a curse back: \"Worms eat kings, not gold.\"",
			"Crush the crown under one talon. Let the rust settle.",
			"Snarl: \"Your empire was a lie. I am real.\"",
		],
	},
	"king_defeat_prophecy": {
		"title": "The King's Last Prophecy",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.22, 0.12, 0.2),
		"text": "\"You may have broken my sword, dragon, but you have not broken my kingdom! A thousand sons shall rise to avenge me, and ten thousand more shall follow! They shall hunt you to the ends of the earth, and when they finally drag your carcass from its mountain, I shall be laughing from the halls of the dead!\"",
		"choices": [
			"Roar a curse back: \"Worms eat kings, not gold.\"",
			"Crush the crown under one talon. Let the rust settle.",
			"Snarl: \"Your empire was a lie. I am real.\"",
		],
	},
	"king_defeat_curse": {
		"title": "The Curse of the Dying King",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.28, 0.1, 0.22),
		"text": "\"By my blood upon this soil, by my crown cast into the mud, I lay upon you the curse of kings! May every treasure you steal bring you sorrow, every maiden you carry bring you misery, and every victory leave you more wretched than the last! May you live a thousand years, dragon... and regret every single one!\"",
		"choices": [
			"Roar a curse back: \"Worms eat kings, not gold.\"",
			"Crush the crown under one talon. Let the rust settle.",
			"Snarl: \"Your empire was a lie. I am real.\"",
		],
	},
	"king_defeat_defiance": {
		"title": "The King's Final Defiance",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.3, 0.12, 0.15),
		"text": "\"Do not mistake my fall for your triumph, serpent! A king does not die when his heart ceases beating, but when the last man forgets his name! And I swear upon the throne of my fathers... even if I must crawl from the grave with my bones for swords, I shall have my vengeance!\"",
		"choices": [
			"Roar a curse back: \"Worms eat kings, not gold.\"",
			"Crush the crown under one talon. Let the rust settle.",
			"Snarl: \"Your empire was a lie. I am real.\"",
		],
	},
	"king_defeat_decree": {
		"title": "The Last Royal Decree",
		"image": "res://assets/story/story_king_fallen.svg",
		"tint": Color(0.2, 0.15, 0.25),
		"text": "\"Then hear my final decree, you winged abomination! I condemn you to an eternity of hunger, an ocean of loneliness, and a mountain of gold you shall never have the wit to spend! And when the last star fades and the world grows cold, may you still be sitting upon your worthless treasure... YOU GLORIFIED CHICKEN!\"",
		"choices": [
			"Roar a curse back: \"Worms eat kings, not gold.\"",
			"Crush the crown under one talon. Let the rust settle.",
			"Snarl: \"Your empire was a lie. I am real.\"",
		],
	},
	"wizard_emerge": {
		"title": "The Tower Reveals Its Master",
		"image": "res://assets/story/story_wizard.svg",
		"tint": Color(0.2, 0.14, 0.3),
		"text": "The kindly old man who sold you flame and shield sets down his ledger. Bows his head. And when he lifts it, his eyes are burning. \"Every scale you bought, I counted. Every flame, I measured,\" he purrs, as his robes bleed to night and the empty locket on his chest begins to glow. \"Gold? Trinkets. I was only ever fattening you up for the one treasure in this realm worth the wait — your HEART, wyrm. Hold still.\"",
		"choices": [
			"Squint: \"So the claw upgrade was CHARITY?\"",
			"Snarl a river of fire into his billing ledger.",
			"Fake your own death. Wizards HATE paperwork.",
		],
	},
	# --- first-meal chapters (2026-11-14: one answer each; the text says
	# plainly what the meal did — pig: +2 flames, cow: full health + flames) ---
	"pig_eaten": {
		"title": "A Pig's Last Oink",
		"image": "res://assets/story/story_pig.svg",
		"tint": Color(0.35, 0.22, 0.25),
		"text": "The pig sees your shadow, does the maths, and lets out one magnificent, indignant OINK — a squeal with real opinions in it. Then: crunch. Bacon has never been so brief. A greasy warmth rolls down your throat and pools in your chest, where the fire lives. Your wounds ease, your fire stirs. The farmers will grumble for a week. Your belly will not. (+2 flames, +10–20 health)",
		"choices": [
			"Lick your chops.",
		],
	},
	"cow_eaten": {
		"title": "The Cow's Moonlit Lament",
		"image": "res://assets/story/story_cow.svg",
		"tint": Color(0.24, 0.26, 0.2),
		"text": "The cow looks up from her grass — unhurried, ancient, deeply unimpressed — and delivers one long, mournful MOO at the moon, as if lodging a formal complaint. You accept it. Then you accept her. Somewhere a milk-bucket tips over. A whole cow is a feast: your wounds knit closed, and every flame in your chest roars back to life. (Full health, full flames)",
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
		"text": "No magic. No prophecy. Just town steel, held shoulder to shoulder by men who did NOT flee — pikes braced while the great shadow dove, and a droning farmhand chorus singing their one rehearsed line: \"THE DRAGON IS SLAIN!\" The commonest metal in the realm spelled the end of the rarest. The song will outlive the hoard.",
		"choices": [
			"Fall growling: \"Enjoy the tax audit, mortals.\"",
			"Bleed with a smirk — men with pitchforks will REMEMBER this.",
			"Whisper: \"A farmer. A FARMER. History is unkind.\"",
		],
	},
	"dragon_death_archer": {
		"title": "The Well-Aimed Silence",
		"image": "res://assets/story/story_dragon_fall.svg",
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
		"image": "res://assets/story/story_dragon_fall.svg",
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
		"image": "res://assets/story/story_dragon_fall.svg",
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
		"image": "res://assets/story/story_dragon_fall.svg",
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
		"image": "res://assets/story/story_goblins.svg",
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
		"image": "res://assets/story/story_goblins.svg",
		"tint": Color(0.25, 0.1, 0.1),
		"text": "The goblins have turned hostile! They swarm from the mountain passes, spears glinting in the dim light. \"WAARGH!\" they shriek, charging with desperate fury. They attack farmers and miners to steal food and gold.",
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
		"text": "She's chewed halfway through the rope and stopped, apparently out of spite. \"Oh, FINALLY. Took you long enough, you oversized lizard. Go on — I've been insulting you to the whole village for an hour. Your breath smells like a burnt tannery, your wings look like wet laundry, and your mother was a newt.\" She juts her chin at your teeth. \"Well? Hungry or scared?\"",
		"choices": ["Bring to lair", "Eat!", "Leave"],
	},
	"sacrifice_defiant_eat_2": {
		"title": "Brannagh Thornwick — Dinner Bell",
		"image": "res://assets/story/sacrifice_defiant_jaws.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "Her face LIGHTS up. \"YES. That's the spirit! Wider — come on, you've opened your mouth wider for a sheep. I want them to hear the crunch from the chapel.\" She wiggles her toes at your fangs. \"Season me with a little fire first? No? Coward. Fine. Raw it is.\"",
		"choices": ["\"You're very strange.\"", "Lick your chops slowly.", "Growl. She cheers."],
	},
	"sacrifice_defiant_eat_3": {
		"title": "Brannagh Thornwick — Last Word",
		"image": "res://assets/story/sacrifice_defiant_jaws.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "She hops — actually HOPS — into your jaws and makes herself comfortable on your tongue. \"Tell the village I tasted like VICTORY,\" she declares, \"and that your breath really is horrendous—\" The last insult is lost in a very satisfying gulp. Her fury burns hot in your belly. (+2 flames)",
		"choices": ["GULP.", "Chew. Thoughtfully. Respectfully.", "Burp a smoke ring in her honour."],
	},
	"sacrifice_defiant_lair_2": {
		"title": "Brannagh Thornwick — Outrage",
		"image": "res://assets/story/sacrifice_defiant_lair.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "\"A RIDER?!\" She kicks your snout the whole way to the lair. \"I came here to be EATEN. I had a whole speech. I insulted your mother!\" She folds her arms on the hoard and glares. \"I'll be the worst rider you ever had. I'll steer you into trees. I'll sing.\"",
		"choices": ["\"Sing, then.\"", "Nudge a shiny bow toward her.", "Settle on the hoard and ignore her."],
	},
	"sacrifice_defiant_lair_3": {
		"title": "Brannagh Thornwick — The Spiteful Oath",
		"image": "res://assets/story/sacrifice_defiant_lair.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "She picks up the bow. Tests the string. A slow, terrible smile spreads. \"Fine. If I can't be dinner, everyone ELSE will be. I'll shoot faster than any rider you've ever had — out of pure, bottomless spite.\" She climbs onto your back and kicks your ribs. \"Well? GIDDY UP, handbag.\"",
		"choices": ["Unfurl your wings. She whoops.", "Snort smoke. Grudging respect.", "\"…Handbag?\""],
	},
	"sacrifice_courageous": {
		"title": "Ysolde of the Wolfrun — The Unbowed",
		"image": "res://assets/story/sacrifice_courageous.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "A wolf pelt hangs off her shoulders and her chin is up so high it's practically pointing at the moon. \"I have faced wolves. I have walked through fire to save my sister. I do not fear you, beast.\" Her knees are knocking audibly. \"…I mostly do not fear you.\"",
		"choices": ["Bring to lair", "Eat!", "Leave"],
	},
	"sacrifice_courageous_eat_2": {
		"title": "Ysolde of the Wolfrun — Bravery, Reconsidered",
		"image": "res://assets/story/sacrifice_courageous_jaws.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "\"Ah — eat, you said? Right. Yes. Bravely.\" She clears her throat. \"Only, a warrior's flesh is very tough. Gristly. All that marching. I'm practically a boot. Have you considered a nice cow? I know a cow. Several cows. I can point.\"",
		"choices": ["Open wider.", "\"You said you weren't afraid.\"", "Sniff her. Hm. Boot."],
	},
	"sacrifice_courageous_eat_3": {
		"title": "Ysolde of the Wolfrun — A Song Unsung",
		"image": "res://assets/story/sacrifice_courageous_jaws.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "\"My sister will avenge me!\" she cries, then, quieter: \"She won't, she's eight, but it sounded good.\" She salutes you with tremendous dignity as your jaws close. A brave meal is a warming meal — perhaps.",
		"choices": ["Gulp, with honour.", "Chew in respectful silence.", "Lick a stray wolf hair off your lip."],
	},
	"sacrifice_courageous_lair_2": {
		"title": "Ysolde of the Wolfrun — Vertigo",
		"image": "res://assets/story/sacrifice_courageous_lair.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "\"A rider? Me? On you? In the SKY?\" She clutches the hoard like it's a cliff edge. \"Funny story — the wolves, the fire, all very brave — but I've never been higher than a hay loft. I get dizzy on a STOOL. Perhaps I could be your… ground rider? I'll run alongside. Very fast.\"",
		"choices": ["\"You'll get used to it.\"", "Hover one inch off the ground. Demonstrate.", "Nudge a bow toward her."],
	},
	"sacrifice_courageous_lair_3": {
		"title": "Ysolde of the Wolfrun — The Oath",
		"image": "res://assets/story/sacrifice_courageous_lair.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "She takes the bow with shaking hands. Then, slowly, the shaking stops. \"For my sister,\" she whispers, and straps herself on with every belt in the lair. And three of yours. \"If I scream the whole first flight, you will tell NO ONE.\"",
		"choices": ["Promise. Solemnly.", "Take off immediately.", "Rumble a laugh."],
	},
	"sacrifice_cunning": {
		"title": "Vesna Silvertongue — The Fox",
		"image": "res://assets/story/sacrifice_cunning.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "She winks at you. Actually winks. One hand is suspiciously busy behind her back. \"Darling. Those scales! Has anyone ever told you that you have a truly majestic jawline? I know where the treasury hides its weakest guard. I know which mountain pass the soldiers fear. Let's make a deal, you and I.\"",
		"choices": ["Bring to lair", "Eat!", "Leave"],
	},
	"sacrifice_cunning_eat_2": {
		"title": "Vesna Silvertongue — The Counter-Offer",
		"image": "res://assets/story/sacrifice_cunning_jaws.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "\"Eat me? Me? Darling, that's like eating the map to the treasure.\" She bats her lashes so hard a little wind picks up. \"Let me sweeten it: I'll owe you a favour. Two favours. A favour and a half and a really good recipe for king. Final offer. Okay — final-final offer…\"",
		"choices": ["\"No deals.\"", "Pretend to consider it.", "Catch the lockpick she drops."],
	},
	"sacrifice_cunning_eat_3": {
		"title": "Vesna Silvertongue — Silver, Swallowed",
		"image": "res://assets/story/sacrifice_cunning_jaws.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "\"You'll regret this when you're old and poor!\" she sings, already halfway down. \"You'll think: if only I'd listened to Vesna—\" The rest of her pitch continues, muffled, for a remarkably long time. Clever ones are rich in flavour — sometimes.",
		"choices": ["Gulp.", "Wait for the muffled pitch to end.", "Spit out three lockpicks."],
	},
	"sacrifice_cunning_lair_2": {
		"title": "Vesna Silvertongue — Renegotiation",
		"image": "res://assets/story/sacrifice_cunning_lair.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "She surveys your hoard with professional interest. \"Rider. Hmm. Let's discuss terms, darling. Salary? Holidays? Do I get a share of the shiny? I'm thinking forty percent.\" A gold chain has already disappeared into her sleeve. \"Thirty. Thirty-five. Okay, I'll start at ten and steal the rest.\"",
		"choices": ["\"Put the chain back.\"", "Narrow one golden eye.", "Count your coins. Pointedly."],
	},
	"sacrifice_cunning_lair_3": {
		"title": "Vesna Silvertongue — The Contract",
		"image": "res://assets/story/sacrifice_cunning_lair.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "\"Fine, fine. No salary.\" She tests the bowstring like she's appraising a necklace. \"But I'm telling everyone I'm your BUSINESS partner.\" She climbs on, already scanning the horizon for things worth stealing. \"Darling, those soldiers over there are wearing SILVER.\"",
		"choices": ["Hmph. Agreed.", "Fly toward the silver.", "Check your hoard one last time."],
	},
	"sacrifice_devout": {
		"title": "Sister Aldith — The Prophet",
		"image": "res://assets/story/sacrifice_devout.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "Candles flicker at her feet; she has clearly brought her own. \"The old gods whispered of you in my dreams, great wyrm. I am ready. I have been ready for years. I have rehearsed this.\" She sneaks a look at your teeth. \"In the dream you were… somewhat smaller.\"",
		"choices": ["Bring to lair", "Eat!", "Leave"],
	},
	"sacrifice_devout_eat_2": {
		"title": "Sister Aldith — A Theological Objection",
		"image": "res://assets/story/sacrifice_devout_jaws.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "\"Now — with respect — the prophecy was VAGUE on the eating part.\" She flips frantically through a tiny prayer book. \"It says 'the dragon shall take her.' TAKE. It could mean take for a walk. Take on as an apprentice. Take tea with. Shall we take tea? I brought biscuits.\"",
		"choices": ["Take a biscuit. Then advance.", "\"Prophecy says EAT.\"", "Blow out her candles."],
	},
	"sacrifice_devout_eat_3": {
		"title": "Sister Aldith — Gospel Received",
		"image": "res://assets/story/sacrifice_devout_jaws.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "She folds her hands, closes her eyes, and announces to the heavens: \"I would like it noted that I asked about the biscuits.\" Then, very small: \"Bless this meal.\" You do not know whether she means you or her.",
		"choices": ["Gulp, reverently.", "Bow your head first.", "Eat the biscuits too."],
	},
	"sacrifice_devout_lair_2": {
		"title": "Sister Aldith — A Calling, Revised",
		"image": "res://assets/story/sacrifice_devout_lair.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "\"Ride you?\" She stares at the saddle, then at the heavens. \"The prophecy did not mention SADDLES. I'm a woman of contemplation. I've never held a weapon. I once apologised to a fly.\" She edges toward the cave mouth. \"Perhaps I'm called to be your… lair chaplain?\"",
		"choices": ["Block the cave mouth with your tail.", "\"The gods want archers now.\"", "Offer her a biscuit. Her own."],
	},
	"sacrifice_devout_lair_3": {
		"title": "Sister Aldith — Divine Aim",
		"image": "res://assets/story/sacrifice_devout_lair.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "She closes her eyes, draws the bow, and looses an arrow that splits a candle wick at forty paces. Opens her eyes. Stares at it. \"…The gods,\" she says faintly, \"have a sense of humour.\" She climbs aboard murmuring a prayer for whoever she shoots first.",
		"choices": ["Bow your head with her.", "Take to the sky.", "Applaud with your wings."],
	},
	"sacrifice_brute": {
		"title": "Horrik Bearhug — The Mountain",
		"image": "res://assets/story/sacrifice_brute.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "He's already snapped two of the ropes just by breathing in. \"Ha! A dragon! I wrestled a grizzly bear once. Twice, actually. Same bear. We're friends now.\" He flexes. Something in the stake creaks. \"You want food or a fighter? I'm warning you, I'm ALL gristle.\"",
		"choices": ["Bring to lair", "Eat!", "Leave"],
	},
	"sacrifice_brute_eat_2": {
		"title": "Horrik Bearhug — Second Thoughts",
		"image": "res://assets/story/sacrifice_brute_jaws.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "He stops flexing. \"…Wait, you went for 'food'? Most people go for 'fighter'.\" He pats his belly nervously. \"I'm terribly stringy, you know. Lot of hair. You'll be picking me out of your teeth for a WEEK. Also I'm allergic to being eaten. Very allergic. Breaks me out in death.\"",
		"choices": ["\"Allergic?\"", "Bare every tooth.", "Tug him off the stake with one claw."],
	},
	"sacrifice_brute_eat_3": {
		"title": "Horrik Bearhug — The Last Flex",
		"image": "res://assets/story/sacrifice_brute_jaws.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "\"Fine! FINE!\" He flexes one final time, magnificently, for the benefit of nobody. \"Tell the bear I said goodbye!\" He was right: you will be picking him out of your teeth for a week. Hearty meat — if you're lucky, it lights a new flame.",
		"choices": ["Gulp. Chew. Chew. Chew.", "Let him finish the flex first.", "Promise to tell the bear."],
	},
	"sacrifice_brute_lair_2": {
		"title": "Horrik Bearhug — Too Big to Ride",
		"image": "res://assets/story/sacrifice_brute_lair.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "\"Ride you?\" He looks at your back, then at himself, then back at your back. \"I'll squash you flat, little dragon. I'm built for wrestling, not flying. Also, bows are for skinny men. I punch things.\" He tries to punch the hoard. It does not go well.",
		"choices": ["\"You'll learn the bow.\"", "Let him sit on you. You don't squash.", "Snort. 'Little'?"],
	},
	"sacrifice_brute_lair_3": {
		"title": "Horrik Bearhug — Big Bow",
		"image": "res://assets/story/sacrifice_brute_lair.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "You find him the biggest bow in the hoard. He bends it like a twig and grins. \"…Alright. ALRIGHT. I like this.\" He mounts, and you sag a little. Neither of you mentions it. \"Tell the bear I got a dragon!\"",
		"choices": ["Launch. Groaning slightly.", "Promise to tell the bear.", "Flex your wings at him."],
	},
	"sacrifice_thief": {
		"title": "Corvin Nimblefoot — The Shadow",
		"image": "res://assets/story/sacrifice_thief.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "One arm is already out of the ropes. He freezes mid-wriggle and smiles very, very widely. \"Evening! This isn't what it looks like. This is a… stretch. Prisoners stretch.\" He waggles the free hand. \"I steal what others cannot see, mighty one. Kings' secrets. Merchants' gold. Your lunch, if you blink.\"",
		"choices": ["Bring to lair", "Eat!", "Leave"],
	},
	"sacrifice_thief_eat_2": {
		"title": "Corvin Nimblefoot — Slippery",
		"image": "res://assets/story/sacrifice_thief_jaws.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "\"Ah. Eat. Classic choice.\" Both arms are out now. A leg is in progress. \"Counter-proposal: you DON'T, and I pay you back in stolen gold. Here—\" he produces a gold coin from behind your own ear. \"See? Already working. There's more where that came from. From you, mostly. But still.\"",
		"choices": ["Pin him with one claw.", "\"That's MY coin.\"", "Watch him wriggle a bit more."],
	},
	"sacrifice_thief_eat_3": {
		"title": "Corvin Nimblefoot — Light Fingers, Last Supper",
		"image": "res://assets/story/sacrifice_thief_jaws.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "He makes one last magnificent leap — straight into your open mouth, because you moved it there. \"…Well played,\" he concedes from somewhere around your tonsils. You feel him pickpocket your gullet on the way down. Clever little snack.",
		"choices": ["Gulp.", "Shake him out first. Check for coins.", "Close your mouth. Slowly."],
	},
	"sacrifice_thief_lair_2": {
		"title": "Corvin Nimblefoot — Sticky Fingers",
		"image": "res://assets/story/sacrifice_thief_lair.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "He's delighted with the lair for exactly four seconds, until he realises he can't carry it all. \"Rider, you say? Hmm. Hmm hmm. Very dangerous. Very high. Very far from all this—\" he gestures at the hoard, two rubies vanishing into his boots. \"What if I stay here and… guard it? Closely. From the inside of my pockets.\"",
		"choices": ["Turn him upside down. Shake.", "\"You ride. Or you're lunch.\"", "Sit on the hoard pointedly."],
	},
	"sacrifice_thief_lair_3": {
		"title": "Corvin Nimblefoot — The Light Touch",
		"image": "res://assets/story/sacrifice_thief_lair.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "Lighter by two rubies (returned) and one pair of boots (confiscated), he hops onto your back and tests the bow. \"You know, from up here I can see EVERYONE'S pockets.\" A slow, criminal grin. \"Partner, I think this is the start of a beautiful crime spree.\"",
		"choices": ["Fly. Toward the pockets.", "Keep the boots.", "Rumble agreement."],
	},
	"sacrifice_renegade": {
		"title": "Garreth the Outcast — The Exile",
		"image": "res://assets/story/sacrifice_renegade.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "An eyepatch, a scar, and the dead-eyed stare of a man who has been exiled by three separate kingdoms. \"They called me traitor. They hounded me to the edge of the world.\" He squints his one eye at you. \"Give me wings and I'll bring their heads back in sacks. Or burn me. Either way, they die.\"",
		"choices": ["Bring to lair", "Eat!", "Leave"],
	},
	"sacrifice_renegade_eat_2": {
		"title": "Garreth the Outcast — Terms and Conditions",
		"image": "res://assets/story/sacrifice_renegade_jaws.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "\"Eat. Right.\" The tough-guy rasp cracks into something higher. \"Thing is, I've got unfinished business. Vengeance, mostly. A small amount of laundry. Could you eat me AFTER the vengeance? I'll come back. Exiles are very punctual. We've got nowhere else to be.\"",
		"choices": ["\"No.\"", "Tilt your head. Exiles ARE punctual.", "Snort a puff of smoke in his eye. The good eye."],
	},
	"sacrifice_renegade_eat_3": {
		"title": "Garreth the Outcast — Exiled, Again",
		"image": "res://assets/story/sacrifice_renegade_jaws.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "\"Exiled from three kingdoms,\" he sighs as your jaws close, \"and now from the world of the living. Consistent, at least.\" He tastes faintly of grudges. Grudges make a fine fuel — some nights.",
		"choices": ["Gulp.", "Chew on the eyepatch.", "Tell the kingdoms. They'll be pleased."],
	},
	"sacrifice_renegade_lair_2": {
		"title": "Garreth the Outcast — Second Thoughts",
		"image": "res://assets/story/sacrifice_renegade_lair.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "\"A rider. Right.\" He stares at the sky, then at you, then at his eyepatch in a shiny shield. \"Thing is, depth perception. One eye. Flying, shooting — I'll be aiming at three of everything. Have you got a dragon that's slower? Or a smaller sky?\"",
		"choices": ["\"You'll aim twice.\"", "Hold a shield up so he can practise.", "Shrug your wings. Only sky we've got."],
	},
	"sacrifice_renegade_lair_3": {
		"title": "Garreth the Outcast — Vengeance Takes Wing",
		"image": "res://assets/story/sacrifice_renegade_lair.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "He squints down the arrow with his one good eye, looses, and pins a fleeing rat to the wall. \"…Huh.\" He mounts up, and for the first time in years the exile smiles. \"Three kingdoms,\" he says, \"are about to have a very bad day.\"",
		"choices": ["Roar. Three kingdoms.", "Take off at full speed.", "Let him savour it."],
	},
	# --- sacrifice outcomes (2026-11-14): close the loop plainly ---
	"sacrifice_defiant_outcome_lair": {
		"title": "Back at the Lair",
		"image": "res://assets/story/sacrifice_defiant_lair.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "You flew Brannagh Thornwick back to your lair — still insulting your wingspan. She waits there now, among the gold. The wizard can train her as your dragon rider: visit his tower and choose \"Train Dragon Rider\" (10g).",
		"choices": ["Onward."],
	},
	"sacrifice_defiant_outcome_eat": {
		"title": "Brannagh Thornwick — Devoured",
		"image": "res://assets/story/sacrifice_defiant_jaws.svg",
		"tint": Color(0.42, 0.20, 0.18),
		"text": "Her fury burns like a forge in your belly. Your fire grows: +2 flame capacity. You can now hold more breaths of fire before you need to eat again.",
		"choices": ["Lick your lips."],
	},
	"sacrifice_courageous_outcome_lair": {
		"title": "Back at the Lair",
		"image": "res://assets/story/sacrifice_courageous_lair.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "You flew Ysolde of the Wolfrun back to your lair — clutching your neck with her eyes squeezed shut. She waits there now, among the gold. The wizard can train her as your dragon rider: visit his tower and choose \"Train Dragon Rider\" (10g).",
		"choices": ["Onward."],
	},
	"sacrifice_courageous_outcome_eat": {
		"title": "Ysolde of the Wolfrun — Devoured",
		"image": "res://assets/story/sacrifice_courageous_jaws.svg",
		"tint": Color(0.36, 0.26, 0.30),
		"text": "Her courage settles warm in your chest. Your fire grows: +1 flame capacity. You can now hold more breaths of fire before you need to eat again.",
		"choices": ["Lick your lips."],
	},
	"sacrifice_cunning_outcome_lair": {
		"title": "Back at the Lair",
		"image": "res://assets/story/sacrifice_cunning_lair.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "You flew Vesna Silvertongue back to your lair — pricing your hoard out loud. She waits there now, among the gold. The wizard can train her as your dragon rider: visit his tower and choose \"Train Dragon Rider\" (10g).",
		"choices": ["Onward."],
	},
	"sacrifice_cunning_outcome_eat": {
		"title": "Vesna Silvertongue — Devoured",
		"image": "res://assets/story/sacrifice_cunning_jaws.svg",
		"tint": Color(0.30, 0.34, 0.26),
		"text": "Her cleverness crackles in your gut. Your fire grows: +1 flame capacity. You can now hold more breaths of fire before you need to eat again.",
		"choices": ["Lick your lips."],
	},
	"sacrifice_devout_outcome_lair": {
		"title": "Back at the Lair",
		"image": "res://assets/story/sacrifice_devout_lair.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "You flew Sister Aldith back to your lair — praying loudly the whole way. She waits there now, among the gold. The wizard can train her as your dragon rider: visit his tower and choose \"Train Dragon Rider\" (10g).",
		"choices": ["Onward."],
	},
	"sacrifice_devout_outcome_eat": {
		"title": "Sister Aldith — Devoured",
		"image": "res://assets/story/sacrifice_devout_jaws.svg",
		"tint": Color(0.28, 0.32, 0.40),
		"text": "Something faintly holy flickers in your belly. Your fire grows: +1 flame capacity. You can now hold more breaths of fire before you need to eat again.",
		"choices": ["Lick your lips."],
	},
	"sacrifice_brute_outcome_lair": {
		"title": "Back at the Lair",
		"image": "res://assets/story/sacrifice_brute_lair.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "You flew Horrik Bearhug back to your lair — whooping like a man on his first pony. He waits there now, among the gold. The wizard can train him as your dragon rider: visit his tower and choose \"Train Dragon Rider\" (10g).",
		"choices": ["Onward."],
	},
	"sacrifice_brute_outcome_eat": {
		"title": "Horrik Bearhug — Devoured",
		"image": "res://assets/story/sacrifice_brute_jaws.svg",
		"tint": Color(0.32, 0.30, 0.26),
		"text": "All that muscle feeds the fire. Your fire grows: +1 flame capacity. You can now hold more breaths of fire before you need to eat again.",
		"choices": ["Lick your lips."],
	},
	"sacrifice_thief_outcome_lair": {
		"title": "Back at the Lair",
		"image": "res://assets/story/sacrifice_thief_lair.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "You flew Corvin Nimblefoot back to your lair — trying to pick the lock on your saddlebags. He waits there now, among the gold. The wizard can train him as your dragon rider: visit his tower and choose \"Train Dragon Rider\" (10g).",
		"choices": ["Onward."],
	},
	"sacrifice_thief_outcome_eat": {
		"title": "Corvin Nimblefoot — Devoured",
		"image": "res://assets/story/sacrifice_thief_jaws.svg",
		"tint": Color(0.26, 0.28, 0.34),
		"text": "Somehow he's stolen a spark for you. Your fire grows: +1 flame capacity. You can now hold more breaths of fire before you need to eat again.",
		"choices": ["Lick your lips."],
	},
	"sacrifice_renegade_outcome_lair": {
		"title": "Back at the Lair",
		"image": "res://assets/story/sacrifice_renegade_lair.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "You flew Garreth the Outcast back to your lair — glaring down at three kingdoms. He waits there now, among the gold. The wizard can train him as your dragon rider: visit his tower and choose \"Train Dragon Rider\" (10g).",
		"choices": ["Onward."],
	},
	"sacrifice_renegade_outcome_eat": {
		"title": "Garreth the Outcast — Devoured",
		"image": "res://assets/story/sacrifice_renegade_jaws.svg",
		"tint": Color(0.32, 0.26, 0.28),
		"text": "His grudges burn long and hot. Your fire grows: +1 flame capacity. You can now hold more breaths of fire before you need to eat again.",
		"choices": ["Lick your lips."],
	},

	# --- rider upgrade story (2026-11-11) ---
	"rider_upgraded": {
		"title": "The Archer's Oath",
		"image": "res://assets/story/story_rider.svg",
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
	# One-answer chapters (meals, outcome reports) just continue.
	var count: int = STORIES[kind]["choices"].size()
	hint_label.text = "Press 1 or ESC to continue" if count == 1 \
		else "Pick an answer (1-%d • ESC for the last line)" % count
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
