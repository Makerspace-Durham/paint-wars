extends Area2D

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var capture_timer: Timer = $CaptureTimer
@onready var team_label: Label = $Label
@onready var score_timer: Timer = $ScoreTimer

# -- Config --
@export var spot_id: int = 0
@export var capture_time: float = Constants.PAINT_DURATION

# -- State --
var owning_team: int = -1       # -1 = neutral
var capturing_team: int = -1
var capture_progress: float = 0.0
var players_in_zone: Dictionary = {}  # { peer_id: team }

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	capture_timer.timeout.connect(_on_capture_tick)
	score_timer.timeout.connect(_on_score_tick)  # new
	score_timer.wait_time = Constants.CONQUEST_SCORE_TICK_RATE
	_refresh_ui()

func _on_score_tick() -> void:
	if not multiplayer.is_server():
		return
	if owning_team == -1:
		score_timer.stop()
		return
	EventBus.score_updated.emit(owning_team, Constants.CONQUEST_POINTS_PER_TICK)

# -- Zone Detection --

func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	if not body.has_method("apply_stun"):
		return

	var peer_id := body.get_multiplayer_authority()
	var player_data := Constants.get_player(peer_id)
	var team: int = player_data.get("team", -1)

	if team == -1:
		return

	players_in_zone[peer_id] = team
	_evaluate_capture()

func _on_body_exited(body: Node) -> void:
	if not multiplayer.is_server():
		return

	var peer_id := body.get_multiplayer_authority()
	players_in_zone.erase(peer_id)
	_evaluate_capture()

# -- Capture Logic --

func _evaluate_capture() -> void:
	if players_in_zone.is_empty():
		capture_timer.stop()
		capturing_team = -1
		return

	# Count players per team in zone
	var team_counts: Dictionary = {}
	for peer_id in players_in_zone:
		var team: int = players_in_zone[peer_id]
		team_counts[team] = team_counts.get(team, 0) + 1

	# Find dominant team (most players, not already owning)
	var dominant_team: int = -1
	var highest_count: int = 0
	for team in team_counts:
		if team_counts[team] > highest_count and team != owning_team:
			dominant_team = team
			highest_count = team_counts[team]

	if dominant_team == -1:
		# Only owning team present, no capture needed
		capture_timer.stop()
		capturing_team = -1
		return

	# Contested — opposing teams both present
	var unique_teams := team_counts.keys().filter(func(t): return team_counts[t] > 0)
	if unique_teams.size() > 1:
		capture_timer.stop()
		capturing_team = -1
		_sync_ui.rpc(owning_team, capture_progress)
		return

	capturing_team = dominant_team
	capture_timer.start()

func _on_capture_tick() -> void:
	if capturing_team == -1:
		return

	var tick_amount: float = (100.0 / capture_time) * capture_timer.wait_time
	capture_progress = min(capture_progress + tick_amount, 100.0)
	_sync_ui.rpc(owning_team, capture_progress)

	if capture_progress >= 100.0:
		_complete_capture()

func _complete_capture() -> void:
	capture_timer.stop()
	owning_team = capturing_team
	capturing_team = -1
	capture_progress = 0.0
	EventBus.paint_spot_captured.emit(spot_id, owning_team)
	_sync_capture.rpc(owning_team)
	# Start scoring for new owner
	if multiplayer.is_server():
		score_timer.start()

# -- UI --

func _refresh_ui() -> void:
	progress_bar.value = capture_progress
	match owning_team:
		Constants.TEAM_A:
			team_label.text = "Team A"
		Constants.TEAM_B:
			team_label.text = "Team B"
		_:
			team_label.text = "Neutral"

# -- RPCs --

@rpc("authority", "call_local", "reliable")
func _sync_capture(team: int) -> void:
	owning_team = team
	capture_progress = 0.0
	_refresh_ui()

@rpc("authority", "call_local", "unreliable")
func _sync_ui(team: int, progress: float) -> void:
	owning_team = team
	capture_progress = progress
	progress_bar.value = progress
	_refresh_ui()
