class_name SceneProbe
extends Node
## Base class for probes: short GDScript checks an agent (or you) writes to
## see what the game actually does, instead of guessing from the code. A probe
## opens scenes, advances frames on a fixed clock, sends input, reads nodes,
## takes screenshots and records findings; tools/probe/run_probe.py runs it in
## an isolated copy of the project and prints one PROBE_RESULT line.
##
##   extends SceneProbe
##   func run() -> void:
##       var menu := await open("res://scenes/main_menu/main_menu.tscn")
##       await tap_action("ui_down")
##       record("focused", focus_path())
##       check(focus_path().ends_with("load"), "ui_down moves to Load")
##       await screenshot("menu")
##
## The probe node lives under the root, beside the autoloads, so changing
## scenes never frees it. Every wait counts frames of the fixed clock the
## runner sets (--fixed-fps), so results don't depend on machine speed.

## The device injected joypad events use. The runner moves every joypad
## binding to this device in windowed runs, so a physical pad plugged into
## the machine can't steer the game while a probe drives it.
const PROBE_PAD_DEVICE := 7

var records := {}
var failures: Array[String] = []
var checks := 0
var screenshots: Array[String] = []
var frames_run := 0
var _out_dir := ""
var _fps := 60

## Override with the probe's steps (await freely).
func run() -> void:
	pass

# --- Scenes and time --------------------------------------------------------

## Opens `path` as the current scene (directly, no transition) and returns it
## once it is in the tree and has had one frame to settle.
func open(path: String) -> Node:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		fail("cannot open %s (error %d)" % [path, error])
		return null
	await get_tree().scene_changed
	await frames(1)
	return get_tree().current_scene

## Advances `count` frames of the fixed clock.
func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
		frames_run += 1

## Advances `duration` seconds of game time (at the runner's fixed fps).
func seconds(duration: float) -> void:
	await frames(maxi(1, ceili(duration * _fps)))

## Waits until `condition` returns true, at most `timeout` seconds of game
## time. Returns whether it happened.
func wait_until(condition: Callable, timeout := 10.0) -> bool:
	var limit := ceili(timeout * _fps)
	for i in limit:
		if condition.call(): return true
		await frames(1)
	return bool(condition.call())

## Waits for a signal, at most `timeout` seconds. Returns whether it fired.
func wait_signal(source: Signal, timeout := 10.0) -> bool:
	var fired := [false]
	var mark := func(_a = null, _b = null, _c = null, _d = null): fired[0] = true
	source.connect(mark, CONNECT_ONE_SHOT)
	var happened := await wait_until(func(): return fired[0], timeout)
	if not happened and source.is_connected(mark): source.disconnect(mark)
	return happened

# --- Input ------------------------------------------------------------------

## Presses an input action for `hold` seconds (0: one frame), through the
## event pipeline, so _input/_unhandled_input and GUI focus see it too.
func tap_action(action: StringName, hold := 0.0) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await _hold(hold)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)

func key(code: Key, hold := 0.0) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _hold(hold)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)

func joy_button(button: JoyButton, hold := 0.0) -> void:
	var event := InputEventJoypadButton.new()
	event.device = _pad_device()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _hold(hold)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)

## Holds a stick axis at `value` (-1..1) for `hold` seconds, then centres it.
func joy_axis(axis: JoyAxis, value: float, hold := 0.2) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = _pad_device()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	await seconds(hold)
	event = event.duplicate()
	event.axis_value = 0.0
	Input.parse_input_event(event)
	await frames(1)

## A left click at a viewport position.
func click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(1)

## Clicks the centre of a Control.
func click_control(control: Control) -> void:
	await click(control.get_global_rect().get_center())

## One frame, or `hold` seconds when given.
func _hold(hold: float) -> void:
	if hold > 0.0: await seconds(hold)
	else: await frames(1)

# --- Reading the game -------------------------------------------------------

## Nodes under `from` (default: the current scene) whose name matches
## `pattern` (String.match wildcards), or that are of class `pattern`, or in
## group `pattern`.
func find(pattern: String, from: Node = null) -> Array[Node]:
	var found: Array[Node] = []
	var start := from if from != null else get_tree().current_scene
	if start == null: return found
	var stack: Array[Node] = [start]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if String(node.name).match(pattern) or node.is_class(pattern) or node.is_in_group(pattern): found.append(node)
		for child in node.get_children(): stack.append(child)
	return found

func first(pattern: String, from: Node = null) -> Node:
	var found := find(pattern, from)
	return found[0] if not found.is_empty() else null

## The tree under `from` as indented text (name, class, visible/disabled
## state for Controls), `depth` levels deep.
func tree_text(from: Node = null, depth := 6) -> String:
	var start := from if from != null else get_tree().current_scene
	if start == null: return "(no scene)"
	var lines: PackedStringArray = []
	_tree_lines(start, 0, depth, lines)
	return "\n".join(lines)

