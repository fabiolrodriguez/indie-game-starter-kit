# Starter Kit 2.0

## Boundaries

`core/` contains generic infrastructure. `ui/` contains menu scripts and the shared
Theme. Existing scene paths/UIDs in `scenes/` are preserved. `game/` is the extension
point for each game's rules and composition; `components/` is reserved for optional,
genre-neutral behaviors. No gameplay is supplied.

The Starter Kit provides genre-agnostic infrastructure. Gameplay systems belong to
individual projects in `game/`; repeated real use may justify extracting a separate
reusable component library. The kit is not a generalized game engine.

## Autoloads (one instance each)

| System | Responsibility / extension point |
| --- | --- |
| AudioManager | UI sounds/generic `play_sfx(stream)` on SFX and `play_bgm(stream)` on Music, including while paused. Applies native bus volumes. |
| LocalizationManager | Translation dictionaries, English fallback, `language_changed`; extend `translations` before opening menus. |
| SettingsManager | Load/apply/save display, Master/Music/SFX volumes and language in the existing settings file; UI calls setters. Owns resolution options. |
| SaveManager | Generic section/key data in the existing save file; explicit load/save/reset. Save/reset return errors. Games own their schema and when to persist. |
| ControlsManager | Descriptions from InputMap; `set_controls_data()` accepts action entries or legacy label/value entries. Does not implement gameplay input or remapping. |
| PauseManager | Sole writer of SceneTree pause, with `set_paused()`, `toggle()`, `pause_changed`. No input or scene paths. |
| SceneManager | `change_scene(path, options = null)` validates, fades, replaces and reveals; rejects concurrent requests, unpauses on successful replacement. |
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
The main menu's controls list scrolls as games add binding descriptions. Its focused
scroll bar uses Up/Down; Left, Tab or Cancel leave it without trapping controller focus.

SceneManager returns an immediate error or OK (request accepted). Observe
`transition_started(path)`, `transition_finished(scene)` and `transition_failed(path,error)`.
Hooks are notifications: started fires with input already blocked; finished fires
after the new scene is ready, revealed and input restored. Invalid requests retain the
current scene and pause state. Successful transitions preserve GameSession; games
explicitly end/reset it. Dictionary values can be mutable; use `snapshot()` for a copy.

SceneManager owns one persistent `ui/transitions/fade_overlay.tscn` child. The overlay
only presents a fullscreen fade and temporarily disables root viewport input, preserving
focus and prior input state. It runs while paused and ignores time scale. Use SceneManager
for every scene change; extend this presenter rather than adding gameplay overlays.
`ui/transitions/fade_options.tres` configures duration per fade (default 0.22 seconds),
active semantic palette `background` or explicit opaque color, and `skip_visual`.
Pass a new `SceneTransitionOptions` for a single request; options are sampled at acceptance.
Busy requests return `ERR_BUSY`. Validation precedes covering; replacement failures
reveal the original scene before emitting failed. Shutdown cancels the tween and releases
input. Loading is synchronous; input polling via `Input` and scene processing continue.
Gameplay that polls input should gate actions on `SceneManager.is_transitioning`.
Non-finite fade durations fall back to an immediate transition.

## Styling and persistence

`ui/theme/theme_config.tres` is the single developer configuration resource.
`ui/theme/menu_theme.tres` is the minimal script-backed project-wide Theme
(`gui/theme/custom`). Styles/icons are generated in memory. Its `PaletteTheme` tool script rebuilds when configuration,
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

Audio uses `default_bus_layout.tres`: Music and SFX both send to Master. Route game
music players to `Music` and effects to `SFX`; native bus settings then apply without
gameplay volume calculations. AudioManager's `set_master_volume()`, `set_music_volume()`
and `set_sfx_volume()` apply linear 0–5 values to buses without persistence. Zero mutes
the bus with a finite dB floor; a positive value unmutes it. Music selection and
special mixing remain game responsibilities.

Settings and save filenames/sections are unchanged. All three volumes retain the
original 0–5 range and default to 1.0; settings UI synchronization does not emit persistence signals.
SettingsManager's corresponding setters save/apply immediately. `reset_audio_volumes()`
returns the save error and restores/applies only these three defaults; the Settings
button also synchronizes the sliders. SFX adjustment plays one UI click on mouse/key/controller release.
The legacy `volume` property and `set_volume()` remain aliases for Master. Old files
load `volume` when `master_volume` is absent; missing Music/SFX keys default to 1.0,
preserving existing output. New saves write `master_volume`, `music_volume`, `sfx_volume`
and the legacy `volume` key. If both Master keys exist, `master_volume` takes precedence.
Successful reloads replace the loaded ConfigFile rather than merging old sections.
Missing/corrupt files return an error (`false` for save loading) and preserve the last
good in-memory state. Missing settings keys use defaults; invalid/non-finite volumes
use 1.0. Settings setters retain automatic save/apply behavior; `save()` returns the
disk error. Saves load only when game code requests it. Session values are never saved
implicitly; call `start()` for a fresh session and `finish()` to clear it.

## Developer Showcase

Open `ui/showcase/developer_showcase.tscn` in Godot and click Run Current Scene
(F6 on Windows/Linux, Cmd+R on macOS). This development-only
reference composes the existing theme gallery, real manager state, ControlsManager
bindings and PauseMenu. Use the navigation buttons with mouse, keyboard or controller.
Foundation actions preview UI sounds/music, temporary localization, pause, default
scene fade and the real Main Menu (including Settings/Controls). Run Current Scene opens the showcase
again; no player-facing entry point or new autoload exists. Language/music previews
restore on exit. Save/session state is inspected without mutation, and previews never
write settings or saves. Real Main Menu settings retain their normal persistence.
The palette selector affects only the embedded gallery; configuration and transitions
continue to use `theme_config.tres`. Native scrolling/stacked cards handle smaller
windows. Showcase, gallery, CLI tools and tests are excluded from the export preset.
