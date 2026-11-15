# The living ground: meadow hills, blended by every prop

Date: 2026-11-15.

## User spec

"The landscape is now all one single colour but I want it to be default
'meadow with hills'. However each prop and building should have an
influence that blends the environment into a suitable environment. I.e.
mountains cause rocky ground. Fields cause flat grassland etc."

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Technique | One ColorRect quad under the world (`scripts/systems/GroundTerrain.gd`, z −100, child of WorldManager) with `assets/shaders/ground.gdshader`. Rejected: TileMapLayer terrain (the world is a feature scatter, not a grid — see 2026-11-08-visuals-terrain) and baked textures (would not follow new landmarks) | Procedural, resolution-free, repaints when the world changes | — |
| Default ground | Meadow: rolling hills (3 broad noise octaves, ~620 px features) lit from the upper left, sunnier tops, deeper hollows, grass tufts, sparse wildflowers | "Meadow with hills" | — |
| Influence | Two RGBA splat maps, one texel per 16 px, painted on the CPU from every WorldManager child's scene path: full strength inside an inner radius, smooth fade to an outer reach, strongest influence wins. Shader warps the lookups with noise for organic, non-circular borders | Every prop shapes its surroundings | — |
| Biomes | rock (mountains ~2× base, mines, temple, tower), farmland (fields, around the city and pens — flat, mown), marsh (bog lakes, the hag's fen — standing pools), trodden dirt (city, pens, mines, tower yard, invader camp, sacrifice pole), forest floor (trees, firs), lush (glade, clear-lake shores — thick with flowers), sand (clear-lake rings), ash (the lair's mouth — glowing embers) | "Mountains cause rocky ground. Fields cause flat grassland" | new props: add a line in `GroundTerrain._paint_prop` |
| Hills vs. flat ground | Farmland, dirt, sand (and the glade, partly) iron the hill shading out | Tilled and trodden ground is flat | — |
| Repaint | After generation, and when a landmark rises: the hag's fen, the glade (its trees removed), the temple, the invader camp, a sacrifice pole. Coalesced to one deferred repaint per frame | Late landmarks change the land too | burnt fields → scorched ground? |
| Noise hash | Integer (uint) hash of lattice cells | A float `fract()` hash lost precision at world coordinates and striped the map with straight bands | — |
| Cost | Each biome's noise is only evaluated where its weight > 0 | Most of the map is plain meadow | — |
| Outside the walls | The ground continues 800 px past the boundary and dims into wilderness | The camera can look past the edge | — |

## Second pass: subtler (2026-11-15)

User: "The different environments must blend better and the rockground look
too cartoonish. Make difference more subtle."

- Gradients reach 30 % further and start 20 % earlier (`GroundTerrain._paint`);
  the shader follows them almost linearly (smoothstep 0.08–0.95) instead of
  thresholding, with gentler noise warp; every biome is capped below full
  strength so the meadow always shows through a little.
- Every biome colour is pulled 25 % toward the meadow.
- Rock: no black crack lines or bright pebbles — muted grey-green stone with
  grain, faint weathering, a few small stones, and grass growing through
  everywhere (more where the stone thins out).
- Marsh pools, farmland rows and lair embers all toned down.

## Third pass: evener greens, more flowers, more colour (2026-11-15)

User: "The difference between the two greens need to be even more subtle.
But please add more flowers in the meadow. Also saturate more."

- Meadow tones narrowed (both ends of the noise mix, sunny tops and lush
  hollows at quarter strength, finer tufts), hill shading clamped to
  0.9–1.08 with a gentler slope factor.
- Wildflowers: meadow density 0.05 → 0.16 on an 11 px grid (glade 0.34);
  still none on stone, dirt, marsh, sand or ash, few on farmland.
- Final colour saturated ×1.35 around its luma.

## Fourth pass: a quiet ground, a fierce flame (2026-11-15)

User: "We need it likely a lot less saturated, and instead increase
saturation on dragon flame (more intense colours)."

- Ground: the final saturation goes from ×1.35 to ×0.78 — a muted sage
  meadow; the ground is the stage.
- Dragon flame (Dragon.tscn ColorRects): outer (1, 0.20, 0) · mid
  (1, 0.46, 0) · core (1, 0.84, 0.18), embers in the same deep reds and
  oranges (were pale orange/cream). Greater Flame's ground fires
  (GroundFire.gd) use the same three colours over a deep-red bed.

## Fifth pass: more dynamic range — a flame shader (2026-11-15)

User: "It is not bad but need even more dynamic range. Lower the saturation
of the ground texture even more and increase saturation of the flame.
Maybe we should try writing a flame shader?"

