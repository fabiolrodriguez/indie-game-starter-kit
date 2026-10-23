extends Node
## Runs one SceneProbe (tools/probe/run_probe.py starts this scene). Refuses
## to run unless the runner's sandbox is in place: the project copy must be
## marked as a probe workspace and user data must resolve inside it, so a
## probe never reads or writes the developer's real saves and settings.

func _ready() -> void:
	var args := _args()
	var out_dir := String(args.get("out", ""))
	# The probe workspace, or the test suite's own disposable copy.
	if not (bool(ProjectSettings.get_setting("starter_kit/probe", false)) or bool(ProjectSettings.get_setting("starter_kit/testing", false))):
		_abort("Run probes through tools/probe/run_probe.py (it isolates user data).")
		return
	var sandbox := String(ProjectSettings.get_setting("starter_kit/user_data_path", ""))
	if sandbox == "" or not (OS.get_user_data_dir().replace("\\", "/").begins_with(sandbox) or _kit_storage_in(sandbox)):
		_abort("User data is not isolated (user://=%s, sandbox=%s)." % [OS.get_user_data_dir(), sandbox])
		return
	var script_path := String(args.get("probe", ""))
	var script := load(script_path) as Script if ResourceLoader.exists(script_path) else null
	if script == null:
		_abort("Probe script not found: %s" % script_path)
		return
	var probe = script.new()
	if not probe is SceneProbe:
		_abort("%s must extend SceneProbe." % script_path)
		return
	if bool(ProjectSettings.get_setting("starter_kit/probe_pads_moved", false)): _move_pad_bindings()
	DirAccess.make_dir_recursive_absolute(out_dir)
	probe.name = "Probe"
	# The probe sits beside the autoloads, so it survives the scene changes
	# it makes (this runner scene is the first one it replaces).
	get_tree().root.add_child.call_deferred(probe)
	probe._launch.call_deferred(script_path, out_dir, int(args.get("fps", "60")), float(args.get("max-game-seconds", "600")))

func _abort(message: String) -> void:
	push_error(message)
	print("PROBE_RESULT ", JSON.stringify({"ok": false, "failures": [message]}))
	get_tree().quit(2)

## The kit's own storage paths, when the runner pointed them at the sandbox
## (platforms where user:// can't be redirected from outside).
func _kit_storage_in(sandbox: String) -> bool:
	for path in ["SettingsManager", "SaveManager"]:
		var manager := get_tree().root.get_node_or_null(path)
		if manager == null: continue
		var constant := "SETTINGS_PATH" if path == "SettingsManager" else "SAVE_PATH"
		if not String(manager.get(constant)).begins_with(sandbox): return false
	return true

func _move_pad_bindings() -> void:
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion: event.device = SceneProbe.PROBE_PAD_DEVICE

func _args() -> Dictionary:
	var result := {}
	for token in OS.get_cmdline_user_args():
		if token.begins_with("--") and "=" in token:
			var parts := token.substr(2).split("=", true, 1)
			result[parts[0]] = parts[1]
	return result
