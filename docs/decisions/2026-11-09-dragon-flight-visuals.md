# Dragon flight + walk split + visual rework — decisions

Date: 2026-11-09. User: "improve on the dragon — more visually appealing.
Introduce walking and flying: flying recharges over 5s, allows fast
movement for 3s, walking a little more slow. Start flying pressing Q. A
flying dragon flaps his wings :)"

## User spec

1. Better-looking dragon.
2. WALK and FLY modes; walking "a little more slow".
3. Flight = fast movement for 3s, then recharge over 5s.
4. Q starts flying.
5. A flying dragon flaps his wings.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Movement split | `walk_speed` 150 replaces the old single `speed` 200 (user: "a little more slow"); `fly_speed` 300 during airborne bursts | The old 200 was also the flee-avoidance reference for balance; walking slower prices flight as the real mobility tool |
| Flight timing | Q bursts `fly_duration` 3s at 300, then auto-lands; landing always sets a full `flight_recharge` 5s; mid-recharge Q refused with a wait print | Exact user numbers. An early-cancel-refund idea (refund unused burst) was rejected WITH evidence: the refund math made a FULL 3s flight recharge in 2s (5 − (3 − 0)), violating "recharge over 5s" — refund and strict-5s cannot both hold. Cancelling therefore wastes the burst; simple and spec-true |
| State machine | three plain counters (`_flight_left`, `_flight_recharge_left`, `_flap_phase`) + a `_flying` bool inside the existing `_physics_process` loop | Two states plus timers: a full FSM node would out-weigh the logic; the dragon's other timers (fire, strike, boost) already live here |
| Input | `fly` action on physical Q (project.godot), read with `Input.is_action_just_pressed` in `_physics_process` | Same pattern as move/fire/eat; physical keycode matches the repo's key style |
| Flap visuals | code-driven on wing PIVOTS (`NearWingPivot`/`FarWingPivot` Node2D rotate the wing rects) — ~3.2 Hz sinusoid (55° near-wing sweep, trailing 36° lower-amplitude far wing), folded rest pose on ground | Repo precedent: the soldier/King weapon swing is code-driven on pivots. The AnimationPlayer already owns `Sprite` position/rotation (idle/fire/death) — a flap track on the same node would fight the autoplay every frame |
| Lift + shadow | new `Vis` Node2D wrapper between Dragon and `Sprite` carries the ~34px lift (+ bob) in code; a detached `Shadow` ColorRect stays on the ground and shrinks/fades with altitude; animation value tracks re-pathed to `Vis/Sprite:...` | Lift on `Sprite` itself would fight `idle`'s position track; a wrapper keeps AnimationPlayer tracks and code on separate nodes. The read shadow sells altitude without any parallax complexity |
| Art rework | richer ColorRect-primitive stack: tail + rotated tail spike, belly + neck plates, three back spikes, horn pair, snout/jaw with nostril, yellow dragon eye with pupil, twin wings (near wing with bone edge), all inside the existing facing-mirror (`sprite.scale.x`) | User: "more visually appealing". Stays in the repo's rect-primitive family — same authoring cost as before, no texture pipeline |
| HUD feedback | new top-bar `WingsLabel` chip: "✈ Ns" (flying), "Wings Ns" (recharge countdown), "Wings: ready (Q)"; pushed via `flight_state_changed(flying, seconds_left, charging)` on phase edges AND whole seconds only | A 5s invisible wait backgrounded every balance decision; whole-second pushes avoid a per-frame signal storm (same shape as the flame-charge chip) |
| Interaction scope | fire breath, loot, eating, E-strikes, interception, collisions ALL unchanged in flight (physics mask untouched); death resets all flight visuals instantly | Flight is a locomotion layer; layering it under combat keeps the run logic intact and leaves the boss fight untouched |

## Probe notes (for next time)

- `dragon.sprite` moved to `$Vis/Sprite` — any probe referencing the old
  direct `$Sprite` path must re-path. Animations intact (idle/fire/death
  still play; P1 asserts all three).
- After an airborne phase assert, note that `_flight_left` ticks during
  the assertion awaits — P4's recharge check runs 0.1s AFTER landing, so
  expect ~4.9 not 5.0.

## Verified

`probe_dragon_flight.gd` 25/25: physical Q bound, Vis/Shadow/wing-pivot
topology + all three animations intact + HUD chip wired; walk 150 /
fly 300 through `effective_speed()`; take-off lifts >18px, wings flap
(rotation delta between samples), shadow fades while grounded under;
3s burst auto-lands and reattaches to the ground; recharge starts and
mid-recharge Q is refused; early landing still pays the full 5s; chip
states push; `die()` mid-air resets flight, Vis to y=0, and shadow.
14400-frame regression: **0 script errors** (no Q in headless play, so
0 flight logs — verified via the probe instead).
