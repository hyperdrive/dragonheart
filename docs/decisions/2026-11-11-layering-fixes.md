# Layering issues fix — decisions

Date: 2026-11-11. Bug: dragon fire doesn't burn fields, and sacrifices don't spawn.

## Issues identified

### Issue 1: Field burning doesn't work

**Root cause:** In `scripts/characters/Dragon.gd`, the `_ignite_flammables()` function had a type-checking order bug:

```gdscript
# BUGGY CODE:
var base := node as BaseNPC
if base == null:
    continue  # ← Fields skipped here!
# ... more checks ...
if node is Field:        # ← Never reached for Fields
    (node as Field).burn()
```

When iterating through the "fields" group, nodes are `Field` instances (not `BaseNPC` subclasses). The cast `node as BaseNPC` returns `null`, causing Fields to be skipped before they could reach the `if node is Field:` check.

**Fix:** Reorder the logic to check for `Field` nodes first:

```gdscript
# FIXED CODE:
# Fields are not BaseNPC subclasses, so handle them first
if node is Field:
    var field := node as Field
    var to_target := field.global_position - global_position
    if to_target.length() <= fire_reach and \
       to_target.normalized().dot(facing_vec) >= fire_ignite_cone:
        field.burn()
    continue

# Now handle BaseNPC subclasses (farmers, miners, soldiers, goblins, king)
var base := node as BaseNPC
if base == null:
    continue
# ... rest of NPC checks ...
base.catch_fire()
```

### Issue 2: Sacrifices don't spawn

**Root cause:** The sacrifice system (implemented but uncommitted) was not integrated with the field burning system:

1. `WorldManager` was missing the `fields_burnt_count` variable
2. `WorldManager` was not connecting to the `field_burnt` signal from Field nodes
3. The field signal connection was made in `_ready()` BEFORE `generate_world()` was called, so when the connection code ran, no fields existed yet (fields are spawned in `generate_world()`)
4. The Sacrifice scene's collision layer was set to 0, but the dragon's EncounterArea expects bodies on layer 4

**Fixes applied:**

1. Added `fields_burnt_count: int = 0` to `WorldManager`
2. Moved field signal connection to AFTER `generate_world()` in `_ready()`:
   ```gdscript
   generate_world()
   # Connect to field_burnt signal AFTER generation (fields are created in generate_world)
   for field_node in get_tree().get_nodes_in_group("fields"):
       var field := field_node as Field
       if field != null:
           field.field_burnt.connect(_on_field_burnt.bind(field))
   ```
3. Added `_on_field_burnt()` handler:
   ```gdscript
   func _on_field_burnt(field: Field) -> void:
       fields_burnt_count += 1
       print("WorldManager: Field burnt at %s (count: %d)" % [
           str(field.global_position), fields_burnt_count])
       # Spawn sacrifice every 3 fields burnt
       if fields_burnt_count % 3 == 0:
           _spawn_sacrifice(field.global_position)
   ```
4. Added `_spawn_sacrifice()` function that:
   - Spawns a sacrifice near the burnt field position
   - Jitters the position slightly for variety
   - Clamps to interior and ensures terrain-free
   - Falls back to original position if no terrain-free spot found
5. Added "sacrifice" to `entity_scenes` dictionary
6. Fixed Sacrifice scene collision layer from 0 to 4 to match dragon's EncounterArea expectations

### Issue 3: Sacrifice collision layer mismatch

**Root cause:** The Sacrifice scene's DetectionArea had `collision_layer = 0`, but the dragon's EncounterArea has `collision_mask = 4`, expecting bodies on layer 4.

**Fix:** Changed Sacrifice DetectionArea to `collision_layer = 4, collision_mask = 1` so:
- Dragon's EncounterArea (mask 4) detects Sacrifice (layer 4) ✓
- Sacrifice's DetectionArea (mask 1) detects Dragon (layer 2) via other systems ✓

## Verification steps

1. **Test field burning:**
   - Burn 3 fields with dragon's fire breath (E key with fire charges)
   - Verify fields turn from green to brown (GROWN → STUBBLE)
   - Check console for "Field burnt at <position>" prints

2. **Test sacrifice spawning:**
   - After burning 3 fields, verify "WorldManager: Spawning sacrifice" print
   - Sacrifice should appear near the 3rd burnt field
   - Check console for "WorldManager: Sacrifice spawned at <position>"

3. **Test story popup:**
   - Approach the sacrifice (within 100px)
   - Verify "Sacrifice: Dragon approached, triggering story popup" print
   - Verify StoryPopup opens with choice options

## Files changed

- `scripts/characters/Dragon.gd` — Fixed `_ignite_flammables()` function
- `scripts/main/WorldManager.gd` — Added field burning tracking and sacrifice spawning
- `scenes/props/Sacrifice.tscn` — Fixed collision layer for dragon detection

## Related decisions

- [2026-11-08-flammable-ecology.md](2026-11-08-flammable-ecology.md): original field burning integration
- [2026-11-09-dragon-death-and-terrain-layers.md](2026-11-09-dragon-death-and-terrain-layers.md): terrain collision layers
- [2026-11-10-sacrifice-system.md](2026-11-10-sacrifice-system.md): sacrifice system design
- [IMPLEMENTATION-SACRIFICE.md](IMPLEMENTATION-SACRIFICE.md): sacrifice system implementation notes
