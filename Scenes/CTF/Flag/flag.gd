extends Area2D

@onready var flag_label: Label = $Label
@onready var return_timer: Timer = $ReturnTimer
@onready var sprite: Sprite2D = $Sprite2D

@export var team: int = Constants.TEAM_A

var home_position: Vector2
var carrier: Node = null
var is_at_home: bool = true

func _ready() -> void:
	home_position = global_position
	body_entered.connect(_on_body_entered)
	return_timer.timeout.connect(_on_return_timer_timeout)
	_refresh_ui()

func _physics_process(_delta: float) -> void:
	if carrier:
		global_position = carrier.global_position + Vector2(0, -32)

# -- Pickup --

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	if carrier:
		return
	if not body.has_method("apply_stun"):
		return

	var peer_id := body.get_multiplayer_authority()
	var player_data := Constants.get_player(peer_id)
	var player_team: int = player_data.get("team", -1)

	# Can't pick up own team's flag
	if player_team == team:
		# If own flag is on ground, return it
		if not is_at_home:
			_return_to_home()
		return

	_pick_up(body, peer_id)

func _pick_up(body: Node, peer_id: int) -> void:
	carrier = body
	is_at_home = false
	return_timer.stop()
	body.set_carrying_flag(true)
	_sync_pickup.rpc(peer_id)
	EventBus.flag_picked_up.emit(peer_id, team)

# -- Drop --

func drop_flag(return_home: bool = false) -> void:
	if not multiplayer.is_server():
		return
	if carrier:
		carrier.set_carrying_flag(false)
		carrier = null

	if return_home:
		_return_to_home()
		return

	# Leave on ground, start return timer
	return_timer.start()
	_sync_drop.rpc(global_position)
	EventBus.flag_dropped.emit(-1, team)

func _return_to_home() -> void:
	carrier = null
	is_at_home = true
	return_timer.stop()
	global_position = home_position
	_sync_return.rpc()

func _on_return_timer_timeout() -> void:
	_return_to_home()

# -- UI --

func _refresh_ui() -> void:
	match team:
		Constants.TEAM_A:
			flag_label.text = "Team A Flag"
			sprite.modulate = Color.BLUE
		Constants.TEAM_B:
			flag_label.text = "Team B Flag"
			sprite.modulate = Color.RED

# -- RPCs --

@rpc("authority", "call_local", "reliable")
func _sync_pickup(peer_id: int) -> void:
	var body := _get_player_node(peer_id)
	if body:
		carrier = body

@rpc("authority", "call_local", "reliable")
func _sync_drop(drop_position: Vector2) -> void:
	carrier = null
	global_position = drop_position

@rpc("authority", "call_local", "reliable")
func _sync_return() -> void:
	carrier = null
	is_at_home = true
	global_position = home_position
	_refresh_ui()

func _get_player_node(peer_id: int) -> Node:
	# Assumes players are in a group called "players"
	for player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() == peer_id:
			return player
	return null
