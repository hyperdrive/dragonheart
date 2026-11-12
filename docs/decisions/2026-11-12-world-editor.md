# World editor — decisions

User spec 2026-11-12: an editor to place key elements (goblin mountain, dragon
lair, city, wizard tower); fields, mines, forest, lakes determined by MASKS with
the exact placement randomized inside them; two tree-density masks; support
starting the project in different "modes".

Off-ramp taken ("These are good defaults … go ahead and build it") — all
recommendations recorded as settled.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Editor nature | In-project **runtime editor mode** (own scene, mouse placement/painting) | Matches the "start in different modes" framing; zero plugin plumbing; reuses the house scene-launch convention (probes) | a professional asset pipeline is wanted |
| Layout data home | Custom Resource `WorldLayout` — `res://worlds/<name>/layout.tres` + mask PNGs beside it | Typed, Inspector-editable; the game loads one `.tres` and falls back to full-procedural generation when none is set | worlds need per-run scripts/overrides |
| Mask authoring | Painted **inside the editor**, one grayscale mask image per category (fields, mines, forest-dense, forest-sparse, lakes) | One PNG per category is trivial to load, sample and debug; the two tree densities are exactly two masks | categories multiply into dozens |
| Mode/boot | Scene-per-mode: editor at `res://scenes/editor/WorldEditor.tscn`; game runs select a saved world via `WorldSession.pending_world` (editor Play button) or `--world=<name>` command-line user arg; empty → legacy procedural | Direct scene launch is already the house style; `main.tscn` stays untouched | a graphical boot menu is wanted |
| Determinism | Layout stores an RNG **seed**; editor has a Re-roll button; same layout + seed = identical world | Probe-verification of saved worlds requires reproducible placement | variety-on-every-run is wanted |
| Editor canvas | **Blank terrain canvas** (ground + grid + footprints), no NPCs/economy | The editor authors the pre-run layout; a live world would leak spawns/loot into the save | in-game rearranging is wanted |

## Derived facts

- Mask sampling: masks are grayscale `Image`s at half world resolution
  (`MASK_SCALE 0.5`); brightness ≥ 128 is placeable, brightness is the
  rejection-sampling weight; candidates must still pass the existing
  clearance checks (`_terrain_free_position`).
- The game never edits a layout at runtime; the editor is the only writer.
- Resolution order for the active world: `WorldSession.pending_world` (set by
  the editor's Play button or a probe) → `--world=<name>` user arg → none.
