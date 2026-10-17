"""Placeholder pixel-art sprites for prototyping, in the project's palette.

Shapes that read at a glance (a character, an enemy, a flyer, an isometric
structure, a ground tile, a projectile, a few icons), drawn from the active
UI palette so temporary art already matches the menus. Deterministic: the
same name and options always draw the same image.

Every PNG carries a "placeholder" text chunk. `save()` only ever replaces
files that carry it, so real art dropped at the same path is never
overwritten (unless `force=True`).

Used by make_placeholders.py; importable for custom generators.
"""
from __future__ import annotations

import hashlib
import math
import re
from dataclasses import dataclass
from pathlib import Path

try:
    from PIL import Image, ImageDraw
    from PIL.PngImagePlugin import PngInfo
except ImportError as error:  # pragma: no cover - environment guard
    raise SystemExit("Pillow is required: pip install pillow") from error

KIT_ROOT = Path(__file__).resolve().parents[2]
PALETTE_DIR = KIT_ROOT / "ui" / "theme" / "palettes"
THEME_CONFIG = KIT_ROOT / "ui" / "theme" / "theme_config.tres"
MARKER_KEY = "placeholder"
MARKER_VALUE = "indie-game-starter-kit"
TYPES = ("character", "enemy", "flyer", "structure", "tile", "projectile", "icon")
ICON_SHAPES = ("heart", "coin", "star", "shield", "sword", "gear")

RGBA = tuple[int, int, int, int]


# --- Palette -----------------------------------------------------------------

@dataclass
class ArtPalette:
    """The UIPalette's semantic roles, mapped to art roles."""
    outline: RGBA
    shade: RGBA
    body: RGBA
    light: RGBA
    shine: RGBA
    accent: RGBA
    secondary: RGBA
    danger: RGBA
    success: RGBA
    warning: RGBA


def _parse_color(text: str) -> RGBA:
    values = [float(v) for v in re.findall(r"[-\d.]+", text)]
    r, g, b = (max(0, min(255, round(v * 255))) for v in values[:3])
    return (r, g, b, 255)


def _hex(text: str) -> RGBA:
    text = text.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16), 255)


def active_palette_name() -> str:
    """The palette ui/theme/theme_config.tres selects ("midnight" if unknown)."""
    if THEME_CONFIG.exists():
        match = re.search(r'path="res://ui/theme/palettes/([a-z0-9_]+)\.tres"', THEME_CONFIG.read_text(encoding="utf-8"))
        if match:
            return match.group(1)
    return "midnight"


def load_palette(name: str | None = None, path: Path | None = None) -> ArtPalette:
    """Reads a UIPalette .tres (by name from ui/theme/palettes/ or by path)."""
    source = path or PALETTE_DIR / f"{name or active_palette_name()}.tres"
    roles = {}
    for line in source.read_text(encoding="utf-8").splitlines():
        match = re.match(r"\s*([a-z_]+)\s*=\s*Color\((.*)\)", line)
        if match:
            roles[match.group(1)] = _parse_color(match.group(2))
    missing = {"background", "border", "primary", "secondary", "accent", "text_primary", "danger", "success", "warning"} - set(roles)
    if missing:
        raise ValueError(f"{source} lacks palette roles: {sorted(missing)}")
    # UI palettes are built around a background; sprites need mid-tones that
    # read on it, so the body sits between the border and the primary color.
    return ArtPalette(
        outline=roles["background"], shade=roles["border"], body=_mix(roles["border"], roles["primary"], 0.5),
        light=roles["primary"], shine=roles["text_primary"], accent=roles["accent"],
        secondary=roles["secondary"], danger=roles["danger"], success=roles["success"], warning=roles["warning"])


def _mix(a: RGBA, b: RGBA, t: float) -> RGBA:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def palette_from_hex(colors: list[str]) -> ArtPalette:
    """Ten HEX colors in ArtPalette field order (outline ... warning)."""
    if len(colors) != 10:
        raise ValueError("palette_from_hex needs 10 colors: outline shade body light shine accent secondary danger success warning")
    return ArtPalette(*(_hex(c) for c in colors))


