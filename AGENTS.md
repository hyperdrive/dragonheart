# Dragonheart — agent instructions

A 2D survival RTS in Godot 4.7 (GDScript). Player: dragon. Antagonists: town farmers,
miners, soldiers, King (final boss). Economy: farmers produce food (support chain),
miners fill a town treasury; the dragon steals and upgrades at the wizard tower.

## GodotPrompter

This is a Godot project with GodotPrompter skills available. Before implementing any game
system, you MUST check for a matching `godot-prompter:*` skill and invoke it. This applies
to all agents, subagents, and sessions working in this repository.

Key skills: `player-controller`, `state-machine`, `event-bus`, `scene-organization`,
`component-system`, `resource-pattern`, `godot-ui`, `hud-system`, `ai-navigation`,
`camera-system`, `audio-system`, `save-load`, `inventory-system`, `godot-testing`.

For the full skill list, invoke `godot-prompter:using-godot-prompter`.

## Project conventions

- Decision records: `docs/decisions/YYYY-MM-DD-<topic>.md` — read before designing; the
  behavior-system record (2026-11-08) governs the NPC economy.
- Implementation plans: `docs/plans/`.
- Verify with: `~/Program/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --quit-after N`
- No GUT/gdUnit4 yet — verification is headless error scanning + gameplay prints.
