# Walkable grid + A* route planning — decisions

Date: 2026-11-14. Supersedes the "no nav mesh" call in
`2026-11-08-pathing-drops-fix.md` (open fields then; mountains, lakes, tree
clusters, firs and the hag's nest since). The detour + StuckMonitor
machinery of `2026-11-09-stuck-monitor.md` stays as the safety net.

## User report

"NPCs tend to get stuck." Proposal discussed and approved ("LGTM"): a
virtual grid over the world with A*, plus — later — an "ant trail" traffic
heatmap.

## Findings (before)

- Movement was a straight seek at the target; only after 0.7 s of stalling
  did a raycast sidestep kick in, and after 5–10 s the StuckMonitor forced
  detours, then teleported or abandoned the trip.
- Prototype on a real generated world: of 60 everyday trips, 34 (57 %)
  needed to bend around scenery — every one of those walked into it first.
- Some goals were unreachable by construction: a goblin home anchored at
  x = −950 (the boundary wall sits at ±960), a soldier patrol point inside
  an obstacle.
- 4 game-minutes of town life, dragon away (two random worlds): **1361 /
  1515 stalled NPC-seconds while MOVING, 354 / 375 watchdog interventions,
  62 / 59 teleports or aborted trips.**

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Representation | `AStarGrid2D`, 16 px cells (120×120 on the 1920 px world) — `scripts/systems/NavGrid.gd` | User's proposal; per-cell weights make the planned trail heatmap trivial; cheap partial updates; easy to visualise | world grows far larger, or paths look too boxy |
| What is solid | A cell whose centre can't hold the BODY box (28×42, offset 0,+3 — covers every NPC's real collision rect: farmer 16×32, soldier/hag/goblin 18×25 at +5, King 25×35 at +5) without touching layers 1 + 16 + 32 (terrain, trees, lakes, walls) — rasterised by physics shape queries, so it matches what actually stops NPC bodies | One source of truth: the colliders. A first cut used an 11 px circle and a soldier slid along a mountain foot on a "clear" straight route (bodies reach 17–22 px below the feet) | an NPC with a bigger body is added |
| When built | One physics frame after `generate_world()` (bodies must be in the space); ~12 ms. Until then NPCs walk straight as before | — | — |
| Live updates | `refresh_area(rect)` re-tests cells; called for the hag's nest + firs | Scenery that appears mid-run | more runtime scenery (world editor live edits) |
| When to plan | Every trip, at the first step: straight line when the grid line of sight is clear (no A*), else A* + string-pulling (corner-to-corner legs) | Planning only after a collision would still bump into the rock first on ~57 % of trips; a route costs ~0.02 ms | profiling shows A* hot |
| Moving goals | Replan when the goal moved > 24 px, at most every 0.25 s; last leg homes in on the live target. "No route" retries after 1 s | Chasing soldiers/fleeing NPCs without replanning every frame | — |
| Unreachable goals | Activity targets and flee targets snap to the nearest walkable cell at pick time; a goal inside scenery also "arrives" at the route's snapped end | A goal inside a rock / beyond the wall can never be reached by any steering | — |
| Fleeing | Runs through the same route follower (`BaseNPC.steer_to`) | "Away from the dragon" often pointed into a lake | — |
| Safety net | `_check_stuck`: first stall → replan from where we stand; second → the old raycast sidestep; the StuckMonitor's rescue is now a **short hop** (~56 px along the route toward the goal, onto grid-walkable ground, as a 0.35 s slide), up to 4 per trip before the trip is abandoned | User: the old rescue (teleport next to the goal) was "a little over the top — just teleport a few steps towards the goal" | it never fires for a long time → remove |
| Miner slowdown | `BaseNPC._move_speed()` hook; Miner returns 0.9× while loaded | The old Miner `_waypoint_update` copy of the seek was dead code — the 2026-11-10 "10 % slower with gold" spec never applied | — |

## Result (after, same 4-minute survey, two random worlds)

**432 / 210 stalled NPC-seconds (−70 % / −86 %), 75 / 36 watchdog
interventions, 10 / 5 teleports or aborts.** Most of the remainder is
goblins standing still on purpose (they wait at their mountain until the
dragon's first encounter) — a false positive of the survey, not a stall.

## Deferred: "ant trails"

Record per-cell foot traffic and feed it back as a lower A* weight
(`astar.set_point_weight_scale`): routes stay guaranteed, but NPCs prefer
trodden ground, so desire paths emerge between town, mines and fields —
optionally drawn as worn dirt. A stall-only heatmap doubles as a debugging
view of remaining trouble spots.