# --- Drawing helpers -----------------------------------------------------------

def _rng(name: str) -> int:
    """A stable number from the asset name (variation without randomness)."""
    return int(hashlib.sha1(name.encode("utf-8")).hexdigest()[:8], 16)


def _canvas(size: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def _s(size: int, value: float) -> int:
    """`value` on a 32px grid, scaled to `size`."""
    return round(value * size / 32)


def _box(size: int, x0, y0, x1, y1) -> tuple[int, int, int, int]:
    return (_s(size, x0), _s(size, y0), max(_s(size, x0), _s(size, x1) - 1), max(_s(size, y0), _s(size, y1) - 1))


def _pts(size: int, points) -> list[tuple[int, int]]:
    return [(_s(size, x), _s(size, y)) for x, y in points]


# --- Shapes ----------------------------------------------------------------------

def character(p: ArtPalette, size: int, frame: int, name: str) -> Image.Image:
    """A small hero: head, body, two eyes; frames bob up and down (idle)."""
    image, d = _canvas(size)
    bob = 1 if frame % 2 else 0
    tint = (p.light, p.secondary, p.accent)[_rng(name) % 3]
    d.ellipse(_box(size, 9, 26, 23, 30), fill=p.shade)                                   # shadow
    d.rounded_rectangle(_box(size, 10, 15 + bob, 22, 27), radius=_s(size, 3), fill=tint, outline=p.outline)
    d.ellipse(_box(size, 9, 4 + bob, 23, 17 + bob), fill=p.shine, outline=p.outline)
    for x in (13, 18):
        d.rectangle(_box(size, x, 9 + bob, x + 2, 12 + bob), fill=p.outline)
    return image


def enemy(p: ArtPalette, size: int, frame: int, name: str) -> Image.Image:
    """A hostile blob with horns and danger-coloured eyes; frames squish."""
    image, d = _canvas(size)
    squish = 1 if frame % 2 else 0
    d.ellipse(_box(size, 5, 25, 27, 30), fill=p.shade)
    hide = _mix(p.shade, p.danger, 0.6)
    d.polygon(_pts(size, [(9, 12), (7, 3), (13, 9)]), fill=p.light, outline=p.outline)
    d.polygon(_pts(size, [(23, 12), (25, 3), (19, 9)]), fill=p.light, outline=p.outline)
    d.ellipse(_box(size, 5, 8 + squish, 27, 28), fill=hide, outline=p.outline)
    d.ellipse(_box(size, 8, 18 + squish, 24, 26), fill=p.danger)
    for x in (10, 18):
        d.rectangle(_box(size, x, 13 + squish, x + 4, 17 + squish), fill=p.shine)
        d.rectangle(_box(size, x + 1, 14 + squish, x + 2, 16 + squish), fill=p.outline)
    d.line(_pts(size, [(12, 22 + squish), (20, 22 + squish)]), fill=p.outline, width=max(1, _s(size, 1.5)))
    return image


def flyer(p: ArtPalette, size: int, frame: int, name: str) -> Image.Image:
    """A flying unit: a body between wings that flap up/down per frame."""
    image, d = _canvas(size)
    up = frame % 2 == 0
    wing_y = 8 if up else 16
    for side in (-1, 1):
        tip = 16 + side * 14
        d.polygon(_pts(size, [(16 + side * 4, 14), (tip, wing_y), (tip, wing_y + 5), (16 + side * 4, 19)]), fill=p.light, outline=p.outline)
    d.ellipse(_box(size, 10, 9, 22, 23), fill=p.body, outline=p.outline)
    d.rectangle(_box(size, 14, 13, 18, 16), fill=p.danger)
    d.ellipse(_box(size, 12, 27, 20, 30), fill=p.shade)                                  # shadow far below: it flies
    return image


def structure(p: ArtPalette, size: int, frame: int, name: str) -> Image.Image:
    """An isometric block with a tower on top; its light blinks on odd frames."""
    image, d = _canvas(size)
    d.polygon(_pts(size, [(16, 19), (28, 24), (16, 29), (4, 24)]), fill=p.light, outline=p.outline)    # top
    d.polygon(_pts(size, [(4, 24), (16, 29), (16, 32), (4, 27)]), fill=p.body, outline=p.outline)      # left face
    d.polygon(_pts(size, [(16, 29), (28, 24), (28, 27), (16, 32)]), fill=p.shade, outline=p.outline)   # right face
    variant = _rng(name) % 3
    if variant == 0:      # turret
        d.rectangle(_box(size, 11, 11, 21, 24), fill=p.body, outline=p.outline)
        d.rectangle(_box(size, 19, 7, 27, 11), fill=p.shine, outline=p.outline)
    elif variant == 1:    # pylon
        d.rectangle(_box(size, 13, 8, 19, 24), fill=p.secondary, outline=p.outline)
        d.ellipse(_box(size, 10, 2, 22, 11), fill=p.accent, outline=p.outline)
    else:                 # tank
        d.rectangle(_box(size, 9, 10, 23, 24), fill=p.shade, outline=p.outline)
        d.ellipse(_box(size, 9, 7, 23, 13), fill=p.body, outline=p.outline)
    light = p.warning if frame % 2 else p.accent
    d.rectangle(_box(size, 15, 20, 17, 22), fill=light)
    return image


def tile(p: ArtPalette, size: int, frame: int, name: str, shape: str = "iso") -> Image.Image:
    """A ground tile ("iso" diamond or "square") with a few stable specks."""
    image, d = _canvas(size)
    seed = _rng(name)
    if shape == "square":
        d.rectangle((0, 0, size - 1, size - 1), fill=p.body, outline=p.outline)
        area = (2, 2, size - 3, size - 3)
    else:
        d.polygon(_pts(size, [(16, 8), (31, 16), (16, 24), (1, 16)]), fill=p.body, outline=p.outline)
        area = (_s(size, 8), _s(size, 13), _s(size, 24), _s(size, 19))
    for i in range(6):
        x = area[0] + (seed >> (i * 3)) % max(1, area[2] - area[0])
        y = area[1] + (seed >> (i * 5 + 1)) % max(1, area[3] - area[1])
        d.point((x, y), fill=p.light if i % 2 else p.shade)
    return image


def projectile(p: ArtPalette, size: int, frame: int, name: str) -> Image.Image:
    """A glowing shot with a short trail; the glow pulses per frame."""
    image, d = _canvas(size)
    glow = 2 if frame % 2 else 0
    d.line(_pts(size, [(4, 16), (18, 16)]), fill=p.secondary, width=max(1, _s(size, 3)))
    d.ellipse(_box(size, 15 - glow, 11 - glow, 27 + glow, 21 + glow), fill=p.accent)
    d.ellipse(_box(size, 18, 14, 24, 18), fill=p.shine)
    return image


def icon(p: ArtPalette, size: int, frame: int, name: str, shape: str = "star") -> Image.Image:
    """A pickup/UI icon: heart, coin, star, shield, sword or gear."""
    image, d = _canvas(size)
    if shape == "heart":
        d.ellipse(_box(size, 5, 7, 17, 19), fill=p.danger, outline=p.outline)
        d.ellipse(_box(size, 15, 7, 27, 19), fill=p.danger, outline=p.outline)
        d.polygon(_pts(size, [(6, 15), (26, 15), (16, 27)]), fill=p.danger, outline=p.outline)
        d.rectangle(_box(size, 9, 10, 12, 13), fill=p.shine)
    elif shape == "coin":
        d.ellipse(_box(size, 6, 5, 26, 27), fill=p.warning, outline=p.outline)
        d.ellipse(_box(size, 10, 9, 22, 23), outline=p.outline)
        d.rectangle(_box(size, 15, 12, 17, 20), fill=p.shine)
    elif shape == "shield":
        d.polygon(_pts(size, [(6, 6), (26, 6), (26, 16), (16, 28), (6, 16)]), fill=p.secondary, outline=p.outline)
        d.rectangle(_box(size, 15, 9, 17, 22), fill=p.shine)
        d.rectangle(_box(size, 10, 13, 22, 15), fill=p.shine)
    elif shape == "sword":
        d.polygon(_pts(size, [(22, 4), (27, 4), (27, 9), (13, 23), (8, 18)]), fill=p.light, outline=p.outline)
        d.line(_pts(size, [(7, 16), (15, 24)]), fill=p.warning, width=max(1, _s(size, 3)))
        d.line(_pts(size, [(6, 25), (10, 21)]), fill=p.outline, width=max(1, _s(size, 3)))
    elif shape == "gear":
        for i in range(8):
            x = 16 + round(11 * math.cos(i * 0.785))
            y = 16 + round(11 * math.sin(i * 0.785))
            d.rectangle(_box(size, x - 2, y - 2, x + 2, y + 2), fill=p.body, outline=p.outline)
        d.ellipse(_box(size, 7, 7, 25, 25), fill=p.body, outline=p.outline)
        d.ellipse(_box(size, 12, 12, 20, 20), fill=p.outline)
    else:  # star
        d.polygon(_pts(size, [(16, 3), (20, 12), (29, 12), (22, 18), (25, 28), (16, 22), (7, 28), (10, 18), (3, 12), (12, 12)]), fill=p.warning, outline=p.outline)
    if frame % 2:  # a sparkle on odd frames (pickups that twinkle)
        d.rectangle(_box(size, 24, 3, 26, 5), fill=p.shine)
    return image


DRAW = {"character": character, "enemy": enemy, "flyer": flyer, "structure": structure,
        "tile": tile, "projectile": projectile, "icon": icon}


def draw(kind: str, palette: ArtPalette, size: int = 32, frame: int = 0, name: str = "", shape: str | None = None) -> Image.Image:
    """One frame of a placeholder of `kind` (see TYPES)."""
    if kind not in DRAW:
        raise ValueError(f"unknown type {kind!r}; choose one of {', '.join(TYPES)}")
    if size < 8:
        raise ValueError("size must be at least 8 px")
    if kind in ("tile", "icon") and shape:
        return DRAW[kind](palette, size, frame, name or kind, shape)
    return DRAW[kind](palette, size, frame, name or kind)


# --- Saving ---------------------------------------------------------------------

def is_placeholder(path: Path) -> bool:
    """Whether the PNG at `path` was made by this tool (carries its marker)."""
    try:
        with Image.open(path) as image:
            return image.info.get(MARKER_KEY) == MARKER_VALUE
    except (OSError, ValueError):
        return False


def save(image: Image.Image, path: Path, force: bool = False) -> bool:
    """Writes `image` with the placeholder marker. Never replaces a file that
    isn't a placeholder (real art) unless `force`. Returns whether it wrote."""
    path = Path(path)
    if path.exists() and not force and not is_placeholder(path):
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    info = PngInfo()
    info.add_text(MARKER_KEY, MARKER_VALUE)
    image.save(path, pnginfo=info)
    return True


def frame_paths(out: str, frames: int) -> list[Path]:
    """`out` for one frame; with several, "{frame}" in it (1-based) or
    "_1", "_2"... before the extension."""
    if frames <= 1:
        return [Path(out.replace("{frame}", "1"))]
    if "{frame}" in out:
        return [Path(out.replace("{frame}", str(i + 1))) for i in range(frames)]
    base = Path(out)
    return [base.with_name(f"{base.stem}_{i + 1}{base.suffix}") for i in range(frames)]
