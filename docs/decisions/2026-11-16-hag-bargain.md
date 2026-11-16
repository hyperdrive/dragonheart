# The hag's bargain: a child for the wizard's death

Date: 2026-11-16. Changes the "spare the hag" branch of the tea
(2026-11-14). That branch used to force the wizard to turn at once.

User: "turn the meeting with the Hag in her Hut into a pact as well, you get
five minutes to attack the wizard and turn him evil (ie wizard should be able
to take damage for this to trigger). If he is killed under five minutes the
Hag will grant her a child. This changes the ending, she lives until she gives
birth to a daughter, Ysolde, and then her ember dies."

| Decision | Choice | Why |
|---|---|---|
| Where | `hag_tea_warning` → "Spare her" → `hag_spared` is now "The Hag's Bargain": *Swear it. Turn the glass.* / *No bargains. Just go.* Both befriend the hag. Refusing forces nothing: Ambrose stays kind until something else turns him | The meeting becomes a pact |
| Wizard already dead | `hag_spared_late` ("The Hag's Shrug"): no bargain, no child | You cannot kill a dead man in time |
| The clock | `HagPact.gd`: 5:00 from the oath. It pauses while the game is paused (the clock runs on game time, like the rider pacts) | "five minutes" |
| Turning him | Any wound turns the kind wizard (`Wizard._on_damaged` → `turn_evil`). The wizard is now a claw target (`Dragon._soldier_in_strike_reach` includes the group "wizard"); fire already turned him | "wizard should be able to take damage for this to trigger" |
| Kept | Wizard dead with time left: `story_flags["hag_child"]`, a green notice, and 3.8 s later (after his death show) the chapter `hag_child_granted` | "the Hag will grant her a child" |
| Lapsed | A red notice; the bargain is void and nothing else changes | — |
| Notices | Opening info (term, prize, the shapeshift key); "Ambrose shows his true face" when he turns; red warnings at 2:00, 1:00, 0:30 and 0:10; HUD chip "Bargain: wound/kill Ambrose · m:ss", red from 2:00 | Same language as the rider pacts |
| Ending | With the gift, `ending_wedding` → `ending_daughter` ("Ysolde") instead of `ending_last_ember`: the ember holds on through winter and spring, she gives birth to a daughter named Ysolde after the queen of the tome, then her ember goes out; the run ends as before (roll of the dead, new run) | "she lives until she gives birth to a daughter, Ysolde, and then her ember dies" |
| HUD | Pact chips generalised: `HUD.set_chip(id, text, danger)`; the rider's chip is id "rider", the hag's is "hag" | Both pacts can run at once |

## Probe

The bargain sworn: chip and notice. Clock set to 10.5 s: warning, red chip,
lapse, bargain void, wizard still kind. Sworn again: the claws found the kind
wizard (80 → 55) and turned him; a 500-damage blow killed him with 4:57 left,
which kept the bargain. The gift opened after the wizard's own chapter.
`ending_wedding` → `ending_daughter`. With the wizard dead → `hag_spared_late`.
The bargain, the daughter's ending and the rider-pact boards were checked in
screenshots.
