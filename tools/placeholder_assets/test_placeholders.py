"""Checks for the placeholder generator (no Godot needed).

    python3 -m unittest discover -s tools/placeholder_assets -p "test_*.py"
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import placeholders as ph  # noqa: E402
import make_placeholders as cli  # noqa: E402

from PIL import Image  # noqa: E402


class PlaceholderTests(unittest.TestCase):
    def setUp(self):
        self.palette = ph.load_palette("midnight")
        self.temp = tempfile.TemporaryDirectory()
        self.dir = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_every_kit_palette_loads(self):
        names = sorted(p.stem for p in ph.PALETTE_DIR.glob("*.tres"))
        self.assertTrue(names)
        for name in names:
            palette = ph.load_palette(name)
            self.assertEqual(len(palette.outline), 4, name)
        self.assertTrue((ph.PALETTE_DIR / f"{ph.active_palette_name()}.tres").exists())

    def test_every_type_draws_at_every_size(self):
        for kind in ph.TYPES:
            for size in (8, 16, 32, 64):
                image = ph.draw(kind, self.palette, size, 0, kind)
                self.assertEqual(image.size, (size, size), kind)
                self.assertIsNotNone(image.getbbox(), f"{kind} at {size}px is empty")
        for shape in ph.ICON_SHAPES:
            self.assertIsNotNone(ph.draw("icon", self.palette, 16, 0, "i", shape).getbbox(), shape)

    def test_deterministic_and_animated(self):
        for kind in ph.TYPES:
            a = ph.draw(kind, self.palette, 32, 0, "same").tobytes()
            self.assertEqual(a, ph.draw(kind, self.palette, 32, 0, "same").tobytes(), kind)
            if kind != "tile":  # tiles are static; everything else animates
                self.assertTrue(a != ph.draw(kind, self.palette, 32, 1, "same").tobytes(), f"{kind} frames should differ")

    def test_real_art_is_never_overwritten(self):
        art = self.dir / "hero.png"
        Image.new("RGBA", (8, 8), (255, 0, 0, 255)).save(art)  # "real" art: no marker
        before = art.read_bytes()
        self.assertFalse(ph.save(ph.draw("character", self.palette), art))
        self.assertEqual(art.read_bytes(), before)
        self.assertTrue(ph.save(ph.draw("character", self.palette), art, force=True))
        self.assertTrue(ph.is_placeholder(art))
        # A placeholder is regenerated freely.
        self.assertTrue(ph.save(ph.draw("enemy", self.palette), art))

    def test_frame_paths(self):
        self.assertEqual(ph.frame_paths("a/b.png", 1), [Path("a/b.png")])
        self.assertEqual(ph.frame_paths("a/b.png", 2), [Path("a/b_1.png"), Path("a/b_2.png")])
        self.assertEqual(ph.frame_paths("a/b-{frame}.png", 2), [Path("a/b-1.png"), Path("a/b-2.png")])

    def test_manifest_and_cli(self):
        manifest = self.dir / "assets.json"
        out = (self.dir / "out").as_posix()
        manifest.write_text(json.dumps({"palette": "ocean", "assets": [
            {"type": "flyer", "name": "bat", "size": 16, "frames": 2, "out": out + "/bat.png"},
            {"type": "icon", "name": "coin", "shape": "coin", "out": out + "/coin.png"},
        ]}), encoding="utf-8")
        self.assertEqual(cli.main(["--manifest", str(manifest)]), 0)
        for name in ("bat_1.png", "bat_2.png", "coin.png"):
            path = self.dir / "out" / name
            self.assertTrue(path.exists() and ph.is_placeholder(path), name)
        with Image.open(self.dir / "out" / "bat_1.png") as image:
            self.assertEqual(image.size, (16, 16))
        with self.assertRaises(SystemExit):
            cli.main([])


if __name__ == "__main__":
    unittest.main()
