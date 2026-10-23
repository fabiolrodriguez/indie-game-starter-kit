extends SceneProbe
## Example probe (also run by tests/run_tests.py): the main menu takes focus,
## ui_down moves it, the settings panel opens and closes with the
## keyboard/controller, and user data stays inside the sandbox.

const MENU := "res://scenes/main_menu/main_menu.tscn"

func run() -> void:
	var menu := await open(MENU)
	if not check(menu != null, "main menu opened"): return
	check(OS.get_user_data_dir().replace("\\", "/").begins_with(ProjectSettings.get_setting("starter_kit/user_data_path", "")) or SettingsManager.SETTINGS_PATH.begins_with(ProjectSettings.get_setting("starter_kit/user_data_path", "")), "user data is sandboxed")
	await wait_until(func(): return focused() != null, 2.0)
	var start := focus_path()
	record("first_focus", start)
	check(start.ends_with("start"), "Start has focus when the menu opens")
	await tap_action("ui_down")
	record("after_down", focus_path())
	check(focus_path() != start, "ui_down moves focus")
	var settings_button := first("settings", menu) as Button
	var panel := first("SettingsPanel", menu) as Control
	if check(settings_button != null and panel != null, "settings button and panel exist"):
		settings_button.grab_focus()
		await tap_action("ui_accept")
		await seconds(0.3)
		check(panel.visible, "ui_accept on Settings opens the panel")
		record("settings_focus", focus_path())
		await screenshot("settings_open")
		await tap_action("ui_cancel")
		await seconds(0.3)
		check(not panel.visible, "ui_cancel closes the panel")
		record("after_cancel", focus_path())
		await seconds(1.0)
		record("after_cancel_1s", focus_path())
		# The kit hands focus back to Start when a panel closes (main_menu.gd).
		check(focus_path().ends_with("start"), "focus returns to the main menu")
	record("game_seconds_so_far", frames_run / 60.0)
