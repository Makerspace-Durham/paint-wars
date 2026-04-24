extends Node

const BROADCAST_PORT: int = 7778  # UDP port for LAN discovery

var _udp_server: UDPServer = UDPServer.new()
var _broadcast_timer: Timer
var _discovery_listener: PacketPeerUDP
var _discovered_servers: Dictionary = {}  # { address: { "name": "", "mode": "", "players": 0 } }

# -- Hosting --

func host_game(player_name: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(Constants.DEFAULT_PORT, Constants.MAX_PLAYERS)
	if err != OK:
		push_error("Failed to host: %s" % err)
		return

	multiplayer.multiplayer_peer = peer
	Constants.register_player(1, {
		"name": player_name,
		"team": -1,
		"is_bot": false
	})
	_start_broadcasting()

func stop_hosting() -> void:
	_stop_broadcasting()
	multiplayer.multiplayer_peer = null
	Constants.clear_players()

# -- Joining --

func join_game(address: String, player_name: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, Constants.DEFAULT_PORT)
	if err != OK:
		push_error("Failed to join: %s" % err)
		return

	multiplayer.multiplayer_peer = peer
	Constants.register_player(multiplayer.get_unique_id(), {
		"name": player_name,
		"team": -1,
		"is_bot": false
	})

func disconnect_from_game() -> void:
	_stop_discovery()
	multiplayer.multiplayer_peer = null
	Constants.clear_players()

# -- LAN Broadcasting (host side) --

func _start_broadcasting() -> void:
	_broadcast_timer = Timer.new()
	_broadcast_timer.wait_time = 2.0
	_broadcast_timer.autostart = true
	_broadcast_timer.timeout.connect(_send_broadcast)
	add_child(_broadcast_timer)

func _stop_broadcasting() -> void:
	if _broadcast_timer:
		_broadcast_timer.stop()
		_broadcast_timer.queue_free()
		_broadcast_timer = null

func _send_broadcast() -> void:
	var udp := PacketPeerUDP.new()
	udp.set_broadcast_enabled(true)
	udp.set_dest_address("255.255.255.255", BROADCAST_PORT)
	var host_data := {
		"name": _get_host_name(),
		"mode": GameManager.current_mode,
		"players": Constants.players.size()
	}
	udp.put_packet(JSON.stringify(host_data).to_utf8_buffer())
	udp.close()

func _get_host_name() -> String:
	var host: Dictionary = Constants.players.get(1, {})
	return host.get("name", "Host")

# -- LAN Discovery (client side) --

func start_discovery() -> void:
	_discovered_servers.clear()
	_udp_server.listen(BROADCAST_PORT)

func stop_discovery() -> void:
	_udp_server.stop()
	_discovered_servers.clear()

func _stop_discovery() -> void:
	stop_discovery()

func poll_discovery() -> Dictionary:
	_udp_server.poll()
	while _udp_server.is_connection_available():
		var peer: PacketPeerUDP = _udp_server.take_connection()
		var packet := peer.get_packet()
		var data = JSON.parse_string(packet.get_string_from_utf8())
		if data and data is Dictionary:
			var address := peer.get_packet_ip()
			_discovered_servers[address] = data
	return _discovered_servers

# -- Multiplayer Callbacks --

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(peer_id: int) -> void:
	EventBus.player_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	Constants.remove_player(peer_id)
	EventBus.player_disconnected.emit(peer_id)
	# If host leaves mid-lobby, handled in lobby.gd via host_disconnected signal

func _on_connected_to_server() -> void:
	_register_with_host.rpc_id(1, Constants.get_player(multiplayer.get_unique_id()))

func _on_connection_failed() -> void:
	push_warning("Connection failed.")
	EventBus.host_disconnected.emit()

func _on_server_disconnected() -> void:
	EventBus.host_disconnected.emit()
	GameManager.quit_to_menu()

# -- RPCs --

@rpc("any_peer", "reliable")
func _register_with_host(data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	Constants.register_player(sender_id, data)
	_sync_lobby.rpc(Constants.players)
	EventBus.lobby_updated.emit(Constants.players)

@rpc("authority", "reliable")
func _sync_lobby(players: Dictionary) -> void:
	Constants.players = players
	EventBus.lobby_updated.emit(players)
