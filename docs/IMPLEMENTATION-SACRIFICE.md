# Sacrifice System Implementation — Completed

## What Was Implemented

### 1. Sacrifice Scene (`scenes/props/Sacrifice.tscn`)
- StaticBody2D with collision for proximity detection
- Area2D for dragon detection (triggers story popup)
- Script reference for sacrifice behavior

### 2. Sacrifice Script (`scripts/props/Sacrifice.gd`)
- `signal dragon_approached(sacrifice: Sacrifice)` — triggers StoryPopup
- `@export var is_male: bool` — 20% chance the virgin is male
- Randomizes gender on `_ready()`

### 3. Story Popup Integration (`scripts/ui/StoryPopup.gd`)
- `"sacrifice_approach"` story — woman tied to pole
- `"sacrifice_male"` story — trainable man
- Choice options:
  - 0: Eat her (+2 flame charges)
  - 1: Bring to lair (train as rider)
  - 2: Leave her be

### 4. WorldManager Integration (`scripts/main/WorldManager.gd`)
- Tracks `fields_burnt_count`
- Spawns sacrifice every 3 fields burnt
- Sacrifice spawns near burnt field (not lair, per decision record)
- `field_burnt` signal connection fixed (moved AFTER generate_world() to ensure fields exist before connecting)

### 5. GameManager Integration (`scripts/main/GameManager.gd`)
- Tracks: `virgin_sacrifices`, `male_trainable_count`, `rider_has_been_trained`
- `_on_sacrifice_choice()` handles story choices
- Rider upgrade cost: 10g at Wizard tower

### 6. Wizard Tower Integration (`scripts/main/GameManager.gd`)
- Rider upgrade option added to `WIZARD_PRICES`
- Cost: 10 gold, 0 gems

### 7. Decision Records
- `docs/decisions/2026-11-10-sacrifice-system.md` — all design decisions
- `docs/plans/sacrifice-system.md` — implementation plan

## Remaining Features (Future Work)
- Dragon rider scene with composite sprite
- Rider combat system (arrow shooting at soldiers/goblins)
- Sprite swap logic when rider is trained
- Visual representation of sacrifice (SVG asset needed)

## How to Test
1. Burn 3 fields with dragon's breath (spacebar)
2. Sacrifice spawns near lair
3. Dragon enters sacrifice's detection area
4. StoryPopup opens with choices
5. Choose "Eat" → +2 flame charges
6. Choose "Bring to lair" → training begins
7. Upgrade rider at Wizard tower (10g) when implemented

## Notes
- Sacrifice is non-colliding (just a marker) for now
- StoryPopup pauses the game while active
- Rider system is scaffolded but not fully implemented yet
