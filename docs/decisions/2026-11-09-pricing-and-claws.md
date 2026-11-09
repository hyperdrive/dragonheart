# Shop reprice + wizard greedy trigger + dragon claw swing — decisions

Date: 2026-11-09. User: "Give dragon claw attack animations. Lower the
cost of claw attack upgrades so this can be gained at 8g. Lower prices
for all upgrades. Set backstabber wizard to attack at 20g in stash."

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Claw animation | code-driven one-shot on a new `ClawPivot` (Dragon.tscn): `CLAW_SWING_TIME` 0.26s — raise −52°, slam +26°, ease back to 0; bone-claw glint warm right at impact; 7px body lunge (`vis.position.x`, free since flight only writes `.y`) | Same pattern as the soldier pickaxe swing and King sword swing (code-driven pivot animation on rect primitives); the AnimationPlayer already owns Sprite position/rotation |
| When it plays | every E-strike ATTEMPT — `_strike_soldier` (before the lottery: a miss still shows the swipe) and `_strike_kill` | "Claw ATTACK animations" = the attack action, not the outcome; a miss with no swing would feel like lag |
| Claw upgrade price | `brute` (Brute Force +5% soldier-strike odds, repeatable to 35% cap) ↓ 20g → **8g**, 0 gems | The exact ask: the claw attack upgrade gainable at 8g |
| Price floor for the rest | flame_1 20→10, flame_2 40+2gems→20+1gem, shield 15→8, speed 25→12, range 30+1gem→15+1gem | Flat ~40–50% cut everywhere; the two gem prices keep value but only flame_2/range still need one — with doubled miner hauls the shop turns over much faster at the same coffer pressure |
| Wizard greedy trigger | `wizard_stash_trigger` 30 → 20, and the check changed from STRICT `>` to `>=` so it fires AT 20g | User: "attack at 20g in stash" — the wizard strikes when the hoard HIT 20, matching an at-value reading of the ask |
| Death safety | `die()` resets claw pose, glint, and lunge (like the flight visuals) | Death mid-swing must not leak a rotated claw or lingering offset into the death animation |

## Interaction notes

- Re-price interacts with the miner haul doubling (same day): treasure
  volume ≈ doubled AND prices ≈ halved → the shop's 3-upgrade wizard
  provocation gate arrives much faster now; the wizard emerges with less
  accumulation. Accepted — user is driving both knobs.
- 8g repeatable brute is the cheapest repeat purchase: with a 35% cap the
  cap now costs 8×7 = 56g total (was 140g) — the dragon's anti-soldier
  tool comes on line long before the King.

## Verified

`probe_pricing_claws.gd` 12/12: brute at exactly 8g and the full reprice
schedule asserted; 8g buys brute (odds up, stash drained to 0) and the
shield; a 7g dragon is refused without half-payment; stash 19 spares the
wizard, stash 20 angers him (>= semantics); the claw swings on E-strike
attempts (rotation delta between samples regardless of the lottery
outcome), the strike recharge is still paid, the one-shot eases back to
0° and the body lunge settles; a deliberate E-kill runs the swing too.
`probe_drill`-partner `probe_archer_wizard` re-run green after updating
its P3 to the new flame_1 price (10g). 14400-frame regression: **0
script errors**.

Probe gotcha: `wizard_spawned` lives on `WorldManager`, not
`GameManager` — writing it to the wrong hub threw mid-probe and killed
the coroutine (infinite headless sim; the harness timeout caught it).
