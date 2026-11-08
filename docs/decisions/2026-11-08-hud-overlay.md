# HUD overlay rework — decisions

Date: 2026-11-08. Companion to `2026-11-08-visuals-terrain.md` (minimap attempt).

## Problems (user report)

"Minimap should be in the lower right always; game states should be on a top
border; HUD doesn't look like a good overlay."

Root causes found:
- **The HUD was not in a CanvasLayer** — it sat under Main (Node2D) in the world
  canvas, so the Camera2D transform shifted every HUD control with the world;
  it behaved like a world object, not an overlay.
- `DragonStats` panel had `anchor_right = 150.0 / anchor_bottom = 150.0`
  (anchors are fractions — 15,000% of the parent) with `anchors_preset = -1`:
  its labels rendered far outside any sane region, so the dragon levels were
  effectively invisible.
- `UpgradePanel` opened bottom-right (`anchors_preset = 3`) — directly under
  the minimap, covering it whenever the player pressed U.
- The stash label was created at runtime and stuffed into a bottom-left panel;
  game state was scattered in three corners instead of one readable strip.

## Decisions (per godot-ui patterns)

- **CanvasLayer**: Main now hosts `HUDLayer` (CanvasLayer, layer 1) and HUD
  instance beneath it — screen-space HUD, camera-independent (skill §1).
- **TopBar chip strip**: all game state lives in one top-wide translucent Panel
  (StyleBoxFlat, 0.72 alpha, rounded lower corners) → MarginContainer →
  HBoxContainer of_LABEL chips: Treasury, Food, Stash, Claws (carried loot,
  gold-tinted), Scales, Fire, and a right-aligned Threat chip
  ("Soldiers: N • swarm-state • ⚔ KING"). Rejected: keeping scattered corner
  panels.
- **Threat chip is a live scan, not a counter**: initial soldiers spawn during
  `WorldManager._generate_world` (sibling child) BEFORE GameManager._ready can
  connect anything — a stream counter misses the first 4 (the same ordering
  insight that made the minimap self-scan). `refresh_threat()` re-counts the
  soldiers/king groups; swarm state comes via the WorldManager signal.
- **Minimap exclusive in the lower-right**: UpgradePanel re-anchored
  bottom-LEFT (also the correct grow directions) so the U-menu can never cover
  it; MessageLabel narrowed to a center strip (offsets 260..-240) so it lands
  left of the minimap; root Control `mouse_filter = IGNORE` for a quiet
  overlay, while interactive children keep their own filters.
- **Same layout survives resize**: anchors/eight-offsets (not fixed positions)
  — verified by resizing the window at runtime and re-measuring rect corners.

## Verification (headless, zero errors)

- 7/7 top-bar chips present and filled; "Claws: 2" reflects a live
  `take_loot` immediately.
- Minimap rect pinned: bottom-right at 1024×768 default and after runtime
  resize to 1440×900 (`end (1430, 840)` = designed 10/60px margins).
- Message strip right edge < minimap left edge; upgrade panel (opened via a
  real InputEventAction "upgrade") spans x 0..250 — separated from the
  minimap at x≥804; toggles closed again.
- Threat chip correct from startup: "Soldiers: 4 • calm".
- Full-run regression: zero script errors; economy/drop/haul loop untouched.
