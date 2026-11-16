# The rider takes the hit

Date: 2026-11-16.

User: "In some cases when fighting a boss like the wizard, the dragon rider
can take the hit for dragon. When dragon is about to die from lightning or
the sword storm, open a story popup where the dragonrider takes the hit
instead. Dragon is now without a dragon rider but survives to fight again.
Dragon also gains two charges as she gets vengeful."

| Decision | Choice | Why |
|---|---|---|
| When | `Dragon.take_damage`: a rider is mounted, the blow is MAGIC from `"wizard"` (lightning) or `"king"` (sword storm), and after the shield it would bring health to 0 | "about to die from lightning or the sword storm"; other killers (soldiers, arrows, goblins) still kill |
| The blow | Spent entirely on the rider: no damage to the dragon | "survives to fight again" |
| The rider | `has_rider` off, `RiderPivot` removed, fire multiplier reset. A new captive can be trained again, and that rider can fall the same way | "without a dragon rider" |
| Vengeance | +2 flame capacity, arriving loaded (`increase_flame_capacity(2)`, like the wizard's "+2 Flames") | "gains two charges as she gets vengeful"; capacity rather than an overfill, because the regen clamps charges to the max |
| Grace | 2 s of no damage after the fall (ticks only while the world runs, so it starts when the popup closes) | Otherwise the next bolt undoes the sacrifice at once |
| Story | `rider_fall_wizard` / `rider_fall_king` ("The Empty Saddle"), opened by `GameManager._on_rider_fell` (signal `Dragon.rider_fell`), not once-per-run. The rider's own last words are appended as the note (`RIDER_LAST_WORDS`, by personality; `Dragon.rider_personality` is set when the rider is trained) | Each of the seven captives dies as themselves |
