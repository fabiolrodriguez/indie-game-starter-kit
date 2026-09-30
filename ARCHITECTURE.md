# Starter Kit 2.0

## Boundaries

`core/` contains generic infrastructure. `ui/` contains menu scripts and the shared
Theme. Existing scene paths/UIDs in `scenes/` are preserved. `game/` is the extension
point for each game's rules and composition; `components/` is reserved for optional,
genre-neutral behaviors. No gameplay is supplied.

## Autoloads (one instance each)

| System | Responsibility / extension point |
| --- | --- |
| AudioManager | UI sounds and music playback, including while paused. Assign UI streams or pass music to `play_bgm()`. |
| LocalizationManager | Translation dictionaries, English fallback, `language_changed`; extend `translations` before opening menus. |
| SettingsManager | Load/apply/save display, master volume and language in the existing settings file; UI calls setters. Owns resolution options. |
| SaveManager | Generic section/key data in the existing save file; explicit load/save/reset. Save/reset return errors. Games own their schema and when to persist. |
| ControlsManager | Descriptions from InputMap; `set_controls_data()` accepts action entries or legacy label/value entries. Does not implement gameplay input or remapping. |
| PauseManager | Sole writer of SceneTree pause, with `set_paused()`, `toggle()`, `pause_changed`. No input or scene paths. |
| SceneManager | `change_scene(path)` validates and defers replacement, rejects concurrent requests, unpauses on accepted replacement. |
| GameSession | Transient dictionary: `start(initial_data)`, `get_value()`, `set_value()`, `snapshot()`, `finish()`. Survives scene changes; never saves automatically. |

Autoload order in `project.godot` puts localization before settings and pause before
scene transitions. Audio, pause and transitions process while paused.

## Composition

Connect MainMenu's `start_requested` / `load_requested` from code in `game/`.
That code decides whether to start/restore a session and which scene to request.
Without a game these buttons remain extension hooks, as the template has no game scene.

Instance PauseMenu in a scene and connect `quit_requested` to the desired exit policy.
Resume only unpauses and restores focus; it never reloads a scene. The supplied main
menu wires quit-from-pause to returning to its main panel. `pause` uses Escape / Start;
`ui_cancel` backs out of subpanels and popups. PauseMenu handles unconsumed input and
can disable its pause input with `handle_pause_input`. Use one pause presenter at a time.

SceneManager returns an immediate error or OK (request accepted). Observe
`transition_started(path)`, `transition_finished(scene)` and `transition_failed(path,error)`.
Hooks are notifications, not awaited animation barriers. Run an optional fade-out
before requesting a change and fade-in on completion. Invalid requests retain the
current scene and pause state. Successful transitions preserve GameSession; games
explicitly end/reset it. Dictionary values can be mutable; use `snapshot()` for a copy.

## Styling and persistence

`ui/theme/theme_config.tres` is the single developer configuration resource.
`ui/theme/menu_theme.tres` is generated output and the project-wide Theme
(`gui/theme/custom`). Its `PaletteTheme` tool script rebuilds when configuration,
`UIPalette` or `UIVisualStyle` changes. Saving the configuration does not serialize
generated styles/icons. No extra autoload or player persistence is involved.

`UIPalette` contains semantic colors; six presets live in `ui/theme/palettes/`.
`UIVisualStyle.build(palette)` produces the supplied visual style and native control
states. `indie_style.tres` owns typography/spacing. Future styles reuse the palette
schema. UI inherits the Theme and uses type variations; modal/backdrop colors also
come from semantic roles. `focus_slider.gd` adds the missing native slider focus ring.

`PaletteImporter` converts five explicitly ordered HEX colors into an editable resource
without overwriting existing palettes. `ui/theme/preview/` is a local-only component
gallery. Selection there does not change the project configuration. Gallery, CLI tools
and tests are excluded from the supplied export preset. See `ui/theme/README.md` for
selection, creation, import and consumption instructions.

Settings and save filenames/sections are unchanged. Volume retains its original 0–5
range for compatibility; settings UI synchronization does not emit persistence signals.
