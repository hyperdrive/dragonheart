# Dragon health model: contact DPS, ablaze soldiers, eating — decisions

Date: 2026-11-08. Companion to the behavior-system record (damage numbers are
balance knobs, contracts unchanged).

## Request

Dragon health 100; soldiers deal 10 damage per second while their hitbox
touches the dragon; dragon flame sets soldiers ablaze (random panicking, then
death); health rises when the dragon eats a pig or a cow.

## Decisions

- **Base health stays 100** (the existing progression may raise the cap via
  scales upgrades — balance decided there; eating heals only up to max).
- **Contact DPS, not discrete hits**: the soldier's "attack" activity now only
  drives the CHASE; damage lives in `Soldier._contact_damage` — while the
  hitbox is in reach (attack_range 60) it accrues `attack_damage` (10) per
  second as float debt and applies it in integer chunks (take_damage is int).
  Rejected: timer-based discrete strikes (bursty, and 15 per 2s contradicts the
  requested 10/s). Old `attack_damage: int = 15 / interval 2s` removed.
- **Ablaze is a status effect guarded for re-entry**: flame breath scanning
  (Dragon `_ignite_soldiers` — runs every physics tick while the breath window
  is open, cone test: distance ≤ 95 AND forward dot ≥ 0.25) calls
  `Soldier.catch_fire()`. Burning: behavior tree killed (soldier abandons
  orders), random direction every 0.25–0.45s at 1.4× speed, burn_damage 10/s
  chunked the same way, sprited tinted scorched. Burn **always** ends in death
  (burn_duration 3s) per the request. Rejected: flee-state reuse (soldiers
  must look disordered, not disciplined).
- **Eating lives on the pen, not the dragon**: `AnimalPen` component script on
  PigPen (+15)/CowPen (+25) — dragon in reach (80px) eats an animal; the sprite
  hides and respawns after 25s so the food chain replenishes. Dragon call
  `eat_food` already clamps at max health. Rejected: dragon-side scan of pens
  (pen knows its animals & respawns; the dragon stays a pure consumer).
- **HP chip on the top bar** (`HP n/max`) — health is now central gameplay; it
  is fed by the existing `dragon.health_changed` signal (damage and eating both
  emit it). Live at boot: "HP 100/100".

## Verification (headless, zero errors)

- Boot health 100/100 (probe).
- Lone soldier in contact for 1.0s → 9–10 damage (10 DPS exact in chunk-average;
  the earlier "20" reading was two ring-adjacent soldiers both in contact).
- Pig +15, cow +25, both clamp at max (full health → no overheal).
- Flame: soldier burned → panic speed 112 (80×1.4), behavior killed, dies when
  the burn runs out (~3.4s later, alive=false).
- HUD: HP chip reacts to damage (70/100) and eating (90/100).
- Full-run regression: zero script errors; passive economy unaffected.
