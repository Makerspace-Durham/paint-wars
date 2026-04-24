extends Control

@onready var server_list: VBoxContainer = $VBoxContainer/ServerList
@onready var no_servers_label: Label = $VBoxContainer/NoServersLabel
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var refresh_button: Button = $VBoxContainer/RefreshButton

var _poll_timer: Timer
var _player_name: String = "Player"  # replace with name input later

func _ready() -> void:
	EventBus.host_disconnected.connect(_on_host_disconnected)
	_start_discovery()

func _exit_tree() -> void:
	Network.stop_discovery()
	if _poll_timer:
		_poll_timer.stop()
		_poll_timer.queue_free()

# -- Discovery --

func _start_discovery() -> void:
	status_label.text = "Searching for games..."
	no_servers_label.visible = false
	Network.start_discovery()

	_poll_timer = Timer.new()
	_poll_timer.wait_time = 1.0
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_poll_servers)
	add_child(_poll_timer)

func _poll_servers() -> void:
	var servers: Dictionary = Network.poll_discovery()
	_refresh_server_list(servers)

# -- UI --

func _refresh_server_list(servers: Dictionary) -> void:
	for child in server_list.get_children():
		child.queue_free()

	if servers.is_empty():
		no_servers_label.visible = true
		status_label.text = "No games found."
		return

	no_servers_label.visible = false
	status_label.text = "Games found: %d" % servers.size()

	for address in servers:
		var data: Dictionary = servers[address]
		var row := _build_server_row(address, data)
		server_list.add_child(row)

func _build_server_row(address: String, data: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()

	var name_label := Label.new()
	name_label.text = data.get("name", "Unknown")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var mode_label := Label.new()
	mode_label.text = _get_mode_string(data.get("mode", -1))
	mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var players_label := Label.new()
	players_label.text = "%d / %d" % [data.get("players", 0), Constants.MAX_PLAYERS]
	players_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var join_btn := Button.new()
	join_btn.text = "Join"
	join_btn.pressed.connect(_on_join_pressed.bind(address))

	row.add_child(name_label)
	row.add_child(mode_label)
	row.add_child(players_label)
	row.add_child(join_btn)

	return row

func _get_mode_string(mode) -> String:
	match mode:
		Constants.GameMode.CONQUEST:
			return "Conquest"
		Constants.GameMode.CAPTURE_THE_FLAG:
			return "Capture the Flag"
		_:
			return "Unknown"

# -- Signals --

func _on_host_disconnected() -> void:
	GameManager.quit_to_menu()

# -- Buttons --

func _on_join_pressed(address: String) -> void:
	Network.stop_discovery()
	_poll_timer.stop()
	Network.join_game(address, _player_name)
	UiManager.go_to_scene("res://Scenes/UI/WaitingRoom/waiting_room.tscn")

func _on_refresh_button_pressed() -> void:
	Network.stop_discovery()
	if _poll_timer:
		_poll_timer.stop()
		_poll_timer.queue_free()
		_poll_timer = null
	_start_discovery()

func _on_back_button_pressed() -> void:
	Network.stop_discovery()
	UiManager.go_to_scene("res://Scenes/UI/MainMenu/main_menu.tscn")
