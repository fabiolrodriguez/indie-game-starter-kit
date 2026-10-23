# Probe kit: check what the game actually does

A **probe** is a short GDScript that drives the real game the way a player
would and reports back. It opens a scene, advances frames, presses actions,
reads nodes, takes screenshots and records findings. You write one when you
need to *know* something instead of guessing from the code:

- Does focus land on Start?
- Does the dash clear the gap?
- How many enemies are alive at second 30?
- What does the pause menu look like at 1280×720?

Probes are made for coding agents, and just as handy by hand.

```sh
python3 tools/probe/run_probe.py --godot /path/to/Godot game/probes/menu_focus.gd
```

Godot can also come from `$GODOT`. The run ends with one summary, and the
exit code says how it went:

```
OK res://game/probes/menu_focus.gd  checks=3 failures=0 frames=74 game=1.233s real=0.9s
  first_focus: /root/MainMenu/menu/MainPanel/MarginContainer/VBoxContainer/start
  result: /tmp/godot-probe-<project>-<id>/out/menu_focus/result.json
  log: /tmp/godot-probe-<project>-<id>/out/menu_focus/godot.log
```

| Exit code | Meaning |
|---|---|
| `0` | Every check passed. |
| `1` | A check failed, or the probe hit a script or engine error. |
| `2` | The probe could not run. |

## Why it is safe to run anytime

The runner never runs against the project folder or your user data:

1. **The project is mirrored into a workspace outside the repository**, in
   the system temp folder, one per checkout. Only files that changed are
   copied and Godot's import cache is kept, so after the first run a probe
   starts in a few seconds.
2. **User data is redirected into the workspace and emptied on every run.**
   `APPDATA` is redirected on Windows, `XDG_DATA_HOME` on Linux and `HOME` on
   macOS. The kit's own `settings.cfg` and `savegame.cfg` paths are also
   pointed there, in the copy only.
3. **`probe_runner` refuses to start** unless the copy is marked as a probe
   workspace and user data really resolves inside it. A probe can't read or
   write your saves, settings or anything else under `user://`.
4. **Windowed runs move every joypad binding to device 7**, so a controller
   plugged into the machine can't steer the game while a probe drives it.
   The probe's own `joy_button()` and `joy_axis()` use that device.

## Time is fixed

The runner starts Godot with `--fixed-fps 60`, or the value of `--fps`. Every
frame advances exactly 1/60 s of game time, and a headless run goes as fast
as the CPU allows. `seconds(5.0)` always means 300 frames: results don't depend
on the machine. If the game uses randomness, seed it in the probe (`seed(42)`)
so repeated runs match.

## Writing a probe

Probes for a game live in `game/probes/`. Each one extends `SceneProbe` and
overrides `run()`:

```gdscript
extends SceneProbe

func run() -> void:
    var level := await open("res://game/levels/level_1.tscn")
    var player := first("Player", level)
    var start: Vector2 = player.global_position
    await tap_action("move_right", 0.5)          # hold for half a second
    record("moved", player.global_position.x - start.x)
    check(player.global_position.x > start.x, "move_right moves the player")
    await wait_until(func(): return player.is_on_floor(), 2.0)
    await screenshot("after_move")               # needs --windowed
```

**Scenes and time**

| Call | What it does |
|---|---|
| `await open(path)` | Makes `path` the current scene, without a transition, and returns it after one frame. |
| `await frames(n)` / `await seconds(s)` | Advance the fixed clock. |
| `await wait_until(func, timeout)` | Waits until the callable returns true. Returns whether it did. |
| `await wait_signal(signal, timeout)` | Waits for a signal. Returns whether it fired. |

**Input**

All input goes through `Input.parse_input_event`, so `_input`, GUI focus and
`InputMap` actions all see it.

