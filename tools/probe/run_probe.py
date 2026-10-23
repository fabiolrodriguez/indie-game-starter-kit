#!/usr/bin/env python3
"""Run a SceneProbe against an isolated copy of this Godot project.

    python3 tools/probe/run_probe.py --godot /path/to/Godot game/probes/my_probe.gd
    python3 tools/probe/run_probe.py --godot ... --scene res://scenes/main_menu/main_menu.tscn --seconds 2 --windowed

The project is mirrored into a persistent workspace outside the repository
(only changed files are copied, and Godot's import cache is kept, so the
second run starts in seconds). User data is redirected into that workspace,
the kit's save/settings paths are pointed there too, and the probe runner
refuses to start if any of that failed: a probe never touches the
developer's real saves or settings.

Prints the probe's own PROBE_* lines and errors, then a summary; the full
result is <out>/result.json (screenshots next to it) and the whole Godot log
is <out>/godot.log. Exit code: 0 all checks passed, 1 a check failed or the
probe errored, 2 the probe could not run.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
SMOKE = "res://tools/probe/probes/smoke.gd"
SKIP_DIRS = {".git", ".godot", "__pycache__", ".import", ".probe"}
# The kit's storage constants, pointed at the sandbox in the copy: user://
# redirection through the environment covers Windows and Linux, this covers
# the rest (and the runner checks one of the two holds).
STORAGE = (
    ("core/settings_manager.gd", "SETTINGS_PATH", "settings.cfg"),
    ("core/save_manager.gd", "SAVE_PATH", "savegame.cfg"),
)
RUNNER = "res://tools/probe/probe_runner.tscn"


def workspace_for(project: Path) -> Path:
    """A stable folder per project checkout, outside it."""
    digest = hashlib.sha1(str(project.resolve()).encode()).hexdigest()[:10]
    return Path(tempfile.gettempdir()) / f"godot-probe-{project.name}-{digest}"


def _stamp(path: Path) -> list:
    stat = path.stat()
    return [stat.st_size, int(stat.st_mtime)]


def sync(source: Path, target: Path) -> list[tuple[str, bool]]:
    """Mirrors `source` into `target/project`, copying only what changed and
    removing what was deleted; keeps the copy's .godot (import cache). Files
    the sandbox patched count as unchanged while their source is.
    Returns the copied files as (relative path, was new)."""
    project = target / "project"
    project.mkdir(parents=True, exist_ok=True)
    manifest = target / "patched.json"
    patched = json.loads(manifest.read_text(encoding="utf-8")) if manifest.exists() else {}
    seen: set[Path] = set()
    copied: list[tuple[str, bool]] = []
    for folder, dirs, files in os.walk(source):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        rel_dir = Path(folder).relative_to(source)
        for name in files:
            rel = rel_dir / name
            if name == "override.cfg" and rel_dir == Path("."):
                continue  # the sandbox writes its own
            seen.add(rel)
            src, dst = source / rel, project / rel
            if dst.exists():
                if patched.get(rel.as_posix()) == _stamp(src) or _stamp(dst) == _stamp(src):
                    continue
            patched.pop(rel.as_posix(), None)
            existed = dst.exists()
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            copied.append((rel.as_posix(), not existed))
    for folder, dirs, files in os.walk(project):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        rel_dir = Path(folder).relative_to(project)
        for name in files:
            rel = rel_dir / name
            if rel == Path("override.cfg") or rel in seen:
                continue
            (project / rel).unlink()
    manifest.write_text(json.dumps(patched), encoding="utf-8")
    return copied


# Text Godot reads directly: changing one needs no reimport.
NO_IMPORT = {".gd", ".tscn", ".tres", ".cfg", ".md", ".json", ".py", ".txt", ".uid", ".import", ".csv", ".godot", ".gdshader"}


def needs_import(project: Path, copied: list[tuple[str, bool]]) -> bool:
    """Whether the copy must be (re)imported: first run, a changed asset, or
    a new class_name script (the global class cache)."""
    if not (project / ".godot" / "global_script_class_cache.cfg").exists():
        return True
    for rel, new in copied:
        suffix = Path(rel).suffix.lower()
        if suffix not in NO_IMPORT or rel == "project.godot":
            return True
        if suffix == ".gd" and new and "class_name" in (project / rel).read_text(encoding="utf-8", errors="replace"):
            return True
    return False


def isolate(target: Path, windowed: bool) -> Path:
    """Writes the sandbox markers and storage redirections into the copy.
    Returns the user-data folder."""
    project = target / "project"
    data = target / "user-data"
    if data.exists():
        shutil.rmtree(data)  # every run starts from empty user data
    data.mkdir(parents=True)
    manifest = target / "patched.json"
    patched = json.loads(manifest.read_text(encoding="utf-8")) if manifest.exists() else {}
    for rel, constant, storage in STORAGE:
        script = project / rel
        if not script.exists() or rel in patched:
            continue
        content = script.read_text(encoding="utf-8")
        original = f'const {constant} := "user://{storage}"'
        if original in content:
            script.write_text(content.replace(original, f'const {constant} := "{(data / storage).as_posix()}"'), encoding="utf-8")
            patched[rel] = _stamp(ROOT / rel)
    manifest.write_text(json.dumps(patched), encoding="utf-8")
    (project / "override.cfg").write_text(
        "\n[starter_kit]\nprobe=true\n"
        f'user_data_path="{data.as_posix()}"\n'
        f"probe_pads_moved={'true' if windowed else 'false'}\n",
        encoding="utf-8",
    )
    return data


def environment(data: Path) -> dict:
    """Points every platform's user-data root at the sandbox."""
    env = dict(os.environ, NO_COLOR="1")
    env["APPDATA"] = str(data)          # Windows
    env["XDG_DATA_HOME"] = str(data)    # Linux / BSD
    if sys.platform == "darwin":
        env["HOME"] = str(data)         # macOS user:// lives under HOME
    return env


