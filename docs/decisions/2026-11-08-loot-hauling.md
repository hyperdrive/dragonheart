# Dragon loot hauling: panic drops, pickup delay, lair banking — decisions

Date: 2026-11-08. Companion to `2026-11-08-behavior-system.md` (economy contracts
unchanged: two pools never mix) and `2026-11-08-directional-facing-cart.md`.

## Request

Miner drops his gold when the dragon comes too close (instead of only losing it
to a landed interception); dragon collects drops after a small delay; carried
loot must be delivered to the dragon's lair before it counts; pick a mountain
and draw symbols for the dragon's lair and the wizard tower.

## Decisions

- **Drop-on-flee via engine signal**: BehaviorTree emits `fled_from_dragon`
  once when the priority-0 escape starts; Miner's handler converts its payload
  into a `GoldDrop` node and empties the slot (cart hides). Rejected:
  drop-on-intercept (interception now covers only a miner caught while already
  fleeing-close) and engine-side drops for all NPC types (farmers keep walking
  food home; the gold economy is what's exposed).
- **GoldDrop entity**: Node2D + sprite (`gold.svg`/`gem.svg` by `res_type`),
  settle delay 1.2s (the "small delay" — loot scatters while the miner runs),
  90s decay if unclaimed. Self-contained: `settled` flag, group `loose_loot`.
- **Dragon claws ≠ stash**: all loot intake funnels through
  `Dragon.take_loot(res_type, amount)` — panic drops (distance scan in
  Dragon._process, one scoop per frame within 70px), the interception system
  (rewired), and landing on a mine. The stash only grows at the lair (`add_stolen`
  fires its existing `stash_changed` signal → HUD refreshes). Rejected: banking
  anywhere / pickup-to-stash shortcuts (they erase the hauling pressure).
- **Lair landmark**: `DragonLair.tscn` (StaticBody2D like other mountains for
  consistent blocking) with `lair.svg` — mountain silhouette, lit cave mouth,
  glowing hoard, dragon sigil, bone offerings. Exported `lair_position`
  (-620, 60) beside the mining district; banking radius 150 (outside the 58px
  collider, so you stand at the cave mouth, not inside the rock).
- **Wizard tower properly spawned**: was preloaded but never placed, and its
  scene used invalid `parent="WizardTower/Sprite"` paths (would have errored the
  moment it loaded) — rewritten with authored `wizard_tower.svg` (spired tower,
  glowing windows, floating orb, arcane octagram) at (520, -420), opposite the
  mining district. Upgrade purchases stay HUD-global for now (recorded deferred
  in the behavior-system record; making the tower mandatory is a later pass).

## Verification (headless, zero errors)

- Panic drop: dragon at 140px (inside 180 fear, outside 100 interception) →
  FLEEING, payload 0, one `GoldDrop` (gold/3) on the ground, stash/carried 0.
- Settle: drop `settled=false` immediately, true after 1.4s.
- Scoop: dragon at the drop → carried 3, drop freed, stash still 0.
- Banking: dragon at lair → stash gold 3, carried 0.
- Interception rewire: caught carting miner → carried gems 2, stash 0.
- Landmarks: lair + tower spawn at their exported positions; terrain clearance
  list includes both.
- Full-run regression: zero script errors, farmer deliveries flowing, miners
  mine/carry (no drops in a passive run — the dragon never approached).
