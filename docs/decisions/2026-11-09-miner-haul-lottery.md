# Miner haul-size lottery — decisions

Date: 2026-11-09. User: "lets allow for miners to sometimes drop 2-3
items 50% one time, 25% 2 and 25% 3."

## Decision

| Decision | Choice | Why |
|---|---|---|
| Where the lottery lives | the roll happens at the END of every mining trip — `Miner._complete_mine()` calls the new `_roll_haul_size()` and adds `npc_level × roll` to the carried payload | "Miners drop 2-3 items" is about what the SEAM pays per pickaxe haul; every downstream path (delivery, panic drop, flyover interception, E-kill steal) already transports whatever `payload_amount` holds, so no stealing/death code changes at all |
| Odds | `_roll_haul_size()`: randf < 0.50 → 1, < 0.75 → 2, else 3 | Exact user split |
| Tier interplay | haul = `npc_level × roll` (level-1 → 1/2/3, level-2 → 2/4/6) | Keeps the documented tier multiplier (`level_multiplier()`, +25% yield per level) meaningful instead of making the lottery cap everyone at 3; the BASE case the user asked for is exactly 1/2/3 |
| No other economy change | payload still grows trip-over-trip ("payload grows until delivery" rule untouched); the gold/gems split (0.7/0.3) rolls independently of the size roll | The user asked for richer hauls, not a different economy shape |

Expected value note: base trip yield moves 1 → 2.0 (1×0.5 + 2×0.25 +
3×0.25) — the treasury, dragon robbery payoff, and street spills all
roughly double in item volume. Soldier purchase pressure scales with it
(treasury drains faster, buys more) — accepted as the user's intent.

## Verified

`probe_miner_hauls.gd` 15/15: 120 direct rolls land 55/31/34 (1s in the
majority band, 2s ≈ 3s, both present); per-trip payload DELTA is 1–3
across 8 consecutive trips (payload CUMULATES until delivery — asserting
absolute assert would mislead); level-2 miner deltas stay in {2,4,6};
a 3-gold haul delivers whole (per the `resource_delivered` signal — a
treasury readback races the city's purchase drain in a live sim); a
3-gem haul lands as ONE GoldDrop of size 3 then frees the miner.
14400-frame regression: **0 script errors**, live prints show 1-item,
2-item, and 3-item collections.
