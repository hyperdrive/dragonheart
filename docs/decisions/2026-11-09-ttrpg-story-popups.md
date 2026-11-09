# TTRPG story popups — decisions

Date: 2026-11-09. User: "Add a popup window that overlays and pause the
game. The window should have space for one image and text. The text can
be multiple choices and the answers will be part of a ttrpg progression
policy. When window closes the game resumes."

## The shape

CanvasLayer overlay mirroring the WizardMenu pause precedent
(layer 12, PROCESS_MODE_ALWAYS, world PAUSED beneath). One image +
story text + 2–3 choices per chapter; click or keys 1–4; **ESC picks
the LAST choice** — a story always ends answered, never muted.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Pause owner | GameManager (`_open_story_now` sets `get_tree().paused`, `_on_story_closed` unpauses + drains) | standing pillar: GameManager is the single state hub; the popup stays dumb |
| Once per run | `story_shown` ledger marks every kind the first time told | user listed ONE-TIME beats ("first pig/cow eaten", King emerge) — repeats would cheapen them |
| Queuing | kinds told while any popup/menu is up wait in `story_queue`; also drained when the wizard menu closes | chapters must never fire against a paused overlay and evaporate |
| Answers | `ttrpg_choices[kind] = index` + `story_choice_made(kind, index)` out of GameManager | the "progression policy" ledger — future TTRPG systems read run-level personality from here |
| Trigger scope | seven kinds exactly: field_burn, miner_burn (miners ONLY), king_emerge, king_defeat (FINAL fall only), wizard_emerge, pig_eaten, cow_eaten (first meals) | the user's list; farmer burns deliberately get no chapter (P2 probe pins it) |
| king_defeat timing | `notify_story("king_defeat")` BEFORE `run_finished = true` in `notify_king_defeated` | the epic chapter must play while the run's tally mirrors it, not after victory tears the world down |
| ESC semantics | ESC = last choice | the choices are in-character answers; dropping them silently would break the ledger contract |

## Triggers wired

`Field.burn()` · `BaseNPC.catch_fire()` (npc_type == "miner") ·
`WorldManager._materialize_king()` · `GameManager.notify_king_defeated()`
· WorldManager wizard spawn path · `Dragon._eat_meal_from` (switch on
`pen.animal_name`). All fire-and-forget `notify_story(kind)` through
`get_first_node_in_group("game_manager")`.

New art: `assets/field_fire.svg`, `pick_flame.svg`, `king_crown.svg`,
`wizard_bolt.svg` (pig/cow chapters reuse the existing pen SVGs).

## Probe hazards (learned this batch)

- Story popups PAUSE the sim: any older probe that touches a trigger
  kind now needs a `drain_all(game)` helper (answer choice 0 in a loop)
  — added to probe_farm_visuals (P3 burn), probe_pricing_claws (P3
  stash-20 wizard), probe_archer_wizard (P0 stash-31 wizard),
  probe_king_lives (P5 final defeat).
- **probe_king_lives deeper trap**: the King RESPAWN path calls
  `_materialize_king()`, so the first respawned King fires king_emerge
  and freezes the respawn Timer node mid-P5 — rises never happen and
  the probe aborts on an empty-array index (dangling sim, no quit).
  The probe now pre-consumes `story_shown["king_emerge"] = true`;
  only its FINAL-defeat chapter is drained live.
- Probes' `create_timer` SceneTreeTimers run while paused (default
  `process_always`), so assertions keep landing even mid-story — the
  freeze symptoms come from world Timer NODES, not probe timers.

## Verified

`probe_ttrpg_stories` 16/16 (open/pause/art/once-per-run/resume for
field burn; miner yes farmer no; king_emerge; forced final defeat →
king_defeat chapter THEN victory; wizard_emerge; first pig/cow only;
ledger full with all 7 kinds). Pause-leak sweep re-ran the four older
probes: farm_visuals / pricing_claws (incl. P6 shield-bypass) /
archer_wizard / king_lives all fails=0. 14400-frame regression:
**0 script errors**.
