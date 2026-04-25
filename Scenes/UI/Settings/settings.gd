extends Control

# -- Audio --
@onready var master_slider: HSlider = $VBoxContainer/TabContainer/AudioTab/MasterRow/MasterSlider
@onready var music_slider: HSlider = $VBoxContainer/TabContainer/AudioTab/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $VBoxContainer/TabContainer/AudioTab/SFXRow/SFXSlider

# -- Keybindings --
@onready var keybind_list: VBoxContainer = $VBoxContainer/TabContainer/KeybindTab/KeybindList

# -- Display --
@onready var fullscreen_toggle: CheckButton = $VBoxContainer/TabContainer/DisplayTab/FullscreenRow/FullscreenToggle
@onready var resolution_option: OptionButton = $VBoxContainer/TabContainer/DisplayTab/ResolutionRow/ResolutionOption

# -- Keybind State --
var _awaiting_rebind: String = ""
var _keybind_buttons: Dictionary = {}

const REBINDABLE_ACTIONS: Array = [
	"move_left",
	"move_right",
	"jump",
	"run",
	"spray"
]

const RESOLUTIONS: Array = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

func _ready() -> void:
	_load_settings()
	_setup_audio()
	_setup_keybindings()
	_setup_display()

# -- Load / Save --

func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load("user://settings.cfg")
	if err != OK:
		return

	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(config.get_value("audio", "master", 1.0))
	)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"),
		linear_to_db(config.get_value("audio", "music", 1.0))
	)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("SFX"),
		linear_to_db(config.get_value("audio", "sfx", 1.0))
	)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", db_to_linear(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	))
	config.set_value("audio", "music", db_to_linear(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	))
	config.set_value("audio", "sfx", db_to_linear(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	))
	config.set_value("display", "fullscreen",
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	config.set_value("display", "resolution", DisplayServer.window_get_size())
	config.save("user://settings.cfg")

# -- Audio --

func _setup_audio() -> void:
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.01
	master_slider.value = db_to_linear(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	)
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.01
	music_slider.value = db_to_linear(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	)
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.01
	sfx_slider.value = db_to_linear(
		AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	)
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

func _on_master_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"), linear_to_db(value)
	)

func _on_music_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"), linear_to_db(value)
	)

func _on_sfx_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("SFX"), linear_to_db(value)
	)

# -- Keybindings --

func _setup_keybindings() -> void:
	for action in REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()

		var label := Label.new()
		label.text = action.capitalize().replace("_", " ")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var btn := Button.new()
		btn.text = _get_action_key_string(action)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_keybind_button_pressed.bind(action, btn))
		_keybind_buttons[action] = btn

		row.add_child(label)
		row.add_child(btn)
		keybind_list.add_child(row)

func _get_action_key_string(action: String) -> String:
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			return event.as_text()
		elif event is InputEventMouseButton:
			return "Mouse %d" % event.button_index
	return "Unbound"

func _on_keybind_button_pressed(action: String, btn: Button) -> void:
	if _awaiting_rebind != "":
		return
	_awaiting_rebind = action
	btn.text = "Press a key..."

func _input(event: InputEvent) -> void:
	if _awaiting_rebind == "":
		return
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if not event.pressed:
		return

	# Cancel rebind on Escape
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		_keybind_buttons[_awaiting_rebind].text = _get_action_key_string(_awaiting_rebind)
		_awaiting_rebind = ""
		return

	InputMap.action_erase_events(_awaiting_rebind)
	InputMap.action_add_event(_awaiting_rebind, event)
	_keybind_buttons[_awaiting_rebind].text = _get_action_key_string(_awaiting_rebind)
	_awaiting_rebind = ""
	_save_settings()
	get_viewport().set_input_as_handled()

# -- Display --

func _setup_display() -> void:
	fullscreen_toggle.button_pressed = (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)

	for res in RESOLUTIONS:
		resolution_option.add_item("%dx%d" % [res.x, res.y])

	var current_res := DisplayServer.window_get_size()
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == current_res:
			resolution_option.selected = i
			break

	resolution_option.item_selected.connect(_on_resolution_selected)

func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()

func _on_resolution_selected(index: int) -> void:
	DisplayServer.window_set_size(RESOLUTIONS[index])
	_save_settings()

# -- Back --

func _on_back_button_pressed() -> void:
	_save_settings()
	UiManager.go_to_scene("res://Scenes/UI/MainMenu/main_menu.tscn")
