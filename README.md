# Indie Game Starter Kit 2.0

A genre-agnostic Godot 4.6+ foundation for 2D or 3D projects. Includes Main Menu,
Settings/Controls UI, audio, English/Brazilian Portuguese localization, persistent
settings and generic saves, keyboard/controller navigation, global pause, scene
transitions, transient sessions, shared Theme and semantic developer palettes.
No gameplay is supplied; build each game's rules and composition in `game/`.

## 1. Create your project

Install Godot 4.6 or newer. Python 3 is needed only for the test runner.
Fork this repository into your own account, then clone your fork. To start from a
local copy instead:

```sh
git clone https://github.com/fabiolrodriguez/indie-game-starter-kit.git my-game
cd my-game
```

If you cloned the starter directly, keep its remote as `upstream` and point `origin`
at your own empty repository before pushing game changes. Replace the example URL
below with your repository's URL:

```sh
git remote rename origin upstream
git remote add origin https://github.com/YOUR-USER/YOUR-GAME.git
```

In Godot's Project Manager, choose **Import**, select `project.godot`, and open it.
Let the assets import, then click **Run Project**. The Main Menu already includes
Settings and Controls. Start and Load are integration hooks until you connect your game.
Set your game's name and icon in **Project Settings → Application → Config**.

## 2. Explore and customize the UI

Open `ui/showcase/developer_showcase.tscn` and click **Run Current Scene** in the
editor toolbar (F6 on Windows/Linux, Cmd+R on macOS). The Showcase lets you inspect
shared controls, palettes, audio, localization, pause and transitions. It is a
development reference and is excluded from the supplied export preset.

To change the project's colors:

1. Select `ui/theme/theme_config.tres` in the FileSystem dock.
2. In the Inspector, set **Palette** to a resource from `ui/theme/palettes/`.
3. Save the resource and run the project.

The Showcase's palette selector previews colors locally; it does not change this
configuration. Duplicate a preset to create your own palette. Change typography
and spacing through `ui/theme/indie_style.tres`. Keep `menu_theme.tres` as the shared
Theme wrapper; its styles and icons are generated automatically.
See the [Theme workflow](ui/theme/README.md) for semantic roles and HEX import.

## 3. Add your game and connect the menu

Keep game rules and composition in `game/`. Reuse the existing managers and UI.

| Location | What belongs here |
| --- | --- |
| `game/` | Your gameplay scenes, scripts and application flow |
| `components/` | Optional reusable behaviors |
| `core/` | Existing global infrastructure |
| `scenes/` | Supplied Main Menu and Pause Menu scenes |
| `ui/` | Reusable UI scripts, Theme, palettes and transitions |
| `tests/` | Isolated regression checks |

For a first integration:

1. Create your playable scene at `res://game/world.tscn` (2D or 3D).
2. Create `res://game/entry.tscn` with a plain Node root.
3. Instance `res://scenes/main_menu/main_menu.tscn` under it, naming the child `MainMenu`.
4. Attach `res://game/menu_flow.gd` to the entry root using the example below.
5. Set `game/entry.tscn` as **Project Settings → Application → Run → Main Scene**.

```gdscript
extends Node

const GAME_SCENE := "res://game/world.tscn"

func _ready() -> void:
    $MainMenu.start_requested.connect(_start_game)
    $MainMenu.load_requested.connect(_load_game)

func _start_game() -> void:
    GameSession.start()
    _open_game()

func _load_game() -> void:
    if not SaveManager.load_game():
        push_warning("No readable save available.")
        return
    var state = SaveManager.get_value("game", "session", {})
    if not state is Dictionary:
        push_warning("Invalid session data.")
        return
    GameSession.start(state)
    _open_game()

func _open_game() -> void:
    var error := SceneManager.change_scene(GAME_SCENE)
    if error != OK:
        GameSession.finish()
        push_error("Could not request game scene: %s" % error_string(error))
```