- Ground saturation ×0.78 → ×0.55: a grey-sage stage.
- `assets/shaders/dragon_flame.gdshader` on one ColorRect (FlameFX, built by
  `Dragon._build_flame_fx`) inside Vis/FireArea/Flame, so the facing flip and
  Greater Flame's ×2 length still apply. A turbulent jet (noise streaming
  out of the mouth, sideways waver), a cone that flares and breaks into
  tongues at the tip, heat through a fully saturated ramp — white-hot core,
  yellow, orange, blood-red, deep-red fringe — and a soft orange halo; every
  edge fades so the rectangle never shows.
- The breath animation is unchanged and still the driver: the three old
  ColorRects are hidden; `_feed_flame_fx` passes OuterFlame's animated
  burst (scale 0 → 1.5 → 1) and fade to the shader as `power` / `fade`.
- Rejected: GPU particles (the ColorRect + shader keeps the existing
  animation contract and the 2026-11-13 fire-animation decision intact).

## Sixth pass: the grim-dark colour grade (2026-11-15)

User: "Saturation is now a little low, but we also need to harmonise the
colour grades across all assets. Pick a colour grading for a grim dark
setting and apply."

- `assets/shaders/color_grade.gdshader`: one full-screen pass on CanvasLayer 1
  (GameManager._build_color_grade). The HUD moved to layer 2; the wizard's
  shop (10) and story popups (12) stay above — the world is graded, the UI
  is not.
- The grade: exposure 0.8, saturation 0.64, contrast 1.2 plus a soft S,
  split tone (cold slate shadows 0.80/0.91/1.08, tarnished-amber highlights
  1.06/0.97/0.83), blacks lifted toward cold blue-grey, a heavy vignette.
- Fire and blood are protected: saturated, bright, red-leading pixels skip
  the exposure cut and the desaturation (×1.25 instead). The dragon's red
  hide falls under the same mask, so the hero stands out of the gloom.
- The ground's own saturation went back to ×1.0 — the grade sets the
  final level for every asset alike.

## Seventh pass: burning NPCs (2026-11-15)

User: "When NPCs are alit with fire they need a better shader too."

- `assets/shaders/body_fire.gdshader`: rising fire on one ColorRect over the
  body — turbulent tongues swaying as they climb, the dragon breath's
  saturated ramp (white-hot base → yellow → orange → blood-red tips), sparks
  drifting up, a glow. `intensity` flares over 0.25 s at ignition and
  gutters over the burn's last 0.7 s; a per-NPC `seed` keeps fires out of
  step. Sized from the body (44–76 px tall, 30–44 wide; the King burns
  bigger but capped).
- The overlay is a child of the NPC, not the sprite — the sprite's scorched
  tint (now a sootier 0.78/0.42/0.28) no longer dulls the flames.
- Greater Flame's ground fires use the same shader (`spread` = 1: wide, low)
  over their glowing bed — every fire in the game now matches.
- Follow-up (user: "before the NPC was ablaze from the hip up which made you
  appreciate the running legs more"): the body fire's base sits at the
  waist (85 % of the sprite's hip height, in NPC space), 34–60 px tall —
  the legs run free beneath it, as with the old tongues.
- Follow-up (user: "the flame has a very flat bottom and seems static when
  the rest of the body moves … more like a candle flame"): a body fire is now
  a candle-like teardrop — round base, pinched tip, ragged licking edges
  with dark gaps flickering through, its height flickering on its own. It
  rides the rig's Torso (bobbing on every footfall, leaning into the run;
  anchored over the chest) and streams back from the run (`lean`, eased
  from velocity.x, so a turn swings the tip over). 30–46 px tall, 22–32
  wide. Ground patches keep the wide ragged bed (`spread` = 1).

## The breath's hitbox (2026-11-15)

User: "The hitbox for the dragon fire is currently strange. It seems to take
a lot of hits far below the actual flame."

The ignition test was a ±75° fan (`fire_ignite_cone` 0.25) out to the full
reach: at 95 px it lit actors ~90 px above and below a jet drawn ~±17 px
tall. Now `Dragon._in_breath`: a band from 8 px behind the jaws to
`fire_reach`, half-width 12 px at the mouth widening 0.14 px per px (±25 at
the normal tip, ±37 at Greater Flame's). An actor burns when its feet stand
in it; a field when its 68×52 plot overlaps it. `fire_ignite_cone` is gone.
Probe: farmers at (60, 0) and (90, 10) ignite; (60, ±45) and (150, 0) don't.
- Follow-up ("could be a tiny bit larger"): half-width 12 → 16 px at the
  jaws, flare 0.14 → 0.18 (±33 px at the normal tip).

## Greater Flame's ground fires ignite (2026-11-15)

User: "The fire on the ground does indeed kill the soldiers but they need to
burst into flame too." `GroundFire._doom`: whoever steps in catches fire
(the burning body and the panic run) and the Queen's fire finishes them
1.1 s later; marked once per actor. Actors who can't burn or whose fire
cloak holds still die at once; the fireproof slayer is unharmed.
