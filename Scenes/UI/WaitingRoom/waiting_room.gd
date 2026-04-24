extends Control

@onready var mode_label: Label = $VBoxContainer/ModeLabel
@onready var player_list: VBoxContainer = $VBoxContainer/PlayerList
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready() -> void:
	EventBus.lobby_updated.connect(_on_lobby_updated)
	EventBus.host_disconnected.connect(_on_host_disconnected)
	EventBus.game_started.connect(_on_game_started)

	mode_label.text = "Mode: %s" % _get_mode_string()

	# Request current lobby state from host on join
	if not multiplayer.is_server():
		_request_lobby_sync.rpc_id(1)

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
	status_label.text = "Players: %d / %d — Waiting for host to start..." % [count, max_p]

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
	status_label.text = "Host disconnected. Returning to menu..."
	await get_tree().create_timer(2.0).timeout
	GameManager.quit_to_menu()

func _on_game_started() -> void:
	UiManager.go_to_scene("res://Scenes/Game/game.tscn")

# -- Buttons --

func _on_leave_button_pressed() -> void:
	Network.disconnect_from_game()
	GameManager.quit_to_menu()

# -- RPCs --

# Client calls this on the host to request a fresh lobby sync
@rpc("any_peer", "reliable")
func _request_lobby_sync() -> void:
	if not multiplayer.is_server():
		return
	var requester_id := multiplayer.get_remote_sender_id()
	Network._sync_lobby.rpc_id(requester_id, Constants.players)
