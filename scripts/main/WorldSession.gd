extends Node

## Boot-mode / world-selection carrier (decision record 2026-11-12-world-editor).
## The game scene resolves WHICH saved world to generate from here, in order:
##   1. pending_world — set by the world editor's Play button or a probe
##   2. --world=<name> command-line user arg (godot --path . -- --world=foo)
##   3. "" — no layout: WorldManager falls back to full-procedural generation.
## Registered as the "WorldSession" autoload in project.godot.

var pending_world: String = ""

const WORLD_ARG := "--world="


static func world_arg() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(WORLD_ARG):
			return arg.trim_prefix(WORLD_ARG)
	return ""


## The world name a fresh Main scene should generate from ("" = procedural).
func active_world() -> String:
	if pending_world != "":
		return pending_world
	return world_arg()
