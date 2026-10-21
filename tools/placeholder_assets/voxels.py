"""Voxel models -> isometric pixel sprites, in the project's palette.

Small 3D grids of materials projected into a 2:1 isometric view. Light,
outlines and rotations come for free, so a structure in four facings, or a
prop with level / evolution variants, is one model instead of many drawings.

  - one voxel is a (2u x 2u) block on screen: a 2u x u top rhombus over two
    u x u sides; x steps (+u, +u/2), y steps (-u, +u/2), z steps (0, -u).
    u is 2 (32 px sprites) or 4 (64 px);
  - each material is a three-tone ramp (top, +y face, +x face) built from
    the active UI palette's roles (`body`, `accent`, `success`...), so the
    voxels match the menus and every kit palette works;
  - painter's order with a depth buffer: a dark inner line where a part
    stands well in front of what is behind it, a highlight on top edges
    facing the sky, then an outline around the silhouette;
  - `turned(facing)` rotates a model to N / E / S / W (models face E, +x);
  - decals pin pixel details to a 3D point (an orb, a spark, a cross) for
    what a voxel is too coarse to draw.

Models are Python (see BUILTIN) or JSON, kept in the game:

    {"parts": [
        {"box": [0, 0, 0, 3, 3, 2], "material": "body"},
        {"cylinder": [1.5, 1.5, 1.3, 3, 4], "material": "metal"},
        {"dome": [1.5, 1.5, 5, 1.6], "material": "accent"},
        {"ring": [1.5, 1.5, 6, 2.2, 1.4], "material": "metal"},
        {"voxel": [1, 1, 7], "material": "danger"},
        {"decal": "orb", "at": [1.5, 1.5, 9], "color": "accent"}
    ]}

Used by make_placeholders.py (type "voxel"); importable for custom tools.
"""
from __future__ import annotations

import json
from pathlib import Path

try:
    from PIL import Image
except ImportError as error:  # pragma: no cover - environment guard
    raise SystemExit("Pillow is required: pip install pillow") from error

import placeholders as ph

RGBA = tuple[int, int, int, int]
FACINGS = ("N", "E", "S", "W")
DECAL_KINDS = ("orb", "spark", "cross")


# --- Materials -------------------------------------------------------------------

def _darker(color: RGBA, palette: ph.ArtPalette, t: float) -> RGBA:
    return ph._mix(color, palette.outline, t)


def materials(palette: ph.ArtPalette) -> dict[str, tuple[RGBA, RGBA, RGBA]]:
    """Material name -> (top, left = +y face, right = +x face). The light comes
    from the top-left: top brightest, +y mid, +x darkest."""
    def ramp(color: RGBA) -> tuple[RGBA, RGBA, RGBA]:
        return (color, _darker(color, palette, 0.3), _darker(color, palette, 0.55))
    return {
        "body": (palette.light, palette.body, palette.shade),
        "dark": (palette.body, palette.shade, palette.outline),
        "metal": (palette.shine, palette.light, palette.body),
        "accent": ramp(palette.accent),
        "secondary": ramp(palette.secondary),
        "danger": ramp(palette.danger),
        "success": ramp(palette.success),
        "warning": ramp(palette.warning),
        "glow": (palette.shine, palette.accent, palette.accent),
    }


# --- Models -----------------------------------------------------------------------

