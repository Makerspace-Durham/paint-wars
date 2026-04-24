extends Area2D

@onready var base_label: Label = $Label
@onready var sprite: Sprite2D = $Sprite2D

@export var team: int = Constants.TEAM_A

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh_ui()

# -- Capture Check --

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	if not body.has_method("apply_stun"):
		return

	var peer_id := body.get_multiplayer_authority()
	var player_data := Constants.get_player(peer_id)
	var player_team: int = player_data.get("team", -1)

	# Only own team can score
	if player_team != team:
		return

	# Player must be carrying enemy flag
	if not body.is_carrying_flag:
		return

	_score_capture(body, peer_id)

func _score_capture(body: Node, peer_id: int) -> void:
	# Drop and return the flag home
	if body._carried_flag:
		body._carried_flag.drop_flag(true)
	body.set_carrying_flag(false)

	EventBus.flag_captured.emit(team)
	GameManager.register_ctf_capture(team)

# -- UI --

func _refresh_ui() -> void:
	match team:
		Constants.TEAM_A:
			base_label.text = "Team A Base"
			sprite.modulate = Color.BLUE
		Constants.TEAM_B:
			base_label.text = "Team B Base"
			sprite.modulate = Color.RED
