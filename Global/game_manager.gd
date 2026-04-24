extends Node

var current_mode: Constants.GameMode = Constants.GameMode.CONQUEST
var is_practice_mode: bool = false
var game_active: bool = false

# -- Scores --
var team_scores: Dictionary = {
	Constants.TEAM_A: 0,
	Constants.TEAM_B: 0
}

func _ready() -> void:
	EventBus.score_updated.connect(_on_score_updated)
	EventBus.game_started.connect(_on_game_started)

func start_game(mode: Constants.GameMode, practice: bool = false) -> void:
	current_mode = mode
	is_practice_mode = practice
	game_active = true
	EventBus.game_started.emit()

func end_game(winning_team: int) -> void:
	game_active = false
	EventBus.game_ended.emit(winning_team)
	UiManager.go_to_scene("res://Scenes/UI/TitleScreen/title_screen.tscn")

func quit_to_menu() -> void:
	game_active = false
	Constants.clear_players()
	UiManager.go_to_scene("res://Scenes/UI/TitleScreen/title_screen.tscn")

func _on_game_started() -> void:
	team_scores[Constants.TEAM_A] = 0
	team_scores[Constants.TEAM_B] = 0
	ctf_captures[Constants.TEAM_A] = 0
	ctf_captures[Constants.TEAM_B] = 0

func _on_score_updated(team: int, points: int) -> void:
	if not multiplayer.is_server():
		return
	if current_mode != Constants.GameMode.CONQUEST:
		return

	team_scores[team] += points
	_sync_scores.rpc(team_scores)

	if team_scores[team] >= Constants.CONQUEST_WIN_SCORE:
		end_game(team)

# -- CTF Scores --
var ctf_captures: Dictionary = {
	Constants.TEAM_A: 0,
	Constants.TEAM_B: 0
}

func register_ctf_capture(team: int) -> void:
	if not multiplayer.is_server():
		return
	if current_mode != Constants.GameMode.CAPTURE_THE_FLAG:
		return

	ctf_captures[team] += 1
	_sync_ctf_captures.rpc(ctf_captures)

	if ctf_captures[team] >= Constants.CTF_WIN_CAPTURES:
		end_game(team)

# -- RPCs --

@rpc("authority", "call_local", "reliable")
func _sync_scores(scores: Dictionary) -> void:
	team_scores = scores
	EventBus.scores_synced.emit(team_scores)

@rpc("authority", "call_local", "reliable")
func _sync_ctf_captures(captures: Dictionary) -> void:
	ctf_captures = captures
	EventBus.ctf_captures_synced.emit(ctf_captures)
