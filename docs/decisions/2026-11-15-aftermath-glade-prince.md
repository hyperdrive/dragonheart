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

## Invasion — implementation plan (next step)

1. `start_invasion()`: open "invasion_begins"; spawn a new King (the dead
   King's cousin) and 200 soldiers from the east edge in 5 waves.
2. Invaders hunt townsfolk (new target provider: nearest farmer/miner)
   as well as the dragon; a burning realm (fields) as they pass.
3. Lose: `invasion_townsfolk_left() == 0` → `GameManager.invasion_lost()`.
4. Win: every invader (and their King) dead → `GameManager.invasion_won()`.
5. Performance: 200 NPCs need the nav grid's cheap straight-line path and
   maybe staggered BT ticks — measure first.
