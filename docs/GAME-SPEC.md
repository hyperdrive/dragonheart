# Dragonheart — Game Specification

A reproducible AI implementation manual. Focus: **NPC rules, game goals, and
the economy**. Every rule below is implemented and verified in this repo;
file pointers and tuning numbers are listed so an AI (or a new developer) can
rebuild the design from this document alone. Companion records live in
`docs/decisions/2026-11-08-*.md` (index at the end) and plans in `docs/plans/`.

---

## 1. Concept

A **survival RTS with TTRPG elements** (Godot 4.7, GDScript, 2D top-down):

- **You are a dragon.** The map holds a town that runs a *worker economy* all
  by itself: **farmers** grow food and deliver it, **miners** haul gold and
  gems into the town treasury, **soldiers** escort and eventually besiege.
- **Your survival diet is the town's economy.** You eat livestock, steal
  treasure, and burn fields. Your only real loss conditions are the growing
  soldier swarm and the **King** — the final boss you must defeat to win.
- **The twist (design spine): crimes have economy-only consequences.**
  Killing and burning slows the town machine (less food, less gold, fewer
  supported workers), but it NEVER accelerates the soldiers or the King.
  The dragon buys survival power at the wizard tower with stolen loot —
  stealing is literally the loop that arms you for the endgame.

Victory: soldier escalation reaches the King threshold → the King spawns and
attacks → the dragon defeats him → run ends with a tally
(gold/gems stolen, treasury left, upgrade levels, time survived).

---

## 2. Design pillars (do not violate when re-implementing)

1. **Two pools never mix.** Town treasury (gold/gems from miners) and the
   dragon's stash (stolen gold/gems) are separate Dictionary pools on
   `GameManager`. All dragon loot intake funnels through
   `Dragon.take_loot()` (the "claws"); it only becomes *stash* when banked
   at the dragon's lair.
2. **Crimes don't speed soldiers.** Soldier escalation runs on its own
   timer toward the King threshold regardless of the dragon's crimes.
3. **Synchronous behaviors.** NPC behavior trees are synchronous per-tick
   activities (move → work → reward). Coroutines/`await` inside behaviors
   are forbidden — `Callable.call()` cannot await in Godot 4.
4. **GameManager is the single state hub** (pools, levels, prices,
   signals). NPC trees, HUD, Dragon, WizardMenu are views/actors; none
   store global state.
5. **Scarcity rations everything.** Food pays for livestock refills;
   dead townsfolk respawn only if a matching animal is "sacrificed";
   fields regrow one per gold delivery. Every economy gate is a limit.

---

## 3. World layout (1600×1600, Godot coordinates: ±800 x/y)

Boundary walls (20px thick) sit at ±800. **Walkable interior band = ±720**
(margin 80) — this was a shipped bug class: any anchor, spawn jitter, or
placement candidate outside the band wedges NPCs against walls forever.

Rule: **every landmark anchor, spawn jitter and placement candidate is
clamped into the interior band minus its own footprint radius**.

Landmarks (default exports, pre-clamped in `_ready`):

| Landmark | Default anchor | Radius | Notes |
|---|---|---|---|
| City (town hall) | (0, 620) | 120 | farmers/miners deliver here (treasury/food) |
| Pig pen | (−260, 760) | 85 | farmer respawn stock; dragon pig meals (+5 HP, +1 flame) |
| Cow pen | (260, 820) | 85 | miner respawn stock; dragon cow meals (+10 HP, +2 flame) |
| Dragon lair | (−620, 60) | 100 | banking radius 150; a claw→stash conversion point |
| Wizard tower | (520, −420) | 75 | walkthrough trigger → upgrade menu (zone Area2D) |
| Mine center | (−480, −420) | 30×8 | miners' work sites |
| Rally point | (0, 500) | 90 | soldier spawn + swarm muster |

Placement system: WorldManager keeps a **footprint registry**
(`_terrain_clearances`, pos + radius) grown during world generation.
Fields (55), mines (30), scenery (tree 30, lake 85, mountain 80) are placed
by jittering around an anchor and rejecting candidates that violate
`self_radius + other_radius + 30px` against ANY registry entry. Fields ring
the city at 420px. Walls/unknown obstacles: NPCs raycast for blockers and
sidestep via tangent detours (stuck watchdog: 0.7s of ≤6px movement).

`FOOTPRINT_RADIUS` const + `_clamp_to_interior()` in
`scripts/main/WorldManager.gd`.

---

## 4. Currency pools (all on GameManager)

| Pool | Owned by | Grown by | Spent by |
|---|---|---|---|
| **Town treasury** `{gold, gems}` | the town | miner deliveries | comments only (regrows fields symbolically) |
| **Town food** `int` | the town | farmer deliveries (+1 per tend, tiered) | livestock refills (20/animal), NPC support thresholds |
| **Dragon stash** `{gold, gems}` | the dragon | **lair banking only** | wizard purchases |
| **Dragon claws** (carried) | the dragon | panic-drop scoops, interceptions, E-kill steals, mine landings | deposited at lair → stash |
| **Dragon flames** `0..max` | the dragon | eating healed animals; purchases | 1 per fire breath |
| **Shield points** | the dragon | wizard purchase | absorbs damage first, gone when spent |

