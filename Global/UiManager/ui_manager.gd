extends CanvasLayer

@onready var hud: Control = $HUD
@onready var mode_label: Label = $HUD/VBoxContainer/ModeLabel
@onready var team_a_score: Label = $HUD/VBoxContainer/ScoreContainer/TeamAScore
@onready var team_b_score: Label = $HUD/VBoxContainer/ScoreContainer/TeamBScore
@onready var win_screen: PanelContainer = $WinScreen
@onready var win_label: Label = $WinScreen/VBoxContainer/WinLabel

func _ready() -> void:
	EventBus.scores_synced.connect(_on_scores_synced)
	EventBus.ctf_captures_synced.connect(_on_ctf_captures_synced)
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_ended.connect(_on_game_ended)
	hud.visible = false
	win_screen.visible = false

# -- Scene Navigation --

func go_to_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

# -- HUD --

func _on_game_started() -> void:
	hud.visible = true
	win_screen.visible = false
	_set_mode_label()
	_reset_scores()

func _set_mode_label() -> void:
	match GameManager.current_mode:
		Constants.GameMode.CONQUEST:
			mode_label.text = "Conquest — First to %d" % Constants.CONQUEST_WIN_SCORE
		Constants.GameMode.CAPTURE_THE_FLAG:
			mode_label.text = "CTF — First to %d Captures" % Constants.CTF_WIN_CAPTURES

func _reset_scores() -> void:
	team_a_score.text = "Team A: 0"
	team_b_score.text = "Team B: 0"

# -- Score Updates --

func _on_scores_synced(scores: Dictionary) -> void:
	team_a_score.text = "Team A: %d" % scores.get(Constants.TEAM_A, 0)
	team_b_score.text = "Team B: %d" % scores.get(Constants.TEAM_B, 0)

func _on_ctf_captures_synced(captures: Dictionary) -> void:
	team_a_score.text = "Team A: %d" % captures.get(Constants.TEAM_A, 0)
	team_b_score.text = "Team B: %d" % captures.get(Constants.TEAM_B, 0)

# -- Win Screen --

func _on_game_ended(winning_team: int) -> void:
	win_screen.visible = true
	hud.visible = false
	match winning_team:
		Constants.TEAM_A:
			win_label.text = "Team A Wins!"
		Constants.TEAM_B:
			win_label.text = "Team B Wins!"

func _on_menu_button_pressed() -> void:
	win_screen.visible = false
	Network.disconnect_from_game()
	GameManager.quit_to_menu()
