# Lakes: flight, visuals, merging — decisions

Date: 2026-11-13. User: "The dragon character currently can't fly over
lakes. Lakes should not be blocking when flying. Make lakes look more
like lakes and if two lakes end up overlapping, merge them into one
lake." Revised the same day: "The dragon can now walk over lakes which
is wrong. The dragon should only be able to cross lakes when flying.
The lakes are still just ellipsis. They should be more complex shapes."

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Flight over lakes | Lakes move from shared solid layer 1 to their OWN layer 6 (value 32). The GROUNDED dragon mask includes layer 6 (19 → 51) — walking into a lake is blocked; `_try_flight` drops layers 5 AND 6 for the flight lane, `land_flight` restores both. Walkers + goblin masks grow 17/15 → 49/47; `BehaviorTree.SCENERY_RAY_MASK` 17 → 49 keeps detour/shadow rays shore-aware | Extends the 2026-11-09 tree-layer pattern ("drop the layer you fly over"); layer 1 stays mountains/lair/walls, which must still block aloft; first cut let the grounded dragon wade — user corrected: ONLY flight crosses | lakes should block flight again, or another flier appears |
| Landing over open water | REFUSED: `_try_flight` while airborne over `_over_water()` prints "Too much water below to land — glide to a shore!" and keeps flying; the auto-expiry check already never fires over water | A blocking lake shape would trap the landed CharacterBody INSIDE the static circle — the dragon could never leave; refusal keeps grounded-vs-flying semantics consistent (water is never landable) | a "splash/refresh at shore" landing is wanted |
| Water-under-dragon test | New `Dragon._over_water()` helper; reach follows the lake's ACTUAL shape radius (+20px) instead of a fixed 70px | Merged lakes grow past 62px; a fixed check would miss their shores | lake shapes become non-circular |
| Lake visuals | `lake.svg` redrawn as GENUINELY IRREGULAR nested bezier-blob paths (vegetation ring, uneven sandy beach, lobed water with a bay biting in from the east), plus an island, a sand spit, depth shading, ripples, lily pads, reeds on two shores. `scripts/props/Lake.gd` rotates (and optionally mirrors) the shared art per spawn — free variety because the collision stays round | First cut was overlapping ellipses — user: "still just ellipsis"; rotation/mirror gives every lake a different silhouette from one texture | hand-drawn art replaces composites |
| Lake collision | Stays a single CircleShape2D (r62 default) even though the art is irregular; water never paints beyond ~r54 so walkers/dragon stop at or before the shoreline | Circle collision keeps merge math, footprint clearances and NPC steering trivial; ellipse-in-circle mismatch was already the shipped norm | shore-accurate polygon collision is wanted |
| Overlap merging | `merge_adjacent_lakes` = union-find clustering of INTERSECTING circles (dist < r1 + r2, chains included); each cluster becomes ONE lake covering the union — area-weighted centroid + covering radius, fresh `CircleShape2D` (the scene shape is a SHARED SubResource — mutating it resizes every lake), sprite scaled `radius / 62`, footprint registered with the real radius | User spec; the old 50px "near" merge fused lakes that were NOT touching and replaced them with a default-size lake (collision 62 vs registered footprint 85). Placement keeps fresh lakes 30px apart, so merging is the guarantee when overlaps do appear | lakes should also fuse when merely near each other |

## Verified

Headless: `custom_world` + `sample_world` boots 0 script errors;
WorldLayoutProbe SUCCESS 9/9 (probe gained a `mountains` REGIONS entry +
on-mask check — it had been silently broken since the 2026-11-13
mountains category); VillagerVisualProbe SUCCESS (walkers unaffected).
New `testfiles/lakes_flight_merge_check.gd`:
- GROUND: dragon mask scans lake layer 6 (walking blocked) while layer 1
  (mountains/walls) stays,
- AIRBORNE: `_try_flight` clears trees AND lakes,
- WATER LANDING: refused over open water ("glide to a shore!"),
- LAND: touchdown on dry ground restores lake blocking,
- merge: two planted overlapping lakes → ONE lake, shape radius 112
  covers both origins, sprite scale follows.