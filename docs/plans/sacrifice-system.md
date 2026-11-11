# Sacrifice System Implementation Plan

## Overview
Introduce a sacrifice mechanic where every 3 fields burnt by the dragon, a sacrifice (woman tied to a pole) appears. The dragon can choose to eat her (flame restore) or bring her to the lair to train as a dragon rider.

## Design Summary

### Sacrifice Scene Tree
```
Sacrifice (StaticBody2D)
├── Sprite2D (visual: woman tied to pole)
├── CollisionShape2D (proximity trigger)
└── Area2D (dragon detection for story popup)
```

### Dragon Rider Scene Tree (when trained)
```
Dragon (CharacterBody2D with rider)
├── Sprite2D (dragon+rider composite)
├── ArrowShooter (Area2D with collision for arrows)
└── AnimationPlayer (rider-specific animations)
```

### Signal Map

| Signal | Source | Consumer | Purpose |
|---|---|---|---|
| `field_burnt(field)` | Field | WorldManager | Track fields burnt for sacrifice spawn |
| `dragon_approached(sacrifice)` | Sacrifice Area2D | StoryPopup | Trigger sacrifice choice popup |
| `sacrifice_eaten(flames)` | StoryPopup | Dragon | Add flame charges |
| `sacrifice_brought_to_lair(rider_data)` | StoryPopup | DragonLair | Train rider |
| `rider_upgraded` | DragonLair | Dragon | Enable rider combat |

### Data Flow
1. Dragon burns field → WorldManager increments burnt count
2. When burnt count % 3 == 0 → WorldManager spawns sacrifice near lair
3. Dragon enters sacrifice's Area2D → StoryPopup opens with choice
4. Dragon chooses:
   - **Eat**: +2 flame charges, sacrifice removed
   - **Bring to lair**: Training begins, rider data stored
5. Dragon upgrades rider in Wizard tower (10g)
6. Rider enables: dragon+rider sprite + arrow combat

## Implementation Tasks

### Phase 1: Sacrifice Core
- [ ] **Task 1**: Create `scenes/props/Sacrifice.tscn`
  - Root: `StaticBody2D`
  - Sprite2D with woman-on-pole SVG
  - CollisionShape2D for proximity detection
  - Area2D for dragon detection
  Skills: `godot-prompter:scene-organization`

- [ ] **Task 2**: Create `scripts/props/Sacrifice.gd`
  - `signal dragon_approached`
  - `@export var is_male: bool` (20% chance)
  - `_on_area_body_entered(body)` → emit signal
  Skills: `godot-prompter:component-system`

### Phase 2: Story Popup Integration
- [ ] **Task 3**: Add sacrifice stories to `StoryPopup.gd`
  - `"sacrifice_approach"` — woman tied to pole
    - Choices: "Eat her (+2 flames)" / "Bring to lair (train as rider)" / "Leave her"
  - `"sacrifice_male"` — if is_male is true
    - "This virgin is a man! He can be trained as a dragon rider."
  Skills: `godot-prompter:godot-ui`

- [ ] **Task 4**: Add StoryPopup story choices to `GameManager.gd`
  - `func _on_story_choice_made(kind: String, choice_index: int)`
  - Handle `sacrifice_approach` and `sacrifice_male`
  - Track: virgin eaten count, male trainable count
  Skills: `godot-prompter:event-bus`

### Phase 3: WorldManager Integration
- [ ] **Task 5**: Track fields burnt in WorldManager
  - `var fields_burnt_count: int = 0`
  - `_on_field_burnt(field)` → increment counter
  - Spawn sacrifice when `fields_burnt_count % 3 == 0`
  Skills: `godot-prompter:scene-organization`

- [ ] **Task 6**: Create sacrifice spawn logic
  - Spawn near lair (safe distance)
  - Randomize position within radius
  Skills: `godot-prompter:math-essentials`

### Phase 4: Dragon Integration
- [ ] **Task 7**: Dragon handles sacrifice story choices
  - Eat: `dragon.flame_charges += 2`
  - Bring to lair: `dragon.train_rider()`
  Skills: `godot-prompter:component-system`

- [ ] **Task 8**: Create Rider training system
  - `func train_rider()` — stores rider data
  - `has_rider: bool` flag
  Skills: `godot-prompter:state-machine`

### Phase 5: Rider Combat System
- [ ] **Task 9**: Create DragonRider scene
  - Dragon + rider sprite composite
  - ArrowShooter Area2D
  - Arrow projectile logic
  Skills: `godot-prompter:animation-system`

- [ ] **Task 10**: Rider combat logic
  - Auto-aim at soldiers/goblins
  - Arrow fire rate: 1.0s
  - Arrow damage: 25 (similar to archer)
  Skills: `godot-prompter:ai-navigation`

### Phase 6: Wizard Tower Integration
- [ ] **Task 11**: Add rider upgrade to WizardMenu
  - Option: "Train Dragon Rider (10g)"
  - Cost: 10 gold
  - Effect: Enables rider combat
  Skills: `godot-prompter:godot-ui`

- [ ] **Task 12**: Upgrade logic in GameManager
  - `func upgrade_rider()` — sets `has_rider = true`
  - Triggers sprite swap
  Skills: `godot-prompter:component-system`

## Assets Needed
- `assets/sacrifice.svg` — woman tied to pole
- `assets/dragon+rider.svg` — composite dragon+rider sprite

## Testing Checklist
- [ ] Burn 3 fields → sacrifice spawns near lair
- [ ] Enter sacrifice area → StoryPopup opens
- [ ] Choose "Eat" → +2 flame charges
- [ ] Choose "Bring to lair" → training begins
- [ ] Upgrade rider at Wizard tower (10g)
- [ ] Rider shoots arrows at soldiers/goblins
- [ ] Rider does NOT attack farmers/miners

## Notes
- Sacrifice should be non-colliding (just a marker) or have minimal collision
- StoryPopup should be paused while active
- Rider combat should be dragon-controlled (not AI)
- Rider sprite swap should be seamless (same position/size)
