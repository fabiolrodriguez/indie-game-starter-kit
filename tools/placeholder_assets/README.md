# Placeholder assets

Temporary pixel-art sprites for prototyping, so a game can be built and
played before its real art exists. They are drawn from the project's UI
palette (`ui/theme/palettes/`, the one `ui/theme/theme_config.tres` selects),
so placeholders already match the menus.

Requires Python 3.9+ and Pillow (`pip install pillow`). No Godot needed.

## What it draws

| Type | Looks like | Frames |
| --- | --- | --- |
| `character` | a small hero (head, body, eyes) | idle bob |
| `enemy` | a horned blob with danger-coloured cheeks | squish |
| `flyer` | a body between two wings, its shadow far below | wings up/down |
| `structure` | an isometric block with a turret, pylon or tank on top (picked by name) | light blinks |
| `tile` | ground: `--shape iso` (diamond, default) or `--shape square` | static |
| `projectile` | a glowing shot with a trail | glow pulses |
| `icon` | `--shape heart\|coin\|star\|shield\|sword\|gear` | sparkle |

Any square size from 8 px (16, 24, 32 and 48 read best). The same name and
options always draw the same image, and the name also picks small variations
(colour, structure top), so `slime` and `goblin` don't look identical.

## Use

One asset:

```sh
python3 tools/placeholder_assets/make_placeholders.py enemy slime --size 24 --frames 2
python3 tools/placeholder_assets/make_placeholders.py icon coin --shape coin --size 16
```

Every asset a game needs, from a manifest kept in the game (recommended):

```sh
python3 tools/placeholder_assets/make_placeholders.py --manifest game/placeholders.json
```

```json
{
  "palette": "midnight",
  "assets": [
    {"type": "character", "name": "hero", "size": 32, "frames": 2},
    {"type": "icon", "name": "coin", "size": 16, "shape": "coin"},
    {"type": "tile", "name": "floor", "size": 16, "shape": "square",
     "out": "assets/placeholders/tile/floor.png"}
  ]
}
```

See `example_manifest.json` for every type. Output defaults to
`assets/placeholders/<type>/<name>.png`; animated assets are `<name>_1.png`,
`<name>_2.png`... (or put `{frame}` in `out`). Open the editor, or run
`godot --headless --import`, so Godot imports the new PNGs. Pixel art wants
nearest filtering (Project Settings → Rendering → Textures → Default Texture
Filter: Nearest, or `texture_filter` on the node).

## Replacing placeholders with real art

Drop the real file at the same path, with the same name: nothing in the game
changes. Every generated PNG carries a `placeholder` marker, and the tool only
overwrites files that have it, so regenerating never touches real art (it
prints "kept (real art…)"). `--force` overrides that; use it only on purpose.

## Tests

```sh
python3 -m unittest discover -s tools/placeholder_assets -p "test_*.py"
```

## Extending

`placeholders.py` is importable: `load_palette()`, `draw(kind, palette, size,
frame, name, shape)` and `save(image, path)`. Add a shape as a function there
and register it in `DRAW` / `TYPES`; keep it readable at 16 px, palette-only,
deterministic, and cover it in the tests.