class Model:
    """A sparse voxel model: {(x, y, z): material}; x / y on the ground grid
    (x -> screen down-right, y -> screen down-left), z up."""

    def __init__(self) -> None:
        self.voxels: dict[tuple[int, int, int], str] = {}
        self.decals: list[tuple[float, float, float, str, dict]] = []

    def set(self, x: int, y: int, z: int, material: str) -> "Model":
        self.voxels[(int(x), int(y), int(z))] = material
        return self

    def box(self, x0, y0, z0, x1, y1, z1, material: str) -> "Model":
        for x in range(int(x0), int(x1) + 1):
            for y in range(int(y0), int(y1) + 1):
                for z in range(int(z0), int(z1) + 1):
                    self.set(x, y, z, material)
        return self

    def cylinder(self, cx, cy, radius, z0, z1, material: str) -> "Model":
        for x in range(int(cx - radius) - 1, int(cx + radius) + 2):
            for y in range(int(cy - radius) - 1, int(cy + radius) + 2):
                if (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius + 0.25:
                    for z in range(int(z0), int(z1) + 1):
                        self.set(x, y, z, material)
        return self

    def dome(self, cx, cy, z0, radius, material: str, squash: float = 1.15) -> "Model":
        r = int(radius) + 1
        for x in range(int(cx) - r, int(cx) + r + 2):
            for y in range(int(cy) - r, int(cy) + r + 2):
                for z in range(int(z0), int(z0) + r + 2):
                    if (x - cx) ** 2 + (y - cy) ** 2 + ((z - z0) * squash) ** 2 <= radius * radius:
                        self.set(x, y, z, material)
        return self

    def ring(self, cx, cy, z, r_out, r_in, material: str) -> "Model":
        for x in range(int(cx - r_out) - 1, int(cx + r_out) + 2):
            for y in range(int(cy - r_out) - 1, int(cy + r_out) + 2):
                d = (x - cx) ** 2 + (y - cy) ** 2
                if r_in * r_in <= d <= r_out * r_out + 0.25:
                    self.set(x, y, z, material)
        return self

    def decal(self, x, y, z, kind: str, **params) -> "Model":
        if kind not in DECAL_KINDS:
            raise ValueError(f"unknown decal {kind!r}; choose one of {', '.join(DECAL_KINDS)}")
        self.decals.append((x, y, z, kind, params))
        return self

    def center(self) -> tuple[float, float]:
        """Middle of the footprint (the turning axis)."""
        xs = [x for x, _, _ in self.voxels] or [0]
        ys = [y for _, y, _ in self.voxels] or [0]
        return ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)

    def turned(self, facing: str, center: tuple[float, float] | None = None) -> "Model":
        """This model (built facing E, +x) turned to `facing` about `center`."""
        if facing not in FACINGS:
            raise ValueError(f"facing must be one of {FACINGS}")
        cx, cy = center or self.center()
        turn = {"E": lambda x, y: (x, y), "S": lambda x, y: (cx - (y - cy), cy + (x - cx)),
                "W": lambda x, y: (2 * cx - x, 2 * cy - y), "N": lambda x, y: (cx + (y - cy), cy - (x - cx))}[facing]
        out = Model()
        for (x, y, z), material in self.voxels.items():
            nx, ny = turn(x, y)
            out.set(round(nx), round(ny), z, material)
        for x, y, z, kind, params in self.decals:
            nx, ny = turn(x, y)
            out.decals.append((nx, ny, z, kind, params))
        return out


def from_json(data: dict | str | Path) -> Model:
    """A model from a dict, a JSON string or a .json path (see the module doc)."""
    if isinstance(data, Path) or (isinstance(data, str) and data.strip().endswith(".json")):
        data = json.loads(Path(data).read_text(encoding="utf-8"))
    elif isinstance(data, str):
        data = json.loads(data)
    model = Model()
    for part in data.get("parts", []):
        material = part.get("material", "body")
        if "box" in part: model.box(*part["box"], material)
        elif "cylinder" in part: model.cylinder(*part["cylinder"], material)
        elif "dome" in part: model.dome(*part["dome"], material)
        elif "ring" in part: model.ring(*part["ring"], material)
        elif "voxel" in part: model.set(*part["voxel"], material)
        elif "decal" in part:
            params = {k: v for k, v in part.items() if k not in ("decal", "at")}
            model.decal(*part["at"], part["decal"], **params)
        else: raise ValueError(f"unknown model part: {part}")
    return model


# --- Built-in models (placeholder structures) ---------------------------------------

def _base(model: Model, size: int = 4, height: int = 3) -> Model:
    model.box(0, 0, 0, size - 1, size - 1, height - 1, "body")
    for x in range(size): model.set(x, size - 1, 0, "warning")  # an accent rim on the front edge
    return model


def turret() -> Model:
    """A base, a drum and a barrel pointing E (+x): turn it for each facing."""
    m = _base(Model())
    m.cylinder(1.5, 1.5, 1.3, 3, 3, "dark")
    m.box(1, 1, 4, 2, 2, 4, "metal")
    m.box(1, 1, 5, 5, 1, 5, "dark")
    m.set(5, 1, 5, "danger")
    return m


def pylon() -> Model:
    """A base, a column, an emitter ring and a glowing orb."""
    m = _base(Model())
    m.box(1, 1, 3, 2, 2, 6, "metal")
    m.ring(1.5, 1.5, 7, 2.1, 1.4, "metal")
    m.decal(1.5, 1.5, 9.5, "orb", radius=4, color="accent")
    return m


def crate() -> Model:
    """A wooden-looking crate with a darker band."""
    m = Model()
    m.box(0, 0, 0, 3, 3, 3, "secondary")
    m.box(0, 0, 1, 3, 3, 1, "dark")
    return m


def tank() -> Model:
    """A base with a dome tank and a service light."""
    m = _base(Model())
    m.dome(1.5, 1.5, 3, 2.5, "metal")
    m.decal(1.5, 1.5, 5.6, "cross", color="success")
    return m


BUILTIN = {"turret": turret, "pylon": pylon, "crate": crate, "tank": tank}


# --- Rendering --------------------------------------------------------------------------

INNER_EDGE_DEPTH = 2.5


