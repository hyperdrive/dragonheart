# Claw damage + the dragon slayer — decisions

Date: 2026-11-14. Builds on the damage model (`scripts/systems/Damage.gd`)
and replaces the soldier-strike lottery of `2026-11-08-soldier-strike.md` /
`2026-11-09-pricing-and-claws.md`.

## User spec

"Introduce a new NPC that appears randomly like the adventurer: the dragon
slayer. He should be riding and have a lance. His attack is that he aims
his lance then dashes forward very quickly. 50p weapon damage on impact.
He is immune to dragon fire and must be clawed. … basic claw attack needs
to be improved. No chance but rather damage now that we have a HP system.
This affects upgrades in the Wizard Tower as well. Without upgrade ~2
attacks per soldier. With upgrades ~1 attack per soldier. Dragon slayer
takes ~3 attacks. Claw attack also has recharge 0.5 s (reasonable?)"

## Decisions

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Claws | Every E strike on a fighter (soldier, goblin, hag, slayer) lands for `Dragon.claw_damage` WEAPON damage — no kill lottery, no miss | User spec | — |
| Numbers | Base 25 (2 per 50 HP soldier, 3 per 75 HP slayer); Brute Force +7 per buy, capped at 50 (4 buys → 1 per soldier) | Matches "~2 / ~1 / ~3"; keeps the shop's 4-step upgrade ladder | soldiers' HP changes |
| Recharge | 0.5 s base (user's number — kept: a flurry, yet soldiers get a beat to answer). Speed's permanent bonus now 0.3 s (was 0.2) | With sure hits, 0.2 s at 50 damage = 250 DPS — trivialises the slayer and the hag | playtests say claws feel slow/fast |
| Townsfolk | Unchanged: E on a farmer/miner still kills outright and steals the payload | That is the theft mechanic, not combat | — |
| Hag | 245 HP (was 200) | Keeps "two fires + five claws" true with 25-point claws (2 × 60 + 5 × 25) | — |
| Slayer stats | 75 HP, speed 95, DRAGON_FIRE ×0 and not flammable (no burn panic), no contact damage, never flees | "Immune to dragon fire and must be clawed" | — |
| The joust | Rides to ~340 px (stand-off, a spot with a clear lane), then within 60–440 px with a clear grid lane (to a lance-length short of the dragon): AIM 0.6 s (tracks the dragon; the last 0.25 s the line is LOCKED and drawn red on the ground) → DASH 800 px/s up to 560 px → 50 WEAPON on contact (once) → RECOVER 0.9 s → 2.5 s cooldown. Tuned 2026-11-15 (user: "aim faster and strike from a longer distance"; was 1.0 s / 270 px / 640 px/s): from lock to impact a walking dragon still has ~0.65 s at the stand-off (~100 px of sidestep vs a 34 px hit radius) | Readable telegraph with a dodge window; a wall or the dash length ends it | dodging feels too easy/hard |
| Spawning | Random: first after 150–270 s, then every 120–240 s while none is out; from the map edge farthest from the dragon; not while the dragon is the farm girl or after the run ends | "Appears randomly like the adventurer" | — |
| Visibility | Hunts `dragon_threat` like every antagonist — the farm girl is invisible to him | Consistency with the human-shape rules | — |
| Art | `SlayerRig` (horse gallop, rider bob, lance raise/couch) on generated polygons: white charger, crimson caparison with Osric's sun, plate, crimson plume, kite shield, lance with pennant; drawn at `visual_scale` 0.85 (2026-11-15, user: "15% smaller") | Lore: Osric's knights | — |
| Death chapter | `dragon_death_slayer` ("The Sun on the Lance") | Killer-named chapters | — |

## Pitfall found on the way (2026-11-14)

The first cut of the shop label read `Dragon.BRUTE_STEP` / `Dragon.CLAW_DAMAGE_MAX`
from `WizardMenu.gd`. Naming the `Dragon` class there pulled the dragon's whole
dependency chain into the menu scene, which GameManager preloads early; the
resulting load cycle made Godot hand `Archer.gd`'s `preload("Arrow.tscn")` an
EMPTY PackedScene ("Failed to instantiate scene state of "", node count is 0"
on every shot). Fix: the menu and GameManager ask the dragon instance
(`claw_damage_after_brute()`, `buy_brute_force()`). Rule of thumb: UI and
manager scripts talk to the dragon through its instance, not its class.
