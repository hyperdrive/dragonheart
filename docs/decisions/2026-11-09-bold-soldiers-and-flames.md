# Bold soldiers + flame overlay — decisions

Date: 2026-11-09. Follow-ups to `2026-11-09-mine-visuals-and-npc-animations.md`
(the fleeing/burning presentation layer).

## User spec

1. "The flee animation is super great! Let's apply it to burning soldiers
   too." (→ generalized below to ALL burning NPCs.)
2. "Add a flame animation on them."
3. "Make the soldiers bold if they have a king nearby or at least two
   other pals. Bold soldiers pursue the dragon until they hit it."
4. Grilled answers (2026-11-09):
   - Morale distance = **body-width based**: pal radius = **5 soldier
     widths**; the King is fat → his radius is **doubled**.
   - On contact: **fight until escape** (contact DPS keeps the fight;
     no hit-and-run cooldowns).
   - Boldness NOT sticky: **re-checked every activity pick**; a bold
     leg breaks off when the dragon escapes the sight reach — an
     in-flight pursuit leg lands first (behavior trees evaluate the
     work_check in WORKING only).
   - Flames on **ALL burning NPC types** (consistent with the
     type-generic scorch tint), not just soldiers.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Morale metric | Body pixels, not vague "nearby": `BODY_WIDTH = 18` (Soldier.tscn Body), pal radius 5×18 = 90px with **≥2 pals**; King radius doubled = 180px | User answered in widths; converts to exact pixels and survives future art rescales |
| Bold sight / pursue reach | 20 widths = 360px; break-off when the dragon exits it | Long enough to reach contact from formation, readable on the 1600×1600 field |
| aggro gate | `_attack_ready() = _swarm_released() OR _is_bold()` — attack_dragon re-picks against it every pick | Morale is state, not an event; never sticky (user choice) |
| Contact fight | No discrete hit step — the existing per-frame contact DPS channel does the damage; leg ends only on escape/death | "Fight until escape"; reuses the shipped damage path |
| King as morale source | King counts for `king` group presence at the doubled radius, but does NOT count as a pal (not in `soldiers`) | Matches user's "king nearby" phrasing; pal math needs 2 true soldiers |
| Flame overlay | `Sprite/Flames` Node2D with 3 ColorRect tongues (dark red → orange → bright yellow interior), z_index 2; per-tongue height wave (differing harmonic multiplier), rotation sway, x-wobble, alpha pulse at 14Hz | Code-driven like the wobble (no rig); layered colors sell fire depth in the flat-polygon style |
| Flame lifecycle | Spawn in `catch_fire`; per-frame `_animate_flames` while burning; torn down the first `_physics_process` frame `_burning_left <= 0` (or death) | Overlay never outlives the fire |
| Burning vs flee wobble | `< _animate_flee>`'s `running` predicate generalized: `_burning_left > 0 OR state == FLEEING`, both require real velocity | "Apply it to burning soldiers" generalized to all burning NPCs per the grilled flames scope |

## Gotchas recorded

- The probe needed `behavior_tree.interrupt_current_activity()` after
  teleporiting soldiers: per-pick re-evaluation waits for the current
  in-flight leg (by design), so a freshly placed phalanx otherwise
  finishes stale patrol trips before going bold.
- Work-check timing again: break-off assertions must allow the current
  pursuit leg to land (poll ≥ the walk time to the far target).
- `root.add_child` (not `add_child`) in SceneTree probes.

## Verified

- Probe `probe_bold_flames.gd` 10/10: flames spawn 3 tongues/flicker/
  tear down after burn-out; burning farmer wobbles while panicking;
  3-man phalanx goes bold in CALM swarm, pursues 283 → 10px, contact
  DPS drains dragon 100 → 10 hp; break-off to 0 chasers after the
  dragon escapes to (900,900); lone soldier beyond 90px/180px morale
  stays calm; instantiating the King beside the loner flips it bold.
- 4800-frame regression: 0 script errors, 17 economy deliveries.
