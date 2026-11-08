# Manual eating + wizard tower upgrade menu — decisions

Date: 2026-11-08. Companion to flammable-ecology and farm-placement-rules (same day).

## User spec

Eating animals becomes an intentional E-key command (skill issue when wasted).
Trying to eat when full telegraphs with flashing chips. Visiting the wizard
tower opens an upgrade-picking scene: +1 flame, +2 flame, a 10-point shield
that absorbs damage once, a short speed boost, +1 longer flame range.

## Decisions (grilled, round 1 — Q1..Q10 all accepted as recommended)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Upgrade currency | Stolen stash (`_pay_stash`; gems worth 10x as top-up) | Stealing remains the game's spine | a second currency is wanted |
| Purchases per visit | Many, menu stays open until ESC/Leave | One-per-visit punishes hoarding play | economy proves too generous |
| "+1/+2 flame" | Permanent max-charge capacity +1 / +2 (purchased charges refill immediately); stackable | Refills by eating already exist; capacity is the non-redundant knob | charge economy rebalanced |
| Shield | +10 absorb pool; absorbs incoming damage until depleted, then gone; cannot restack while any shield remains | "Lost when used" = consumable pool; stacking pools would trivialize boss hits | boss damage raised |
| Speed boost | Triggers at purchase, +60% for 6s, non-stacking (re-purchase just refreshes) | No inventory UI exists anywhere else | boost/affix items appear |
| Flame range | +20px breath reach per purchase (95 → …), permanent, stackable | "+1 longer range" = one increment per buy | reach feels short/long |
| Menu presentation | Own scene (`WizardMenu.tscn`, CanvasLayer overlay) with `get_tree().paused = true`; world state untouched | A `change_scene` swap would destroy the live economy; the overlay feels like a distinct scene | |
| Selection input | Mouse click + number keys 1–5; ESC or Leave closes | Discoverable + fast | |
| Prices (draft const) | flame +1 = 30, flame +2 = 60, shield = 40, speed = 50, range = 45 (gold) | Mid-early map tuning; single PRICES table | any ledger drift |
| Old U-key panel | Trigger removed; scales/fire purchase paths retired (levels stay at 1; existing math unaffected) | Purchases now only at the wizard site (recorded deferred decision) | scales armor is wanted back |
| Manual eat reach | Nearest pen (`pig_pens` ∪ `cow_pens`) within its `pen_radius` from E | Matches steering feel; pens own their reach | one-shot global eat |
| Waste telegraphing | Refuse when health full (no heal ⇒ no flames ⇒ pure waste) → flash HP chip; if flames full, flash Fire chip (recharge clamp) | Cheapest full telegraphing; chips own the flash visuals | dedicated overlay |
| Eating pacing | One animal per E press (no bite timer) | Intentional command paced by the player's hand | animation gating desired |

## Open / deferred
- Wizard menu art/labels — programmer-color placeholder assumed.
- Purchase failure feedback — stash label flash assumed (matches chip-flash pattern).
- PRICES superseded same day by 2026-11-08-dragon-strikes-respawn-prices
  (per-item {"gold","gems"}; the int table above is historical).
