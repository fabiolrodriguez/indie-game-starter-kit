# Theme + Palette

## Select a palette

Open `ui/theme/theme_config.tres` in the Godot Inspector. Set **Palette** to a resource
from `ui/theme/palettes/`: Midnight (default), Forest, Ocean, Crimson, Amber or
Monochrome. Save the resource. This is the single selection point; the project-wide
Theme updates existing controls in the editor and at runtime. No player setting is
written. Amber is a light palette; the others have distinct dark surface families.

Open `ui/theme/preview/theme_preview.tscn` and press F6 for the developer gallery.
Its selector changes only that preview. Assign its optional **Custom Palette** in
the Inspector to include your own resource in the gallery.

## Create a palette

Duplicate an existing palette with a new filename, or create a `UIPalette` resource.
Edit its semantic colors in the Inspector, save it, then select it in `theme_config.tres`.
Changing a palette affects every Theme referencing that resource. Duplicate it first
if you want an independent variation.

## Import HEX

Create a `.hex` or `.txt` file containing exactly five six-digit RGB colors in this
order: **background, surface, surface_alt, primary, text_primary**. Prefix `#` is
optional; separate colors with newlines, spaces or commas. Example:

```text
#0f172a
#1e293b
#334155
#38bdf8
#f8fafc
```

From the repository root, after importing/opening the project in Godot:

```sh
godot --headless --path . --script res://ui/theme/tools/import_palette.gd -- /path/to/colors.hex res://ui/theme/palettes/custom.tres "My palette"
```

The importer derives supporting roles, checks 4.5:1 text contrast against all three
surfaces, rejects invalid input and refuses to overwrite an existing file. It never
selects the result automatically. Fine-tune the resulting Resource in the Inspector.
The five-role order is deliberate: arbitrary downloaded swatch lists need arranging
before import. Alpha, GPL and remote services are not supported.

## Semantic roles and style

- `background`, `surface`, `surface_alt`: page and layered surfaces.
- `primary`, `secondary`, `accent`: emphasis; `focus`: keyboard/controller indication.
- `text_primary`, `text_secondary`, `text_disabled`, `border`: content and structure.
- `success`, `warning`, `danger`: status meaning; `overlay`: modal scrim with alpha.

`UIPalette` contains only colors. `UIVisualStyle` supplies typography, spacing, borders,
state rules and generated icons. `indie_style.tres` configures the supplied visual
style; future styles can implement `build(palette)` with the same palette data.
Primary-button text is derived for contrast. Body text uses Godot's bundled fallback
font; headings retain the supplied pixel font. Both can be replaced in the style.

## Consume the shared Theme

`menu_theme.tres` is generated output; do not edit or save its individual style boxes.
New Controls inherit it through Project Settings → GUI → Theme → Custom. Use theme
type variations such as `PrimaryButton`, `BackButton`, `Title`, `MutedLabel`,
`SuccessLabel`, `WarningLabel`, `DangerLabel`, `Backdrop` and `PauseOverlay`.
For custom drawing, read semantic values with `get_theme_color("accent", "Palette")`
and redraw on theme changes. Use `focus_slider.gd` on HSliders for a visible focus ring.
Game UI may extend the Theme; avoid node color overrides and duplicated style boxes.
The gallery's swatches are data visualization, not styling overrides.

Validation: `python3 tests/run_tests.py --godot /path/to/Godot`.
Add `--screenshots /tmp/theme-shots` for rendered UI captures (requires a display).
