# King lives (3 respawns), fire cloak, magic sword, weapon swing — decisions

Date: 2026-11-09. Follow-ups to `2026-11-09-gate-handoff-and-aggressive-bold.md`.

## User spec

1. "Let's allow for King to respawn three times after he is defeated."
2. "Make him immune to fire after first hit and then for 5s."
3. "He has a magic sword so he should make a lot of damage."
4. "Add a swing animation to all soldiers and king when attacking."

## Decisions

| Decision | Choice | Why |
|---|---|---|
| King lives | `WorldManager.king_respawn_count = 3`; `king_respawns_left` counts respawns REMAINING after each decrement → the King dies FOUR times total (first life + 3 rises). `King.die()` → `world.on_king_defeated()`: lives left → 3s one-shot Timer re-materializes the King at the city (swarm pinned ATTACK, purchases/farming stay frozen via `king_spawned`); lives exhausted → false → victory via `notify_king_defeated()` | User asked for respawns after defeat, not extra pre-multiplication of HP |
| Fire cloak | Generic `BaseNPC.fire_immunity_seconds` (0 = off everywhere else): every SUCCESSFUL ignition arms the window — re-breaths inside it slide off, and the 3s burn runs INSIDE the 5s cloak, so he is only truly flammable 2s in every 5s cycle. King sets 5.0 and prints his cloak line on activation | "immune after first hit and then for 5s" — arming on EVERY successful ignition keeps the rule meaningful after the burn-out |
| Magic sword | `attack_damage = 50` (5× the soldier's 10). Contact already carries the special AoE (30% × 1.5× = 75) on top | No discrete sword-hit system exists; the contact DPS channel IS the sword, damage number does the heavy lifting |
| Weapon swing | Code-driven in Soldier (King inherits): while ACTIVELY fighting (alive, not burning, dragon within `attack_range`), the carried weapon (`Sprite/Spear`, King's `Sprite/Sword` resolves by the same `_resolve_weapon()` lookup) swings overhead→strike at ~2.2 Hz (`-55°→+25°`), a warm glint at the bottom of each strike, small body lean on `sprite.rotation`; the non-fighting branch restores the EXACT rest pose. Presentation only — DPS stays `_contact_damage` | No AttackPlayer exists on these NPCs; a deterministic sinusoid reads as a melee swing without new assets |

## The bug this batch uncovered (worth the price of the probe)

`Soldier._ready()` ran its profile (npc_type soldier, 50 HP, speed 80,
danger_radius 0) UNCONDITIONALLY — and the King sets his boss config
before `super._ready()`. Result: since the King's introduction, every
King ran as a 50-HP, 10-DPS `npc_type = "soldier"` unit. The 200-HP spec
line was aspirational fiction.

Fix: Soldier's defaults now apply only when `npc_type` is still the
BaseNPC default `"villager"` (a configured subclass keeps its values).

Second-order leak the fix EXPOSED: with the King's config finally
honored, `danger_radius` defaulted to BaseNPC's 150 — he began FLEEING
the dragon (never configured it; the old stomp had incidentally zeroed
it). Pinned `danger_radius = 0.0` in King._ready. Lesson: subclasses that
configure-before-super must be audited for every default the parent
profile used to overwrite.

## Probe evolution (for next time)

- Respawn lands the King at the CITY, never at the probe's spawn point —
  identify risen kings by `distance_to(city_position)`, not by position
  equality; every poll is bounded (≤6s at 0.5s cadence, total run ~60s).
- Probe-hygiene guards ran last time: a 50-HP probe king burned to death
  mid-probe and triggered the live respawn path (then a freed-instance
  crash + hang). With the stomp fixed the king survives burns.
- King chases hard (whole-map aggro) — park him far during cloak tests,
  or he'll drag contact DPS into unrelated asserts.
- BaseNPC's fire cloak ticks down ONLY in the non-burning `_physics_process`
  branch; tests force re-ignition by zeroing `_fire_immune_left` manually.

## Addendum — the town recruits through the boss battle (same day)

User follow-up: "Soldiers should always be coming and especially if
there are treasure in the treasury. When the King comes out new
soldiers stop spawning."

Supersedes this record's frozen-economy intent: `king_spawned` no
longer gates recruitment anywhere —
- `_try_buy_soldiers` drops the `king_spawned` check (purchases fire
  while the King is alive AND during respawn gaps),
- `_on_escalation_tick` drops its `king_spawned` check (the trickle
  keeps ticking; its `spawn_king()` back-call is a no-op while one is
  out),
- `spawn_king` and the respawn timer no longer `_soldier_timer.stop()`.

Only `game_manager.run_finished` still stops purchases (post-victory).
Probe `probe_always_spawning.gd` 6/6: purchases during boss phase
(spawned 4→6, treasury drained), trickle keeps running, purchases
during a respawn gap (7→10, lives decrementing), recruit timer never
stopped; 14400-frame regression 0 script errors.

## Verified

`probe_king_lives.gd` 23/23: boss stats land (200 HP / "king" / 50 DPS /
cloak 5.0); first ignition burns + arms; inside-window immune;
post-window re-ignite re-arms; 2s of contact DPS observed (175 hp on a
godmode dragon incl. one special spike — traced 50/s sustained); King
sword swings during the fight and rests after; soldier spear swings +
rests; three defeats each produce a rise at the city with lives
3→2→1→0; the 4th defeat produces no rise and declares victory.
14400-frame regression: 0 script errors, purchases/deliveries flowing.
