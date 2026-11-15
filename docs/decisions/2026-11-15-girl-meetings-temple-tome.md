# The girl's meetings: the hag, the adventurer, the wizard — the Temple of the Dragon Queen, the Ember Tome, Greater Flame

Date: 2026-11-15.

## User spec

"We need to add some storypopup hooks when the dragon is in its human form.
Current policy is that she is attacked by soldiers and the king and turn
into a dragon. For the Hag, the same thing should happen if and only if the
Hag wasn't attacked during the visit in her house. Hag will still attack the
dragon because she is a Hag. If the human form dragon encounters the
adventurer, she can let herself be seduced (3-level decision tree and
animate bees and flowers, litterally, for the symbolic meaning). This cause
the adventurer to reverse his stealing and he is now stealing from the city.
But the soldiers will also attack him. When the human form dragon meets the
Wizard we also need a Storypopup. The wizard doesn't recognise the dragon,
but he recognise her as belonging to a people long gone and provide the
background story told in the book at the Hags house. He then offers a
quest: Find the magic tombe of the dragon sorceress who ruled that people.
This should spawn a new building near the dragon lair, Temple of the Dragon
Queen. Upon entering the temple either as dragon or human, she recognise it
from a dream, find a secret entrance beneth the ruins and gain the tombe. If
she returns the book to the wizard he turns evil and tries to kill her to
get the book. If she keeps it until the second wave of the invasion, she
will learn automatically Greater flame, that is twice as long and leave
fires on the ground for 5s killing anyone who moves into them."

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Meeting trigger | `Dragon._check_meetings()`: walking within 34 px of the hag / the adventurer (girl only) or the KIND wizard (girl, or either shape carrying the tome). Fires on first touch, re-arms after stepping 70 px away — standing beside someone never reopens a popup | Same feel as the prince; no popup loops | — |
| "Attacked during the visit" | = the "Nice try, hag. YOU die." answer over tea (`story_flags.hag_attacked_at_house`). Wounds dealt outside the house don't count | The visit is the tea scene; that answer is the attack | if "attacked" should also mean damage dealt while inside the house box |
| Hag, not attacked at tea | "Waste Not": she smells the dragon on the girl, unmasks (hostile even if befriended — "because she is a Hag"), the dragon tears out | User spec | — |
| Hag, attacked at tea | No chapter, no forced change; HUD line "she knows that face". She is hostile anyway and hunts the dragon in her territory | "if and only if" | — |
| Adventurer courtship | Named Corvin Larkspur. L1 `adventurer_meet`: flirt / banter / walk on. L2 `_flirt` or `_banter`: walk the lane / ask about the backpack / leave him wanting. L3 `_moment` or `_backpack`: be seduced / not today. Seduced → `adventurer_bees` → `adventurer_turned`. Every "no" ends the meeting; he can be met again | 3-level tree; Disney-flirt tone; never a dead end | — |
| Bees and flowers | `adventurer_bees` has `"animation": "bees"`: `BeesAndFlowers.gd` (a Control over the story image, runs while paused) — a bee loops in, the shy pink flower leans toward it, pollen bursts, the flower blushes, hearts float up, the bee wobbles off. 9 s loop | "Literally, for the symbolic meaning"; the text fades to the meadow, nothing explicit | — |
| The outlaw | `Adventurer.turn_outlaw()`: group "outlaws", 90 HP (2-3 soldiers kill him: 2 lose one man, 3 lose none), activities haul_to_lair (any carried gold → `stash`) › rob_city (whole TOWN TREASURY at the north gate) › lurk between city and lair. Never hits the dragon; fights back against soldiers. Runs with the sack at 100 (soldiers 80) | "Reverse his stealing … stealing from the city" | — |
| Soldiers hunt him | `Soldier` activity `hunt_outlaw` (prio 55, soldiers + the King, not archers/hag/heroes/garrison): sight 380 px, only within 650 px of the city; a sneaking outlaw (empty-handed on the way in) is only seen at 70 px. Contact DPS as on the dragon | "The soldiers will also attack him"; first probe (sight everywhere, 120 HP) killed him at the gate before the first coin | balance after playtests |
| Wizard meets the girl | Only while he is kind. `wizard_girl_meet` (he doesn't know her; knows the eyes) → `wizard_girl_lorindel` (the book's history, told by him) → `wizard_girl_quest` (Queen Ysolde's Ember Tome) → `WorldManager.spawn_dragon_temple()` | User spec | — |
| The temple | `DragonTemple.tscn` (walkable ruins, no collision; footprint registered) 250–380 px from the lair, south first, ≥260 px from the hag's fen. Entering (either shape) → `temple_enter` (the dream) → `temple_secret` (the hidden stair) → `temple_tome` (`story_flags.has_tome`) | User spec | — |
| Returning the tome | `wizard_tome_offer`: give → `wizard_tome_betrayal`: the tome burns his hand and STAYS with her; he turns (`force_wizard_turn`, tower barred, `wizard_emerge` suppressed — this chapter tells his fall) and hunts her; the girl turns back into the dragon. Keep → `wizard_tome_kept`; he asks again only when the girl visits | "Tries to kill her to get the book" implies she still has it | if returning should cost her the tome / Greater Flame |
| Greater Flame | At the invasion's wave 2 (or at once if the tome is found later in the invasion) while she holds the tome: `Dragon.learn_greater_flame()` — `fire_reach` ×2, drawn flame ×2 long; while breathing a `GroundFire` patch drops every 0.09 s along the cone (max 60). Patches burn 5 s; any living NPC whose feet enter one takes 9999 dragon fire. Chapter "Greater Flame" | User spec | — |
| Who the ground fire kills | Everyone who walks, the Prince and townsfolk included ("anyone"). The dragon slayer is fireproof by design and walks through. The dragon is never hurt | "Killing anyone"; existing fire immunity kept | if friendly fire costs too many runs |
