# Gem rate & goblin employment — decisions

User spec 2026-11-12: "The exchange rate for gems in the wizards tower should be
1 gem = 2gp but you can't get gems for gold. The reason you employ the goblins
to work for gems is that you avoid having them steal your gold."

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Gem gold value | `GameManager.GEM_GOLD_VALUE := 2`, used by `_pay_stash`, `stash_value`, `can_afford_wizard`, `_pay_wizard_cost` | User's exact rate ("1 gem = 2gp"); one shared const beats four copies of a magic `* 10` | the rate needs tuning again |
| No gems for gold | Nothing changed — verified there is no gold→gems path | The user's second clause is a *constraint*: gems stay a currency you can only EARN (goblin protection fees) or find, never buy; the shop's only gem flow is paying them out (HARD requirement on flagship prices, decision 2026-11-08) | a merchant selling gems appears |
| Top-up kept | Spare gems may still flatten a gold cost at 2:1 | Removing it would strand spare gems as dead weight; the user set a rate for gems-as-gold, which is exactly this conversion | user says spare gems must not convert |
| Town-side rate | `soldiers_per_gem = 2` untouched | The user scoped the change to "the wizards tower"; the town's gem-for-soldiers exchange is a different faucet | the town economy is retuned |
| Hostile goblin theft | New `steal_fetch` (prio 30) + `steal_haul` (prio 25) activities in the shared Activity engine | The refusal premise was UNIMPLEMENTED: plunder mode only dealt contact damage, so "avoid having them steal your gold" had no alternative to compare against. Now a refused tribe raids the LAIR, rips up to `steal_haul_size` (5) gold out of the stash per visit, and banks it at the tribe mountain | theft should scale with tribe size |
| Trade/steal exclusivity | `_carrying_gold_haul` now requires `service_state == BUYING` | A hostile thief carrying gold must never run `trade_transact` (paying a gem fee for his own loot); the two loops also can't both be ready — service_state gates each side | goblins change allegiance mid-run |
| Goblin interception | `GoldInterceptionSystem` carrier scan includes the `goblins` group | Payload-slot rule is universal (Miner/Adventurer precedent): what a carrier holds, the dragon can steal back — including the thief's haul and the trader's fee gem | goblins hide their loot |
| Verification | `scenes/probes/GemGoblinProbe.tscn` (headless, 9 checks, exit 0) | 2:1 rate math (4g/5 gems buying a 12g item leaves exactly 0g/1 gem — the old 10:1 would leave 4), no gem grant on purchase, all 8 menu options are priced payments, employed goblins haul gold in and pay gem fees out while stash gold never drops, hostile goblin drains the stash dry and the dragon can intercept the haul mid-flight | any economy rule changes |

## Trade-offs

- **2:1 makes gem-topped purchases cheaper** (a gem now bridges 2 missing gold,
  was 10). Flagship items keep their HARD gem requirement, so the goblin fee
  stays the only way to unlock flame_2 / range.
- **Theft is slower than trading for the dragon's pocket but not for the
  tribe**: a hostile goblin takes 5 gold per ~2 minute raid round trip; an
  employed one delivers 1 gold per trip and costs 1 gem. The gem fee is the
  price of keeping the dragon's gold safe — matching the user's framing.
- **The theft payload rides the same payload slot as trade goods**, so the
  dragon can intercept it mid-haul: stealing from the thief is the counter-play,
  not a loophole.
