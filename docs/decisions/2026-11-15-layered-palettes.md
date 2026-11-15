# Layered palettes — four grim-dark colour schemes to cycle

Date: 2026-11-15.

## User spec

"Explore different colour schemas. Take a look here:
https://color.adobe.com/explore?q=grim+dark . Please select four which I can
cycle through. Right now there are no warm colours so I'm thinking we should
work with layers. Back layer, ie the ground should be grim dark. Houses
should be more saturated towards a warm tone and characters should be
bright. Only compatible colours, even if they don't follow same gradients."

The Adobe Color explore page renders in JavaScript; fetched, it returns
only the generic trending list, not the search results. The four palettes
below are designed in that spirit; Adobe themes can be dropped in by hex
(scripts/systems/Palettes.gd).

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Layers | back: the ground (GroundTerrain) + the land (mountains, trees, firs, lakes, glade) · middle: houses and works (city, tower, mines, pens, fields, hag's hut, temple, lair, invader camp, sacrifice pole) · front: the dragon and every NPC | User spec | new props: add the scene path to GameManager.BACK_SCENES / MIDDLE_SCENES |
| Mechanism | `assets/shaders/layer_grade.gdshader` material on each layer root; drawn descendants inherit it (`use_parent_material`); anything with its own shader (dragon flame, burning fire) keeps it. New nodes are graded as they enter WorldManager; the dragon again on each shape change. The ground shader takes the back layer's grade directly | One material per layer, three in all — cycling a palette updates them in place | — |
| The grade | Gradient map: luminance → the layer's dark/mid/light ramp, replacing the original colour by `mix`; then saturation and exposure. Fire and blood are left alone | Gradient maps harmonise wildly different art; `mix` keeps each asset's own detail | — |
| The full-screen pass | `color_grade.gdshader` now only frames: vignette, faded cold blacks, a hair of contrast | The colour moved into the layers | — |
| Palettes | 1 **Ashen Hearth** — slate & lichen land, rust & ochre hearths · 2 **Blood Moon** — bruised-violet dusk, crimson & brass · 3 **Peat & Lantern** — bog-brown moor, amber lanterns · 4 **Frostbitten** — teal steel & frost, copper candlelight. Back: mix ~0.6, saturation ~0.72, exposure ~0.9. Middle: warm ramp, mix ~0.4, saturation ~1.2. Front: neutral-warm ramp at mix ~0.12, saturation ~1.1, exposure 1.1 | Warm middle opposite the cold back on the wheel: compatible without sharing a gradient | after playtesting |
| Cycling | **C** — HUD names the palette | Free key (WASD, E, Q, T, Space, F6 taken) | — |

## Follow-up: Peat & Lantern, brighter buildings (2026-11-15)

User: "I like the peat and lantern, but buildings need to be brighter."
Peat & Lantern is the default palette (`Palettes.DEFAULT`); its middle layer
got a lighter ramp (3a2812 / c98a34 / ffe3a0), exposure 1.02 → 1.25, a
little less ramp (0.36) so the buildings' own colours show through.

## Follow-up: brighter still, and the leaf trees (2026-11-15)

User: "The buildings can be brighter still. And we need to work on the leaf
trees. Make a few variations, and stem needs to be more brownish."

- Peat & Lantern middle layer: ramp 4a3418 / d89a44 / fff0c4, mix 0.3,
  exposure 1.45 — warm, bright sandstone.
- Leaf trees: four variants (assets/sprites/tree_oak, tree_elm, tree_old,
  tree_rowan; generator in the session scratchpad, gen_trees.py), drawn in
  the old tree's 64×64 frame and imported at 2×: a broad oak, a tall elm,
  an old gnarled tree with a sparse split crown and a dead twig, an
  autumn-touched rowan with red berries. Tapered brown trunks (80522b, lit
  a36d3c, shadow 4f301c) with root flare, branch forks and bark lines.
  `scripts/props/LeafTree.gd` picks one per spawn (35/30/15/20 %), mirrors
  half, scales 0.9–1.12 with the foot kept on the ground line, and swaps
  the old flat grey shadow slab for a soft round one.
- A fourth grade layer, "land" (trees and firs): the back palette at 40 %
  ramp strength, saturation +0.25, exposure +0.16 — the full grim ramp had
  washed the bark to olive-grey. Palettes may name their own "land".
