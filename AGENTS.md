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

## Probes: check behaviour instead of guessing

- To learn what the game does (focus order, whether an action works, a value
  over time, how a screen looks), write a probe in `game/probes/<question>.gd`
  extending `SceneProbe` and run it with
  `python3 tools/probe/run_probe.py --godot <Godot> game/probes/<question>.gd`.
  Read `tools/probe/README.md` first. For a first look at a scene, use the
  smoke probe: `--scene res://... --seconds 2`.
- Never run game scenes, saves or probes directly against the project or
  the developer's user data. Always go through `run_probe.py`; it isolates
  user data, and the runner refuses to start otherwise. Never edit
  `override.cfg` or storage paths to get around it.
- Drive the game through player input (`tap_action`, `key`, `joy_button`,
  `click_control`), and observe through the scene (`find`, `focus_path`,
  `snapshot`). Use `check()` for what must hold and `record()` for numbers to
  compare between runs. Seed randomness (`seed(n)`) so reruns match.
- Run headless by default. Add `--windowed` only for screenshots or rendering
  questions; headless runs skip screenshots and record why. Look at the
  screenshots you take before you describe the result.
- Report the summary line and the relevant records to the user, with failures
  quoted. Keep probes that answered a lasting question as regression checks.
  Promote one to `tests/` only when it guards something that must never break.
- After changing the probe kit, run
  `python3 -m unittest discover -s tools/probe -p "test_*.py"` and the full
  suite, which runs the example probe.

## Assets: placeholders when no art or asset pack is given

- When a task needs sprites (characters, enemies, flyers, structures, tiles, projectiles, icons) and the user supplied no art and named no asset pack, generate placeholders with `tools/placeholder_assets/make_placeholders.py` instead of drawing ad-hoc shapes in code, leaving an empty `Sprite2D`, or inventing a third-party pack. Read `tools/placeholder_assets/README.md` first.
- If the user names an asset pack or provides art, use that; placeholders are only the fallback. Never download packs or assets without being asked.
- List the game's placeholders in a manifest (`game/placeholders.json`) and generate from it, so they can be regenerated and later replaced one by one. Keep them under `assets/placeholders/<type>/` with stable names; code references those paths so real art can be dropped in at the same path without code changes.
- Never pass `--force` unless the user asks to replace real art: the tool keeps any file without its placeholder marker, which protects art already in place.
- Placeholders use the project palette (the one `ui/theme/theme_config.tres` selects); don't hardcode other colors for them. Import new PNGs (`godot --headless --import` or open the editor) and use nearest filtering for pixel art.
- For isometric structures and props (towers, turrets, buildings, crates), prefer the `voxel` type: describe the piece as a small voxel model (a built-in like `turret`, or a JSON in `game/voxels/`) and generate it, instead of hand-placing pixels. Light, outlines and the four facings come from the model, so rotations and variants stay consistent. Keep models in the game (not in `tools/`) and list them in the manifest.
- Tell the user which assets are placeholders and where to drop the real files. Run `python3 -m unittest discover -s tools/placeholder_assets -p "test_*.py"` after changing the generator.