This example restores the dictionary saved in the next section. Your game owns
the save schema and validation. `GameSession.start()` clears previous session values.
Scene changes preserve the current session; call `GameSession.finish()` when ending it.

Always request scene changes through `SceneManager.change_scene(path)`. An `OK`
return means the request was accepted; use `transition_finished` or
`transition_failed` for the eventual result. Gameplay that polls `Input` should
skip input actions while `SceneManager.is_transitioning` is true.

## 4. Use the foundation systems

**Session and saving.** Session state is temporary. Saving and loading are explicit
game decisions; neither a save nor a new session is created at startup. For example,
from your game code:

```gdscript
GameSession.set_value("progress", 3)
SaveManager.set_value("game", "session", GameSession.snapshot())
var error := SaveManager.save_game()
if error != OK:
    push_error("Could not save: %s" % error_string(error))
```

Settings use `user://settings.cfg`; game saves use `user://savegame.cfg`.
Settings UI setters automatically save and apply their values. Give each derived
project its own application name so unrelated games do not share default user data.

**Pause.** Instance `scenes/pause_menu/pause_menu.tscn` in your gameplay scene.
It handles Escape / controller Start and resumes through `PauseManager`.
Connect its `quit_requested` signal to your game's return-to-menu policy, including
ending the session when appropriate. Use one pause presenter per scene and call
`PauseManager.set_paused()` rather than writing `SceneTree.paused` yourself.

**Controls.** Add gameplay actions in **Project Settings → Input Map**, preserving
the supplied UI actions. Call `ControlsManager.set_controls_data()` with entries
such as `{"label_key": "controls_jump", "action": "jump"}` to list your actions in
the Controls panel. Add the label's translations before opening the menu.
ControlsManager displays current bindings; it does not implement input remapping.

**Localization and audio.** Extend `LocalizationManager.translations` from game code
before opening menus; read text with `tr_key()` and refresh custom UI on
`language_changed`. Use SettingsManager for a persisted language choice.
Reuse AudioManager's `play_click()`, `play_hover()` and `play_bgm(stream)` for playback.
Use `play_sfx(stream)` for other effects. Music players should use the `Music` bus;
effect players should use `SFX`. Both feed `Master`, so player preferences apply to
your own AudioStreamPlayer/2D/3D nodes as well.

Settings exposes Master, Music and SFX sliders with immediate, persistent changes.
**Reset Audio Volumes** restores all three to 1.0 without changing display/language
preferences. Values are linear 0–5; zero mutes the corresponding bus. Use
`SettingsManager.set_master_volume()`, `set_music_volume()` and `set_sfx_volume()`
for persisted preferences, or AudioManager's same-named setters for runtime-only
bus adjustments. Existing `SettingsManager.volume` / `set_volume()` still control
Master, and older settings files load without migration steps.

See [ARCHITECTURE.md](ARCHITECTURE.md) for API responsibilities and lifecycle details.
When using a coding agent, keep [AGENTS.md](AGENTS.md) in the project so it reuses
the foundation and places gameplay in the intended directories.

## 5. Validate your changes

Tests import and run a temporary project copy with isolated settings/save paths.
Never launch persistence tests directly against a development project's user data.

```sh
python3 tests/run_tests.py --godot /path/to/Godot
```

Add `--screenshots /tmp/starter-kit-shots` for rendered checks.

On macOS, pass the executable inside the Godot application bundle, for example:

```sh
python3 tests/run_tests.py --godot /Applications/Godot.app/Contents/MacOS/Godot
```

Adjust the path to wherever you installed Godot. These checks cover the supplied
foundation; add tests for your own gameplay separately.

## 6. Export your game

Install export templates matching your Godot version, then open **Project → Export**.
The supplied preset targets Windows; add or configure presets for your target platforms
and choose your own output path. Confirm the configured Main Scene is your game entry.

Keep `tests/*`, `ui/showcase/*`, `ui/theme/preview/*` and `ui/theme/tools/*` excluded
in every player export preset. Validate the exported build as well as editor runs.

No repository license file is currently supplied.
