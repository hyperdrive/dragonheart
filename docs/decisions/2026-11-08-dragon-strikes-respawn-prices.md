# Dragon strikes (E-kills), respawn food loop, gem pricing — decisions

Date: 2026-11-08. Companion to manual-eat-wizard-menu and behavior-system (same day).

## User spec

Some farmers stop farming and stand still. Flyovers must not kill miners — only
an E-press does. Farmers can be killed with E too. Killing a miner or farmer
earns the dragon 5 health. Killing a miner carrying gold/gems steals them.
Cows/pigs should respawn as soon as farmers deliver food (consuming the food).
Upgrade costs are too steep, and some items should cost gems, not just gold.

## Diagnosis + fix (stall & pens share one root cause)

World is 1600×1600 with 20px boundary walls at ±800 x/y; the walkable interior
band is ±720 (margin 80). The export defaults predate the margin rule:
`cow_pen=(260,820)` sits OUTSIDE the band, pig_pen=(−260,760) drives farmer
spawn jitter into the wall pocket, and field jitter (up to ±23×12px in
`_terrain_free_position`) escaped the old ±~720 anchor clamp — fields landed at
y≈845–866 behind the south wall. Farmers pendulate at y≈774–830 forever
(velocity dithers, distance never closes); the pen-refill loop and pen access
starve with them.

Rule: **every anchor, spawn jitter and placement candidate is clamped into the
interior band minus its own footprint radius** (`_clamp_to_interior`,
`WORLD_MARGIN = 80`). Landmark exports are pre-clamped in `_ready` before world
generation; `_terrain_free_position` clamps each candidate with `self_radius`.

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| E semantics | Single context action: nearest valid target of {pen→eat, farmer/miner→kill} within its own reach wins | One key, unambiguous priority by distance | distinct keys desired |
| Flyover interception | Steal-only — `attempt_interception` never calls `take_damage`; `Miner.intercepted_by_dragon` loses its 40 damage (keeps the mining cooldown panic) | Miners die ONLY to an explicit E-press (user spec) | player asks for range pressure |
| E-kill payload | `steal_payload()` runs BEFORE `kill_by_dragon()`, routed into the claws via `take_loot` | Loaded miner = instant loot; burn-out spill path never triggers (flags cleared) | drop-on-kill wanted |
| Kill reward | +5 health per E-kill (capped at max, granted even at full health) | Chosen for both farmer and miner | different values per tier |
| Burned targets | E-kill on a burning NPC: fire flags cleared, dies via the deliberate path (no extra spill) | Deliberate death ≠ burn-out death | |
| Pen refills | After EVERY food delivery: loop BOTH pens until empty slots are filled or food < 20 | One-refill-per-delivery starved slots; "respawn as soon as farmers deliver food" | refill cost retune |
| Price scheme | Per-item `{"gold", "gems"}`; gems part is a HARD requirement; the gold part may use spare gems as 10:1 top-up (legacy `_pay_stash` rule) | User wants gems to matter, not be interchangeable | dual-currency contested |
| New prices | flame_1 20g, flame_2 40g+2 gems, shield 15g, speed 25g, range 30g+1 gem | "too steep" — roughly halved; gem-gated items are the big ones | any ledger drift |
| Menu display | Price strings show `Ng` / `Ng + Ngems`; affordability via `GameManager.can_afford_wizard` | One affordability rule, shared by menu and purchase | |

## Open / deferred
- No soldier-kill via E yet (soldiers fight back; strike scope = economic townsfolk only).
- Killing raises no alarm — economy-only consequences (behavior-system record holds).
