extends Control

@onready var score_value_label: Label = $VBoxContainer/ScoreValueLabel
@onready var name_input: LineEdit = $VBoxContainer/NameRow/NameInput
@onready var save_button: Button = $VBoxContainer/SaveButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

var _score: int = 0
var _saved: bool = false

func _ready() -> void:
	_score = GameManager.time_attack_last_score
	score_value_label.text = "You collected %d coins!" % _score
	status_label.text = ""
	save_button.disabled = false
	name_input.max_length = 20
	name_input.placeholder_text = "Enter your name"
	name_input.text = ""

func _on_save_button_pressed() -> void:
	if _saved:
		return

	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		status_label.text = "Please enter a name."
		return

	var rank := Leaderboard.add_entry(player_name, _score)
	_saved = true
	save_button.disabled = true
	name_input.editable = false

	if rank >= 0:
		status_label.text = "Saved! You placed #%d." % (rank + 1)
	else:
		status_label.text = "Saved!"

func _on_leaderboard_button_pressed() -> void:
	GameManager.game_active = false
	UiManager.go_to_scene("res://Scenes/UI/TimeAttackLeaderboard/time_attack_leaderboard.tscn")

func _on_menu_button_pressed() -> void:
	GameManager.game_active = false
	UiManager.go_to_scene("res://Scenes/UI/MainMenu/main_menu.tscn")