def godot_command(godot: str, project: Path, probe: str, out: Path, args: argparse.Namespace, extra: list[str]) -> list[str]:
    command = [godot, "--path", str(project), "--fixed-fps", str(args.fps), "--log-file", str(out / "godot.log")]
    if not args.windowed:
        command.insert(1, "--headless")
    else:
        command += ["--rendering-method", args.renderer, "--audio-driver", "Dummy"]
    command += [RUNNER, "--", f"--probe={probe}", f"--out={out.as_posix()}", f"--fps={args.fps}",
                f"--max-game-seconds={args.max_game_seconds}", *extra]
    return command


# Godot's leak report at quit: shown as a warning, not counted as a failure
# (the probe quits cleanly; a leak there is the game's to look at).
BENIGN = ("instances were leaked at exit", "resources still in use at exit", "cleanup (core/object/object.cpp", "clear (core/io/resource.cpp")
# Lines that mean the probe can never start: stop waiting for it.
FATAL = ("Parse Error", "Compile Error", "Failed to load script")


def run_streaming(command: list[str], env: dict, timeout: float) -> tuple[str, int]:
    """Runs Godot, collecting its output; kills it on timeout, and a few
    seconds after a compile error (a probe that doesn't compile never quits)."""
    process = subprocess.Popen(command, env=env, text=True, encoding="utf-8", errors="replace",
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    lines: list[str] = []
    fatal_at = [None]

    def read() -> None:
        for line in process.stdout:
            lines.append(line.rstrip("\n"))
            if fatal_at[0] is None and any(marker in line for marker in FATAL):
                fatal_at[0] = time.monotonic()

    reader = threading.Thread(target=read, daemon=True)
    reader.start()
    started = time.monotonic()
    reason = ""
    while process.poll() is None:
        now = time.monotonic()
        if now - started > timeout:
            reason = f"killed after {timeout} s real time"
        elif fatal_at[0] is not None and now - fatal_at[0] > 3.0:
            reason = "a script failed to compile (see the errors above)"
        if reason:
            process.kill()
            break
        time.sleep(0.1)
    process.wait()
    reader.join(timeout=2)
    if reason:
        lines.append("PROBE_RESULT " + json.dumps({"ok": False, "failures": [reason]}))
    return "\n".join(lines), process.returncode


def res_path(project: Path, probe: str) -> str:
    """`probe` as a res:// path (accepts res://, or a file in the project)."""
    if probe.startswith("res://"):
        return probe
    path = Path(probe).resolve()
    try:
        return "res://" + path.relative_to(project.resolve()).as_posix()
    except ValueError:
        raise SystemExit(f"{probe} is not inside the project ({project})")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("probe", nargs="?", help="probe script (res:// or a path in the project); omit with --scene for the smoke probe")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"), help="Godot 4.6+ executable (or $GODOT)")
    parser.add_argument("--windowed", action="store_true", help="real window: screenshots and rendering costs (slower, real time)")
    parser.add_argument("--fps", type=int, default=60, help="fixed frames per game second (default 60)")
    parser.add_argument("--renderer", default="gl_compatibility", help="rendering method for --windowed")
    parser.add_argument("--out", help="result folder (default: <workspace>/out/<probe name>)")
    parser.add_argument("--timeout", type=float, default=300.0, help="real seconds before the run is killed")
    parser.add_argument("--max-game-seconds", type=float, default=600.0, help="game seconds before the probe is stopped")
    parser.add_argument("--scene", help="smoke probe: scene to open")
    parser.add_argument("--seconds", type=float, default=2.0, help="smoke probe: game seconds to run")
    parser.add_argument("--quiet", action="store_true", help="print only the summary")
    args, extra = parser.parse_known_args(argv)
    extra = [e for e in extra if e != "--"]
    if args.scene:
        extra += [f"--scene={args.scene}", f"--seconds={args.seconds}"]
    probe = args.probe or (SMOKE if args.scene else None)
    if probe is None:
        parser.error("give a probe script, or --scene for the smoke probe")
    probe = res_path(ROOT, probe)

    target = workspace_for(ROOT)
    copied = sync(ROOT, target)
    project = target / "project"
    data = isolate(target, args.windowed)
    out = Path(args.out).resolve() if args.out else target / "out" / Path(probe).stem
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    env = environment(data)
    if needs_import(project, copied):
        print("Importing the project copy (first run or changed assets)…", flush=True)
        subprocess.run([args.godot, "--headless", "--path", str(project), "--import"], env=env,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=args.timeout)
    command = godot_command(args.godot, project, probe, out, args, extra)
    output, code = run_streaming(command, env, args.timeout)
    summary = None
    errors = []
    for line in output.splitlines():
        if line.startswith("PROBE_RESULT "):
            summary = json.loads(line[len("PROBE_RESULT "):])
        elif any(marker in line for marker in BENIGN):
            if not args.quiet:
                print("warning (at quit): " + line.strip())
        elif "SCRIPT ERROR" in line or line.startswith("ERROR:") or line.startswith("   at:"):
            errors.append(line)
            if not args.quiet:
                print(line)
        elif not args.quiet and (line.startswith("PROBE") or line.startswith("WARNING:")):
            print(line)
    if summary is None:
        summary = {"ok": False, "failures": ["the probe printed no result (see godot.log)"]}
    if errors and summary.get("ok"):
        summary["ok"] = False
        summary.setdefault("failures", []).append(f"{len(errors)} engine/script error line(s) in the log")
    (out / "result.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    status = "OK" if summary.get("ok") else "FAILED"
    print(f"\n{status} {probe}  checks={summary.get('checks', 0)} failures={len(summary.get('failures', []))} "
          f"frames={summary.get('frames', 0)} game={summary.get('game_seconds', 0)}s real={summary.get('real_seconds', 0)}s")
    for failure in summary.get("failures", []):
        print(f"  - {failure}")
    for key, value in summary.get("records", {}).items():
        text = json.dumps(value, ensure_ascii=False) if not isinstance(value, str) else value
        print(f"  {key}: {text if len(text) < 400 else text[:400] + ' ...'}")
    for shot in summary.get("screenshots", []):
        print(f"  screenshot: {shot}")
    print(f"  result: {out / 'result.json'}\n  log: {out / 'godot.log'}")
    if not summary.get("probe"):
        return 2  # the runner refused or never started the probe
    return 0 if summary.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
