# Fire animation — implementation plan

Date: 2026-11-13. Decision: quick build-up, fade-out dispersion into smaller
pieces, pulsing for sustained breaths.

## 1. New fire animation (AnimationPlayer)

Add a new animation `fire_breath_pulsed` to Dragon's AnimationPlayer that
oscillates between "build-up" and "dispersion" phases:

- **0.0–0.1 s**: build-up (fire grows from core to full size, modulate fades
  from 0 to 1.0)
- **0.1–0.4 s**: peak (full fire, slight bob/rotation for realism)
- **0.4–0.8 s**: dispersion (fire splits into smaller pieces, each fades and
  drifts away)

Since AnimationPlayer only animates properties on existing nodes, the
dispersion pieces must be pre-created (as children of `FireArea`), and the
animation will control their visibility, scale, and modulate.

### Scene tree changes

```
Dragon (CharacterBody2D)
└── FireArea (Area2D)
    ├── Flame (Node2D)                # base fire visual (existing)
    │   ├── OuterFlame (ColorRect)    # largest ring (existing)
    │   ├── MidFlame (ColorRect)      # middle ring (existing)
    │   └── CoreFlame (ColorRect)     # inner core (existing)
    └── EmberPieces (Node2D)          # NEW: dispersion pieces container
        ├── Ember1 (ColorRect)        # small piece 1
        ├── Ember2 (ColorRect)
        └── Ember3 (ColorRect)        # small piece 3
```

### Animation tracks for `fire_breath_pulsed`

- `Vis/Sprite:position`: bob 0→−7→0 over 0.8 s (pulsing body)
- `Vis/Sprite:rotation`: slight wobble (0→0.15→0)
- `FireArea/Flame/OuterFlame:scale`: build-up (Vector2(0,0)→Vector2(1.5,1.5)→Vector2(1.0,1.0))
- `FireArea/Flame/MidFlame:scale`: same build-up curve
- `FireArea/Flame/CoreFlame:scale`: same build-up curve
- `FireArea/Flame/OuterFlame:modulate.a`: 0→1.0→0.8 (build-up→peak→dispersion start)
- `FireArea/EmberPieces/Ember1/2/3:visible`: true at 0.4 s (dispersion)
- `FireArea/EmberPieces/Ember1/2/3:scale`: 0→Vector2(0.3,0.3) over 0.8 s
- `FireArea/EmberPieces/Ember1/2/3:modulate.a`: 1.0→0 over 0.4–0.8 s (fade-out)
- `FireArea/EmberPieces/Ember1/2/3:position`: drift (e.g., ±20px over 0.4 s)

## 2. Runtime code (Dragon.gd)

Change `fire_breath()` to loop while the key is held:

```gdscript
func fire_breath() -> void:
    if _dying or fire_cooldown > 0.0:
        return
    if flame_charges < 1.0:
        print("Dragon: flame spent — eat a pig (+1) or a cow (+2) to recharge!")
        return
    
    is_firing = true
    fire_cooldown = fire_rate  # cooldown starts after breath ends
    flame.visible = true
    fire_area.monitoring = true
    animation_player.play("fire_breath_pulsed")
    fire_attacked.emit()
    
    # Wait for animation to finish (0.8 s) before cooldown resets
    await animation_player.animation_finished
    is_firing = false
    flame.visible = false
    fire_area.monitoring = false
    # dispersion pieces stay visible briefly (handled by animation or cleanup)

func _process(delta: float) -> void:
    if is_firing and Input.is_action_pressed("fire") and flame_charges >= 1.0:
        # Pulse the breath: every 0.8 s, spend a charge
        fire_breath()
```

## 3. Dispersion pieces (EmberPieces)

Create Ember1/2/3 as ColorRect children of `FireArea/EmberPieces` with:

- Size: 8×8 (smaller than fire rings)
- Color: orange-red with varying alpha (0.8–1.0)
- Initial scale: 0
- Position: slight offset from Flame center (±10px x, ±5px y)
- In the animation: scale up at 0.4 s, drift, then fade out by 0.8 s

## 4. Optional enhancements (Beat 5 suggestions)

- Add a **Call Method track** to spawn a `Sparkle` particle at the tip of the
  fire at 0.2 s, 0.4 s, and 0.6 s for extra texture.
- Add a **Audio Playback track** to play a short "whoosh" SFX looped during
  the breath, fading in and out at the build-up/dispersion edges.

## Implementation order

1. Add `EmberPieces` container and 3 Ember ColorRects to Dragon.tscn.
2. Add `fire_breath_pulsed` animation with tracks for build-up + dispersion.
3. Update Dragon.gd `fire_breath()` to pulse while key held.
4. Verify build-up (sharp spike) and dispersion (small pieces fade away) feel right.
