# Wandering Adventurer — decisions

The hero NPC (user spec 2026-11-12): spawns at the city every 5 minutes, walks to
the dragon's lair, kills goblins, and finally steals ALL the lair gold. Dragon
fire is the counter-play.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| NPC architecture | `Adventurer extends Soldier` (King subclassing precedent), Activity engine | Decision record 2026-11-08: code subclasses, no .tres configs; the user asked to base the NPC on the King | a second hero archetype needs shared hero behavior |
| Brave profile | `danger_radius = 0` (never flees), still flammable | A hero walks into the monster's den; the spec's counter is FIRE (burn-out kills regardless of HP via `BaseNPC._flames_teardown`), not panic-fleeing | the hero should fear something |
| Job order | hunt_goblin (prio 50, cooldown 0) → raid_lair (40) → haul_home (30) → idle | User spec order: "kill goblins and finally steal"; cooldown 0 on the hunt keeps lower activities from slipping in between chase legs | multiple heroes specialize |
| Raid gate | No living goblin within `lair_guard_radius` (500px) of the lair | The hunt's own cooldown gaps let the raid slip in between chase legs (probe-verified); the mountain is ~200px from the lair so the guards must fall first | goblins learn to bait the hero away |
| Loot definition | Drains `GameManager.stash["gold"]` to zero (gems untouched) | The stash IS the lair hoard ("banked at the lair"); the user spec is gold only | gems join the heist |
| Haul destination | Town treasury, then the hero despawns (no `die()`) | The hero returns stolen wealth; the town re-arms with it — emergent economy loop. Despawn means spawn-slot accounting must count by GROUP size, not death events | the hero retires in town instead |
| Goblin DPS | Independent `_goblin_debt` accumulator overriding `Soldier._contact_damage` | The inherited soldier flow feeds the goblin branch from the DRAGON-contact debt (`if _contact_debt <= 0.0: return` precedes the goblin loop) — soldiers practically never kill goblins; the hero's core job needs his own blade | soldier-vs-goblin combat is meant to stay decorative |
| Death loot | Spills the payload as a loose GoldDrop (Miner precedent), no town alarm | The dragon can scoop his stolen haul back; `report_loot_spill` is a town-streets signal and the hero usually dies at the lair | the spill should alarm the town |
| Interception | `GoldInterceptionSystem` carrier scan includes the `adventurers` group | Payload-slot rule is universal: what a carrier holds, the dragon can steal | other carrier types appear |
| Spawn | WorldManager timer 300s (exports `adventurer_spawn_interval` / `adventurer_max_alive` = 1) | User spec "every 5 minutes"; one hero at a time — the raid drains ALL gold, overlapping heroes double-walk to an empty rock | hero parties wanted |
| StuckMonitor | Adventurers join the audit loops | The hero walks the whole map through scenery; supervision keeps the trip alive | — |

## Derived facts (probe-verified, scenes/probes/AdventurerProbe.tscn)

- The hero clears goblins before raiding; the raid drains the whole stash gold;
  the haul lands in the treasury and the hero leaves; fire kills him mid-haul
  and spills the loot.
- Terrain-clearing matters twice over: an uncleared idle jitter parked the hero
  against the goblin mountain for 50s, and an uncleared hunt pick stalled 30s
  against the same rock (both now route through `terrain_free_target`).

## 2026-11-13 update (user spec)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Spawn trigger | The hoard itself calls the hero: `GameManager.stash_changed` (gold ≥ `adventurer_gold_trigger` = 10) spawns instantly; the 300 s timer is removed | User spec "as soon as there are 10gp in the treasure"; event-driven — no polling, no 5-minute delay; a raid zeroes the hoard so the hero only returns once the dragon re-banks the trigger | periodic pressure is wanted again (e.g. hoard is empty too long) |
