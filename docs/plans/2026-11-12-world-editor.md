# World editor — implementation plan

Decision record: `docs/decisions/2026-11-12-world-editor.md` (off-ramp: all
recommended answers assumed). Existing behavior decision 2026-11-08 governs the
NPC economy — untouched; the editor only changes WHERE the world's pieces sit.

## Design

```
Main.tscn
└── WorldManager  (generation: layout-driven when a world is selected,
                   else today's full-procedural path — untouched fallback)

WorldEditor.tscn (scenes/editor/, run directly like a probe)
├── WorldEditor (Node2D, root — draws ground/grid/footprints/ghost, owns input)
│   ├── Camera2D                (whole-world view; wheel zoom, right-drag pan)
│   ├── MaskOverlay ×5 (Sprite2D per category, ImageTexture, modulated color)
│   └── UI (CanvasLayer, code-built)
│       ├── TopBar: place buttons (city, lair, goblin mountain, wizard tower,
│       │          pig pen, cow pen, mine district) + brush buttons (fields,
│       │          mines, forest dense, forest sparse, lakes, eraser) + size
│       └── BottomBar: name LineEdit, seed SpinBox, Re-roll, Load, Save, ▶ Play
└── data: per-category Image (L8, world_size*0.5) + key-position dict
```

Signal map: editor is a leaf tool — no signals out; it writes files.
Data flow: click/drag → editor state (positions dict / mask Image) → Save →
`res://worlds/<name>/` (masks PNG + layout.tres) → Play → `WorldSession.pending_world`
→ WorldManager loads layout → generation samples masks for exact placement.

## Tasks

- [ ] **Task 1: `WorldLayout` resource** — `scripts/main/WorldLayout.gd`: key
  positions (city, lair, goblin mountain, wizard tower, pens, mine district),
  counts (non-zero override), seed, 5 mask textures; save/load helpers writing
  PNGs + `.tres` under `res://worlds/<name>/`; mask<->world coordinate mapping.
  Skills: `godot-prompter:resource-pattern`, `godot-prompter:save-load`
- [ ] **Task 2: `WorldSession` autoload** — pending world name (editor Play /
  probe) vs `--world=` command-line user arg; registered in project.godot.
  Skills: `godot-prompter:dependency-injection`
- [ ] **Task 3: layout-aware generation in WorldManager** — apply layout
  (positions, counts, seeded `_rng` routed through the generation randomness),
  mask-anchored placement for fields / mines / dense+sparse trees / lakes
  (rejection sampling + existing clearance checks); mountains stay random.
  Skills: `godot-prompter:procedural-generation`, `godot-prompter:math-essentials`
- [ ] **Task 4: WorldEditor scene** — blank canvas, grid, footprint ghost,
  placement palette, mask brushes (half-res L8 images), eraser, seed re-roll,
  save/load, ▶ Play into the game.
  Skills: `godot-prompter:godot-ui`, `godot-prompter:2d-essentials`
- [ ] **Task 5: `WorldLayoutProbe`** — programmatic layout (painted masks, fixed
  seed) → save → boot Main via `WorldSession.pending_world` → assert landmarks
  at layout positions, scenery/fields/mines inside their masks, and second boot
  reproduces identical placements (seed determinism). Also the no-layout
  fallback (default city position).
  Skills: `godot-prompter:godot-testing`
- [ ] **Task 6: verify headless** (probe + `--quit-after` boot check), update
  decision record, commit.
