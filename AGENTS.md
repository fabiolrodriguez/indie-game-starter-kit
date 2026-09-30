# Working on this starter kit

- Inspect `ARCHITECTURE.md`, existing managers, scenes and callers before adding infrastructure.
- Reuse the autoloads in `core/`; never recreate save, audio, settings, input, pause or scene systems in game code or scenes.
- Preserve the existing autoload set/order: Audio and Localization before Settings; Pause before SceneManager. Avoid new global services without a concrete architectural need.
- Keep reusable UI in `ui/`. Existing scenes retain their paths under `scenes/`.
- Put game-specific rules and composition in `game/`; optional reusable behaviors belong in `components/`.
- Core must not assume a genre, player, combat, inventory or levels. Prefer small composed systems over large managers.
- Preserve keyboard/controller navigation, focus restoration and localization, including live language changes.
- Reuse `ui/theme/menu_theme.tres`; select the Palette in `ui/theme/theme_config.tres`. Use UIPalette semantic roles and shared Theme variations, never hardcoded UI colors. Game UI may extend the theme; read `ui/theme/README.md` first.
- Keep `menu_theme.tres` a minimal script-backed resource; do not commit generated styles, icons or embedded font bytes into it.
- Palette selection is developer configuration, never player settings/save data. Keep the gallery/import tools outside the player flow.
- Use `SceneManager.change_scene(path, options)` for automatic transitions. Extend the reusable presenter in `ui/transitions/`; do not add scene-local fades. Gameplay that polls `Input` should check `SceneManager.is_transitioning`.
- Preserve existing `user://settings.cfg` and `user://savegame.cfg` formats; never write sample saves during startup.
- Validate with Godot 4.6+ and `python3 tests/run_tests.py --godot /path/to/Godot`. Tests use a temporary project and isolated user data.
