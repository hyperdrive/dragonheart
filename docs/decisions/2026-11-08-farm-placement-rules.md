# Farm placement rules: single-farmer fields, gold regrow, tame dragon meals, non-colliding terrain

Date: 2026-11-08. Companion to flammable-ecology (same day) and behavior-system.

## User spec

Only ONE farmer may farm one field at a time. Fields can respawn when the
city gets gold. Dragon gets only 5 health from a pig and 10 from a cow.
Unless the dragon is healed he gets NO flames back. Bug: terrain and fields
collide randomly and shouldn't.

## Decisions

- **Claim lease on the Field** (not a matchmaking service in the world):
  `claimant_id` + `claim_expires` (Time.get_ticks_msec). Lease length =
  (tend_work_time × level + 14s), covering walk + work + flee slack. Reasons
  for the lease over a hard lock: abandonment paths (flee preemption,
  mid-tend burn, death) must never permanently lock a plot — the lease
  self-heals. Alternatives rejected: WorldManager mutex (another hub
  responsibility; the provider already caches the field node), and
  farmer-side "occupied by" scanning (N×N churn). `release()` is idempotent
  and claimant-checked.
- **Release paths**: completion (`_complete_field_tend`), death
  (`Farmer.die` override), and BehaviorTree `state_changed` — the farmer
  drops a stale claim whenever the tree leaves MOVING/WORKING (flee
  preemption, abort-on-burnt-gate). The hook ignores MOVING/WORKING so the
  pick→commit transition doesn't drop a fresh claim.
- **Gold regrows fields, one per delivery** (RP: the treasury funds new
  sowing): `_on_resource_delivered("gold")` → regrow the first STUBBLE field
  (`Field.regrow()`, instant GROWN, stops the RegrowTimer). Food and gem
  deliveries explicitly do NOT regrow (verified negative). The slow natural
  regrow timer still exists underneath — gold is a fast lane.
- **Tame meals**: pig heals 5 (was 15), cow heals 10 (was 25), scene values.
  Flame recharge is now GATED on healing: `Dragon.eat_animal` grants charges
  only when `healed > 0` (partial heal of a nearly-full bar still counts).
  A full-health dragon still eats (consumes) the animal — it visibly
  snacked — but gains nothing beyond a hint print. Interpretation kept
  literal to the rule "unless he is healed he can't get any flames back".
- **Non-colliding placement — unified footprint registry**: WorldManager
  keeps `_terrain_clearances` (position+radius dicts) grown as the world is
  generated. Landmarks (city 120, pens 85, lair 100, tower 75), fields
  (55), mines (30) and scenery (tree 30, lake 85, mountain 80) all register
  before/at placement; every later placement (scenery, then mines) jitters
  against the FULL registry with self_radius + other_radius + 30px margin
  (`_terrain_free_position`). Why a registry instead of pairwise scene
  collision: world generation is sequential and cheap, and placement-time
  rejection avoids physics-layer workarounds (moving plots post-hoc).
  Fields keep the 420px ring (city-centered, 80px map-margin clamp); when
  edge-clamping pulls a plot inside the ring, the registry clearance
  (≥ city 205px) still holds. Scenery's protected list is now dict spots
  `{"pos", "pad"}` (dragon start clearing); the per-spot radius bookkeeping
  lives entirely in the registry.
- Probe-verified boundary cases: two farmers on the same nearest field pick
  different plots; an all-plots-claimed world yields TARGET_NONE (idle, no
  crash); lease expiry frees the plot without the farmer doing anything.

## Verification (headless, zero errors)

- Claim exclusivity + TARGET_NONE-on-full + lease expiry + release, direct
  provider probes on tree-killed farmers.
- Gold regrow + food/gem negative controls.
- Eat rules: full-health → charges unchanged + hint print; hurt pig →
  +5/+1 (clamped heal); hurt cow → +10/+2 clamp at 4; partial heals grant
  charges.
- Placement: 6/6 randomized layouts clean (field-field ≥ 140, fields vs
  landmarks/mines/scenery ≥ registry margins, field-city ≥ 205); two probe
  false-positives found and tightened along the way (farmers aren't
  scenery; in-code boundary walls are excluded — fields intentionally sit
  inside them).
- Full-run regression (quit-after 3000): zero script errors; live
  tend→deliver→treasury cycles observed.