Gems are worth 10 gold in gold computation, but certain shop items carry a
**hard gems requirement** (Section 8) — gems are not interchangeable savings.

Stash size gates the wizard shop; nothing else drains the treasury (the
treasury is a score/stat pool — "treasury_left" appears in the victory tally).

---

## 5. NPC rules

All NPCs derive from `BaseNPC` (`scripts/npcs/BaseNPC.gd`): health, tiers
(`level_multiplier()`: +25% yield/speed per level), `is_flammable` burning
engine (10 burn damage/s for 3s, tree killed, panicked 1.4×-speed runs,
**always dies at burn-out**), `npc_died` signal, payload API
(`set_payload` / `steal_payload` → `{"res_type","amount"}`), and
`kill_by_dragon()` (cleared fire flags → guaranteed death via the
deliberate path, no burn-out spill).

### 5.1 Farmer — the food engine

- **Cycle**: tend fields → carry food → deliver at the city (+1 food per
  tend × tier) → repeat. Behavior states IDLE/MOVING/WORKING/FLEEING.
- **Field claims**: one farmer per field. The field holds a claim *lease*
  (`claimant_id`, `claim_expires` ≈ tend time + 14s slack) that self-heals
  so abandonment (flee, burning, death) never locks a plot. Claim released
  on completion, on death, and whenever the tree leaves MOVING/WORKING.
- **Flee priority**: dragons nearby (or fire) preempt everything at
  priority 0; a food-laden farmer runs with the payload and stalls the
  delivery (that's intended pressure).
- **Kill rules**: burnable (dies at burn-out), killable ONLY by an explicit
  dragon E-press. Death → town respawn request: **one pig is consumed from
  the pig pen** after ~10s delay (2s retry cadence while stock lasts);
  respawn at the farmer's home anchor. No pig in stock → no farmer.
  E-killing a farmer heals the dragon **+5**.
- **Death effect on fields**: none extra — fields are burnable separately.

### 5.2 Miner — the gold engine

- **Cycle**: mine at the mine sites → accumulate payload (tiered, ~70%
  gold / 30% gems, payload grows until delivery) → deliver at the city
  (treasury).
- **Haul-size lottery (2026-11-09)**: every working trip rolls its size —
  **50% one item, 25% two, 25% three** (×miner tier, so a level-2 miner
  hauls 2/4/6). The dice roll is per pickaxe trip, not per miner lifetime;
  deliveries, panic drops, and interceptions each carry whatever the haul
  rolled.
- **Exposed while hauling**: a cart sprite shows during payload; miners run
  faster with payload exposed. When the dragon comes within fear distance
  (180px), the miner **panics and drops the payload as a ground GoldDrop**
  (1.2s settle delay before the dragon can scoop, 90s decay). NOT scored
  as a "crime" — only the spill raises a street alarm.
- **Flyover interception**: the dragon's automatic system (range
  100px, chance-weighted by distance, 3s cooldown) steals the payload into
  the claws when a loaded miner passes under flight. **Steal-only**:
  interception NEVER damages or kills — the miner keeps its cooldown panic
  (10s mine cooldown) but takes zero damage.
- **Kill rules**: killable ONLY by an explicit dragon E-press (an E-kill of
  a loaded miner steals the payload into the claws BEFORE death). Burns
  same as anyone. Spill on burning death: payload drops where he fell.
  Death → town respawn request: **one cow consumed from the cow pen**.
- **Support chain (the "miners enable" gate)**: the town spawns its first
  miner only when ≥ 3 farmers AND ≥ 10 food exist; subsequent miner spawns
  timer at 30s while support conditions hold. Miner death thus SLOWS the
  gold economy but the soldier build-rate ignores it entirely.

### 5.3 Soldier — the escort/escalation (kill-lottery target)

- **Behavior**: rally to escort positions; chase the dragon in range
  (attack_range 60) and deal **10 contact damage per second** (accrued as
  float debt, applied as int chunks) as long as the hitbox touches.
- **Flame interaction**: breath sets soldiers ABLAZE (cone: within 95px,
  forward dot ≥ 0.25) — they panic-run randomly and die at burn-out.
  Burning panic runs reuse the flee wobble (§11 presentation layer).
