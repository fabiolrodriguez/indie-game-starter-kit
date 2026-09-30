#!/usr/bin/env python3
"""Run Godot checks in a disposable copy, never against a developer's user data."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', default='godot', help='Godot 4.6+ executable')
args = parser.parse_args()
source = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix='starter-kit-tests-') as temporary:
    root = Path(temporary)
    project = root / 'project'
    shutil.copytree(source, project, ignore=shutil.ignore_patterns('.git', '.godot', '__pycache__'))
    data = root / 'user-data'
    data.mkdir()
    # Redirect only storage constants in the disposable copy. Godot's custom
    # user directory is relative to OS app data, even with an absolute name.
    for filename, constant, storage in (
        ('settings_manager.gd', 'SETTINGS_PATH', 'settings.cfg'),
        ('save_manager.gd', 'SAVE_PATH', 'savegame.cfg'),
    ):
        script = project / 'core' / filename
        original = f'const {constant} := "user://{storage}"'
        replacement = f'const {constant} := "{(data / storage).as_posix()}"'
        content = script.read_text()
        if content.count(original) != 1:
            raise SystemExit(f'Cannot isolate storage in {filename}')
        script.write_text(content.replace(original, replacement))
    (project / 'override.cfg').write_text(
        f'\n[starter_kit]\ntesting=true\nuser_data_path="{data.as_posix()}"\n'
    )
    env = dict(os.environ, NO_COLOR='1')
    commands = [
        ('import', ['--editor', '--import', '--quit']),
        ('startup', ['--quit-after', '120']),
        ('foundation', ['res://tests/foundation_test.tscn']),
    ]
    for name, extra in commands:
        command = [args.godot, '--headless', '--max-fps', '60', '--path', str(project),
                   '--log-file', str(root / f'{name}.log'), *extra]
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, env=env, timeout=90)
        print(f'[{name}]\n{result.stdout}', flush=True)
        if result.returncode or 'ERROR:' in result.stdout or 'SCRIPT ERROR:' in result.stdout:
            raise SystemExit(result.returncode or 1)
    if not (data / 'settings.cfg').is_file():
        raise SystemExit('Isolated persistence file was not created')
    print('All isolated checks passed.')