| Call | What it does |
|---|---|
| `await tap_action(action, hold)` | Presses an action for one frame, or holds it for `hold` seconds. |
| `await key(KEY_*, hold)` | Presses a keyboard key. |
| `await joy_button(JOY_BUTTON_*, hold)` | Presses a controller button. |
| `await joy_axis(JOY_AXIS_*, value, hold)` | Holds a stick axis, then centres it. |
| `await click(position)` / `await click_control(control)` | A left click at a viewport position, or at a Control's centre. |

**Reading the game**

| Call | What it does |
|---|---|
| `find(pattern, from)` / `first(pattern, from)` | Nodes whose name matches the pattern (`*` wildcards), or of that class, or in that group. |
| `tree_text(from, depth)` | The scene tree as text, with hidden and disabled states and labels. |
| `focused()` / `focus_path()` | The Control that has keyboard or controller focus. |
| `snapshot(node, ["position", "health"])` | Chosen properties as plain values. |
| `arg(name, fallback)` | A value passed after `--` (`-- --level=3`). |
| `is_headless()` | Whether the run has no window. |

**Findings**

| Call | What it does |
|---|---|
| `record(key, value)` | Adds a finding to the result. Nodes, vectors and colours become text. |
| `check(condition, message)` | A soft assertion: it is counted and listed, and the probe keeps going. |
| `fail(message)` | Records a failure. |
| `await screenshot(name)` | Saves `<out>/<name>.png`. Headless runs record why it was skipped. |

The result lands in `<out>/result.json` with:

- `ok`, `checks` and `failures`;
- `records` and `screenshots`;
- `frames`, `game_seconds` and `real_seconds`;
- `headless` and `user_data_dir`.

Pass `--out DIR` to choose the folder.

## No-code smoke probe

To see what a scene does before writing anything:

```sh
python3 tools/probe/run_probe.py --godot ... --scene res://scenes/main_menu/main_menu.tscn --seconds 2 --windowed
```

It opens the scene, runs it for the given seconds, and records:

- its tree, four levels deep (`-- --depth=6` for more);
- what has focus;
- a screenshot, when the run is windowed.

## Options

| Option | Default | Meaning |
|---|---|---|
| `--windowed` | off | Real window, rendering and screenshots. Slower, but still on the fixed clock. |
| `--fps N` | 60 | Fixed frames per game second. |
| `--renderer` | `gl_compatibility` | Rendering method for windowed runs. |
| `--out DIR` | workspace `out/<probe>` | Where `result.json`, screenshots and `godot.log` go. |
| `--timeout S` | 300 | Real seconds before the run is killed. |
| `--max-game-seconds S` | 600 | Game seconds before the probe is stopped. |
| `--quiet` | off | Print only the summary. |
| `-- --name=value` | | Values for the probe's `arg()`. |

## Good habits

- **One question per probe.** Name the file after the question
  (`dash_clears_gap.gd`) and keep it: it becomes a regression check you can
  rerun.
- **Use `check()` for what must hold and `record()` for what you want to
  see.** Numbers in `records` are what an agent should compare between runs.
- **Run headless by default.** Add `--windowed` only for screenshots or
  rendering questions.
- **Don't reach into private state** when the player-facing behaviour can be
  observed. Press the action and look at the result.
- **Probes are not the test suite.** Promote a probe to `tests/` when it
  guards something that must never break.
- `tools/*` and `game/probes/*` are excluded from player exports.

## Files

| File | Role |
|---|---|
| `run_probe.py` | CLI: workspace mirror, isolation, Godot launch, output parsing, summary. |
| `probe_runner.tscn` / `.gd` | Refuses to run outside the sandbox, loads the probe and keeps it under the root. |
| `scene_probe.gd` | `SceneProbe`, the base class with every helper above. |
| `probes/smoke.gd` | The no-code smoke probe. |
| `examples/menu_navigation.gd` | Example probe: menu focus, Settings opening and closing. `tests/run_tests.py` runs it. |
| `test_run_probe.py` | Unit tests for the mirror and the isolation, no Godot needed. |
