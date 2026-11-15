# The aftermath: the glade, the deer, the Prince — and the invasion (prepared)

Date: 2026-11-15.

## User spec

"When the King is slayed, spawn a beautiful glade. In the glade spawn deer
every 10s up to max 3 which can be hunted and eaten for +2 flame recharge
and +20 health. Also spawn the Prince, the son of the King, who looks like
the adventurer but with a nice cape. If Dragon meets with him using her
human form, spawn a story popup — your best impression of a Disney flirt
dialogue. They don't kiss the first time (they could reject each other),
but the prince will respawn near the city. The second time the flirting
leads to a kiss (or rejection). The kiss triggers the next phase: the
invasion. Don't implement this, but prepare for it: 200 soldiers + a King
invade and kill everything (farmers and miners). If they succeed the game
ends — the cycle has repeated and the Dragon failed. If the Dragon kills
the invasion she can marry the prince and become queen."

(Read "they don't kill the first time" as "kiss" — confirmed by the next
sentence.)

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| King's last fall | No longer ends the run: no `run_finished`, no VICTORY banner. `GameManager.phase` REALM → AFTERMATH; `king_defeat` chapter, then "Where the Crown Fell" | The story continues into the courtship and the invasion | — |
| Phases | `GameManager.Phase { REALM, AFTERMATH, INVASION, ENDED }`, `phase_changed` signal | One switch for everything phase-dependent | — |
| The glade | `Glade.tscn` at open ground far from every landmark (random candidates scored by distance to the nearest landmark, meadow radius clear on the nav grid): ground decal (meadow, wildflowers, spring, mossy stones, fairy ring) under the y-sort pool, breathing sunbeams, fireflies; a ring of 6 trees (real blockers; nav grid refreshed) | "A beautiful glade" | — |
| Deer | `Deer.tscn` (DeerRig: springy gait, grazing head, flicking tail; 35 % stags with antlers). One every 10 s, max 3, graze inside the glade, flee the dragon at 132 px/s (a walking dragon, 150, catches up). Fireproof (not part of the fire ecology) | User spec; a short chase, not a chore | — |
| Hunting | E on the nearest deer in strike reach (when it is nearer than any other E target): +2 flames, +20 health; first deer tells "The Hart of the Glade". Refused (deer lives) when the dragon could gain nothing — same rule as the pens | User spec | — |
| The Prince | `Prince.tscn`: the adventurer's build in ivory doublet, midnight hose, gold circlet, rapier, royal-blue cape with ermine collar (own pivot, sways with speed). Strolls near his home; flees the DRAGON (danger radius), never fights; fireproof and in no strike group — story-critical | "Looks like the adventurer but with a nice cape" | — |
| Meetings | Walking into him as the farm girl (34 px). Meeting 1 "Once Upon a Glade": flirt / play coy (HE retreats) / turn him down (SHE rejects; remembered) — no kiss; he moves to the city road. Meeting 2+: "Twice Upon a Time" (or "Second Chances" if she spurned him): kiss / reject (→ "The Well Road", back to the city, try again) | "Could reject each other"; the courtship never dead-ends | — |
| The kiss | "True Love's First Kiss" (he sees the slit pupils and doesn't let go; two hundred war-horns on Osric's ridge) → `begin_invasion()` | — | — |
| Invasion (PREPARED) | `begin_invasion()` → phase INVASION, `invasion_started` signal, `WorldManager.start_invasion()` (logged stub; consts INVASION_SOLDIERS 200, INVASION_WAVES 5), `invasion_townsfolk_left()` for the lose check. Endings ready: `invasion_won()` → "Long Live the Queen" + victory tally; `invasion_lost()` → "The Wheel Turns" + a fresh run. Chapter "The Second Purification" written for the invasion's start | User: "don't implement, prepare" | implementing the invasion |

## The invasion — implemented (2026-11-15, second pass)

User: "create the trigger for the invasion. Create a new building: the
invaders camp and spawn far away from the city so it becomes a tower
defense situation. After the kiss and hand holding let the invaders come.
Game over if the prince is killed. If the invading king dies, trigger the
evil wizard to attack, and if he is dead too trigger a storypopup for the
wedding... but... alas: [the last ember]". Also: "the dialogue can be
improved and be a little clearer on the intention".

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Courtship wording | Choices say what they mean ("Flirt with him. (You like him.)", "Play hard to get.", "Reject him.", "Kiss him. (Choose him.)", "Reject him. (Not yet.)"); every non-kiss outcome ends with where to find him next | "Clearer on the intention" | — |
| Trigger | The kiss → "The Second Purification" (the camp, the goal: keep the Prince alive, slay the usurper) → `WorldManager.start_invasion()` | — | — |
| Camp | `InvaderCamp.tscn`: flat compound like the city (palisade, crimson tents, Osric's sun banners, command pavilion, campfire), no collision; placed on walkable ground as far from the city as the map allows (and clear of the glade); waves leave from its gate | Tower defence: a long road to defend | — |
| Waves | 200 invaders in 8 ramping waves (10, 14, 18, 22, 26, 32, 36, 42), 40 s apart, first after 20 s; trickle 0.35 s apart; ≤ 30 alive at once. First tuning (8 × 25 every 28 s, ≤ 45 alive) wiped an undefended town out in under a minute | Learnable pressure, bounded NPC count | playtests |
| Invaders | `Invader.gd` (Soldier art in the usurper's crimson, 50 HP = two claws, flammable): march for the nearest Prince/farmer/miner (else the city), cut down whoever they reach (10 DPS), fight the dragon only within 140 px. Group "invaders" (not "soldiers") | Tower defence: they go for the people, the dragon intercepts | — |
| The realm stands down | At the invasion the town's soldiers retire to the city; recruiting, soldier purchases, townsfolk respawns, miner spawns and slayer arrivals pause | Their King is dead; and a respawning town could never be "wiped out" | — |
| The Prince | Moves to the city centre; 200 HP; runs from any invader within 110 px; still fireproof and unclawable. His death → "The Prince Falls" → new run | "Game over if the prince is killed" — but give the defender a fighting chance | — |
| Usurper | A King (King.tscn, `invader = true`): one life, 240 HP, rides with the last wave, hunts the dragon (storm, flaming sword). His fall routs the army (every invader retires to the camp) | "If the invading king dies…" | — |
| Reckoning | Phase RECKONING: the evil wizard turns (or already has) and attacks — "The Usurper Falls"; if he is already dead, "The Usurper Falls" (quiet) goes straight on | User spec | — |
| Endings | Wizard slain → "The Wedding" (in the glade) → "The Last Ember" (the user's text, verbatim) → victory tally → new run. Townsfolk all dead → "The Wheel Turns"; Prince dead → "The Prince Falls"; both → new run | User spec | — |
