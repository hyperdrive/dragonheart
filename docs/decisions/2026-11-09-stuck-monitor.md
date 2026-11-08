# NPC stuck monitor (supervision watchdogs) — decisions

Date: 2026-11-09. Companion to dragon-strikes-respawn-prices (same-week
placement/detour fixes) and the GAME-SPEC behavior contract.

## User spec

NPCs still get stuck. Introduce a monitor that detects when an NPC isn't
moving or changing actions as it should, then affect it with pathfinding
tweaks or teleporting.

## Decisions (grilled)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Alarm types | BOTH: (a) MOVING displacement ~zero across an audit window, (b) same activity id without any completion for ~30s (loop/circle detection) | Two distinct failure faces: wedged-in-place vs perpetual re-target circles | new failure modes appear |
| Audit cadence | 2.5s per NPC, all NPCs (farmers, miners, soldiers, King); burning/dead/WORKING/W-stalls skipped | Working NPCs are legitimately stationary — the activity-hold alarm covers them instead | performance issues |
| Remediation ladder | Movement stall: detour (window 2) → teleport (window 4). Activity stall: one rescue | User picked the two-step ladder — the first step is cheap (existing detour math) | detours misfire often |
| Teleport destination | Near the CURRENT activity target (+ jitter, clamped to interior band) — NOT the home anchor | Lets the trip COMPLETE normally after the hop (walks the last ~35px); home would throw away started deliveries | teleports re-wedge |
| Repeat failures | If the SAME activity already ate 3 rescues, the 4th escalation ABORTS the trip instead (claim released, tree re-picks) | An unreachable target would otherwise teleport-loop forever | — |
| Detection threshold | moved < max(4px, speed×0.05) per window | Catches dither-against-wall (moves ±2px) without flagging slow detour hops | |

## Implementation

- Lives on WorldManager (supervision of the whole town, reuses
  `_clamp_to_interior`), runs on a Timer so it pauses with the menu.
- Per-NPC record: pos / state / activity_id / stationary_wins / hold_wins /
  rescue_count. Records reset on state or activity change; freed NPCs are
  scrubbed each pass.
- BehaviorTree gains two public bridges: `force_detour()` (the existing
  tangent-hop math) and `force_repick()` (cancel WITHOUT reward → IDLE,
  which also releases field claim leases via the existing state hook).

## Open / deferred
- Monitor prints every intervention — future polish may aggregate them.
