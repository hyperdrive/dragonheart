# Flammable ecology: fire economy, animal-gated respawns, field burning — decisions

Date: 2026-11-08. Companion to dragon-health (burn status origin) and
behavior-system (economy-only consequences).

## User spec

All actors flammable; miner respawn needs a cow (farmer respawn a pig),
consuming it; cows/pigs return when farmers harvest, 20 food each, cap 4/4;
eating a pig +1 flame recharge of 4 max (cow +2); fields flammable and moved
farther from the city; food-laden farmers run from the dragon, stalling
delivery.

## Decisions

- **Burning hoisted into BaseNPC** (from Soldier): `is_flammable`,
  `burn_damage` (10/s), `burn_duration` (3s) exports; burning kills the
  behavior tree, random-burst runs at 1.4× speed with a scorched tint, and
  ALWAYS ends in death — now uniformly for farmers, miners, soldiers and the
  King (inherits through Soldier). Balance flag: the 200-HP King also dies
  when his burn runs out — his per-node exports can be retuned in
  King.tscn if the boss proves flammable-trivial.
- **Flame economy on the Dragon**: 4 charges max (export), −1 per breath,
  empty = quiet dragon (with a hint print). `AnimalPen.eat` calls the new
  `Dragon.eat_animal(heal, recharge)`: pig +1, cow +2, clamped (overfeed
  wastes the animal). Old `eat_food` (loose food) unchanged. Pen eating is
  PACE-LIMITED (one animal per 0.8s): hovering a pen no longer strip-mines
  every animal in a single frame, which the first probe run exposed (a
  dragon parked on a pen emptied both pens in ~30ms and starved the new
  respawn chain).
- **Pens are slot pools, not timers**: max 4 slots (scene sprites first,
  hidden slots extended from the first sprite's template), no 25s
  self-respawn. Two town operations: `consume_animal()` (dragon eating OR
  NPC-respawn stock check) and `respawn_animal()` (paid fill).
- **WorldManager mediates the farm→animal economy**: every farmer food
  delivery triggers one paid refill attempt per pen (20 food each from the
  town pool → scarcity rations stock). NPC deaths enqueue a respawn request
  ("farmer ← pig", "miner ← cow") that retries every 2s after a 10s delay
  until the matching pen can pay; soldiers/King don't respawn.
  Respawn position = the dead NPC's home anchor.
- **Fields flammable via the breath cone**: the Dragon's ignition scan
  (which was soldier-only) now sweeps farmers/miners/soldiers/king + the
  "fields" group → `Field.burn()` → stubble → slow regrow. Field.burn's old
  comment claimed the FireArea called it — nothing did; the cone scan is the
  single fire entry point now.
- **Fields pushed out**: ring radius 230 → 420 (city-centered), clamped
  inside an 80px world margin. Farmers walk farther; the farm belt becomes a
  real front line.
- **Loaded-farmer bailout**: `danger_radius` flips 120 (unloaded) → 220
  (food_carrying > 0) and flee speed multiplier to 1.3, re-evaluated per
  physics tick. Flee preemption already blocks the deliver activity, so a
  lurking dragon starves the delivery. Miners keep their always-on 180/1.3
  profile (they're a stealing target, not the spec's subject).

## Verification (headless, zero errors)

- Burn sweep: farmer/miner/soldier ignite → panic 112 px/s → all dead by
  burn-out (3s). Chip: "Fire 1 • N/4" tracks breaths/eats.
- Charges: 4 boot → breath −1 → pig +1 → cow +2 clamped at 4.
- Fields: ring at 400px from the city; cone hit → workable=false (stubble).
- Bailout differential: unloaded = MOVING at 150px, loaded = FLEEING,
  unloaded FLEEING again at 100px (<120).
- Respawns: farmer death → queued → null unless a pig is in stock; paid
  refills unblock ("Farmer respawned (a pig was consumed)!"); miner needs a
  cow (blocked, then resumed after the farm cycle bought a cow).
- Full-run regression: zero script errors; a passive run self-bought a pig
  back after deliveries crossed 20 food.