def render(model: Model, palette: ph.ArtPalette, size: int = 32, unit: int | None = None) -> Image.Image:
    """The model on a `size` x `size` canvas, centred, standing on its bottom row."""
    unit = unit or (2 if size < 48 else 4)
    if unit not in (2, 4):
        raise ValueError("unit must be 2 or 4 (the iso steps must land on whole pixels)")
    mats = materials(palette)
    pad = size * 2
    w = h = size + pad * 2
    color = [[None] * w for _ in range(h)]
    depth = [[-1e9] * w for _ in range(h)]
    top_face = [[False] * w for _ in range(h)]
    half = unit // 2
    for (x, y, z), material in sorted(model.voxels.items(), key=lambda i: (i[0][0] + i[0][1], i[0][2], i[0][0])):
        if material not in mats:
            raise ValueError(f"unknown material {material!r}; choose one of {', '.join(mats)}")
        top, left, right = mats[material]
        sx = pad + (x - y) * unit
        sy = pad + (x + y) * half - z * unit
        d = x + y + z
        if not (0 <= sx and sx + unit * 2 <= w and 0 <= sy and sy + unit * 2 <= h):
            raise ValueError(f"model reaches voxel {(x, y, z)}: too far out for a {size} px sprite")
        for r in range(unit):  # top rhombus, widening
            for px in range(sx + unit - (r + 1), sx + unit + (r + 1)):
                color[sy + r][px] = top; depth[sy + r][px] = d; top_face[sy + r][px] = True
        for r in range(unit, unit * 2):  # the two sides
            for px in range(sx, sx + unit):
                color[sy + r][px] = left; depth[sy + r][px] = d; top_face[sy + r][px] = False
            for px in range(sx + unit, sx + unit * 2):
                color[sy + r][px] = right; depth[sy + r][px] = d; top_face[sy + r][px] = False
    lighter = lambda c: ph._mix(c, palette.shine, 0.35)
    final = [row[:] for row in color]
    for py in range(1, h):
        for px in range(w):
            if color[py][px] is None: continue
            if top_face[py][px] and (color[py - 1][px] is None or depth[py - 1][px] < depth[py][px] - INNER_EDGE_DEPTH):
                final[py][px] = lighter(color[py][px])
            for nx, ny in ((px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)):
                if 0 <= nx < w and 0 <= ny < h and color[ny][nx] is not None and depth[ny][nx] < depth[py][px] - INNER_EDGE_DEPTH:
                    final[ny][nx] = palette.outline
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pixels = canvas.load()
    for py in range(h):
        for px in range(w):
            if final[py][px] is not None: pixels[px, py] = final[py][px]
    for x, y, z, kind, params in model.decals:
        cx = round(pad + (x - y) * unit + unit)
        cy = round(pad + (x + y) * half - z * unit + half)
        _DECALS[kind](pixels, cx, cy, palette, unit, w, h, **params)
    canvas = _outline(canvas, palette.outline)
    box = canvas.getbbox()
    if box is None:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sprite = canvas.crop(box)
    if sprite.width > size or sprite.height > size:
        raise ValueError(f"model is {sprite.width}x{sprite.height} px: too big for a {size} px sprite (try a bigger size or unit 2)")
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(sprite, ((size - sprite.width) // 2, size - sprite.height))
    return out


def _outline(image: Image.Image, color: RGBA) -> Image.Image:
    src = image.load()
    out = image.copy()
    dst = out.load()
    w, h = image.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3]: continue
            if any(0 <= nx < w and 0 <= ny < h and src[nx, ny][3] for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
                dst[x, y] = color
    return out


def _role(palette: ph.ArtPalette, name: str) -> RGBA:
    return getattr(palette, name)


def _put(pixels, w, h, x, y, color) -> None:
    if 0 <= x < w and 0 <= y < h: pixels[x, y] = color


def _decal_orb(pixels, cx, cy, palette, unit, w, h, radius=3, color="accent") -> None:
    fill = _role(palette, color)
    shade = _darker(fill, palette, 0.4)
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if dx * dx + dy * dy <= radius * radius + radius * 0.6:
                _put(pixels, w, h, cx + dx, cy + dy, shade if dx + dy > radius * 0.7 else fill)
    for dx, dy in ((-1, -1), (-1, -2), (-2, -1)): _put(pixels, w, h, cx + dx, cy + dy, palette.shine)


def _decal_spark(pixels, cx, cy, palette, unit, w, h, color="danger") -> None:
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (0, -2)): _put(pixels, w, h, cx + dx, cy + dy, _role(palette, color))


def _decal_cross(pixels, cx, cy, palette, unit, w, h, color="success") -> None:
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)): _put(pixels, w, h, cx + dx, cy + dy, _role(palette, color))


_DECALS = {"orb": _decal_orb, "spark": _decal_spark, "cross": _decal_cross}


def model_for(spec: str | dict) -> Model:
    """A built-in name, a .json path (relative to the kit root) or a dict."""
    if isinstance(spec, dict): return from_json(spec)
    if spec in BUILTIN: return BUILTIN[spec]()
    path = Path(spec)
    if not path.is_absolute(): path = ph.KIT_ROOT / path
    if path.exists(): return from_json(path)
    raise ValueError(f"unknown voxel model {spec!r}: a built-in ({', '.join(BUILTIN)}) or a .json path")
