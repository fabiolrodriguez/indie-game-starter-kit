#!/usr/bin/env python3
"""Generate placeholder sprites for a prototype, in the project's palette.

One asset:
    python3 tools/placeholder_assets/make_placeholders.py enemy slime --size 16 --frames 2
    python3 tools/placeholder_assets/make_placeholders.py icon coin --shape coin

Isometric structures / props from a voxel model (built-in or a JSON in the
game), in one or more facings:
    python3 tools/placeholder_assets/make_placeholders.py voxel cannon --model turret --facings N,E,S,W
    python3 tools/placeholder_assets/make_placeholders.py voxel crate --model game/voxels/crate.json

Every asset a game needs, from a manifest (regenerate it any time):
    python3 tools/placeholder_assets/make_placeholders.py --manifest game/placeholders.json

Files go to assets/placeholders/<type>/<name>.png by default (multi-frame
assets: <name>_1.png, <name>_2.png...). Real art dropped at the same path is
never overwritten; the tool skips it and says so. See README.md here.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import placeholders as ph  # noqa: E402
import voxels  # noqa: E402

KINDS = ph.TYPES + ("voxel",)

DEFAULT_ROOT = ph.KIT_ROOT / "assets" / "placeholders"


def generate(entry: dict, palette: ph.ArtPalette, force: bool = False, root: Path = DEFAULT_ROOT) -> list[tuple[Path, bool]]:
    """Draws one manifest entry; returns [(path, written)]."""
    kind = entry["type"]
    name = entry["name"]
    size = int(entry.get("size", 32))
    frames = int(entry.get("frames", 1))
    out = entry.get("out") or str(root / kind / f"{name}.png")
    if not Path(out).is_absolute():
        out = str(ph.KIT_ROOT / out)
    results = []
    if kind == "voxel":
        model = voxels.model_for(entry.get("model") or name)
        facings = entry.get("facings") or ["E"]
        if isinstance(facings, str): facings = [f.strip() for f in facings.split(",") if f.strip()]
        for facing in facings:
            image = voxels.render(model.turned(facing), palette, size, entry.get("unit"))
            results.append((facing_path(out, facing, len(facings)), ph.save(image, facing_path(out, facing, len(facings)), force)))
        return results
    for frame, path in enumerate(ph.frame_paths(out, frames)):
        image = ph.draw(kind, palette, size, frame, name, entry.get("shape"))
        results.append((path, ph.save(image, path, force)))
    return results


def facing_path(out: str, facing: str, count: int) -> Path:
    """`out` for one facing; with several, "{facing}" in it or "_N", "_E"...
    before the extension."""
    if "{facing}" in out: return Path(out.replace("{facing}", facing))
    if count <= 1: return Path(out)
    base = Path(out)
    return base.with_name(f"{base.stem}_{facing}{base.suffix}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("type", nargs="?", choices=KINDS, help="what to draw")
    parser.add_argument("name", nargs="?", help="asset name (also seeds its variation)")
    parser.add_argument("--size", type=int, default=32, help="square size in px (default 32)")
    parser.add_argument("--frames", type=int, default=1, help="animation frames (default 1)")
    parser.add_argument("--shape", help=f"tile: iso|square; icon: {'|'.join(ph.ICON_SHAPES)}")
    parser.add_argument("--out", help="output path (use {frame} for frame numbers, {facing} for voxel facings)")
    parser.add_argument("--model", help=f"voxel: a built-in ({'|'.join(voxels.BUILTIN)}) or a model .json")
    parser.add_argument("--facings", help="voxel: comma list of N,E,S,W (default E)")
    parser.add_argument("--unit", type=int, choices=(2, 4), help="voxel: pixels per voxel step (default 2 below 48 px, else 4)")
    parser.add_argument("--manifest", type=Path, help="JSON list of assets to generate")
    parser.add_argument("--palette", help="palette name in ui/theme/palettes (default: the one theme_config.tres selects)")
    parser.add_argument("--force", action="store_true", help="also overwrite files that are not placeholders (real art!)")
    args = parser.parse_args(argv)

    palette = ph.load_palette(args.palette)
    if args.manifest:
        data = json.loads(args.manifest.read_text(encoding="utf-8"))
        entries = data["assets"] if isinstance(data, dict) else data
        if isinstance(data, dict) and data.get("palette") and not args.palette:
            palette = ph.load_palette(data["palette"])
    elif args.type and args.name:
        entries = [{"type": args.type, "name": args.name, "size": args.size, "frames": args.frames, "shape": args.shape, "out": args.out,
                    "model": args.model, "facings": args.facings, "unit": args.unit}]
    else:
        parser.error("give a type and a name, or --manifest")

    skipped = 0
    for entry in entries:
        for path, written in generate(entry, palette, args.force):
            shown = path.relative_to(ph.KIT_ROOT) if path.is_relative_to(ph.KIT_ROOT) else path
            if written:
                print(f"placeholder  {shown}")
            else:
                skipped += 1
                print(f"kept (real art, not a placeholder)  {shown}")
    if skipped:
        print(f"{skipped} file(s) kept: they are not placeholders. Use --force only to replace real art on purpose.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