## The Control that has keyboard/controller focus, and its path.
func focused() -> Control:
	return get_viewport().gui_get_focus_owner()

func focus_path() -> String:
	var control := focused()
	return str(control.get_path()) if control != null else ""

## Chosen properties of a node as a plain dictionary (for record()).
func snapshot(node: Node, properties: Array) -> Dictionary:
	var result := {}
	if node == null: return result
	for property in properties: result[property] = _plain(node.get(property))
	return result

## A command-line value given to the probe (`--name=value` after `--`).
func arg(name: String, fallback := "") -> String:
	for token in OS.get_cmdline_user_args():
		if token.begins_with("--%s=" % name): return token.split("=", true, 1)[1]
	return fallback

func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"

# --- Findings ---------------------------------------------------------------

## Keeps a finding for the result (plain values: numbers, text, arrays,
## dictionaries; nodes and vectors are converted).
func record(key: String, value: Variant) -> void:
	records[key] = _plain(value)

## A soft assertion: the probe keeps running and the result lists it.
func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition: fail(message)
	return condition

func fail(message: String) -> void:
	failures.append(message)
	print("PROBE_FAIL ", message)

## Saves the viewport as <out>/<name>.png. Needs a window (run_probe.py
## --windowed): a headless run draws no pixels, so it records why instead.
func screenshot(name: String) -> String:
	if is_headless():
		record("screenshot_" + name, "skipped: headless run (use --windowed)")
		return ""
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _out_dir.path_join(name + ".png")
	if image == null or image.save_png(path) != OK:
		fail("screenshot %s could not be saved" % name)
		return ""
	screenshots.append(path)
	return path

# --- Runner hooks -----------------------------------------------------------

var _done := false

## Called by probe_runner once the probe is in the tree: runs it, enforces the
## game-time limit, writes <out>/result.json and prints PROBE_RESULT.
func _launch(script_path: String, out_dir: String, fps: int, max_game_seconds: float) -> void:
	_out_dir = out_dir
	_fps = maxi(1, fps)
	var started := Time.get_ticks_msec()
	# A Timer node (not a SceneTreeTimer) so nothing outlives the tree at quit.
	var limit := Timer.new()
	limit.one_shot = true
	limit.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(limit)
	limit.timeout.connect(_on_limit.bind(script_path, started, max_game_seconds))
	limit.start(max_game_seconds)
	await run()
	_finish(script_path, started)

func _on_limit(script_path: String, started: int, max_game_seconds: float) -> void:
	fail("still running after %s s of game time" % max_game_seconds)
	_finish(script_path, started)

func _finish(script_path: String, started: int) -> void:
	if _done: return
	_done = true
	var result := {
		"probe": script_path, "ok": failures.is_empty(), "checks": checks, "failures": failures,
		"records": records, "screenshots": screenshots, "frames": frames_run,
		"game_seconds": snappedf(float(frames_run) / _fps, 0.001), "real_seconds": snappedf((Time.get_ticks_msec() - started) / 1000.0, 0.001),
		"headless": is_headless(), "user_data_dir": OS.get_user_data_dir(),
	}
	var file := FileAccess.open(_out_dir.path_join("result.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result, "  "))
	print("PROBE_RESULT ", JSON.stringify(result))
	# Quit cleanly: a UI sound still playing would be reported as a leak.
	for player in get_tree().root.find_children("*", "AudioStreamPlayer", true, false) + get_tree().root.find_children("*", "AudioStreamPlayer2D", true, false) + get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false):
		player.stop()
	# The audio thread releases stopped playbacks on its own clock: give it
	# real time (unthrottled fixed-fps frames take microseconds).
	for i in 3:
		await get_tree().process_frame
		OS.delay_msec(80)
	get_tree().quit(0 if result.ok else 1)

func _pad_device() -> int:
	return PROBE_PAD_DEVICE if bool(ProjectSettings.get_setting("starter_kit/probe_pads_moved", false)) else 0

func _tree_lines(node: Node, level: int, depth: int, lines: PackedStringArray) -> void:
	var line := "%s%s (%s)" % ["  ".repeat(level), node.name, node.get_class()]
	if node is CanvasItem and not (node as CanvasItem).visible: line += " [hidden]"
	if node is BaseButton and (node as BaseButton).disabled: line += " [disabled]"
	if node is Label or node is Button: line += " \"%s\"" % String(node.get("text")).left(40)
	lines.append(line)
	if level >= depth: return
	for child in node.get_children(): _tree_lines(child, level + 1, depth, lines)

func _plain(value: Variant) -> Variant:
	match typeof(value):
		TYPE_OBJECT:
			if value is Node: return str((value as Node).get_path())
			return str(value)
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_COLOR, TYPE_RECT2, TYPE_RECT2I, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value)
		TYPE_ARRAY:
			return (value as Array).map(func(item): return _plain(item))
		TYPE_DICTIONARY:
			var out := {}
			for k in value: out[str(k)] = _plain(value[k])
			return out
	return value
