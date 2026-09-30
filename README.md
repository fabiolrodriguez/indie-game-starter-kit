# Indie Game Starter Kit 2.0

A genre-agnostic Godot 4.6+ foundation for 2D or 3D projects. Includes Main Menu,
Settings/Controls UI, audio, English/Brazilian Portuguese localization, persistent
settings and generic saves, keyboard/controller navigation, global pause, scene
transitions, transient sessions, shared Theme and semantic developer palettes.
No gameplay is supplied; build each game's rules and composition in `game/`.

## Start

1. Open `project.godot` in Godot and let assets import. Run the project for Main Menu.
2. Connect the menu's `start_requested` / `load_requested` from game code. These are
   integration hooks, not a sample game. Change scenes with `SceneManager.change_scene(path)`.
3. Choose the developer palette in `ui/theme/theme_config.tres`.
4. For the development-only visual reference, open
   `ui/showcase/developer_showcase.tscn` and click **Run Current Scene**
   (F6 on Windows/Linux, Cmd+R on macOS). It is excluded from the export preset.

Settings use `user://settings.cfg`; explicit game saves use `user://savegame.cfg`.
Neither a save nor a new session is created at startup. ControlsManager describes
InputMap bindings; it does not remap inputs or implement gameplay.

## Validate

Tests import and run a temporary project copy with isolated settings/save paths.
Never launch persistence tests directly against a development project's user data.

```sh
python3 tests/run_tests.py --godot /path/to/Godot
```

Add `--screenshots /tmp/starter-kit-shots` for rendered checks.

See [ARCHITECTURE.md](ARCHITECTURE.md) for responsibilities, APIs and extension points,
[AGENTS.md](AGENTS.md) for contribution rules and [Theme workflow](ui/theme/README.md)
for palette selection/import. The supplied export preset targets Windows; configure
export presets/templates for your target. No repository license file is currently supplied.
