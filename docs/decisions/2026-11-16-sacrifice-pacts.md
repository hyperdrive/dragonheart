# The sacrifice tree and the riders' pacts

Date: 2026-11-16. Supersedes the three-stage "same options on every board"
negotiation (2026-11-14) and the defiant-only fire-rate row of
2026-11-10-sacrifice-system.

User: "The dialogue with the sacrifice must matter more. Lets make it into a
decision/expert system tree of three levels where the outcomes are train as
dragon rider, eat or leave. Leave does nothing - you can come back later, and
this ESC option should remain through the decisions. There must however be
some trade offs. … One can be bad at shooting (and we should be able to guess
it from the decision tree). Maybe each character before accepting should ask
something of the dragon, what it values, then accept on a condition."

## The tree

| Level | Board | Answers |
|---|---|---|
| 1 | The stake (`sacrifice_X`) | What can you do? → trial · Eat! → plea · Leave |
| 2 | The trial (`_trial`): the captive shows their aim, then asks what the dragon values | Gold · Fire · What is mine · Leave |
| 2 | The plea (`_eat_2`) | Eat! → last words · What can you do? → trial · Leave |
| 3 | The pact (`_pact`): the captive answers the dragon's value, then names their price | Swear it (train) · Eat! · Leave |
| 3 | Last words (`_eat_3`) | Eat! · Show me what you can do → trial · Leave |

- **Leave** is always the last answer, so ESC leaves. It changes nothing: the captive stays bound (`Sacrifice.rearm`), and once the dragon has gone 160 px away and comes back, the same board reopens.
- **The trial gives the aim away**: Brannagh splits the apple and the priest's hat; Garreth hits the stake's shadow and nearly the dragon's eye; Corvin hits a hay bale; Aldith won't touch the bow and heals a scratch instead; Horrik snaps the bow.
- **Values**: naming what the captive values most makes the rider *devoted*, and one broken term is forgiven. Gold: Vesna, Corvin. Fire: Brannagh, Garreth. What is mine: Ysolde, Aldith, Horrik.
- The old `_lair_2` and `_lair_3` boards are gone. The rider outcomes for Aldith, Horrik and Garreth were rewritten so they no longer contradict the new aims.

## The riders (`scripts/systems/RiderPacts.gd`)

| Captive | Aim (fire rate / hit chance) | Gift | Pact; on breach the rider leaves |
|---|---|---|---|
| Brannagh (defiant) | deadly 1.5x / 100% | — | With a soldier within 420 px, one must die every 10 s (the clock runs only while one is in sight) |
| Ysolde (courageous) | true 1.25x / 95% | — | Never kill a farmer or miner |
| Vesna (cunning) | fair 1.0x / 85% | +1 stash gold per soldier killed | Bank 25 gold every 5 min; on breach she leaves with 22% of the stash |
| Sister Aldith (devout) | none (never shoots) | +10 HP every 10 s, never above 50 HP | Slay the hag before the invasion (or within 5 min, if trained after it began); she points the way to the fen, which spawns it if not yet found. Kept: she stays and keeps healing |
| Horrik (brute) | none | Takes 25% of every WEAPON blow | A meal (pig, cow, deer, a captive) every 3 min; if the dragon is full, Horrik eats it |
| Corvin (thief) | poor 0.7x / 50% | +1 on every loot pickup | Never stay within 360 px of the city for more than 8 s |
| Garreth (renegade) | wretched 0.6x / 30% | Pact kept: +2 flame capacity, and he stays | Kill 10 farmers within 5 min |

Kills count when the dragon, her Greater Flame or her rider makes them, the
same sources as the body count. A missed arrow flies up to 70 px wide of its
target. The HUD shows the pact and its clock after "Dead: N" (♥ = devoted). A
broken pact opens "The Broken Pact" with the rider's own parting words. The
rider taking a killing blow (2026-11-16) also ends the pact.

## Probe

Leaving and coming back at both the stake and the pact boards (the devoted
reply is kept). The eat path takes three boards. Garreth's 10 farmers gave
+2 flames. Brannagh's forgiveness and then her breach. Aldith healed 20→30,
then 45→50 and no higher. Horrik turned a 20-point blow into 15, and a meal
reset his clock. Corvin left after 8 s by the city, and his light fingers
turned 2 loot into 3. Vesna's breach took 22% of the stash.

## Notices during play

User: "Please add warnings and info about pact during game play. If you are
granted a bonus, show it in a notice. If you are close to breaking the pact -
show it as a warning in the notice."

| Kind | Colour | When |
|---|---|---|
| info | pale gold | the pact is sworn (term + gift); Horrik fed; Garreth's farmer count; Brannagh's count reset; Corvin out of the city |
| bonus | green | Aldith mends (+HP); Vesna's finder's fee (+gold, summed); Corvin's light fingers (+1 loot); Horrik takes part of a blow; Vesna paid in full; a pact kept (Garreth's +2 flames, the hag dead) |
| warning | red | a clock passes a mark: Brannagh 5 s; Vesna 60 s / 20 s; Horrik 45 s / 15 s; Corvin on entering the city and at 3 s; Garreth 90 s / 30 s; Aldith when the aftermath begins (the war is near), when the invasion starts, then 120 s / 30 s; Ysolde when a farmer or miner is within 70 px (at most every 20 s); a forgiven breach |

- Warnings end with "Break it and <name> leaves" unless the rider is devoted.
- While a warning is due, the pact chip turns red, and it pulses when the warning appears.
- **Rolling window** (user: "make the notifications into a rolling window so that we see the last 4 notices"): the HUD's message line is now a log of the last four lines (`HUD._log`), newest at the bottom, older ones fading (alpha 1 / .86 / .74 / .62). Each line has a dark backing and leaves when its own time is up; a fifth pushes the oldest out; the same text again refreshes its line. Notices and plain messages share it, so the earlier "a warning holds the line for 2.5 s" rule was dropped.
- Frequent bonuses are throttled per kind.
