"""Checks for the voxel sprite renderer (no Godot needed).

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
import voxels as vx  # noqa: E402
import make_placeholders as cli  # noqa: E402

from PIL import Image  # noqa: E402


class VoxelTests(unittest.TestCase):
    def setUp(self):
        self.palette = ph.load_palette("midnight")
        self.temp = tempfile.TemporaryDirectory()
        self.dir = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_builtins_render_in_every_palette(self):
        for name in sorted(p.stem for p in ph.PALETTE_DIR.glob("*.tres")):
            palette = ph.load_palette(name)
            for model in vx.BUILTIN:
                for size in (32, 64):
                    image = vx.render(vx.BUILTIN[model](), palette, size)
                    self.assertEqual(image.size, (size, size), model)
                    box = image.getbbox()
                    self.assertIsNotNone(box, f"{model} {name} {size}")
                    self.assertEqual(box[3], size, f"{model} stands on the bottom row")

    def test_colours_come_from_the_palette_roles(self):
        roles = set(vars(self.palette).values())
        ramps = {c for ramp in vx.materials(self.palette).values() for c in ramp}
        allowed = roles | ramps | {ph._mix(c, self.palette.shine, 0.35) for c in roles | ramps} | {vx._darker(self.palette.accent, self.palette, 0.4)}
        image = vx.render(vx.pylon(), self.palette)
        used = {px for px in image.getdata() if px[3]}
        self.assertTrue(used <= allowed, sorted(used - allowed)[:4])
        self.assertIn(self.palette.outline, used, "outlined")

    def test_deterministic_and_turns(self):
        a = vx.render(vx.turret(), self.palette).tobytes()
        self.assertEqual(a, vx.render(vx.turret(), self.palette).tobytes())
        self.assertEqual(a, vx.render(vx.turret().turned("E"), self.palette).tobytes(), "models face E")
        faces = {f: vx.render(vx.turret().turned(f), self.palette).tobytes() for f in vx.FACINGS}
        self.assertEqual(len(set(faces.values())), 4, "four distinct facings")
        # Turning four times comes back.
        m = vx.turret()
        for _ in range(4): m = m.turned("S")
        self.assertEqual(set(m.voxels), set(vx.turret().voxels))
        with self.assertRaises(ValueError):
            vx.turret().turned("NE")

    def test_json_models(self):
        spec = {"parts": [
            {"box": [0, 0, 0, 3, 3, 2], "material": "body"},
            {"cylinder": [1.5, 1.5, 1.2, 3, 4], "material": "metal"},
            {"dome": [1.5, 1.5, 5, 1.4], "material": "accent"},
            {"ring": [1.5, 1.5, 4, 2.2, 1.6], "material": "dark"},
            {"voxel": [3, 3, 3], "material": "danger"},
            {"decal": "spark", "at": [1.5, 1.5, 8], "color": "warning"},
        ]}
        path = self.dir / "beacon.json"
        path.write_text(json.dumps(spec), encoding="utf-8")
        a = vx.render(vx.model_for(str(path)), self.palette)
        self.assertEqual(a.tobytes(), vx.render(vx.from_json(spec), self.palette).tobytes())
        self.assertIn(self.palette.warning, set(a.getdata()), "the decal is drawn")
        with self.assertRaises(ValueError):
            vx.from_json({"parts": [{"pyramid": [0, 0, 0]}]})
        with self.assertRaises(ValueError):
            vx.render(vx.Model().set(0, 0, 0, "plutonium"), self.palette)
        with self.assertRaises(ValueError):
            vx.model_for("no_such_model")

    def test_too_big_is_an_error_not_a_crop(self):
        tower = vx.Model().box(0, 0, 0, 1, 1, 20, "body")
        with self.assertRaises(ValueError):
            vx.render(tower, self.palette, 32)
        self.assertEqual(vx.render(tower, self.palette, 64, unit=2).size, (64, 64))
        with self.assertRaises(ValueError):
            vx.render(vx.Model().box(0, 0, 0, 0, 0, 200, "body"), self.palette, 32)  # never wraps around

    def test_manifest_facings_and_real_art(self):
        out = (self.dir / "out").as_posix()
        manifest = self.dir / "assets.json"
        manifest.write_text(json.dumps({"assets": [
            {"type": "voxel", "name": "cannon", "model": "turret", "facings": ["N", "E", "S", "W"], "out": out + "/cannon.png"},
            {"type": "voxel", "name": "crate", "out": out + "/crate.png"},
            {"type": "voxel", "name": "beacon", "model": "pylon", "facings": "E,W", "out": out + "/beacon-{facing}.png"},
        ]}), encoding="utf-8")
        art = self.dir / "out" / "cannon_N.png"
        art.parent.mkdir(parents=True)
        Image.new("RGBA", (8, 8), (255, 0, 0, 255)).save(art)  # real art: no marker
        self.assertEqual(cli.main(["--manifest", str(manifest)]), 0)
        for name in ("cannon_E.png", "cannon_S.png", "cannon_W.png", "crate.png", "beacon-E.png", "beacon-W.png"):
            path = self.dir / "out" / name
            self.assertTrue(path.exists() and ph.is_placeholder(path), name)
        self.assertFalse(ph.is_placeholder(art), "real art kept")
        self.assertEqual(cli.main(["voxel", "tank", "--size", "64", "--out", out + "/tank.png"]), 0)
        with Image.open(self.dir / "out" / "tank.png") as image:
            self.assertEqual(image.size, (64, 64))


if __name__ == "__main__":
    unittest.main()
