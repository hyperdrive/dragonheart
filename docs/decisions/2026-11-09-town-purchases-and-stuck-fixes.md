# Town purchases + stuck root causes — decisions

Date: 2026-11-09. Companion to `2026-11-09-stuck-monitor.md` (the
supervision watchdog itself) and `2026-11-08-dragon-strikes-respawn-prices.md`.

## User spec

1. Food should respawn cows/pigs — 18 food gathered brought back only one
   pig and one cow. 10 food should buy a pig, 20 a cow.
2. Treasury growth bought no soldiers: "If there is gold in the treasury
   we should always try to buy new soldiers." 2g = 1 soldier, 1 gem = 2.
3. NPCs still get stuck.

## Grilled answers (soldier economy)

| Decision | Choice | Why |
|---|---|---|
| Escalation timer vs purchases | BOTH: the 8s trickle continues (bare militia) AND treasury purchases stack on top | The dragon shouldn't win just by starving miners; purchases give the town real pressure |
| King trigger | soldiers_spawned ≥ 15 counting initial + trickle + BOUGHT (unchanged pacing, new supply mix) | Keeps the escalation curve recognizable |
| Spend cadence | Instant drain: every miner delivery + 1s heartbeat | "Always try" literally — parked miner money buys real pressure |
| Currency order | Gold first (2g=1), gems only when gold is dry (1g=2) | Protects gold-only shop items (Brute Force) from gem leaks |

## Pen pricing (no grill needed — user gave the numbers)

- `AnimalPen._ready` species-prices: pig 10 food, cow 20. Greedy refills
  were already instant-on-delivery — the bug was BOTH pens paying the
  20 default, so 18 food bought nothing new.

## StuckMonitor root-cause findings (forensic probes)

Forensic sampling (1s × 150–240s, dragon parked away) found the ladder
worked but had forgivable blind spots — all fixed:

1. **Unpinned trip goals**: soldier `patrol`/`idle` targets were bare
   `home ± jitter` — often INSIDE the city footprint (spawn home is the
   north-gate ring). An in-wall goal is unreachable by definition:
   proven streak of 99s+ in MOVING with endless forced detours, plus
   activity-stall teleport → still wedged (the user's "still stuck").
   FIX: `WorldManager.terrain_free_target()` (spawn-placement rules,
   140px city no-go ring) routes soldier/rally/patrol/idle targets.
2. **Rescue teleports didn't check terrain**: a rescue could drop an NPC
   into the very obstacle that wedged it. FIX: rescue landing = nearest
   terrain-free spot to the goal (new `nearest` mode on
   `_terrain_free_position`); when no clear spot exists near the goal,
   ABORT the trip instead of wall-dropping.
3. **FLEEING was unsupervised**: the movement ladder handled only MOVING;
   one miner crossed an entire run fleeing (state never changing) with
   zero coverage. FIX: the ladder covers FLEEING too.

## Open / deferred

- Farmer/Miner providers were already footprint-clean (fields/pens are
  placed by the registry); King inherits Soldier's fixed providers.
