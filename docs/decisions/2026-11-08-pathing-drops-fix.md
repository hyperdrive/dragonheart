# Pathfinding unstuck + loot drop fixes — decisions

Date: 2026-11-08. Companion to the behavior-system record (steering stays
seek-based; no nav mesh added) and hud-overlay (minimap geometry).

## User bug report

1. Minimap stopped working. 2. Miners/farmers get stuck. 3. Gold/gems drop at
the map center instead of where they were dropped. 4. The dragon must get
close to the miner before he drops. 5. Dropping gold should cause soldiers to
attack.

## Root causes & fixes

### 1 — Minimap draw space (Minimap.gd)
`_draw()` draws in LOCAL space, but `_world_to_minimap()` added
`get_rect().position` — parent-relative — and `_draw` hashed background/border
from `get_rect()`. With the HUD in a CanvasLayer the parent rect is
screen-anchored; the offset shifted every dot off-panel (nearly invisible at
some sizes, garbage at others). Fix: draw `Rect2(Vector2.ZERO, get_size())`
and map world coords straight into the local panel size. Verified: all world
corners (±800) map inside the panel rect; world (0,0) maps to the exact panel
center.

### 2 — Unstuck detour (BehaviorTree.gd + BaseNPC.gd)
Seek steering runs straight into blocking scenery (mountains, lair, lakes —
all physics layer 1) with no detour. No nav mesh is warranted on open fields,
so a movement watchdog + detour waypoints were added:

- `BaseNPC._waypoint` (INF sentinel): when set, `move_towards` and the flee
  tick steer to the waypoint first; it clears at ≤16px and the real target
  resumes.
- `BehaviorTree._check_stuck()` after every movement tick: <6px travelled
  over a 0.7s window while MOVING or FLEEING → `_place_detour()`.
- `_place_detour()` casts a 3-ray shadow (center + ±26px perpendicular,
  layer-1 mask, 160px reach) toward the goal. With a hit: waypoint =
  blocker + outward stand-off (95) + tangent hop, chosen smallest-first
  (50/110/170/230/300) per BOTH sides, winning by shortest tangent, and each
  candidate must be in-world (bounds via WorldManager.world_size − 70 margin)
  AND shadow-clear toward the goal. Growth was needed — a single 50px tangent
  orbits large convex blobs (58px lair radius + stand-off).
- Fallback (rays clear but still grinding — wedged bodies, corner pockets):
  flip-alternating perpendicular sidestep, also bounds-checked. The old blind
  300px tangent could aim into the boundary walls (also layer 1) and wedge
  the body inside the wall overlap zone — the deterministic west-wall end
  state found while tuning.

Verified: 8/8 randomized layouts — a miner parked behind the lair reaches a
target placed straight through it. Rejected: NavigationRegion2D baking
(whole-map rebake per scenery placement; overkill for seek-based NPCs).

### 3 — Drops at the map center (Miner.gd)
`_drop_payload` wrote `drop.position` (the jitter) BEFORE `add_child`, as if
global — the miner's parent is WorldManager at the world origin, so
`position ≈ (jitter)` IS the map center. Fix: add to the world parent first,
then `drop.global_position = miner.global_position + jitter` (set-after-add
defensive ordering). Rejected: reparenting drops to the miner (they would
flee along with him).

### 4 — Drop distance decoupled from flee (Miner.gd)
The old wiring connected `fled_from_dragon` → drop: the payload spilled at
the 180px flee trigger. Fix: the drop now lives in the miner's physics tick —
`_check_dragon_drop()` spills only within `drop_radius` (85px, exported).
Balance: miner flees at 117 px/s, dragon at 200 — the dragon necessarily
catches up, so "drop when the claws arrive" holds while the miner keeps his
loot during the chase phase.
`fled_from_dragon` stays emitted (interrupt semantics) but no longer drops.

### 5 — Spill → soldiers ATTACK (WorldManager.gd)
`report_loot_spill()` forces `_set_swarm_state(ATTACK)` (skip RALLY). Called
by the miner on drop. This is reaction to treasure spilled in the streets —
the economy-only-consequences record is intact: stealing never accelerates
soldiers, but spilled treasure is a visible dragon crime the town can act on.

## Verification (headless, zero errors)

- Minimap: all world corners inside the panel rect; center maps to center.
- 8/8 randomized-layout unstuck runs (waypoint used, beyond-lair reached).
- Drop radius: payload intact at 150px; dropped within 85px AT the miner
  (8–11px off), provably not at map center.
- Spill: swarm state == ATTACK right after the drop.
- Full-run regression: zero script errors; passive economy unaffected.
