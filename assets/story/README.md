# Story Popup Images

Artwork for the TTRPG story popup (`scenes/ui/StoryPopup.tscn`,
`scripts/ui/StoryPopup.gd`) lives here — drop future chapter
illustrations in this folder.

## Conventions

- **One image per story kind.** Name files after the story key in
  `StoryPopup.STORIES` (e.g. `king_emerge.png`, `sacrifice_approach.svg`).
- **Format:** SVG or PNG, landscape-ish (the popup's image frame is
  ~640×130 at min size and stretches with `STRETCH_KEEP_ASPECT_CENTERED`).
- **Wiring:** set the story's `"image"` path in `StoryPopup.gd` to
  `res://assets/story/<file>` and pick a matching `"tint"` backdrop color.
  An empty string `""` shows the framed tint without art (see the goblin
  stories).

## Currently used story art (still in `assets/`)

`field_fire.svg`, `pick_flame.svg`, `king_crown.svg`, `wizard_bolt.svg`,
`pig.svg`, `cow.svg`, `dragon_fall.svg`, plus `assets/sprites/sacrifice.svg`
and `assets/sprites/dragon+rider.svg`. Existing stories keep those paths;
new art should go here.
