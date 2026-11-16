# The body count, the graveyard, the ghosts

Date: 2026-11-16.

User: "introduce a body count. Every soldier, farmer, miner, adventurer and
dragon slayer should be counted. When the dragon dies they should be listed
with their name, age and occupation. Also if more than 10 people are killed
spawn a small graveyard. For every 3rd person that is an adventurer, farmer
or miner killed spawn a haunting ghost. It can't be killed but moves slowly
and in the vicinity of the graveyard. It will however suck all the flames
out of the dragon if she comes in contact with it."

| Decision | Choice | Why |
|---|---|---|
| Who counts | `BodyCount.COUNTED`: soldiers, archers and the usurper's invaders (all soldiers), farmers, miners, adventurers, dragon slayers | User's list; archers and invaders are soldiers too |
| Whose kills | The dragon's only: the killing blow's source is `"dragon"` (claws, breath, burning), `"greater_flame"` (ground fires) or `"rider"` (the rider's arrows). Deaths to wolves, invaders and goblins are not on her roll | It is her body count |
| Reporting | `BaseNPC.take_damage` reports the killing blow (`_report_death`) before `die()`, so subclasses that override `die()` are still counted → `GameManager.record_kill` | One place every death by damage passes |
| Identity | Made when they fall (`BodyCount.identity`): a first name and an occupation-flavoured surname (Thatcher, Delver, Pike, "the Bold", "Sir … Wyrmbane"), an age range per trade (farmers 14–68, miners 13–52, …); never two of the same name; plus the cause ("burned", "torn by your claws", "shot by your rider", "burned in the Greater Flame") | Name, age, occupation as asked; the cause makes the roll land |
| HUD | "Dead: N" after the wings chip | A body count you can see |
| The roll | `BodyCountRoll.gd`: "The Roll of the Dead" over the paused world after the run's last chapter (the dragon's death chapter, the prince's fall, the cycle, the last ember), every name in the order they fell, scrolling; "Let them rest." starts the new run. No dead: "Not one soul." | "When the dragon dies they should be listed" |
| Graveyard | At the 11th dead (`GRAVEYARD_AFTER` 10): `scenes/props/Graveyard.tscn`, a walled plot with a lychgate and a dead yew, 320–560 px from the city, away from the lair; one headstone or cross per dead (up to 28 shown), the newest with fresh mounds. Land-layer grade | "more than 10 people are killed" |
| Ghosts | Every 3rd adventurer/farmer/miner dead (`GHOST_EVERY`): `Ghost.gd`, the ghost of that person ("the ghost of Wilfred Plowright, farmer"). Raised before the graveyard exists, it waits and rises with it | User spec |
| Ghost rules | Not a BaseNPC and in no damage group: nothing can hurt it. Drifts at 18 px/s within 170 px of the graveyard. Touching the dragon (within 32 px; not the farm girl): every flame she carries streams into it (`Dragon.drain_flames`), it glows orange, the HUD names it; 2.5 s before it can drink again | "can't be killed but moves slowly … suck all the flames out" |
| Probe | 13 dragon kills plus one wolf kill: the wolf's isn't counted; graveyard at the 11th with the two waiting ghosts, a third ghost at the 9th farmer/miner; a touch drained 4 flames to 0; the roll lists all 13 after the death chapter | — |
