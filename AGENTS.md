# Working on this starter kit

- Inspect `ARCHITECTURE.md`, existing managers, scenes and callers before adding infrastructure.
- Reuse the autoloads in `core/`; never recreate save, audio, settings, input, pause or scene systems in game code or scenes.
- Keep reusable UI in `ui/`. Existing scenes retain their paths under `scenes/`.
- Put game-specific rules and composition in `game/`; optional reusable behaviors belong in `components/`.
- Core must not assume a genre, player, combat, inventory or levels. Prefer small composed systems over large managers.
- Preserve keyboard/controller navigation, focus restoration and localization, including live language changes.
- Reuse `ui/theme/menu_theme.tres`; select the Palette in `ui/theme/theme_config.tres`. Use UIPalette semantic roles and shared Theme variations, never hardcoded UI colors. Game UI may extend the theme; read `ui/theme/README.md` first.
- Palette selection is developer configuration, never player settings/save data. Keep the gallery/import tools outside the player flow.
- Preserve existing `user://settings.cfg` and `user://savegame.cfg` formats; never write sample saves during startup.
- Validate with Godot 4.6+ and `python3 tests/run_tests.py --godot /path/to/Godot`. Tests use a temporary project and isolated user data.
