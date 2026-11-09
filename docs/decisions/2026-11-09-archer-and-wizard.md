# Archer + backstabbing wizard + tower revisit — decisions

Date: 2026-11-09. Follow-ups to `2026-11-09-king-lives-and-swing.md`.

## User spec

1. New NPC: **archer** — a soldier with a range attack; fires when in
   range of the dragon, 1 per 2s; 5 damage; never misses a dragon that
   doesn't move.
2. New NPC: **wizard** — exits his castle when the dragon has purchased
   3 upgrades AND visited more than 3 times, OR has more than 30g in
   his treasure. Shoots lightning: 30p, long range, 2s recharge; has a
   shield like the King; "the backstabbing wizard won't stop until he
   killed you."
3. "Make sure dragon can enter the tower to buy 3–4 separate times."

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Archer architecture | `class_name Archer extends Soldier` — same profile (50 HP / 80 speed / never flees / morale + bold phalanx / counts toward the King threshold via `_escalation_soldier_spawned`), with `_contact_damage` replaced by a projectile channel | A range soldier is a soldier variant; the repo's registered-activity NPC layer already gives movement/patrol/morale for free |
| Fielding | every THIRD fielded recruit is an Archer (`_next_recruit_type()`, applied per-unit in both the 8s trickle and treasury purchases) | Keeps the escalation curve intact (soldiers still dominate) while the archer corps grows continuously — user wants them "always" among the soldiers |
| Firing cadence | `_tick_ranged_fire` on the Archer's own `_physics_process`, INDEPENDENT of the BehaviorTree — 1 arrow / 2s whenever the dragon is within `arrow_range` 350px, 5 damage | "He fires when in range" is a weapon rule, not a morale rule; a calm-town archer must still shoot an in-range dragon |
| Never-miss rule | the Arrow is a straight-line projectile aimed at the dragon's CURRENT position at fire time (no tracking); a stationary dragon stands exactly where the arrow is going; a moving dragon dodges for free | Exactly encodes "1/2s damage 5 but if the dragon doesn't move he never misses" with zero special-casing |
| Stand-off | `_pick_dragon_target` holds a ring `arrow_range − 60` from the dragon instead of closing to contact | Walking INTO breath-melee while "ranged" would be suicide puppetry; the ring keeps the fantasy and the kiting look |
| Wizard architecture | `class_name Wizard extends Soldier` with ALL attack gates unlocked (`_attack_ready`/`_dragon_in_chase_range` = dragon exists, whole-map target) and `_contact_damage` replaced by the lightning channel | "Won't stop until he killed you" = morale/swarm states are irrelevant to him; the Soldier chase locomotion handles the relentless pursuit |
| Emergence triggers | counters on GameManager (single state hub): `tower_visits += 1` on every tower door opening, `upgrade_purchases += 1` on every successful purchase; WorldManager checks every frame: `(purchases ≥ 3 AND visits > 3) OR stash.gold > 30` → spawns the Wizard at the tower, prints the emergence | User's exact gates; the OR-greedy path means an untaxed rich dragon gets hunted too |
| Lightning | instant bolt at 500px reach: 30 damage through `dragon.take_damage` (scales reduction applies), 2s recharge, Line2D flash visual freed by a SceneTreeTimer (synchronous — no coroutines in NPC code), print each hit | "Lightning is instant by nature" — no projectile dodge realism; the recharge is the only relief |
| Wizard shield | `fire_immunity_seconds = 5.0` — the same generic cloak the King uses (burn inside the window, re-ignite re-arms), with his own shield print | "a shield like the king" — reuse the tested mechanic, zero new code paths |
| Tower re-entry | kept the existing exit-reset guard AND added the visits counter with per-visit print; WizardMenu still opens on every entry (world paused beneath) | The loop "enter → buy → leave → come back" is the intended shop UX; nothing may monetarily or mechanically close the tower off |

## Probe notes (for next time)

- Disarm ALL wizard triggers before phase cleanup: `_try_spawn_wizard`
  runs every frame, so a leftover trigger (stash 31) instantly
  re-spawns a freed wizard ("P1 ghost" in the first probe run).
- A dragon parked in the city band flips swarm RALLY→ATTACK and
  released soldiers hunt across the WHOLE map — range/accuracy windows
  must reset the swarm to CALM and stash plain soldiers at a stub
  corner, or soldier contact DPS pollutes weapon-delta measurements.
- The wizard comes out already-chasing from P4 onward: park the dragon
  (not the wizard) for in-range lightning tests, and park BOTH at
  opposite corners for the out-of-range test.

## Verified

`probe_archer_wizard.gd` 20/20: stash trigger spawns the wizard with
zero visits/purchases; no triggers = no wizard; 4 tower entries open
the shop each time and count; visits alone do NOT spawn him; a real
purchase increments the counter; 3 purchases + 4 visits spawn him via
the live watcher; lightning lands 60 in 4.5s in range and nothing out
of range; the fire shield arm/immune/re-arm cycle; the archer fires 1/2s
(≈15–20 over the window), a stationary dragon never misses, a moving
dragon dodges to ≤5 hp, and he holds the standoff ring under ATTACK.
`probe_king_lives` still 22/22. 14400-frame regression: 0 script
errors, purchases flowing.
