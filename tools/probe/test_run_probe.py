"""Checks for the probe runner's mirror and sandbox (no Godot needed).

    python3 -m unittest discover -s tools/probe -p "test_*.py"
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_probe as rp  # noqa: E402


class ProbeRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        base = Path(self.temp.name)
        self.source = base / "game"
        self.target = base / "workspace"
        (self.source / "core").mkdir(parents=True)
        (self.source / ".godot").mkdir()
        (self.source / ".godot" / "secret.cache").write_text("editor cache")
        (self.source / "project.godot").write_text("[application]\n")
        (self.source / "core" / "settings_manager.gd").write_text('const SETTINGS_PATH := "user://settings.cfg"\n')
        (self.source / "core" / "save_manager.gd").write_text('const SAVE_PATH := "user://savegame.cfg"\n')
        (self.source / "player.gd").write_text("extends Node\n")
        (self.source / "override.cfg").write_text("[developer]\nmine=true\n")
        self._root = rp.ROOT
        rp.ROOT = self.source

    def tearDown(self):
        rp.ROOT = self._root
        self.temp.cleanup()

    def test_mirror_copies_only_changes_and_removes_deleted(self):
        first = rp.sync(self.source, self.target)
        project = self.target / "project"
        self.assertTrue((project / "player.gd").exists())
        self.assertFalse((project / ".godot" / "secret.cache").exists(), "the source's .godot is never copied")
        self.assertFalse((project / "override.cfg").exists(), "the developer's override.cfg is never copied")
        self.assertEqual(len(first), 4)
        self.assertEqual(rp.sync(self.source, self.target), [], "nothing changed, nothing copied")
        time.sleep(1.1)
        (self.source / "player.gd").write_text("extends Node2D\n")
        self.assertEqual(rp.sync(self.source, self.target), [("player.gd", False)])
        (project / ".godot").mkdir()
        (project / ".godot" / "keep.cache").write_text("import cache")
        (self.source / "player.gd").unlink()
        rp.sync(self.source, self.target)
        self.assertFalse((project / "player.gd").exists(), "deleted in the source, deleted in the copy")
        self.assertTrue((project / ".godot" / "keep.cache").exists(), "the copy's import cache is kept")

    def test_isolation_redirects_storage_and_marks_the_copy(self):
        rp.sync(self.source, self.target)
        data = rp.isolate(self.target, windowed=True)
        project = self.target / "project"
        settings = (project / "core" / "settings_manager.gd").read_text()
        self.assertIn((data / "settings.cfg").as_posix(), settings)
        self.assertNotIn("user://", settings)
        self.assertIn((data / "savegame.cfg").as_posix(), (project / "core" / "save_manager.gd").read_text())
        override = (project / "override.cfg").read_text()
        self.assertIn("probe=true", override)
        self.assertIn(f'user_data_path="{data.as_posix()}"', override)
        self.assertIn("probe_pads_moved=true", override)
        # The source is untouched.
        self.assertIn("user://settings.cfg", (self.source / "core" / "settings_manager.gd").read_text())
        self.assertIn("mine=true", (self.source / "override.cfg").read_text())
        # A patched file isn't recopied while its source is unchanged...
        self.assertEqual(rp.sync(self.source, self.target), [])
        # ...and is recopied (then patched again) when the source changes.
        time.sleep(1.1)
        (self.source / "core" / "settings_manager.gd").write_text('const SETTINGS_PATH := "user://settings.cfg"\nvar x := 1\n')
        self.assertEqual(rp.sync(self.source, self.target), [("core/settings_manager.gd", False)])
        rp.isolate(self.target, windowed=False)
        self.assertIn((data / "settings.cfg").as_posix(), (project / "core" / "settings_manager.gd").read_text())
        self.assertIn("probe_pads_moved=false", (project / "override.cfg").read_text())

    def test_user_data_starts_empty_every_run(self):
        rp.sync(self.source, self.target)
        data = rp.isolate(self.target, windowed=False)
        (data / "savegame.cfg").write_text("left over")
        data = rp.isolate(self.target, windowed=False)
        self.assertEqual(list(data.iterdir()), [])

    def test_environment_points_user_data_at_the_sandbox(self):
        env = rp.environment(Path("/tmp/sandbox"))
        self.assertEqual(env["APPDATA"], str(Path("/tmp/sandbox")))
        self.assertEqual(env["XDG_DATA_HOME"], str(Path("/tmp/sandbox")))

    def test_import_only_when_needed(self):
        project = self.target / "project"
        (project / ".godot").mkdir(parents=True)
        self.assertTrue(rp.needs_import(project, []), "no class cache yet: first run")
        (project / ".godot" / "global_script_class_cache.cfg").write_text("")
        self.assertFalse(rp.needs_import(project, [("player.gd", False), ("level.tscn", True)]))
        self.assertTrue(rp.needs_import(project, [("art/hero.png", True)]))
        self.assertTrue(rp.needs_import(project, [("project.godot", False)]))
        (project / "new_class.gd").write_text("class_name Thing\nextends Node\n")
        self.assertTrue(rp.needs_import(project, [("new_class.gd", True)]))
        self.assertFalse(rp.needs_import(project, [("new_class.gd", False)]))

    def test_probe_paths(self):
        self.assertEqual(rp.res_path(self.source, "res://game/probes/a.gd"), "res://game/probes/a.gd")
        self.assertEqual(rp.res_path(self.source, str(self.source / "player.gd")), "res://player.gd")
        with self.assertRaises(SystemExit):
            rp.res_path(self.source, str(Path(self.temp.name) / "elsewhere.gd"))

    def test_workspace_is_outside_the_project_and_stable(self):
        a = rp.workspace_for(self.source)
        self.assertEqual(a, rp.workspace_for(self.source))
        self.assertFalse(str(a.resolve()).startswith(str(self.source.resolve())))


if __name__ == "__main__":
    unittest.main()
