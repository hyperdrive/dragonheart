# Settings menu (ESC)

Date: 2026-11-15.

User: "Please add a way to affect godot scale and window fit by pressing esc
to get a settings menu."

| Decision | Choice | Why |
|---|---|---|
| Opening | ESC in play (`GameManager._unhandled_input`, only when no story/menu is open and the world isn't paused) opens `scripts/ui/SettingsMenu.gd` and pauses; ESC or Resume closes it and drains queued stories | ESC already closes the story popup and the wizard menu; those keep it while they are open |
| Knobs | Scale = `Window.content_scale_factor` (0.5–3.0); Window fit = `content_scale_aspect` (keep / expand / keep width / keep height / ignore); Stretch = `content_scale_mode` (off / canvas items / viewport); Window = windowed / maximized / fullscreen / exclusive fullscreen | Godot's own scaling knobs, applied live |
| Defaults | The window as launched from project.godot, captured before saved choices apply. Note: the project's legacy `stretch/mode="2d"` runs as **Off** in Godot 4 — kept so "Defaults" changes nothing | No surprise on reset |
| Persistence | `user://settings.cfg`, `[display]` section; applied at start by `SettingsMenu.apply_saved` from `GameManager._ready` | Survives restarts |
| Build | A CanvasLayer (layer 20) built in code, no scene; no class_name (editor rescan caveat) | Small, self-contained |
| StoryPopup | `_unhandled_input` ignores input while hidden | A closed popup must never answer ESC or number keys |

## Keymapper (2026-11-15)

User: "add a keymapper to the settings menu as well."

| Decision | Choice | Why |
|---|---|---|
| Layout | The menu gets tabs: Display and Keys | Fits both without a tall panel |
| What can be rebound | `SettingsMenu.REMAPPABLE`: move ×4, fire, eat/act, fly, shapeshift, palette — one binding each. The hard-coded T (Dragon) and C (GameManager) became the `shapeshift` and `palette` input actions in project.godot | Every gameplay key remappable; ESC (`ui_cancel`), story 1–4 and wizard 1–8 stay fixed menu keys |
| Binding | Click a binding, press a key (stored as its physical keycode, so it means the same place on any layout) or a mouse button (wheel ignored); ESC cancels. A key another action uses swaps over to the old binding | No silent double-bindings, no dead actions |
| Saving | `[keys]` in `user://settings.cfg` (int: keycode, or −button for the mouse); Defaults restores display and keys as launched | — |
| Hints | `key_name(action)` names the bound key on the player's layout; HUD "Wings: ready (…)", the wake-the-dragon messages and the dragon's prints use it; story text uses `{key:action}` tokens (`with_keys`) | Hints never lie after a rebind |
