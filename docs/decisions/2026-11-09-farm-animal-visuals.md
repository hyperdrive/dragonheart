# Farm + animal visuals — decisions

Date: 2026-11-09. User: "make the farms look better. Also make the pigs
look more like pigs and the cows more like cows."

## User spec

1. Farms look better.
2. Pigs look like pigs (they were pink letter-"P" blobs on a 32px canvas).
3. Cows look like cows (same, letter-"C" brown blobs).

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Animal art format | new SVGs on a 48px canvas replacing the 1-bit PNGs — `assets/pig.svg` (pink body, shaded belly, curly tail, 4 legs with hooves, ears, snout with nostrils, eye) and `assets/cow.svg` (white body with brown patches, horns, ears, pink muzzle with nostrils, udder with teats, swishing tail, dark hooves) | The repo's art precedent is SVG (gold gems, mine hill); SVG scales crisply and edits as text |
| Pen resolution of the swap | pig sprites at scale 0.75, cow 0.8 — the cow sprite reads slightly larger than the pig (cow body is wider in the art; the scales keep the species-size contrast the pens always had) | User asked pigs ≈ pigs and cows ≈ cows, with the pre-existing size relation preserved |
| Slot pool | no AnimalPen change — the pool already copies template texture/scale into freshly created hidden slots | A respawned animal gets the real art with zero new code |
| Field layout | layered visual stack: dark soil plot base (72×56), `Crops` color-flip rect (kept exactly, name intact), green furrow strip node `CropRows` (visible when GROWN), tan `StubbleRows` (visible when burnt), plus the pen-family fence rails/posts on z 1–2 | The old field was one flat green ColorRect — indistinguishable from grass at a glance; furrows + a soil border + fence read as A FARM |
| State-visual architecture | single `_apply_state_visuals()` funnel on Field used by `burn()`, `regrow()` and `_on_regrow_timeout()`; row overlays are `get_node_or_null` optionals so every field-across-variants still boots if overlays are absent | Burn→stubble and regrow→grown both flipped base color in three places; a single funnel keeps base AND rows in agreement and keeps the `$Crops` node name for the Dragon/farmer integration |
| Per-field variation | small random brightness/hue jitter to `modulate` in `_ready()` (0.9–1.1, ±0.04 warmth) | Identical plots grid-aligned looked cloned; the jitter breaks the pattern like real farmland |
| Economy untouched | burn/regrow durations, claim lease, workable() semantics, delivery flows all unchanged | This is a visual batch — zero tuning moves |

## Verified

`probe_farm_visuals.gd` 20/20: pens resolve, both sprite templates carry
the .svg (48px canvas), field starts GROWN with green rows + green base,
burn() flips BOTH rows to tan + stubble color and unworkable(), gold
regrow() restores rows + workability, the slow RegrowTimer path runs
through the same funnel, the slot pool copies the SVG, per-field tint
jitter prints sane. 14400-frame regression: **0 script errors**, field
burn events + pen refills flowing.

Helper re-verified headless after the SVG constexpr (probe uses
`resource_path.ends_with` + `get_size()` asserts so the actual art is
what loads, not just the file existing).
