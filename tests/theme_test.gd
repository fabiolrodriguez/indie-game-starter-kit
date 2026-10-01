extends Node

const Palette = preload("res://ui/theme/ui_palette.gd")
const Importer = preload("res://ui/theme/palette_importer.gd")
var shared_theme = preload("res://ui/theme/menu_theme.tres")
var configuration = preload("res://ui/theme/theme_config.tres")
const BUILT_INS := ["midnight", "forest", "ocean", "crimson", "amber", "monochrome"]
const VALID := "#0f172a\n#1e293b\n#334155\n#38bdf8\n#f8fafc\n"
var failures := 0
var checks := 0
var capture_dir: String

func _ready() -> void:
	if not ProjectSettings.get_setting("starter_kit/testing", false):
		push_error("Run tests/run_tests.py to isolate test data")
		get_tree().quit(1)
		return
	capture_dir = ProjectSettings.get_setting("starter_kit/capture_dir", "")
	get_tree().create_timer(45.0).timeout.connect(func(): get_tree().quit(1))
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func capture(name: String) -> void:
	for frame in range(3):
		await get_tree().process_frame
	if not capture_dir.is_empty():
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		check(image.save_png(capture_dir.path_join(name + ".png")) == OK, "Screenshot failed")

func check_bounds(control: Control) -> void:
	check(get_viewport().get_visible_rect().encloses(control.get_global_rect()), "Clipped panel: " + control.name)

