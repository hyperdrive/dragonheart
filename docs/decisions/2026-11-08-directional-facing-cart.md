# Directional facing & gold cart — decisions

Date: 2026-11-08. Companion to `2026-11-08-visuals-terrain.md`.

## Request

Characters must show left/right representation by direction; dragon fire follows
facing; miners push a visible gold cart and run from the dragon; the dragon can
take the gold from the cart.

## Decisions

- **Facing = mirror the visual container** (`Sprite.scale.x = ±1`), driven by the
  sign of horizontal velocity (`BaseNPC.update_facing` — also called from
  BehaviorTree's FLEEING tick; Dragon mirrors its input x). Rejected: separate
  left/right art (no source art; ColorRect composites mirror cleanly about the
  container origin) and 180° rotation (upside-down characters). Dragon
  animations animate `Sprite:position/rotation` only — both mirror correctly
  under a negative-x parent scale, so the death/fire animations are safe.
- **Fire direction = explicit component mirroring in code** (`Dragon._apply_facing`):
  FireArea offset, hitbox offset, and Flame visual each flip sign. Rejected:
  negative scale on the physics Area2D (negative scale is unsupported territory
  for physics nodes).
- **Gold cart = attachment node on Miner** (cart bed/rails/wheels + gold.svg
  pile), shown/hidden via the existing `carrying_changed` payload signal and
  repositioned every frame to `26 * facing` — riding in front, because the
  miner pushes it toward town. No mirror needed (cart is nearly symmetric).
- **Flee urgency = one `flee_speed_multiplier` (BaseNPC), consumed by the
  existing priority-0 FLEEING state.** Miner carriers get 1.3× run speed and a
  wider fear radius (180 vs the 150 default) — the gold economy on legs is
  deliberately more skittish. Rejected: a separate cart-specific activity
  (duplicating the flee machinery for no behavioral difference).
- **Stealing from the cart needs no new system**: GoldInterceptionSystem already
  targets any miner with `payload_amount > 0` within 100px regardless of state
  (fleeing included) — the cart visual just makes the act, and its emptying
  (payload cleared → cart hides), readable.

## Verification (headless, zero errors)

- Dragon: input left → `sprite.scale.x = -1`, `fire_area.x = -20`,
  `flame.scale.x = -1`, hitbox `x = -15`; right restores all.
- Miner (BT killed for determinism): moved right → facing 1, left → facing −1,
  Sprite container mirrored.
- Cart: visible at payload set, rides at `26 * facing`, hides on steal.
- Flee: fear radius 180 triggers FLEEING outside the 100px steal range; payload
  intact while running; velocity = 117 (90 × 1.3), directed away from the dragon.
- Steal-from-cart probe: stash 0→2 on interception, payload cleared, cart hid.
- Full-run regression: zero script errors, economy deliveries flowing.
