extends Control

@onready var mode_label: Label = $VBoxContainer/ModeLabel
@onready var player_list: VBoxContainer = $VBoxContainer/PlayerList
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var start_button: Button = $VBoxContainer/StartButton

var _player_name: String = "Player"  # replace with name input later

func _ready() -> void:
	EventBus.lobby_updated.connect(_on_lobby_updated)
	EventBus.host_disconnected.connect(_on_host_disconnected)

	mode_label.text = "Mode: %s" % _get_mode_string()
	start_button.visible = multiplayer.is_server()
	start_button.disabled = true

	Network.host_game(_player_name)

# -- UI --

func _refresh_player_list(players: Dictionary) -> void:
	for child in player_list.get_children():
		child.queue_free()

	for id in players:
		var data: Dictionary = players[id]
		var label := Label.new()
		label.text = "%s %s" % [data.get("name", "Unknown"), "(Host)" if id == 1 else ""]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_list.add_child(label)

func _update_status(players: Dictionary) -> void:
	var count := players.size()
	var max_p := Constants.MAX_PLAYERS
	status_label.text = "Players: %d / %d" % [count, max_p]
	start_button.disabled = count < max_p

func _get_mode_string() -> String:
	match GameManager.current_mode:
		Constants.GameMode.CONQUEST:
			return "Conquest"
		Constants.GameMode.CAPTURE_THE_FLAG:
			return "Capture the Flag"
		_:
			return "Unknown"

# -- Signals --

func _on_lobby_updated(players: Dictionary) -> void:
	_refresh_player_list(players)
	_update_status(players)

func _on_host_disconnected() -> void:
	GameManager.quit_to_menu()

# -- Buttons --

func _on_start_button_pressed() -> void:
	if not multiplayer.is_server():
		return
	_launch_game.rpc()

func _on_cancel_button_pressed() -> void:
	Network.stop_hosting()
	GameManager.quit_to_menu()

# -- RPCs --

@rpc("authority", "call_local", "reliable")
func _launch_game() -> void:
	GameManager.start_game(GameManager.current_mode, false)
	UiManager.go_to_scene("res://Scenes/Game/game.tscn")
