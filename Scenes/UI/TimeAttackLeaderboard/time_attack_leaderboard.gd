extends Control

@onready var score_list: VBoxContainer = $VBoxContainer/ScrollContainer/ScoreList
@onready var no_scores_label: Label = $VBoxContainer/NoScoresLabel

func _ready() -> void:
	_refresh_leaderboard()

func _refresh_leaderboard() -> void:
	# Clear existing entries
	for child in score_list.get_children():
		child.queue_free()

	var entries: Array = Leaderboard.get_entries()

	if entries.is_empty():
		no_scores_label.visible = true
		no_scores_label.text = "No scores yet. Be the first!"
		return

	no_scores_label.visible = false

	for i in entries.size():
		var entry: Dictionary = entries[i]
		var row := _build_score_row(i + 1, entry)
		score_list.add_child(row)

func _build_score_row(rank: int, entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var rank_label := Label.new()
	rank_label.text = "#%d" % rank
	rank_label.custom_minimum_size.x = 40

	var name_label := Label.new()
	name_label.text = entry.get("name", "???")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var score_label := Label.new()
	score_label.text = str(entry.get("score", 0))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.custom_minimum_size.x = 60

	row.add_child(rank_label)
	row.add_child(name_label)
	row.add_child(score_label)
	return row

# -- Buttons --

func _on_start_button_pressed() -> void:
	GameManager.start_game(Constants.GameMode.TIME_ATTACK, true)
	UiManager.go_to_scene("res://Scenes/TimeAttack/time_attack_game.tscn")

func _on_back_button_pressed() -> void:
	UiManager.go_to_scene("res://Scenes/UI/MainMenu/main_menu.tscn")
