# Sacrifice System — decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Sacrifice spawn condition | Every 3 fields burnt | Ties to dragon's destruction pattern, predictable progression | A different progression system is wanted |
| Sacrifice options | Eat (flame restore) OR bring to lair (train as rider) | Player's choice based on current needs | A different mechanic is desired |
| Dragon rider avatar | Replace sprite entirely | Clean separation, easier to manage | Composite/overlay is wanted |
| Rider combat ability | Shoot arrows like archer | Consistent with archer threat level | Different combat behavior desired |
| Rider target priority | Soldiers and goblins (non-allies) | Matches dragon's enemies | Different targeting needed |

## Open / deferred
- Rider upgrade cost: 10g — can be tuned
- Virgin gender: 20% male (trainable as rider) — can be adjusted
- Sacrifice scene: separate from StoryPopup for clean separation

## Assumptions
- Fixed 20 slots for inventory (already designed)
- Sacrifice is a world object (StaticBody2D or Node2D)
- StoryPopup handles the choice (eat vs bring to lair)
- Dragon rider is a visual change + new combat capability
- Rider only fights soldiers/goblins (not farmers/miners)

---

## Implementation Plan

### 1. Sacrifice Scene (`scenes/props/Sacrifice.tscn`)
- Root: `StaticBody2D` (non-colliding, just a marker)
- `CollisionShape2D` for dragon proximity detection
- `Sprite2D` showing a woman tied to a pole (SVG)
- `AnimationPlayer` for idle animation (subtle struggling)
- `Area2D` for dragon proximity (story popup trigger)

### 2. Sacrifice.gd Script
- `@onready var dragon_area: Area2D` — detects dragon proximity
- `signal dragon_approached` — triggers story popup
- `@export var is_male: bool` — 20% chance at spawn
- `_on_dragon_body_entered()` — opens StoryPopup

### 3. Story Popup Entries (`StoryPopup.gd`)
Add two new story kinds:
- `"sacrifice_approach"` — first encounter with sacrifice
  - Choices: "Eat her (+2 flames)" / "Bring to lair (train as rider)" / "Leave her"
- `"sacrifice_male"` — if is_male is true, different text
  - "This virgin is a man! He can be trained as a dragon rider."

### 4. GameManager Integration
- `var virgin_sacrifices: int = 0` — track sacrifices
- `var male_trainable: bool = false` — track if we have a trainable male
- `func train_rider() -> void` — upgrade sacrifice to rider
- Rider adds:
  - Dragon sprite replacement (dragon+rider SVG)
  - Arrow shooting capability (like archer)
  - Rider combat: targets soldiers/goblins

### 5. Dragon Rider System
- New dragon state: `has_rider: bool`
- When `has_rider` is true:
  - Sprite swaps to dragon+rider texture
  - Arrow attack: similar to archer, but dragon-controlled
  - Rider shoots at soldiers/goblins (not allies)

### 6. WorldManager Integration
- Track fields burnt count
- After every 3rd field burnt, spawn a sacrifice near the burnt field
- Sacrifice position: near the burnt field but safe from immediate destruction
