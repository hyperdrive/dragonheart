# Dragonheart

**An RTS survival game with RPG elements — play as the dragon.**

> **Warning:** This is an early concept exploring the life of a dragon in a world that fears you.

---

## Overview

In *Dragonheart* you are not the hero. You are the **dragon** — a creature of fire and gold, hoarding treasure and growing stronger while the world sends wave after wave of defenders to stop you.

The game blends **real-time strategy** with **role-playing progression**. You start small, hungry, and vulnerable. With every raid, every stolen gem, and every upgrade purchased from the unreliable wizard, you grow stronger — until you can stand against the King himself.

---

## The World

### The Town
A thriving settlement that feeds and funds its defenders:

- **Farmers** — Grow food to sustain soldiers. Burn their fields and they’ll try to appease you by sacrificing a virgin. *You can turn this to your advantage.*
- **Miners** — Dig gold and gems from the earth, filling the town treasury.
- **Soldiers** — Patrol the town, chase you when you appear, and die in droves.

### The Outskirts
- **Mining district** — Where your treasure-hunting rivals make their living.
- **Goblin tribe** — A nomadic people who hide in the mountains, occasional allies or distractions.

### The Bosses
- **King** — The final boss. Dies three times before falling forever. Each resurrection makes him stronger.
- **Wizard** — The shopkeeper who sells you upgrades. Betrays you once you’ve spent enough gold.

---

## Gameplay Loop

1. **Scout & Raid** — Hunt farmers, miners, and soldiers. Steal gold and gems.
2. **Upgrade** — Visit the wizard’s tower and spend your loot on:
   - More flame charges
   - Shield absorption
   - Speed boosts
   - Longer flight
3. **Survive** — Defend yourself against increasingly organized resistance.
4. **Ascend** — Take down the King. Or keep grinding for the perfect hoard.

---

## Unique Mechanics

### Dragon Upgrades
- **Flame** — More breath charges, longer duration, wider reach
- **Shield** — Absorbs incoming damage before your health
- **Speed** — Fast wings for quick positioning
- **Flight** — Extend your air time

### Fire Mechanics
- **Ignition** — Enemies catch fire and burn over time
- **Panic** — Burning NPCs lose their orders and flee randomly
- **Field burning** — Farmers’ livelihoods destroyed = desperation = sacrifice

### The Sacrifice Mechanic
If you burn a farmer’s field, they’ll try to appease you with a virgin sacrifice. You can:
- **Accept** — Gain a one-time bonus (gold, gems, or a temporary power-up)
- **Refuse** — Continue burning until they collapse or flee
- **Eat** — Consume the sacrifice for a health boost

---

## RPG Elements

### Progression
- **Scales** — Reduce incoming damage by 2% per level
- **Flame** — Increase your offensive capacity
- **Shield** — Absorb incoming attacks

### Upgrades
Purchased from the wizard in his tower. Each upgrade is a one-time purchase (except brute force and flame upgrades, which are repeatable with diminishing returns).

---

## The Story (Emergent)

*Dragonheart* doesn’t tell you a story — it **emerges** from your actions:

- Burn too many fields? The town builds more soldiers.
- Steal too much gold? The wizard raises his prices.
- Defeat the King three times? The realm enters permanent war.

Your hoard grows. Your legend grows. The world fights back.

---

## Status

**Early concept.** Core systems in place:

- Dragon movement, flight, and fire breath
- NPC AI (farmers, miners, soldiers, goblins)
- Wizard shop with upgrades
- King boss with multiple lives
- Shield absorption system
- Fire burn mechanics

---

## Controls (PC)

- **WASD** — Move
- **Q** — Flight toggle
- **E** — Attack (fire breath)
- **R** — Shield toggle
- **1–8** — Wizard menu selection

---

## License

MIT License. See `LICENSE` for details.

---

## Contributing

This is a personal project, but bug reports and suggestions are welcome. Open an issue or submit a pull request.

---

*Dragonheart — Where the hero is the monster.*</parameter>
</function>
</tool_call>
<tool_call>
<function=shell>
<parameter=command>
cd /home/thek/Development/godot/dragonheart && git add README.md && git commit -m "docs: add README with game introduction\n\n- RTS survival with RPG elements\n- Play as the dragon, not the hero\n- Upgrade from unreliable wizard\n- Fire farmers' fields to trigger sacrifice mechanic\n- King boss with 3 lives\n- Early concept status noted\n\nIncludes overview, gameplay loop, unique mechanics, and controls.\"\ngit log --oneline -1 && git push origin main 2>&1"