func _run() -> void:
	get_tree().current_scene = null
	var original = configuration.palette
	check(SceneManager.change_scene("res://scenes/main_menu/main_menu.tscn") == OK, "Main scene failed")
	await SceneManager.transition_finished
	var menu = get_tree().current_scene
	for name in BUILT_INS:
		var palette = load("res://ui/theme/palettes/%s.tres" % name)
		check(palette is Palette, "Invalid built-in palette " + name)
		for background in [palette.background, palette.surface, palette.surface_alt]:
			check(Palette.contrast(palette.text_primary, background) >= 4.5, "Text contrast " + name)
			check(Palette.contrast(palette.text_secondary, background) >= 4.5, "Secondary text contrast " + name)
		check(Palette.contrast(palette.focus, palette.surface) >= 3.0, "Focus contrast " + name)
		for status in [palette.success, palette.warning, palette.danger]:
			check(Palette.contrast(status, palette.surface) >= 4.5, "Status contrast " + name)
		configuration.palette = palette
		check(shared_theme.get_stylebox("normal", "Button").bg_color == palette.surface_alt, "Surface did not propagate: " + name)
		check(menu.start_button.get_theme_color("font_color") == Palette.ink_on(palette.primary), "Theme did not reach existing UI")
		for type in ["Button", "CheckBox", "OptionButton"]:
			for state in ["normal", "hover", "pressed", "disabled", "focus"]:
				check(shared_theme.has_stylebox(state, type), "Missing control state " + type + state)
		check(shared_theme.get_stylebox("normal", "Button").bg_color != shared_theme.get_stylebox("hover", "Button").bg_color, "Hover indistinguishable")
		await capture("main_" + name)
		check_bounds(menu.menu_panel)
	# Palette edits propagate without replacing the active Theme reference.
	var custom = original.duplicate()
	configuration.palette = custom
	custom.primary = Color("a9d6bb")
	check(shared_theme.get_stylebox("normal", "PrimaryButton").bg_color == custom.primary, "Inspector palette edits do not rebuild")
	configuration.palette = original
	menu.settings_button.pressed.emit()
	for language in ["en_US", "pt_BR"]:
		SettingsManager.set_language(language)
		await capture("settings_" + language)
		check_bounds(menu.settings_panel)
	for size in [Vector2i(800, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = size
		await capture("settings_%dx%d" % [size.x, size.y])
		check_bounds(menu.settings_panel)
		for slider in [menu.volume_slider, menu.music_volume_slider, menu.sfx_volume_slider]:
			check(menu.settings_panel.get_global_rect().encloses(slider.get_global_rect()), "Audio slider outside Settings")
			check(slider.get_theme_stylebox("focus", "Button") != null, "Audio slider focus style missing")
	get_tree().root.size = Vector2i(1280, 720)
	await get_tree().process_frame
	menu.resolution_selector.grab_focus()
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	Input.parse_input_event(accept)
	await get_tree().process_frame
	accept = accept.duplicate()
	accept.pressed = false
	Input.parse_input_event(accept)
	await capture("settings_popup")
	menu.resolution_selector.get_popup().hide()
	menu.controls_button.pressed.emit()
	await capture("controls")
	check_bounds(menu.controls_panel)
	menu._on_back_button_pressed()
	PauseManager.set_paused(true)
	await capture("pause")
	check_bounds(menu.pause_menu.get_node("PausePanel"))
	PauseManager.set_paused(false)

	var parsed := Importer.parse_hex(VALID, "Test import")
	check(parsed.get("error", "") == "" and parsed.get("palette") is Palette, "Valid HEX import failed")
	check(parsed.palette.background == Color("0f172a"), "Mapping changed")
	check(Importer.parse_hex(VALID.replace("\n", ", ")).has("palette"), "Comma/space list failed")
	var light_import := Importer.parse_hex("#898989 #909090 #989898 #224488 #000000")
	check(light_import.has("palette"), "Light palette import failed")
	for role in ["success", "warning", "danger", "text_secondary"]:
		check(Palette.contrast(light_import.palette.get(role), light_import.palette.surface) >= 4.5, "Imported role loses contrast: " + role)
	for text in ["", "#nope", "#12345678", VALID + "#123456", VALID.replace("#38bdf8", "#12345g"), "#ffffff\n#ffffff\n#ffffff\n#eeeeee\n#ffffff"]:
		var rejected := Importer.parse_hex(text)
		check(not rejected.get("error", "").is_empty() and not rejected.has("palette"), "Malformed input accepted")
	var directory: String = ProjectSettings.get_setting("starter_kit/user_data_path")
	var source := directory.path_join("test.hex")
	var target := directory.path_join("test_palette.tres")
	var config_path := directory.path_join("theme_config.tres")
	check(ResourceSaver.save(configuration, config_path) == OK, "Theme configuration save failed")
	check(not "StyleBoxFlat" in FileAccess.get_file_as_string(config_path), "Generated styles leaked into configuration")
	var restored = load(config_path)
	check(restored.palette.display_name == original.display_name and restored.visual_style.build(restored.palette).has_stylebox("normal", "Button"), "Theme configuration round trip failed")
	var file := FileAccess.open(source, FileAccess.WRITE)
	file.store_string(VALID)
	file.close()
	check(Importer.import_file(source, target).get("error", "") == "", "File import failed")
	var saved := FileAccess.get_file_as_string(target)
	check(load(target) is Palette, "Imported palette cannot be reloaded")
	check(not Importer.import_file(source, target).get("error", "").is_empty(), "Overwrite allowed")
	check(FileAccess.get_file_as_string(target) == saved, "Existing palette was corrupted")
	check(not Importer.import_file(directory.path_join("missing.hex"), target).get("error", "").is_empty(), "Missing input accepted")

	check(SceneManager.change_scene("res://ui/theme/preview/theme_preview.tscn") == OK, "Gallery scene failed")
	await SceneManager.transition_finished
	var gallery = get_tree().current_scene
	for index in BUILT_INS.size():
		gallery.select_palette(index)
		await capture("gallery_" + BUILT_INS[index])
	check(configuration.palette == original, "Preview changed global selection")
	check(not SettingsManager.config.has_section_key("settings", "palette"), "Palette leaked into player settings")
	AudioManager.player.stop()
	await get_tree().create_timer(0.2).timeout
	print("Theme: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
