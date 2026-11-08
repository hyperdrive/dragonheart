# Soldier strike (E kill chance) — decisions

Date: 2026-11-08. Companion to dragon-strikes-respawn-prices (same day).

## User spec

A chance of killing a soldier with E: 15% per strike with a 0.5s recharge,
upgradable +5% per repeated purchase; the "speed" upgrade lowers the
recharge to 0.2s.

## Decisions (grilled)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Chance item | Own shop row "Brute Force", repeatable | Separate progression from the boost | two candidates won't shop |
| Price | 20 gold, gold-only | Cheapest ladder rung — risk is its own cost | strike becomes dominant |
| Cap | 35% (15 → 5×4) — refused while capped, no payment taken | A 50% death lottery would trivialize the swarm | swarm size raised |
| Speed → recharge | FIRST Speed buy ever drops the strike recharge 0.5s → 0.2s permanently; later buys only refresh the run boost | One knob, one unlock; matches Speed's "refresh" semantics | faster cadence desired |
| Failed strike feedback | Threat chip flashes red (new `strike_missed` signal); recharge still ticks | User pick; silent misses read as lag | — |
| Cooldown behavior | While on cooldown, soldiers are NOT valid targets — E falls through to pens/other NPCs | Recovers food/strike variety without waste | per-target cooldowns |
| King | NOT strikable (excluded despite sharing the "soldiers" group) | Boss has his own battle rules | boss phase design |
| Kill reward | No health grant on soldier kill (unlike townsfolk's +5) | Risk asymmetry: soldiers retaliate | user asks |

## Open / deferred
- No soldier AI upset from failed strikes (they already retaliate in reach).
