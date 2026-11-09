# Dragon death chapters + terrain collision layers — decisions

Date: 2026-11-09. User: "add a window popup when the dragon dies. Take
into account which NPC killed it. Also make dragon ignore trees as he
flies over them. Mountain will still block. Also make sure the base of
the terrain is blocking for all walking npcs. They can still walk
'behind' but not across the base."

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Killer attribution | `Dragon.take_damage(amount, bypass_shield := false, killer := "")` stores `_last_killer`; callers named: Soldier → "soldier", King → "king", Wizard → "wizard", Arrow → "archer"; unnamed sources leave "" | user: "take into account which NPC killed it" — the chapter picked via `GameManager.DRAGON_DEATH_KINDS`, unknowns get the generic dragon_death fall |
| Death hand-off | `Dragon.die()` plays the death animation, then `notify_dragon_death`; `_pending_death_reload` makes the scene reload ONLY when the chapter closes (`_run_scene_reload`, guarded on `current_scene != null` so probes are safe) | reloading BEFORE the story would destroy GameManager + popup instantly; the hub owns the teardown, the dragon only asks |
| Once per run | `dragon_death_served` flag, NOT `story_shown` — a second `notify_dragon_death` call reloads immediately | every OTHER chapter is once-per-run because it happens once; death needs its own gate since the run ends and probes revive the dragon to test each slayer |
| Tree physics layer | trees move to their OWN layer 5 (collision_layer value 16) with a ~30×10 RectangleShape2D at the trunk base (y≈9, at the shadow line); canopy zone gets NO shape | user: walkers "can still walk 'behind' but not across the base" — full-circle blockers made behind unreachable; base-only strips give pseudo-3D y-heaps without pathing chaos |
| Walkers | all six walker scenes (farmer/miner/soldier/wizard/archer/king) mask 17 (solid + wood); BehaviorTree detour + shadow rays use `SCENERY_RAY_MASK := 17` | stuck-detour planning must "see" tree bases or NPCs would grind into the new strip |
| Flight over trees | dragon mask 19 grounded (scenery + dragons + wood); `_try_flight` drops the wood bit, `land_flight` restores it | user: "dragon ignore trees as he flies over them. Mountain will still block" — layer 1 (mountains/lair/lake/walls) never leaves the mask |
| Death art | one shared `assets/dragon_fall.svg`, palette/tint varies per slayer-kind | one strong falling-dragon image, five voices |

## Chapters

`dragon_death_soldier` (common steel), `dragon_death_archer` (the
well-aimed silence), `dragon_death_king` (the crown's vengeance),
`dragon_death_wizard` (the overlord collects — the invoice), and the
generic `dragon_death` (the hoard goes cold). All share the fall art;
choices are the dragon's LAST WORDS.

## Verified

New `probe_dragon_death_and_terrain` 19/19: tree layer 16/base-strip
rect, mountain still layer 1 circle; walker masks scan wood; point
query proves canopy free + trunk base blocked; dragon grounded scans
wood → airborne drops it (mountains stay); king then wizard death
chapters open per-killer, pause, and closing resumes (reload skipped:
probes have no current_scene); archer/soldier/generic chapters map
distinct kinds — caught `_last_killer` leaking across a probe revival
(wiped in `_revive`). Standing battery re-ran ALL green (ttrpg_stories
16, farm_visuals, pricing_claws 14, archer_wizard, king_lives,
probe_death — its "SCRIPT ERROR" grep hit is the probe's own pass
message string). 14400-frame regression: **0 script errors**.

Probe gotcha additions: `take_damage(..., "")` does NOT clear the
previous slayer (the arg is opt-in) — probes between test deaths must
reset `_last_killer` themselves; and probe_death's pass line literally
contains "SCRIPT ERROR", so error-scan greps need `-A 1 | -B` context
awareness for that file.
