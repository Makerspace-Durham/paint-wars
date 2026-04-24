extends Node2D

@export var map_limits: Rect2 = Rect2(0, 0, 3200, 1800)

func _ready() -> void:
	if multiplayer.is_server():
		_setup_mode_elements()
	_apply_camera_limits()

func _apply_camera_limits() -> void:
	# Wait for local player camera to exist
	await get_tree().process_frame
	var local_player := _get_local_player()
	if not local_player:
		return

	var cam: Camera2D = local_player.get_node_or_null("PlayerCamera")
	if not cam:
		return

	cam.limit_left = int(map_limits.position.x)
	cam.limit_top = int(map_limits.position.y)
	cam.limit_right = int(map_limits.position.x + map_limits.size.x)
	cam.limit_bottom = int(map_limits.position.y + map_limits.size.y)

func _get_local_player() -> Node:
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_multiplayer_authority():
			return player
	return null

func _setup_mode_elements() -> void:
	match GameManager.current_mode:
		Constants.GameMode.CONQUEST:
			_setup_conquest()
		Constants.GameMode.CAPTURE_THE_FLAG:
			_setup_ctf()

func _setup_conquest() -> void:
	var mode_elements := get_node_or_null("ModeElements")
	if not mode_elements:
		push_error("ModeElements node missing from map.")
		return

	for spot in mode_elements.get_children():
		if spot.has_method("_evaluate_capture"):
			spot.visible = true

func _setup_ctf() -> void:
	var mode_elements := get_node_or_null("ModeElements")
	if not mode_elements:
		push_error("ModeElements node missing from map.")
		return

	for child in mode_elements.get_children():
		child.visible = true
