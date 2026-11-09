# Gate hand-off exemption, whole-map bold soldiers, city-spend prints — decisions

Date: 2026-11-09. Follow-ups to `2026-11-09-bold-soldiers-and-flames.md`;
supersedes its pursue-reach choice (360px sight → whole-map hunt).

## User spec

1. "We still fail to spawn soldiers."
2. "The soldiers also need to be more aggressive and attack the dragon
   when they are bold."
3. "Print a message when city uses resources."

## Forensics — the spawn failure was a delivery choke, not a purchase bug

Purchase mechanics verified healthy headless (4 → 16 soldiers in 50s with
purchases). Simulating a REAL session (dragon raiding near the town)
reproduced the failure exactly:

- Miners/farmers deliver at the north gate; the dragon's 180px flee ring
  sits right ON the gate zone. A loaded carrier entered the ring,
  panic-ran away, re-picked deliver, walked back in, fled again —
  circling for 45s+ with a full cart, ZERO deliveries of any kind in
  90s (treasury 0 the entire sim) → no purchases → "fail to spawn".
- Purchases even fired the moment a quiet-run treasury had sources —
  so the town spends fine; the money just never got IN.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Gate hand-off | `BehaviorTree._tick_danger` consults `npc._handoff_stretch()`; a LOADED carrier ON ITS DELIVER LEG finishes the trip even with the dragon in the flee ring | The choke was "flee vs deliver" ping-pong at exactly the delivery point. Panicking away from the destination can never complete it |
| Drop rule untouched | `_check_dragon_drop` (spill at 85px) runs in the miner's own physics regardless of exemption | The claws arriving under the cart still win (2026-11-08 spill rule + interception system stay as the dragon's theft paths) |
| Farmer wording | Same exemption for loaded `deliver` legs; robbery of food stays physical (the dragon eats the farmer) | Farmers have no spill/interception path, so the exemption trades panic walks only |
| Bold reach | `BOLD_HUNT_REACH = 4000` (whole map, same reach as a released swarm) for BOTH `_pick_dragon_target` and `_dragon_in_chase_range`; user: "more aggressive, attack the dragon when they are bold" | Supersedes the 360px sight (grilled 2026-11-09 same day). Morale decay remains the ONLY brake: the straggler finishes the in-flight leg and re-picks to home behavior |
| City-spend prints | Soldier purchases now print the exact spend ("spent X gold, Y gems", treasury left, fielded total); pen refills already print via AnimalPen ("a new pig grew up — town paid 10 food") | User hates blind resource flow; every city spend is narrated |

## Probe evolution (for next time)

- `dragon.health = max_health` inside a sim loop UNDOES godmode — soldiers
  then legitimately kill the dragon (`_dying=true` forever; `_contact_damage`
  bails on dying dragons = "hp stuck at max" illusion). Use
  `max_health * 100.0` in every reset.
- The healthy economy CROWNS the real King at 15 fielded mid-probe —
  morale probes must free him and reset `king_spawned` before testing
  king-boldness against a hand-instantiated king.
- P1/P2 gotchas as before: interrupt after teleport for immediate picks.

## Verified

`probe_gate_bold.gd` 9/9: deliveries DO flow under raid parking (treasury
+food inflow across 100s); purchases fire ("City bought…" xN, gem path and
gold path both seen); bold phalanx hunts 1262px across the map to contact
and chips the dragon through contact DPS; scattered-phalanx straggler
gives up after morale loss; lone soldier stays calm; king presence flips
a loner bold instantly. 14400-frame regression: 0 script errors, 30
deliveries, both purchase messages printed with full breakdowns.
