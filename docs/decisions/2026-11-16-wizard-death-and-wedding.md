# The wizard's death, the silence, the wedding declared

Date: 2026-11-16.

User: "We should let the wizard die spectacularly in multiple lightning
strikes and an explosion. Then nothing for 5s. Only after the pause is the
wedding declared. Add some text about all threats being removed with the
Wizard and king gone."

| Decision | Choice | Why |
|---|---|---|
| The death | `Wizard.die()` overrides BaseNPC's: no 2 s corpse timer; it drops `scripts/fx/WizardDeathFX.gd` at his feet. The sky's own lightning strikes him 8 times, faster and faster (gaps 0.42 → 0.1 s), lighting him white and jolting him; then 3 bolts at once; a violet charge swells; he bursts: white core and violet fireball, two shockwave rings, 26 shards of robe and gold, a screen flash, a camera shake. A scorch stays about 20 s. The effect frees him at the burst | "multiple lightning strikes and an explosion"; he is killed by the thing he stole |
| Every death | The show plays whenever the wizard dies, not only in the finale | It is how he dies |
| Bookkeeping | `npc_died` still fires at once (the tower seals, the finale starts its clock). `_tick_lightning` now also checks `is_alive`, so a dead wizard can't cast during his own show | — |
| The pause | `GameManager.on_wizard_slain`: phase ENDED right away, then `WizardDeathFX.DURATION` (3.6 s) + `FINALE_SILENCE` (5 s) of nothing; the game runs, no messages | "Then nothing for 5s" |
| The declaration | A new chapter, `ending_peace` ("A Wedding Is Declared"): the old King in his tomb, the usurper in the mud, the wizard ash, the soldiers, goblins and wolves gone quiet; the herald proclaims the wedding. → `ending_wedding` → `ending_last_ember` as before | "Only after the pause is the wedding declared … text about all threats being removed" |
| The quiet path | Wizard already dead before the finale (`usurper_falls_quiet`): `on_wizard_slain(0.0)`, the declaration opens at once | There is nothing to wait for |
| Probe | The finale path: the killing blow → burst at about 2.2 s → "A Wedding Is Declared" at 8.6 s | — |
