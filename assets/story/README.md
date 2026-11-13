# Story Popup Images

Artwork for the TTRPG story popup (`scenes/ui/StoryPopup.tscn`,
`scripts/ui/StoryPopup.gd`) lives here — drop future chapter
illustrations in this folder.

## Conventions

- **One image per story kind.** Name files after the story key in
  `StoryPopup.STORIES` (e.g. `king_emerge.png`, `sacrifice_approach.svg`).
- **Format:** SVG or PNG, landscape-ish (the popup's image frame is
  ~640×130 at min size; the art fills it with `STRETCH_KEEP_ASPECT_COVERED`,
  so keep key subjects away from the far left/right edges).
- **Wiring:** set the story's `"image"` path in `StoryPopup.gd` to
  `res://assets/story/<file>` and pick a matching `"tint"` backdrop color.
  An empty string `""` shows the framed tint without art.

## Story vignettes (2026-11-14)

Panoramic 552×100 SVGs (imported at 2× for crispness) that fill the image
frame edge to edge. Story kinds that share a theme share one vignette:

| File | Story kinds |
|---|---|
| `story_fields_burn.svg` | `peasant_burn_1..5`, `field_burn` |
| `story_mine_fire.svg` | `miner_burn` |
| `story_king.svg` | `king_emerge`, `king_defiant` … `king_renegade` |
| `story_king_fallen.svg` | `king_defeat*` |
| `story_wizard.svg` | `wizard_emerge` |
| `story_pig.svg` / `story_cow.svg` | `pig_eaten` / `cow_eaten` |
| `story_dragon_fall.svg` | `dragon_death*` — its sky is translucent so the per-killer `"tint"` shows through |
| `story_goblins.svg` | `goblin_encounter_*` |
| `story_sacrifice.svg` | `sacrifice_*` |
| `story_rider.svg` | `rider_upgraded` |

The old 96×96 icons (`assets/field_fire.svg`, `pick_flame.svg`,
`king_crown.svg`, `wizard_bolt.svg`, `dragon_fall.svg`) are no longer
referenced by stories; `pig.svg` / `cow.svg` remain the pen sprites.
