extends Node2D

const CONQUEST_MAP = preload("res://Scenes/Game/Maps/conquest_map.tscn")
const CTF_MAP = preload("res://Scenes/Game/Maps/ctf_map.tscn")
const PLAYER_SCENE = preload("res://Scenes/Player/player.tscn")

var _spawn_points: Dictionary = {
	Constants.TEAM_A: [],
	Constants.TEAM_B: []
}

@onready var map_container: Node2D = $MapContainer

func _ready() -> void:
	_load_map()
	# Wait one frame for map to be fully added to the scene tree
	await get_tree().process_frame
	_cache_spawn_points()
	if multiplayer.is_server():
		_assign_teams()
		_spawn_all_players()

func _load_map() -> void:
	var map_scene: PackedScene
	match GameManager.current_mode:
		Constants.GameMode.CONQUEST:
			map_scene = CONQUEST_MAP
		Constants.GameMode.CAPTURE_THE_FLAG:
			map_scene = CTF_MAP

	if map_scene:
		var map := map_scene.instantiate()
		map_container.add_child(map)

func _cache_spawn_points() -> void:
	var team_a_spawns := map_container.get_node_or_null(
		"%s/SpawnPoints/TeamASpawns" % map_container.get_child(0).name
	)
	var team_b_spawns := map_container.get_node_or_null(
		"%s/SpawnPoints/TeamBSpawns" % map_container.get_child(0).name
	)

	if team_a_spawns:
		for spawn in team_a_spawns.get_children():
			_spawn_points[Constants.TEAM_A].append(spawn.global_position)

	if team_b_spawns:
		for spawn in team_b_spawns.get_children():
			_spawn_points[Constants.TEAM_B].append(spawn.global_position)

func _assign_teams() -> void:
	var peer_ids := Constants.players.keys()
	peer_ids.shuffle()

	var half := peer_ids.size() / 2
	for i in peer_ids.size():
		var team := Constants.TEAM_A if i < half else Constants.TEAM_B
		Constants.players[peer_ids[i]]["team"] = team

	# Sync updated player data to all clients
	_sync_teams.rpc(Constants.players)

func _spawn_all_players() -> void:
	if GameManager.is_practice_mode:
		_spawn_player(1, Constants.TEAM_A)
		return

	for peer_id in Constants.players:
		var player_data := Constants.get_player(peer_id)
		var team: int = player_data.get("team", Constants.TEAM_A)
		_spawn_player(peer_id, team)

func _spawn_player(peer_id: int, team: int) -> void:
	var player := PLAYER_SCENE.instantiate()
	var players_node := map_container.get_child(0).get_node("Players")

	# Assign multiplayer authority to the correct peer
	player.set_multiplayer_authority(peer_id)
	player.add_to_group("players")

	# Pick spawn position
	var spawns= _spawn_points[team]
	var spawn_index: int= Constants.players.keys().find(peer_id) % spawns.size()
	player.global_position = spawns[spawn_index]

	players_node.add_child(player)

	# Sync spawn to all clients
	_sync_player_spawn.rpc(peer_id, team, player.global_position)

@rpc("authority", "call_local", "reliable")
func _sync_teams(players: Dictionary) -> void:
	Constants.players = players

@rpc("authority", "reliable")
func _sync_player_spawn(peer_id: int, team: int, spawn_pos: Vector2) -> void:
	if multiplayer.is_server():
		return

	var player := PLAYER_SCENE.instantiate()
	var players_node := map_container.get_child(0).get_node("Players")

	player.set_multiplayer_authority(peer_id)
	player.add_to_group("players")
	player.global_position = spawn_pos
	players_node.add_child(player)