- **Bold rule (2026-11-09, decision record
  `2026-11-09-gate-handoff-and-aggressive-bold.md`, superseding
  `2026-11-09-bold-soldiers-and-flames.md`'s 360px sight)**: a bold
  soldier ignores the calm-town aggro gate and hunts the dragon alone.
  Boldness is presence-based, NEVER sticky — re-checked on every
  activity pick: King within **180px** (his fatness doubles the 5-width
  morale radius), or **≥2 soldier pals within 90px** (5 body widths;
  body = 18px). Bold sight/pursue reach = **whole map (4000px)** —
  user escalation "more aggressive, attack the dragon when they are
  bold": pursue **until contact**, fight there with the contact DPS
  channel; the ONLY brake is morale decaying (King/pals leave the band
  → the straggler finishes the in-flight leg, then re-picks home).
  Released swarm (ATTACK) unchanged; the King IS bold himself but does
  not count as a pal for the ≥2 rule.
- **Weapon swing (2026-11-09)**: while ACTIVELY fighting (alive, not
  burning, dragon inside `attack_range`) every soldier's carried
  weapon (`Sprite/Spear`, King: `Sprite/Sword` via the same lookup)
  hammers a ~2.2Hz overhead→strike arc (`-55°→+25°`) with a
  bottom-of-arc glint and a slight combat lean on the body sprite;
  the exact rest pose is restored when the fight ends (guaranteed
  reset leg). Burning soldiers keep the flee wobble (no swing), and
  the dragon-killing DPS stays the `_contact_damage` channel — the
  swing is presentation only.
- **E-strike lottery**: an explicit E within `strike_reach` 100px has a
  **15% chance** to kill a soldier outright (0.5s recharge between
  strikes). "Brute Force" wizard purchases add **+5% each** (cap 35%).
  **The first Speed purchase drops the recharge to 0.2s permanently.**
  A missed strike flashes the HUD threat chip. While the strike is on
  cooldown soldiers are NOT valid E-targets (the context action falls
  through to pens/townsfolk). The **King is excluded** from E-strikes.
  Soldier kills heal nothing.
- **No respawn**: soldiers never return (the King does — Section 5.4).

### 5.4 King — the final boss

- **Boss profile (2026-11-09 stomp fix)**: 200 HP, 60 speed, 30 DPS→**50
  DPS magic sword** (5× a soldier; his main threat is contact damage),
  `attack_range 70`, whole-map `aggro_range`, `danger_radius 0` (never
  flees), reward_gold 0. He extends Soldier — his own config is set
  BEFORE `super._ready()`, and Soldier's defaults now apply only when
  `npc_type` is still the BaseNPC default (`"villager"`) so the boss
  values survive. History note: the old unconditional Soldier
  profile-stomp silently overwrote the King to 50 HP / `"soldier"` /
  10 DPS since his introduction; the leak surfaced while wiring his
  fire cloak (he began fleeing with the default 150 danger radius).
- Spawns at the King threshold (Section 9).
- **Fire cloak (`fire_immunity_seconds = 5.0`)**: every successful
  ignition arms a 5s cloak — re-breaths inside the window slide right
  off (`catch_fire` bails), the burn itself (3s) runs inside the cloak,
  and after it expires the next hit ignites AND re-arms. Generic
  `BaseNPC.fire_immunity_seconds` (= 0 elsewhere), so any NPC can
  opt into the rule. The King prints his cloak activation line.
- **Three respawns after defeat (`king_respawn_count = 3`)**: each
  defeat calls `WorldManager.on_king_defeated()` — while respawns
  remain the death schedules a 3s one-shot Timer that re-materializes
  the King at the city (the swarm stays ATTACK), printing falls/rises.
  The FOURTH death (all lives spent) is the true one → victory tally,
  run ends.
- **The town recruits THROUGH the boss battle (2026-11-09)**: the
  recruit trickle never stops at `king_spawned` and treasury purchases
  keep firing while he is alive or mid-respawn-gap — the King fights a
  constantly refreshed army. (Earlier rule "purchases stop at the
  King" superseded by user: "soldiers should always be coming,
  especially if there are treasure in the treasury".)
- **Weapon swing**: the King inherits Soldier's code-driven combat
  swing (`Sprite/Sword` resolves the same weapon lookup as spear) —
  see Section 5.3's swing notes and
  `docs/decisions/2026-11-09-king-lives-and-swing.md`.
- His periodic area special attack (30% chance × `attack_damage ×
  1.5`, 80px) is unchanged and independent of the weapon swing.
- Defeating him triggers the victory tally and ends the run.

### 5.5 Kills by fire vs by E


| Death path | Effect |
|---|---|
| Burning out | guaranteed death AFTER the 3s panic run; miner spills payload where he fell |
| Dragon E-press | immediate deliberate death; payload stolen into the claws first; +5 health (townsfolk only) |
| Flyover interception | NO death — payload steal only |
| Soldier chase/collisions | dragon takes contact DPS; NPC never dies from body-blocking |

### 5.6 StuckMonitor — world supervision of NPCs

A town-level watchdog (decision record 2026-11-09) audits every NPC on a
2.5s `Timer` on WorldManager and remedies trips that stall, so no NPC can
be silently wedged or circle-loop forever:

- **Movement stall** — NPC in `MOVING` that progressed less than
  `max(4px, speed×0.05)` since its last recorded move:
  after `detour_after_sec` (5s) force a tangent detour waypoint
  (pathfinding tweak); after `teleport_after_sec` (10s) teleport
  (±35px jitter, interior-clamped) next to the CURRENT activity target so
  the trip still completes naturally.
- **Activity stall** — the same activity id held ≥
  `activity_stall_after_sec` (30s) with no completion (loop/circle
  detection) → one teleport rescue of the same kind.
- **Escape valve** — the 3rd rescue for the SAME activity declares the
  target unreachable: the trip aborts WITHOUT reward (claim leases
  released, field plots freed) and the tree re-picks fresh.
- **Skipped** — dead, burning, and legitimately-stationary NPCs; WORKING
  is covered by the activity alarm, never the movement alarm.
- **Terrain-safe goals (2026-11-09 fix)**: every trip target must be
  standable — soldier patrol/idle/rally anchors route through
  `WorldManager.terrain_free_target()` (footprint rules, city 140px
  no-go ring), because goals inside city walls are unreachable no matter
  how many detours or teleports follow (forensic: soldiers grinding in
  MOVING for 99s+ with in-wall goals).
- **Rescue teleports are terrain-cleared too** — the landing searches
  the nearest standable spot around the goal; when NO clear spot exists
  near the goal the trip aborts instead of dropping an NPC inside an
  obstacle (a wall-drop recreates the wedge it was healing).
- The movement ladder also covers **FLEEING** — a flee wedged against
  terrain never self-arrives and previously had zero supervision.
- Time-based thresholds (not audit counts) so cadence changes never skew
  escalation; all knobs live under the WorldManager `StuckMonitor` export
  group. BehaviorTree exposes `force_detour()` / `force_repick()` bridges.

### 5.7 Gate hand-off exemption + city spending (2026-11-09)

- **Gate hand-off**: `BehaviorTree._tick_danger` skips the flee
  preemption when `npc._handoff_stretch()` is true — a LOADED carrier
  ON his deliver leg finishes the trip even with the dragon inside his
  flee ring (Miner/Farmer overrides). Without it a dragon parking near
  the north gate wedged every loaded carrier in a flee/deliver
  ping-pong exactly over the delivery point: forensic sim showed 45s+
  of circling carts and ZERO deliveries in 90s → treasury starved →
  no soldier purchases ("we still fail to spawn soldiers").
- **Theft paths intact**: the miner's drop rule (spill at `drop_radius`
  85) and the GoldInterceptionSystem (pockets at 100) run regardless of
  the exemption — the dragon robbing carts mid-map is still how the
  player keeps the town poor; the exemption only trades panic-looping
  for a brave straight walk into the gate zone.
- **City spending messages**: soldier purchases print the exact spend
  (`City bought N soldier(s) — spent X gold, Y gems (... left)`) on the
  1s spend heartbeat and every delivery; pen refills print via
  AnimalPen (`a new pig grew up at the pen — town paid 10 food`). Every
  city resource use is narrated on the console.

### 5.8 Archer — the ranged soldier (2026-11-09)

- Every THIRD fielded recruit (`WorldManager._next_recruit_type()`, in
  both the 8s trickle and treasury purchases) is an **Archer**: a
  soldier-family NPC (same 50 HP, 80 speed, never flees, morale/bold
  rules, counts toward the King threshold) that attacks FROM RANGE.
- **Fires one arrow every 2s** whenever the dragon is inside
  `arrow_range` 350px — 5 damage per hit, INDEPENDENT of the behavior
  tree and morale (a calm-town archer still shoots an in-range dragon;
  morale only drives positioning).
- **Aim is exact**: the arrow flies STRAIGHT to the dragon's position
  captured at fire time — a STATIONARY dragon never misses; a moving
  dragon naturally dodges (the projectile never tracks him).
- Stand-off positioning: instead of pressing into contact he holds a
  ring `arrow_range - 60px` from the dragon (via `_pick_dragon_target`
  hold). No melee DPS channel at all.

### 5.9 Wizard — the backstabbing caster (2026-11-09)

- Lives at his tower and STAYS OUT of the war until provoked
  (`WorldManager._try_spawn_wizard`, every frame): emerges when the
  dragon has **bought ≥4 upgrades AND visited the tower more than 3
  times** (counters on GameManager: `tower_visits` increments on every
  door opening, `upgrade_purchases` on every successful purchase) OR
  has **20g or more hoarded in the stash** (repriced 2026-11-09: was
  30; the greedy line fires AT 20).
- Emerged profile: 80 HP, speed 75, never flees; **lightning**: instant
  long-range bolt (500px reach) at **30 damage, 2s recharge** with a
  Line2D flash visual and a print; NO melee contact at all.
- **No shield against his attacks** (2026-11-09): his lightning calls
  `take_damage(30, bypass_shield = true)` — the wizard-shop shield pool
  does NOT absorb it (every other damage source still goes through the
  pool unchanged). Baiting the shop shield or stacking it buys nothing
  against the caster.
- **Relentless**: every attack gate is unlocked — once out, he hunts
  the dragon across the whole map and does not stop until the dragon
  is dead (swarm morale/rally are irrelevant to him).
- **Fire shield like the King**: `fire_immunity_seconds = 5.0` — every
  ignition arms the 5s cloak (the burn runs inside it; re-ignition
  re-arms), with his own shield-flare print.
- The tower shop stays open for repeat visits: every entry reopens the
  WizardMenu (world paused) and counts toward the visits counter —
  buying 3–4 times in separate entries is the intended loop.


---

## 6. Livestock, fields, food chain

### Pens — slot pools, not timers

- Each pen (`AnimalPen`) has **4 slots** (sprites), a species name, and
  `refill_cost = 20`. No self-respawn: the farm cycle is the ONLY return.
- Two operations: `consume_animal()` (meal or respawn sacrifice) and
  `respawn_animal()` (town pays 20 food → one slot fills).
- **Refill rule**: after EVERY farmer food delivery, WorldManager loops
  BOTH pens greedily — slots fill until the town's food runs below 20.
  This is the respawn pressure the user asked for: "cows/pigs respawn as
  soon as farmers deliver food".
- Dragon meals are E-commanded (Section 7), one animal per press, refused
  when full. Pig +5 HP/+1 flame, cow +10 HP/+2 flame.
- **Visuals (2026-11-09)**: proper SVG art per species on a 48px canvas —
  `assets/pig.svg` (pink pig: curly tail, hooves, shaded belly, snout
  with nostrils) and `assets/cow.svg` (white cow with brown patches,
  horns, muzzle, udder, dark hooves). Pen scenes reference the SVGs with
  resize scales (pig 0.75, cow 0.8 — pigs read slightly smaller); the
  slot pool copies the template texture/scale, so refilled slots get the
  real art automatically.

### Fields

- **Claim lease** per field: one farmer at a time (Section 5.1).
- **Burnable**: field caught in flame → STUBBLE state → slow natural
  regrow timer (~default per Field exports).
- **Gold regrow fast lane**: every GOLD miner delivery regrows exactly ONE
  stubble field instantly (RP: the treasury funds re-sowing). Food/gem
  deliveries do NOT regrow.
- **Layered farm visuals (2026-11-09)**: soil plot base + pen-style fence
  rails/posts around `Crops` (name kept — the color-flip node). Plowed
  furrow ROWS (`CropRows`, lighter-green strips) show when GROWN;
  `StubbleRows` (tan strips) show when burnt — one `_apply_state_visuals()`
  funnel drives base color AND both row overlays from burn()/regrow()
  regrow timeout, so they can never disagree. Each field gets a small
  random brightness/warmth modulate jitter in `_ready` so identical plots
  don't look cloned.

### Food chain summary

```
farmer tend → food → town pool ──→ pen refills (20/animal) ──→ farmer/miner respawns need pigs/cows
                │
                └─→ miner support gate (≥3 farmers, ≥10 food) → miners spawn → treasury gold
```

Burning fields/eating livestock adds friction to this loop; the loop is
self-healing as long as deliveries keep flowing.

---

## 7. Dragon mechanics (`scripts/characters/Dragon.gd`)

- **Health** 100 (max raised +25 per old scales-level if that wiring is
  reused), contact DPS 10/s from soldiers, burnable rules N/A (the dragon
  is not flammable).
- **Locomotion split (2026-11-09)**: walking at **150** (deliberately a
  little slower than the old single speed) and FLYING at **300**. Press
  **Q** to take off: a 3s burst of fast flight, then the dragon auto-lands
  and recharges for **5s** (early Q lands immediately and wastes the
  burst — cancelling never shortens the wait). Mid-recharge Q is refused
  with a print. Visual flight: the body lifts ~34px over a detached
  ground shadow (shadow shrinks/fades with altitude), and the wing pivots
  FLAP (~3.2 Hz sinusoid, far wing trailing); the lift rides a `Vis`
  wrapper so the AnimationPlayer tracks (`idle`/`fire_breath`/`death`,
  which own `Sprite`) never fight the code. Death resets all flight
  visuals to the ground pose. Stuff stays hostable mid-air (fire breath,
  loot, interception all unaffected).
- **Flames**: max-charge pool (base 4, extendable via shop). Breath = −1
  charge. Empty flames = a quiet dragon. Eating an animal recharges ONLY
  IF the meal healed you (health-gated).
- **Loot**: claws intake (`take_loot`), banked at the lair (150px) into the
  stash. Panic-drop scoops auto-collect within 70px once the drop settles.
  Loyalty mechanic: loot in claws is NOT stash (hauling pressure).
- **E = context action** on the NEAREST valid target in reach:

| Nearest valid target at E | Result |
|---|---|
| Animal pen (stock in its `pen_radius`) | eat 1 animal (refused with HUD chip flash if health full) |
| Farmer / Miner ≤ 100px | deliberate kill: steal payload → die → +5 HP |
| Soldier ≤ 100px (not King, strike not on cooldown) | 15% kill-odds lottery (Section 5.3) |
| Nothing | hint print |

- **Fire breath** (Space): −1 flame charge, ignition cone (95px reach,
  forward dot ≥ 0.25), sets NPCs/fields ablaze.
- **Movement**: direct WASD steering via `effective_speed()`; the shop's
  speed boost multiplies it ×1.6 for 6s (refresh not stack).

---

## 8. Wizard tower shop (purchases = steep-coffers tuned, gem-aware)

The tower is the mandatory upgrade site: driving the dragon into the tower
Area opens a paused overlay menu (world procession stops — pause live
world, menu survives reopen). Mouse or number keys 1–6; ESC leaves.
Prices in one `WIZARD_PRICES` const on `GameManager` as
`{kind: {"gold": int, "gems": int}}` (**re-priced 2026-11-09**, user:
"lower prices for all upgrades" + claw upgrade at 8g):

| Key | Item | Cost | Effect |
|---|---|---|---|
| 1 flame_1 | +1 Flame | 10g | max flame charges +1, arrives loaded |
| 2 flame_2 | +2 Flames | 20g + 1 gem | capacity +2, loaded |
| 3 shield | Shield 10 | 8g | absorb pool +10; eats damage first; gone when spent; refused while any shield remains |
| 4 speed | Speed Boost | 12g | ×1.6 for 6s (refresh), AND first-ever buy drops soldier strike recharge to 0.2s |
| 5 range | Longer Flame | 15g + 1 gem | +20px breath reach, permanent |
| 6 brute | Brute Force (claw) | 8g | soldier E-kill odds +5%, repeatable to 35% cap |

Payment rule: **the gems part is a hard requirement**; the gold part may be
topped up with spare gems at 10:1 (matching the legacy `_pay_stash` rule).
A refused purchase never half-pays. The menu shows `40g + 2 gems` price
strings and gates affordability through the SAME
`can_afford_wizard()`/`_pay_wizard_cost()` pair the purchase uses.

---

## 9. Escalation and victory

- **Soldier supply has two lanes** (2026-11-09 prices): the town's bare
  trickle (initial 4, then one per 8s interval) is INDEPENDENT of the
  dragon's crimes (economy-only-consequences pillar stands) — and on top
  the town SPENDS its treasury: **2 gold = 1 soldier, 1 gem = 2
  soldiers**. Gold drains first so gold-only shop stock (Brute Force)
  keeps meaning; gems only pay when no gold remains. The drain runs
  instantly on every miner delivery AND on a 1s heartbeat, so miner
  money is never parked idle.
- At the King threshold the swarm musters (rally, ATTACK state) and the
  King spawns. The threshold counts EVERY soldier the town has fielded —
  initial + trickle + treasury-bought (15).
- Victory = the King STAYS dead. With `king_respawn_count = 3`
  (2026-11-09) he rises up to THREE times after each defeat (3s timer,
  re-materialized at the city, swarm pinned ATTACK); soldier spawning
  keeps running through all of it (Section 5.4). Only the defeat that
  spends the last life calls
  `GameManager.notify_king_defeated()` for the tally: time survived,
  gold/gems stolen, treasury left, fire/scales levels. There is no
  other win/loss condition beyond dragon death.

### 9.1 TTRPG story popups (2026-11-09)

- **The overlay** (`scripts/ui/StoryPopup.gd` + `scenes/ui/StoryPopup.tscn`):
  a full-screen story chapter while the live world is PAUSED beneath it —
  one image + fantasy-novel-told story text + 2–3 answer choices. Mouse
  click or the matching number key (1–4) picks; **ESC picks the LAST
  choice** (the story always answers; it never closes unanswered).
- **Progression policy**: the chosen answer lands in the run ledger
  `GameManager.ttrpg_choices` (kind → chosen choice index) via
  `story_choice_made(kind, index)` — every recorded answer is part of the
  run's TTRPG progression policy.
- **Once per run each**: `GameManager.notify_story(kind)` marks the kind
  in `story_shown` the first time and ignores repeats; story kinds told
  while another popup/menu is up queue in `story_queue` and open when the
  current one closes (`_drain_story_queue` — also flushed when the
  wizard menu closes).
- **The seven chapters** (all defined in `StoryPopup.STORIES`, image art
  per chapter: field_fire / pick_flame / king_crown / wizard_bolt /
  pig / cow SVGs):

| Kind | Opens on | What the chapter tells |
|---|---|---|
| `field_burn` | `Field.burn()` | the farmers scream "THE DRAGON BURNS OUR FIELDS!" |
| `miner_burn` | `BaseNPC.catch_fire()` for MINERS only | the criers claim "Miners refuse to work because of dragon terror!" (the tavern tells another tale) |
| `king_emerge` | `WorldManager._materialize_king()` | the King's epic arrival speech |
| `king_defeat` | `GameManager.notify_king_defeated()` — the FINAL fall only | the crown tumbles; victory |
| `wizard_emerge` | wizard spawn path in WorldManager | the shopkeeper unmasked as the treacherous evil overlord |
| `pig_eaten` / `cow_eaten` | `Dragon._eat_meal_from` after the meal | first pig / first cow of the war |

- **Pause ownership is ALL GameManager's** (2026-11-09): `_open_story_now`
  instantiates one shared popup (layer 12, PROCESS_MODE_ALWAYS) and sets
  `get_tree().paused = true`; `_on_story_closed` unpauses and drains.
  Story calls pass through `get_first_node_in_group("game_manager")`
  from the source nodes — popup never owns state.


## 10. Tuning reference (all live as exports)

| Knob | Value | Home |
|---|---|---|
| World size / margin band | 1600×1600 / ±720 interior | WorldManager exports |
| Farmer count / fields | 5 / 6 | WorldManager |
| field ring radius | 420 from city | spawn_fields |
| Pen max slots | 4 | AnimalPen (# animals in scene = live slots) |
| Pen refill price (2026-11-09) | pig 10 food / cow 20 food | AnimalPen._ready (species-priced) |
| Pig / Cow meal | +5 HP +1 flame / +10 HP +2 flame | AnimalPen (heal_amount, flame_recharge) |
| NPC respawn delay / retry | 10s / 2s | WorldManager |
| Flame max charges / reach | 4 / 95 (+20 per range buy) | Dragon exports |
| Fire cone | 95px, dot ≥ 0.25 | Dragon fire_area |
| Strike reach / chance / recharge | 100 / 0.15 / 0.5 (0.2 after Speed) | Dragon Strikes group |
| Brute Force | +5%, cap 0.35 | STRIKE_CHANCE_CAP |
| Interception | range 100, 3s min cooldown, risk-scaled | GoldInterceptionSystem |
| Soldier contact DPS | 10/s within 60px | Soldier exports |
| King boss stats (2026-11-09) | 200 HP / 50 DPS sword / 70px range / never flees / whole-map aggro | King._ready (pre-super config) |
| King fire cloak (2026-11-09) | immune 5s from every ignition (burn runs inside it); re-arms on re-ignite | BaseNPC.fire_immunity_seconds |
| King respawns (2026-11-09) | 3 (4 deaths total); 3s re-materialize at city each; last death = victory | WorldManager king_respawn_count |
| Weapon swing (2026-11-09) | ~2.2Hz, -55°→+25° arc (pivot at the GRIP), glint at strike bottom, 0.09 rad lean | Soldier swing consts |
| Archer (2026-11-09) | every 3rd fielded recruit; arrow 5 dmg / 2s in 350px reach; never misses a stationary dragon | Archer.gd / _next_recruit_type |
| Wizard (2026-11-09, trigger repriced) | emerges (≥4 buys AND >3 tower visits) OR stash ≥20g; lightning 30 dmg / 2s / 500px PIERCES the shop shield; fire shield 5s; relentless whole-map hunt | Wizard.gd / WorldManager Wizard group / Dragon.take_damage bypass flag |
| Prices (2026-11-09 reprice) | flame_1 10g / flame_2 20g+1gem / shield 8g / speed 12g / range 15g+1gem / brute (claw) 8g | GameManager.WIZARD_PRICES |
| Dragon claw swing (2026-11-09) | one-shot 0.26s on every E-strike attempt: −52°→+26° slash, warm glint at impact, 7px body lunge, plays on hit or miss | Dragon `_play_claw_swing` / ClawPivot |
| Burn | 10/s for 3s then death | BaseNPC |
| Lair banking radius | 150 | Dragon |
| Wizard prices | Section 8 table | GameManager.WIZARD_PRICES |
| Miner support gate | ≥3 farmers, ≥10 food, 30s timer | Miner/WorldManager exports |
| StuckMonitor audit / detour / teleport / hold | 2.5s / 5s / 10s / 30s | WorldManager StuckMonitor group |
| Soldier purchase prices | 2 gold : 1 soldier, 1 gem : 2 soldiers | WorldManager SoldierPurchases group |
| Animal art (2026-11-09) | pig.svg / cow.svg, 48px canvas; pens scale 0.75 / 0.8 | assets/*.svg, pen scenes |
| Field visuals (2026-11-09) | soil base + fence, CropRows green / StubbleRows tan overlays, per-field modulate jitter | Field.tscn / `_apply_state_visuals` |
| Dragon flight (2026-11-09) | Q: fly 300 for 3s → auto-land → 5s recharge; walk 150; lift 34px, flap ~3.2Hz, detached shadow | Dragon.gd Flight group / Dragon.tscn Vis+Shadow+wing pivots |
| Miner haul lottery (2026-11-09) | per trip: 50% ×1, 25% ×2, 25% ×3 (×tier) | Miner `_roll_haul_size` |
| Bold morale radii (2026-11-09) | pals 90px (5 widths, ≥2) / King 180px / hunt reach whole-map (4000) | Soldier morale consts |
| Gate hand-off (2026-11-09) | loaded deliver legs skip flee preemption; claws still spill at 85px | Miner/Farmer `_handoff_stretch` |
| TTRPG story popups (2026-11-09) | 7 kinds, each ONCE per run; choices recorded (kind→index); keys 1–4 pick, ESC = last line; queue drains on close | StoryPopup.STORIES / GameManager story group |


## 11. Implementation notes (engine mapping)

- **Engine**: Godot 4.7, GDScript. Dragon = `CharacterBody2D`; NPC = same
  base; pens/fields/scenery = Node2D/Area2D/StaticBody2D per prop.
- **Behavior trees**: each NPC owns a `BehaviorTree` node with registered
  activities (id, target provider, work_time, cooldown, on_complete) —
  synchronous ticks only, movement via one shared `move_towards` with
  stuck-detour raycasts. `check_danger` is a priority-0 preemption.
- **State hub**: GameManager (autoloaded-equivalent scene node) holds
  pools/levels/prices and re-emits signal-driven HUD refreshes.
- **UI**: retirable HUD chips; wizard menu is a `CanvasLayer` overlay with
  `get_tree().paused` — NEVER `change_scene` (the economy must survive).
  TTRPG story popups use the same shape (CanvasLayer layer 12 +
  PROCESS_MODE ALWAYS + GameManager-owned pause) — see Section 9.1.
- **Input Map actions**: `move_left/right/up/down`, `fire` (Space),
  `eat` (physical E), `upgrade` (retired U-panel; keep wizard-site flow).
- **Verification convention**: headless runs
  `Godot --headless --path . --quit-after N` must show ZERO
  `SCRIPT ERROR`. Behavior validations are disposable SceneTree probes
  that state expectations on the print (see `/tmp/opencode/probe_*.gd`
  during the original build for the pattern).
- **Presentation layer** (2026-11-09): NPC visuals are `$Sprite` (Node2D)
  ColorRect composites mirrored whole via `_apply_facing` — animations are
  code-driven on that container, no skeletons/spritesheets:
  - Fleeing = wobbly cartoon run for EVERY NPC: alternating foot-to-foot
    hop (±4.5px at 9Hz), lean wobble (±0.18 rad), squash on landings
    (scale.y −12%); instant reset to rest pose when not fleeing
    (`BaseNPC._animate_flee`).
  - Mining = pickaxe hammering during the miner's `mine` WORKING phase:
    handle-top pivot, raise→slam arc (2.2Hz, −62°→+12°), warm modulate
    flash at the bottom of each slam + body dip (`Miner._animate_mining`).
  - Mines render as grassy hills (assets/sprites/mine.svg, palette matched
    to mountain/lair/tree) with timber-framed entrances; the script's
    Gold/Gems toggles are ore piles flanking the arch — node names are
    load-bearing (Mine.gd shows/hides for depletion/respawn).
  - Flames on burning NPCs (2026-11-09, ALL types): `Sprite/Flames` holds
    3 ColorRect tongues (dark red → orange → yellow core, z_index 2)
    spawned by `catch_fire`; per-tongue height waves (14Hz, harmonic
    multipliers), rotation sway, x-wobble and alpha pulse in
    `BaseNPC._animate_flames`; torn down the first frame the fire is out.
    Burning NPCs panic-run with the flee wobble (same predicate cover).
- **NOT a comment format**: scene files (.tscn) use `;` comments;
  free-text `##` prose inside one corrupts node parsing (silent fallback
  renaming) — keep design prose in scripts/docs only.
- **Flee border clamp**: `WorldManager.clamp_into_playfield()` is applied
  to escape targets in `BehaviorTree.check_danger` so pushed runners slide
  along boundary walls instead of pinning into them (note: BehaviorTree's
  world ref is deliberately UNTYPED — a typed WorldManager field there
  creates the WorldManager→Miner.tscn→Miner.gd preload cycle and breaks
  scene compilation).

## 12. Decision record index (theory behind every rule above)

- `2026-11-08-behavior-system.md` — economy contracts, tiered NPCs, two pools
- `2026-11-08-flammable-ecology.md` — fire economy, pens as slot pools, food-paid refills
- `2026-11-08-dragon-health.md` — contact DPS, ablaze soldiers, healing rules
- `2026-11-08-loot-hauling.md` — panic drops, scoop delay, claws vs stash, lair/tower
- `2026-11-08-farm-placement-rules.md` — field claims, gold regrow, terrain registry
- `2026-11-08-manual-eat-wizard-menu.md` — E-commanded meals, wizard menu, retired U-panel
- `2026-11-08-dragon-strikes-respawn-prices.md` — interior band fix, E context action, greedy pen refills, gem pricing
- `2026-11-08-soldier-strike.md` — soldier kill lottery, Brute Force, speed-to-recharge strike coupling
- `2026-11-08-farmer-nan-spawn.md` mentioned in dragon-strikes record — INF spawn fallback, lost-in-space watchdog *(addendum: see commit be4f2f9)*
- `2026-11-09-stuck-monitor.md` — NPC supervision: movement/activity stall alarms, detour→teleport ladder, 3-rescue abort valve
- `2026-11-09-town-purchases-and-stuck-fixes.md` — pen species pricing (pig 10/cow 20), treasury soldier buys (2g=1, 1gem=2, instant drain, King at 15 fielded), terrain-safe trip goals + rescue landings, FLEEING ladder coverage
- `2026-11-09-mine-visuals-and-npc-animations.md` — hill SVG mines, code-driven flee wobble (all NPCs), miner pickaxe hammering, flee-target border clamp
- `2026-11-09-bold-soldiers-and-flames.md` — width-based soldier morale (bold phalanx/king presence, fight-until-escape, re-check each pick), flame overlay on all burning NPCs, burning panic runs reuse the flee wobble
- `2026-11-09-gate-handoff-and-aggressive-bold.md` — gate hand-off exemption (the delivery choke that starved soldier purchases), bold reach escalated to whole-map, city-spend console messages
- `2026-11-09-king-lives-and-swing.md` — King 3 respawns + fire cloak + 50-DPS magic sword, weapon swing for Soldiers/King, and the Soldier._ready profile-stomp bug it exposed
- `2026-11-09-archer-and-wizard.md` — Archer (range attack, stand-off) + backstabbing Wizard (tower-count triggers, lightning, fire shield) + tower revisit counters
- `2026-11-09-farm-animal-visuals.md` — pig/cow SVG art in the pens + layered furrow-row field visuals with a single state-visual funnel
- `2026-11-09-dragon-flight-visuals.md` — walking/flight split (Q, 3s/5s), wing flaps + lift + shadow, the Vis wrapper that keeps animation/code from fighting
- `2026-11-09-miner-haul-lottery.md` — miner haul size 50/25/25 (×1/×2/×3 per trip), accumulation-until-delivery untouched
- `2026-11-09-pricing-and-claws.md` — wizard shop re-price (brute 8g, all cheaper), wizard greedy trigger 30→20g, code-driven dragon claw swing
- `2026-11-09-wizard-4-buys-shield-bypass.md` — wizard provocation now four upgrades, lightning pierces the shop shield
- `2026-11-09-ttrpg-story-popups.md` — paused story overlay (7 chapters, once per run), multiple-choice answers in the ttrpg_choices progression ledger
