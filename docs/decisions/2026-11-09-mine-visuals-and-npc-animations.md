# Mine redesign, NPC animations, flee border clamp — decisions

Date: 2026-11-09. Presentation-layer + supervision follow-ups to
`2026-11-09-town-purchases-and-stuck-fixes.md`.

## User spec

1. "The Mines look terrible — redesign, make it look like a hill or
   mountain." (They were flat gray ColorRect boxes.)
2. Miners sometimes get stuck on the (map) border.
3. Mining animation for miners: hammering with a pickaxe.
4. Fleeing animation for ALL NPCs: wobbly cartoonish run, jumping from
   foot to foot as they run off.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Animation tech | Code-driven on the `$Sprite` container (no AnimationPlayer/frames) | NPC bodies are ColorRect composites; three float phases sell both looks without a rig |
| Flee wobble scope | ALL NPC types, in BaseNPC | One hook, every type; container hop/lean/squash reads as "jumping foot to foot" |
| Wobble cadence | 9Hz bounce, ±4.5px hop, ±0.18rad lean, squash −12% on landings | Fast + rhythmic = panic tone; tuned by probe, reset exactly to rest pose |
| Mining arc | Pick pivots at handle top, −62°→+12° at 2.2Hz, warm modulate flash at slam, body dip | Reads as hammering while keeping the flat-color style; fires only in the `mine` WORKING phase |
| Mine art | New SVG (`assets/sprites/mine.svg`) — grassy hills, timber arch, boulders, spoil heap, rail; gold/gem piles stay script-controlled Polygon2D nodes named Gold/Gems | Matches the flat-polygon house style (mountain/lair/tree palettes); Mine.gd reuse without changes — node names are load-bearing |
| Border wedge fix | Clamp flee targets into the interior band (`clamp_into_playfield`, pad = own radius) in check_danger | The wedge is the escape vector pointing past the boundary while the dragon keeps the pressure — clamping turns pin-in-wall into slide-along-wall |

## Gotchas recorded

- `.tscn` free-text comments (`##`) corrupt node parsing — Godot scene
  comments are `;` only; the corrupted Mine.tscn silently renamed its
  visual subtree (probes caught it).
- A typed `WorldManager` field inside BehaviorTree adds a parse-time
  edge into `WorldManager -> preload Miner.tscn -> Miner.gd` and breaks
  compilation of Miner — BehaviorTree's world cache stays untyped, the
  call path is dragged each tick only while actually fleeing.

## Verified

- Probes: 8 mines all carry Hill Sprite2D + visible Gold/Gems ore piles;
  miner's pick swings below −30° during WORKING and resets after;
  wobble engages in ≤240 frames of flee and resets exactly to
  rotation 0 / scale.y 1 / home position when danger passes; flee target
  clamps to ±708 when the dragon presses a cornered NPC; 4800-frame
  regression with zero script errors.
- Rendered screenshot (`/tmp/opencode/mine_zone.png`) reviewed: mine
  cluster reads as a range of little hills with entrances + ore piles.
