# Bug Fix: Dragon Rider Training System

## Issue Summary

When three fields are burnt and a sacrifice appears, if the dragon chooses "Train as rider" and then visits the Wizard Tower, the "Train Dragon Rider" upgrade option does not appear even though 10g is available.

## Root Causes

1. **Missing signal handler**: The `sacrifice_choice_made` signal was connected but the `game_manager._on_sacrifice_choice_from_popup()` function was never implemented
2. **Missing state tracking**: No variable existed to track if a sacrifice was chosen to be trained
3. **Missing wizard option**: The WizardMenu did not have a "Train Dragon Rider" option
4. **Missing upgrade logic**: The Dragon class had no `train_rider()` or `upgrade_rider()` function
5. **Missing epic story**: No story popup was shown after the rider was upgraded

## Changes Made

### 1. GameManager.gd

**Added:**
- `_trainable_sacrifice: bool` - tracks if a sacrifice was chosen to be trained
- `sacrifice_choice_made` signal - emitted when sacrifice choice is made
- `_on_sacrifice_choice_from_popup(choice_index)` - handles the sacrifice story choice
- `train_sacrifice_as_rider()` - marks sacrifice as trainable
- `eat_sacrifice()` - grants 2 flame charges if dragon chooses to eat
- `_on_rider_upgraded()` - shows epic story when rider is upgraded
- `has_trainable_sacrifice()` - getter for the trainable flag
- Updated `purchase_upgrade()` to handle "rider_train" option
- Added "rider_train" to WIZARD_PRICES with 10g cost

### 2. Dragon.gd

**Added:**
- `has_rider: bool` - tracks if dragon has a rider
- `_rider_animation_player: AnimationPlayer` - for rider animations
- `_sacrifice_trained: bool` - tracks if sacrifice was trained
- `rider_upgraded` signal - emitted when rider is fully upgraded
- `set_has_sacrifice_trained(flag)` - sets the trained flag
- `train_rider(should_upgrade)` - marks sacrifice for training
- `upgrade_rider()` - upgrades rider with combat and sprite
- `_upgrade_rider()` - internal upgrade logic with sprite swap
- `_set_rider_sprite()` - swaps to dragon+rider texture
- `_rider_shoot_at_enemies(delta)` - rider combat system
- `_rider_shoot_at(target)` - fires arrow at enemies
- `_rider_shoot_cooldown: float` - shooting cooldown timer
- `RIDERSHOOT_INTERVAL: float = 1.5` - seconds between shots

### 3. WizardMenu.gd

**Added:**
- `rider_train_button: Button` - reference to the rider training button
- "rider_train" option to OPTIONS array with 10g cost
- Updated `_ready()` to hide the rider_train button initially
- Updated `_refresh()` to show/hide rider_train button based on trainable status
- Hotkey 6 added to HOTKEYS array

### 4. StoryPopup.gd

**Added:**
- "rider_upgraded" story kind with epic dialogue
- "sacrifice_male" story kind for male sacrifices
- `sacrifice_choice_made` signal
- Proper signal disconnection in `_rebuild_choices()` to prevent errors

### 5. Sacrifice.gd

**No changes needed** - already had the correct story triggering logic

## How to Test

1. **Setup**: Burn 3 fields to spawn a sacrifice
2. **Choice**: Approach the sacrifice and select "Take to lair. Train as rider."
3. **Upgrade**: Visit the Wizard Tower and verify the "Train Dragon Rider (10g)" option appears
4. **Purchase**: Purchase the rider training option
5. **Epic Story**: Verify the "The Archer's Oath" story appears
6. **Combat**: Rider should now shoot arrows at soldiers/goblins

## Implementation Details

### Signal Flow

1. Sacrifice._check_dragon_encounter() → story_open = true
2. Sacrifice._trigger_story() → StoryPopup.open("sacrifice_approach")
3. StoryPopup._on_choice_pressed(choice_index) → sacrifice_choice_made.emit(choice_index)
4. GameManager._on_sacrifice_choice_from_popup(choice_index) → train_sacrifice_as_rider()
5. GameManager._trainable_sacrifice = true
6. Dragon approaches Wizard Tower → WizardMenu.open()
7. WizardMenu._refresh() → rider_train_button.visible = true (if has_trainable_sacrifice)
8. WizardMenu._on_option_pressed("rider_train") → GameManager.purchase_upgrade("rider_train")
9. GameManager.purchase_upgrade() → dragon.upgrade_rider()
10. Dragon.upgrade_rider() → _upgrade_rider() + rider_upgraded.emit()
11. GameManager._on_rider_upgraded() → notify_story("rider_upgraded")
12. StoryPopup.open("rider_upgraded") → epic story displayed

### Rider Combat

The rider automatically shoots arrows at soldiers and goblins every 1.5 seconds when:
- The rider is active (has_rider = true)
- The dragon is not dying
- An enemy is within fire_reach distance

Enemies are prioritized by nearest distance. The rider does NOT attack farmers/miners.
