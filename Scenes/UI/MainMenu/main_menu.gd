extends Control

@onready var mode_view: VBoxContainer = $VBoxContainer/ModeView
@onready var host_join_view: VBoxContainer = $VBoxContainer/HostJoinView
@onready var mode_info_label: Label = $VBoxContainer/HostJoinView/ModeInfoLabel

var _selected_mode: Constants.GameMode

func _ready() -> void:
	_show_mode_view()

# -- View Control --

func _show_mode_view() -> void:
	mode_view.visible = true
	host_join_view.visible = false

func _show_host_join_view() -> void:
	mode_view.visible = false
	host_join_view.visible = true
	mode_info_label.text = _get_mode_label(_selected_mode)

func _get_mode_label(mode: Constants.GameMode) -> String:
	match mode:
		Constants.GameMode.CONQUEST:
			return "Mode: Conquest"
		Constants.GameMode.CAPTURE_THE_FLAG:
			return "Mode: Capture the Flag"
		_:
			return ""

# -- Mode Selection --

func _on_conquest_button_pressed() -> void:
	_selected_mode = Constants.GameMode.CONQUEST
	_show_host_join_view()

func _on_ctf_button_pressed() -> void:
	_selected_mode = Constants.GameMode.CAPTURE_THE_FLAG
	_show_host_join_view()

func _on_practice_button_pressed() -> void:
	_selected_mode = Constants.GameMode.CONQUEST  # default mode for practice
	GameManager.start_game(_selected_mode, true)
	UiManager.go_to_scene("res://Scenes/UI/ModeSelect/mode_select.tscn")

func _on_settings_button_pressed() -> void:
	UiManager.go_to_scene("res://Scenes/UI/Settings/settings.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

# -- Host / Join --

func _on_host_button_pressed() -> void:
	GameManager.current_mode = _selected_mode
	UiManager.go_to_scene("res://Scenes/UI/Lobby/lobby.tscn")

func _on_join_button_pressed() -> void:
	GameManager.current_mode = _selected_mode
	UiManager.go_to_scene("res://Scenes/UI/ServerBrowser/server_browser.tscn")

func _on_back_button_pressed() -> void:
	_show_mode_view()
