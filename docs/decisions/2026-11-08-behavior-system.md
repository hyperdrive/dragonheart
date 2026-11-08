# Behavior System & Economy — decisions

Game: survival RTS with TTRPG elements. Player = dragon. Town = farmers, miners, soldiers,
King. Farmers are the engine that enables cows/pigs; miners enable gold/gems and extra
soldiers. Miners' death slows gold/gem production but soldiers keep building.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | Foundation others build on | Cow/pig, soldier, wizard systems will plug into the same behavior + economy model | a system proves to need something the model can't express |
| Dragon conscience | Consequences (economy only) | Dragon *can* kill farmers / burn fields; crimes slow the economy (burned fields regrow slow, dead farmers cut food → support chain thins → less to steal and fewer supported miners) | a fear/escalation system is wanted |
| Soldier escalation | Crimes do NOT speed soldiers | Soldier build-up runs on its own rate toward the King threshold — punishing the dragon economy-wise, but not accelerating the boss | feedback desired |
| TTRPG touchpoint | Tiered levels now, dice later | NPC level tiers govern yields/speed; dice-roll checks deferred | designing the roll system |
| Treasury | Two pools | Miners deposit into the town treasury (grows); dragon intercepts/stores stolen gold & gems; dragon spends its stash at the wizard tower for flame/armor upgrades | co-op or town-playable mode exists |
| Endgame | Soldiers reach threshold → King attacks → final boss → victory ends run | Run ends with a tally (gold stolen, upgrade levels, time) | endless mode is wanted |
| NPC architecture | Code subclasses | Each NPC type is a GDScript subclass (current Farmer/Miner pattern confirmed); no .tres behavior configs | tuning-by-non-programmer becomes a requirement |
| Behavior engine contract (derived from code + foundation) | Synchronous per-tick behaviors returning `success` / `running` / `failure`; per-behavior cooldown in real seconds (delta-threaded); supported states tracked on the NPC via `current_behavior`; coroutines forbidden inside behaviors | Callable.call() can't await in Godot 4; the old sequence resets on frame-count decay broke progress entirely | parallel actions needed |

## Derived decisions (engine facts, tuned at implementation)

- Single source of truth for dragon progression: GameManager owns scales/fire levels and the
  dragon stash; Dragon node reads/requests. (Today both duplicate it.)
- Behavior trees keep executing a behavior until it reports success after doing its work —
  no more start-then-abandon cycling; per-behavior cooldowns owned by the tree.
- Food chain: farmer food output feeds support thresholds that gate cow/pig spawns and miner
  support (base: `Miner.check_support_conditions`), numbers live as @export on the subclasses.

## Open / deferred

- Cows/pigs entity model (livestock behaviors vs property resources) — deferred to those systems.
- Wizard tower spending flow (must the dragon fly to the tower to upgrade?) — deferred;
  currently upgrades are purchasable anywhere.
- Concrete tuning numbers: field regrow time, King threshold, soldier build rate, yields.
- Duplicate/dead files to remove (scenes use the `npcs/` and `dragon/` + `systems/` copies):
  - `scripts/objects/Farmer.gd` + `scenes/objects/Farmer.tscn`
  - `scripts/systems/GoldInterceptionSystem.gd` + `scenes/systems/GoldInterceptionSystem.tscn`
    (live copy: `scripts/dragon/GoldInterceptionSystem.gd`)
  - `scripts/town/TownResourceSystem.gd` (live copy: `scripts/systems/TownResourceSystem.gd`)
