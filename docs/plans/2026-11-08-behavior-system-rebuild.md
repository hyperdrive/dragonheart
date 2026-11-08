# Behavior System & Economy Rebuild — design + plan

Date: 2026-11-08. Decisions: see `docs/decisions/2026-11-08-behavior-system.md`.

## Approach (approved)

**Activity-based FSM + priority list.** A `BehaviorTree` per NPC is a priority list of
Activities. The engine loop: pick highest-priority ready activity → `MOVING` → `WORKING`
(timer) → completion emits output → per-activity cooldown. States: enum FSM on `BaseNPC`
(`IDLE, MOVING, WORKING, FLEEING, DEAD`).

Engine contract:
1. Activities are synchronous; `work_time` + tree tick handles all waiting.
2. The tree stays on a behavior until it completes — sequence advances only on genuine
   completion; `check_danger` is priority 0 and preempts into `FLEEING`.
3. Per-activity cooldown = real seconds, decremented by tick `delta`.
4. `GameManager` in `Main.tscn` is the single state hub (treasury, stash, food, levels,
   soldier_count, victory). Resources flow via the signals below; payloads are never
   written outside the hub.

## Scene tree (approved)

```
Main (Node2D, GameManager.gd)
├── Camera (Camera2D)
├── World (Node2D, group="world")
│   ├── Dragon (Dragon.tscn) — AnimationPlayer, FireArea, Hurtbox, GoldInterceptionSystem
│   ├── WorldManager (Node2D, WorldManager.gd) └── SpawnTimer (Timer)
│   ├── NPCs (Node2D)           spawned farmers/miners/soldiers/king
│   ├── Fields (Node2D)         Field.tscn instances
│   └── Town (Node2D)           └── WizardTower (WizardTower.tscn)
└── HUD (HUD.tscn)

Field.tscn: Field (Area2D, group="flammable") ├── Crops (visual, grown→stubble) └── RegrowTimer
Farmer/Miner/Soldier/King .tscn: CharacterBody2D root + Sprite + CollisionShape2D + Hurtbox
```

## Signal map (approved)

| Signal | Source → Consumer | Payload |
|---|---|---|
| `food_delivered` | Farmer → GameManager.add_food | amount: int |
| `resource_delivered` | Miner → GameManager.deposit_treasury | npc_type, res_type, amount |
| `carrying_changed` | Miner/Farmer → GoldInterceptionSystem | res_type, amount |
| `seized` | GoldInterceptionSystem → GameManager.add_stolen | res_type, amount |
| `stash_changed` / `treasury_changed` / `food_changed` | GameManager → HUD | res_type/amount |
| `upgrade_purchased` | GameManager → Dragon.update_stats, HUD | kind, level |
| `field_burnt` | Dragon fire → Field.burn() | field: Field |
| `field_ready` | Field (RegrowTimer done) | field: Field |
| `npc_died` | BaseNPC.die → GameManager, WorldManager, GoldInterceptionSystem | npc_type |
| `soldier_spawned` | WorldManager → GameManager | soldier: Soldier |
| `boss_battle_started` | King → GameManager, HUD | king |
| `king_defeated` | King.die → GameManager → victory | — |
| `victory_achieved` | GameManager → HUD | tally: Dictionary |

Economy shape: miners deposit → town treasury; theft moves payloads → dragon stash; stolen
gold/gems buy flame/armor at the wizard tower level (purchase UI stays anywhere in this
pass — site requirement deferred).

## Tasks

- [x] **Task 0: Delete dead duplicates** — `scripts/objects/Farmer.gd`,
      `scenes/objects/Farmer.tscn`, `scripts/systems/GoldInterceptionSystem.gd`,
      `scenes/systems/GoldInterceptionSystem.tscn`, `scripts/town/TownResourceSystem.gd`.
      (Verified unreferenced 2026-11-08.)
- [x] **Task 1: Rewrite `BehaviorTree.gd` as the activity engine** — enum FSM
      (`IDLE/MOVING/WORKING/FLEEING/DEAD`), `register_activity()`, stay-until-done ticking,
      real-second cooldowns, `check_danger` priority 0 preemption.
      Skills: `godot-prompter:state-machine`, `godot-prompter:ai-navigation`, `godot-prompter:gdscript-patterns`
- [x] **Task 2: Refactor `BaseNPC.gd` onto activities** — default activities (idle, go_home,
      flee), `npc_died` emission, tiered `npc_level` scaffolding, payload slot.
      Skills: `godot-prompter:state-machine`, `godot-prompter:gdscript-patterns`
- [x] **Task 3: Rewrite `Farmer.gd`** — activities `tend_fields` (Field targets, abort on
      `field_burnt`), `tend_pigs`, `deliver` → `food_delivered`; tiered yields.
      Skills: `godot-prompter:ai-navigation`, `godot-prompter:gdscript-patterns`
- [x] **Task 4: Rewrite `Miner.gd`** — activities `mine` (70/30 gold/gems), `deliver` →
      `resource_delivered` + `carrying_changed`; `check_support_conditions` gating.
      Skills: `godot-prompter:ai-navigation`, `godot-prompter:gdscript-patterns`
- [x] **Task 5: Create `Field.tscn` + `Field.gd`** — Area2D flammable, burn(), RegrowTimer,
      `field_burnt`/`field_ready`, stubble visuals.
      Skills: `godot-prompter:2d-essentials`
- [x] **Task 6: Consolidate `GameManager.gd`** — treasury/stash/food/levels/soldier_count
      single source of truth; `victory_achieved` tally; welcome the signals above.
      Skills: `godot-prompter:gdscript-patterns`
- [x] **Task 7: Slim `Dragon.gd`** — read levels from GameManager, interception → `seized`,
      FireArea ignites Fields (already via "flammable"), remove duplicated stats.
      Skills: `godot-prompter:player-controller`, `godot-prompter:gdscript-patterns`
- [x] **Task 8: `Soldier.gd` CHASE/patrol/attack + `King.gd` subclass + WorldManager
      escalation** — `SpawnTimer` staggered spawns, king threshold, escort, boss battle.
      Skills: `godot-prompter:ai-navigation`, `godot-prompter:state-machine`
- [x] **Task 9: Rewrite `GoldInterceptionSystem.gd`** — `carrying_changed`-driven targets,
      steal transfers payload → `seized`, nonce animation lock.
      Skills: `godot-prompter:gdscript-patterns`
- [x] **Task 10: Config `HUD`/`WizardTower`** — treasury/stash/food displays, purchase UX,
      victory panel, boss warning. Skills: `godot-prompter:godot-ui`, `godot-prompter:hud-system`
- [x] **Task 11: Fix `WorldManager` spawn structure** — NPC/Fields containers, remove
      vanished `./ Sprite` parent-path warnings.
      Skills: `godot-prompter:scene-organization`
- [x] **Task 12: Verify** — headless run zero script errors, farmers actually tend/deliver,
      miners deposit, theft moves stash, field regrows, King + victory path reachable.
      Then run `godot-prompter:godot-code-review` over all touched scripts.
