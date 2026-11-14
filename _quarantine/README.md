# Quarantine (2026-11-14)

Files moved out of the Godot project because they fail to parse or load and
nothing in the game uses them. Godot skips this whole folder (`.gdignore`).
Decide later per file: fix and move back, or delete.

| Moved | From | Problem |
|---|---|---|
| `root/*.gd`, `*.gd.uid`, `*.tscn` | repo root (gitignored debug tools, Nov 4–6) | Godot 3-era API (`Input.parse_event`, `get_window_mode`), syntax errors, missing `await` |
| `scenes/test/` | `scenes/test/` (gitignored) | references the root test scripts; duplicate UIDs with Main.tscn / each other |
| `scripts/test_input.gd` | `scripts/` (gitignored) | Godot 3-era `Input.parse_event` |
| `scenes/ui/Minimap.tscn` | `scenes/ui/` (tracked) | invalid `script = preload(...)` line; unused (the HUD draws its own minimap) |
| `scripts/probes/KingDefeatProbe.gd` + scene | `scripts/probes/`, `scenes/probes/` (tracked) | stray `\` at line 105 |
| `scripts/probes/SacrificeProbe.gd` | `scripts/probes/` (tracked) | Variant-inference warning-as-error at line 31; also predates the 2026-11-14 sacrifice dialogue flow |
| `assets/fonts/DefaultFont.tres` | `assets/fonts/` (tracked) | declared as the abstract `Font` class (Godot 3-style stub) — the editor's file preview errors "Class 'Font' cannot be instantiated"; unreferenced |
| `assets/fonts/StoryPopupFont.res` | `assets/fonts/` (tracked) | not a valid binary resource ("Unrecognized binary resource file"); unreferenced — StoryPopup uses Metamorphous-Regular.ttf directly |
| `assets/animations/` (all six files) | `assets/animations/` (tracked, initial commit) | unreferenced — the dragon animates procedurally now; the three `dragon_anim*.tres` have malformed tracks (3 key times, 2 transitions → "transitions.size() != valcount") |
| `assets/shapes/dragon_shape.tres`, `fire_shape.tres` | `assets/shapes/` (tracked) | malformed (a `[sub_resource]` inside a `[gd_resource]` with no `[resource]`) → parse error; unreferenced (the dragon defines its shapes in its own scene) |
| `root-assets/icon.png` (+ `.import`) | repo root | 95 bytes of ASCII text, not a PNG → "Failed loading resource"; unreferenced (`config/icon` is commented out; `icon.svg` remains) |
