# Wizard: four-upgrade provocation + shield-piercing lightning — decisions

Date: 2026-11-09. User: "the wizard will emerge after four upgrades
right? And there's no shield against his attacks."

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Purchase provocation | `wizard_upgrade_threshold` 3 → **4** — the wizard provokes at **4 purchases AND >3 tower visits** (OR the 20g greedy line, unchanged) | The user's correction of their previous spec; the visit half ("more than 3") already reads 4+ so the pair stays symmetric at ~four |
| Shield bypass | `Dragon.take_damage(amount, bypass_shield := false)` — new optional flag; the ONLY caller passing true is the wizard's lightning (`take_damage(LIGHTNING_DAMAGE, true)`) | User: "there's no shield against his attacks" — buying the 8g shield (halved same day) must not become a lightning immortality loop; the backstabbing wizard pierces counterplay of any price. Scales reduction still applies (only the shield pool is pierced) |
| Nothing else pierces | soldiers, archers, the King, burn ticks all use the default path — the shield still absorbs them exactly as before | "No shield **against HIS attacks**" is wizard-specific; making the whole shop shield dead would gut an 8g purchase users can still buy |
| Fire shield untouched | the wizard's own 5s fire cloak (BaseNPC.fire_immunity_seconds) is unaffected — that's HIS armor | Keeps "a shield like the king" per the original wizard spec; the bypass only governs damage ENDING on the dragon |

## Interactions

- With halved prices + doubled miner hauls, four purchases now come fast —
  the wizard is an EARLY-mid boss threat. The intended path around him:
  stay out of his 500px lightning reach or out-endure the 15 DPS while
  killing him (80 HP), since relocation does not stop the hunt — only
  death does.
- Counterplay asymmetry is deliberate: his lightning is instant at range
  (no dodge beyond distance) and unblocking, but the dragon can kill him.

## Verified

`probe_pricing_claws` re-run 14/14 (added P6): lightning with shield 10
active takes the FULL 30 hp and leaves the shield untouched; ordinary
damage still eats the shield below its previous value.
`probe_archer_wizard` re-run green with P4 updated to the four-purchase
threshold (live watcher spawns at purchases=4 + visits=4). 14400-frame
regression: **0 script errors**.

Probe gotcha: `wizard_spawned` lives on WorldManager (re-learned from
the pricing batch's mid-probe crash — kept in the record).
