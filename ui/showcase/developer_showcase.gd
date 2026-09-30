extends Panel
## Development-only composition of real kit components. No storage mutations.

const Gallery = preload("res://ui/theme/preview/theme_preview.tscn")
const PauseMenu = preload("res://scenes/pause_menu/pause_menu.tscn")
const MENU := "res://scenes/main_menu/main_menu.tscn"
var configuration = preload("res://ui/theme/theme_config.tres")
var gallery: Panel
var pause_menu: CanvasLayer
var navigation: Array[Button] = []
var pages: Array[Control] = []
var status_labels: Dictionary = {}
var language_selector: OptionButton
var language_codes: Array = []
var localized_sample: Label
var bindings: GridContainer
var music_button: Button
var action_buttons: Array[Button] = []
var foundation_grid: GridContainer
var _original_language: String
var _original_music: AudioStream
var _original_music_position := 0.0
var _music_was_playing := false
var _music_previewed := false

func _ready() -> void:
	_original_language = LocalizationManager.current_language
	_original_music = AudioManager.bgm_player.stream
	_original_music_position = AudioManager.bgm_player.get_playback_position()
	_music_was_playing = AudioManager.bgm_player.playing
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	var column := VBoxContainer.new()
	margin.add_child(column)
	column.add_child(_label("DEVELOPER SHOWCASE", "Title"))
	column.add_child(_label("Development only · shared foundation · gameplay belongs in /game", "MutedLabel"))
	var nav := HBoxContainer.new()
	column.add_child(nav)
	for title in ["UI & Palette", "Foundation", "Controls"]:
		var button := _button(nav, title, show_page.bind(navigation.size()))
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		navigation.append(button)
	gallery = Gallery.instantiate()
	gallery.content_margin = 0
	gallery.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gallery)
	pages.append(gallery)
	var systems := _page(column)
	pages.append(systems.get_parent())
	foundation_grid = GridContainer.new()
	foundation_grid.columns = 2
	systems.add_child(foundation_grid)
	_build_status(_card(foundation_grid))
	_build_actions(_card(foundation_grid))
	var controls := _page(column)
	pages.append(controls.get_parent())
	controls.add_child(_label("INPUT MAP", "Eyebrow"))
	controls.add_child(_label("Bindings come from ControlsManager. Use arrows / WASD / D-pad and Tab to navigate.", "MutedLabel"))
	bindings = GridContainer.new()
	bindings.columns = 2
	bindings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card(controls).add_child(bindings)
	pause_menu = PauseMenu.instantiate()
	add_child(pause_menu)
	pause_menu.quit_requested.connect(func(): SceneManager.change_scene(MENU))
	LocalizationManager.language_changed.connect(_update_localization)
	ControlsManager.controls_changed.connect(_update_bindings)
	PauseManager.pause_changed.connect(func(_paused): refresh_status())
	GameSession.started.connect(refresh_status)
	GameSession.ended.connect(refresh_status)
	GameSession.value_changed.connect(func(_key, _value): refresh_status())
	SceneManager.transition_started.connect(func(_path): refresh_status())
	SceneManager.transition_finished.connect(func(_scene): refresh_status())
	SceneManager.transition_failed.connect(func(_path, _error): refresh_status())
	AudioManager.bgm_player.finished.connect(refresh_status)
	resized.connect(_update_columns)
	_update_localization()
	refresh_status()
	show_page(0)
	_update_columns.call_deferred()
	gallery.selector.grab_focus.call_deferred()

func _build_status(column: VBoxContainer) -> void:
	column.add_child(_label("FOUNDATION STATUS", "Eyebrow"))
	var grid := GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	for singleton in ["AudioManager", "LocalizationManager", "SettingsManager", "ControlsManager", "SaveManager", "PauseManager", "SceneManager", "GameSession"]:
		var title := _label(singleton.trim_suffix("Manager"), "ControlsText")
		title.custom_minimum_size.x = 120
		grid.add_child(title)
		var value := _label("", "BindingText")
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value)
		status_labels[singleton] = value
	_button(column, "Refresh status", refresh_status)

func _build_actions(column: VBoxContainer) -> void:
	column.add_child(_label("TRY THE REAL SYSTEMS", "Eyebrow"))
	column.add_child(_label("Language and music previews are temporary. Settings and saves remain untouched.", "MutedLabel"))
	language_selector = OptionButton.new()
	column.add_child(language_selector)
	language_codes = LocalizationManager.translations.keys()
	for code in language_codes:
		language_selector.add_item(code)
	language_selector.item_selected.connect(func(index): LocalizationManager.set_language(language_codes[index]))
	localized_sample = _label("", "ControlsText")
	column.add_child(localized_sample)
	var actions := VBoxContainer.new()
	column.add_child(actions)
	action_buttons.append(_button(actions, "Play UI click", AudioManager.play_click))
	music_button = _button(actions, "Preview music", _toggle_music)
	action_buttons.append(music_button)
	action_buttons.append(_button(actions, "Pause / resume", func(): PauseManager.set_paused(true)))
	action_buttons.append(_button(actions, "Replay default fade", func(): SceneManager.change_scene(scene_file_path)))
	action_buttons.append(_button(actions, "Open real Main Menu", func(): SceneManager.change_scene(MENU)))
	column.add_child(_label("Esc / Start opens the shared PauseMenu. Main Menu contains the real Settings and Controls panels. Use Run Current Scene in the editor to return.", "MutedLabel"))

