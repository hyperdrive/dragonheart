# Visuals, terrain & swarm pass — decisions

Date: 2026-11-08. Companion to `2026-11-08-behavior-system.md` (unchanged contracts).

## Problems (user report)

Farmers/miners invisible (empty Sprite2D in their scenes); most work sites off-screen
(world 2000×2000 vs ~1365×1024 view at zoom 0.75, camera on the dragon start); minimap
stubbed out and anchored top-right; no cow/pig pens existed; fire breath had a collision
Area but no visual; no scenery; soldiers straggled individually.

## Decisions

- **NPC visuals: ColorRect composites** (match Soldier/Dragon/WizardTower style; zero new
  assets, no import variance). Rejected: PNG/SVG characters — no source art to match.
- **Scenery: authored SVG textures** (tree/mountain/lake/city in `assets/sprites/`),
  scenes in `scenes/props/`. Rejected: TileMapLayer terrain — the world is a feature
  scatter, not a tile grid; blocking obstacles are individual StaticBody2D with
  **circular shapes** so direct steering-seek slides around them (no nav mesh, per the
  behavior-system decision).
- **World layout is feature-based, not uniform scatter**: city (0, 620) — soldier anchor;
  field belt rings it; pig/cow pens beside the farms; mining district NW. Terrain spawns
  with **clearance checks** against features + prior obstacles (`_terrain_clearances`).
  WorldManager now sets NPC anchors after `add_child` (it was designed for this; BaseNPC
  spawn-relative defaults remain the fallback).
- **Minimap: custom `_draw` dot panel** self-scanning groups on a 0.3s timer, lower-right
  corner (overlapping ResourcePanel moved bottom-left). Rejected: SubViewport camera map —
  heavier and untestable headless for a debug-style dot map.
- **Swarm tactics**: WorldManager owns a `SwarmState` machine (CALM → RALLY → ATTACK):
  dragon within `rally_range` of the city (or a soldier sighting cityward) → RALLY at
  `rally_point`; ATTACK when `swarm_size` soldiers massed, dragon at the walls, or the
  King spawns. Soldier runs `rally` activity (priority 40) and gates `attack_dragon` on
  ATTACK state; King `aggro_range` 10000 + forced ATTACK on spawn.
- Fire breath: Flame composite under FireArea toggled with the monitoring window.

## Verification

Headless: zero errors; farmers cluster/deliver to the city gate (anchor probe);
swarm CALM at start, RALLY→ATTACK on approach probe; dragon damaged by released swarm;
flame visibility toggles; 22-obstacle terrain budget minus crowded skips.
