# Dragon fire attack layering bug — decisions

Date: 2026-11-11. Bug: dragon fire breath no longer affects crop fields.

## Bug description

The dragon's fire breath attack (E key with fire charges) ignites farmers, miners, soldiers, and goblins, but crop fields (Field nodes) in the flame cone do not catch fire.

## Root cause

In `scripts/characters/Dragon.gd`, the `_ignite_flammables()` function iterates through groups including "fields". The code has a logic error in the type checking order:

```gdscript
var base := node as BaseNPC
if base == null:
    continue  # ← Fields are skipped here!
if base.npc_type == "goblin" ...
var target_pos: Vector2 = base.global_position
# ... distance and cone checks ...
if node is Field:        # ← Never reached for Fields
    (node as Field).burn()
else:
    base.catch_fire()
```

When iterating through the "fields" group, each node is a `Field` instance, not a `BaseNPC`. The cast `node as BaseNPC` returns `null` for Fields, causing them to be skipped by the `if base == null: continue` guard.

The `if node is Field:` check on line 421 is never reached for Fields because they're filtered out earlier.

## Solution

Check if the node is a `Field` BEFORE attempting to cast to `BaseNPC`. This allows the function to handle Fields and NPCs separately:

```gdscript
for group: String in ["farmers", "miners", "soldiers", "goblins", "king", "fields"]:
    for node: Node in get_tree().get_nodes_in_group(group):
        # Handle Fields separately from NPCs
        if node is Field:
            var field := node as Field
            var to_target := field.global_position - global_position
            if to_target.length() <= fire_reach and \
               to_target.normalized().dot(facing_vec) >= fire_ignite_cone:
                field.burn()
            continue
        
        # Now handle BaseNPC subclasses
        var base := node as BaseNPC
        if base == null:
            continue
        if base.npc_type == "goblin" and ... :
            continue
        var target_pos: Vector2 = base.global_position
        var to_target := target_pos - global_position
        if to_target.length() <= fire_reach and \
           to_target.normalized().dot(facing_vec) >= fire_ignite_cone:
            base.catch_fire()
```

## Alternative approaches considered

1. **Keep single loop with order-based handling**: Iterate "fields" separately from NPC groups to avoid type confusion.
2. **Use `is_instance_of()` instead of `as`**: Would still need conditional logic but avoids null checks.
3. **Revert to old `_ignite_soldiers()` pattern**: Lose the unified flammable scan but simplify type handling.

**Chosen**: Separate handling because it's clearer and prevents future type-confusion bugs.

## Verification steps

1. Run the game with dragon at close range to a field
2. Press E to fire breath while facing the field
3. Verify the field turns from green to brown (GROWN → STUBBLE)
4. Check console for "Field burnt at <position>" print
5. Run headless test: `~/Program/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --quit-after 5`

## Files changed

- `scripts/characters/Dragon.gd` — `_ignite_flammables()` function (lines 405-424)

## Related decisions

- [2026-11-08-flammable-ecology.md](2026-11-08-flammable-ecology.md): original field burning integration
- [2026-11-09-dragon-death-and-terrain-layers.md](2026-11-09-dragon-death-and-terrain-layers.md): terrain collision layers (unrelated to this bug)