func refresh_status() -> void:
	var values := {
		"AudioManager": "%s · music %s" % ["UI streams ready" if AudioManager.click_sound != null and AudioManager.hover_sound != null else "UI streams missing", "playing" if AudioManager.bgm_player.playing else "stopped"],
		"LocalizationManager": "Active: " + LocalizationManager.current_language,
		"SettingsManager": "%s · volume %.2f · %s" % [SettingsManager.resolutions[SettingsManager.resolution_index], SettingsManager.volume, "fullscreen" if SettingsManager.fullscreen else "windowed"],
		"ControlsManager": "%d action descriptions from InputMap" % ControlsManager.get_controls_data().size(),
		"SaveManager": "Save file present (read only)" if SaveManager.has_save() else "No save file · not created by showcase",
		"PauseManager": "Paused" if PauseManager.is_paused() else "Running",
		"SceneManager": "Transition active" if SceneManager.is_transitioning else "Ready · fade %.2f s per phase" % SceneManager.default_options.fade_duration,
		"GameSession": "%s · %d values" % ["Active" if GameSession.active else "Inactive", GameSession.snapshot().size()]
	}
	for singleton in status_labels:
		var present := get_node_or_null("/root/" + singleton) != null
		status_labels[singleton].text = values[singleton] if present else "Missing"
		status_labels[singleton].theme_type_variation = &"BindingText" if present else &"DangerLabel"
	if music_button != null:
		music_button.text = "Stop music preview" if _music_previewed and AudioManager.bgm_player.playing else "Preview music"

func _toggle_music() -> void:
	if _music_previewed and AudioManager.bgm_player.playing:
		AudioManager.stop_bgm()
	else:
		AudioManager.play_bgm(AudioManager.bg_music)
	_music_previewed = true
	refresh_status()

func _update_localization() -> void:
	language_selector.select(language_codes.find(LocalizationManager.current_language))
	localized_sample.text = "%s · %s · %s" % [LocalizationManager.tr_key("menu_start"), LocalizationManager.tr_key("menu_settings"), LocalizationManager.tr_key("menu_controls")]
	_update_bindings()
	refresh_status()

func _update_bindings() -> void:
	for child in bindings.get_children():
		bindings.remove_child(child)
		child.queue_free()
	for item in ControlsManager.get_controls_data():
		var action := _label(LocalizationManager.tr_key(item.label_key), "ControlsText")
		action.custom_minimum_size.x = 220
		bindings.add_child(action)
		var value := _label(item.value, "BindingText")
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bindings.add_child(value)

func show_page(index: int) -> void:
	for page_index in pages.size():
		pages[page_index].visible = page_index == index
		navigation[page_index].set_pressed_no_signal(page_index == index)
	refresh_status()
	# Native navigation connects the page to its persistent navigation row.
	var first: Control = gallery.selector if index == 0 else language_selector if index == 1 else navigation[2]
	if index != 2:
		first.focus_neighbor_top = navigation[index].get_path()
		navigation[index].focus_neighbor_bottom = first.get_path()
	else:
		navigation[index].focus_neighbor_bottom = pages[index].get_v_scroll_bar().get_path()
	if index != 0:
		pages[index].get_v_scroll_bar().focus_neighbor_left = navigation[index].get_path()

func _update_columns() -> void:
	foundation_grid.columns = 2 if size.x >= 1100 else 1

func _page(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL
	scroll.get_v_scroll_bar().custom_step = 40.0
	scroll.get_v_scroll_bar().focus_neighbor_top = scroll.get_v_scroll_bar().get_path()
	scroll.get_v_scroll_bar().focus_neighbor_bottom = scroll.get_v_scroll_bar().get_path()
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	return column

func _card(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(column)
	return column

func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	button.pressed.connect(action)
	button.mouse_entered.connect(AudioManager.play_hover)
	button.focus_entered.connect(AudioManager.play_hover)
	return button

func _exit_tree() -> void:
	# Restore only previewed, transient state. Do not reload or write persistence.
	LocalizationManager.language_changed.disconnect(_update_localization)
	LocalizationManager.set_language(_original_language)
	if _music_previewed:
		AudioManager.stop_bgm()
		AudioManager.bgm_player.stream = _original_music
		if _music_was_playing:
			AudioManager.bgm_player.play(_original_music_position)
