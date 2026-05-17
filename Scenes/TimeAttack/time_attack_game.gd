extends Node2D

const COIN_SCENE: PackedScene = preload("res://Scenes/TimeAttack/coin.tscn")
const PLAYER_SCENE: PackedScene = preload("res://Scenes/Player/player.tscn")

@onready var timer_label: Label = $CanvasLayer/HUD/VBoxContainer/TimerLabel
@onready var score_label: Label = $CanvasLayer/HUD/VBoxContainer/ScoreLabel
@onready var countdown_label: Label = $CanvasLayer/CountdownLabel
@onready var game_timer: Timer = $GameTimer
@onready var coin_container: Node2D = $CoinContainer
@onready var player_spawn: Marker2D = $PlayerSpawn

var score: int = 0
var time_remaining: float = Constants.TIME_ATTACK_DURATION
var _game_running: bool = false
var _coin_spawns: Array[Vector2] = []
var _active_spawn_indices: Array[int] = []  # tracks which spawn points have coins

func _ready() -> void:
	# Cache coin spawn points from the CoinSpawns node
	var coin_spawns_node := get_node_or_null("CoinSpawns")
	if coin_spawns_node:
		for marker in coin_spawns_node.get_children():
			if marker is Marker2D:
				_coin_spawns.append(marker.global_position)

	# Spawn the player
	_spawn_player()

	# Start with a 3-2-1 countdown
	_run_countdown()

func _spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.set_multiplayer_authority(1)
	player.add_to_group("players")
	if player_spawn:
		player.global_position = player_spawn.global_position
	add_child(player)

func _run_countdown() -> void:
	countdown_label.visible = true
	timer_label.text = "Time: %d" % int(Constants.TIME_ATTACK_DURATION)
	score_label.text = "Coins: 0"

	for i in [3, 2, 1]:
		countdown_label.text = str(i)
		await get_tree().create_timer(1.0).timeout

	countdown_label.text = "GO!"
	await get_tree().create_timer(0.5).timeout
	countdown_label.visible = false

	_start_game()

func _start_game() -> void:
	_game_running = true
	time_remaining = Constants.TIME_ATTACK_DURATION

	# Spawn initial coins
	_spawn_initial_coins()

func _spawn_initial_coins() -> void:
	# Spawn coins at up to half the available spawn points to start
	var count := mini(_coin_spawns.size(), Constants.TIME_ATTACK_MAX_COINS)
	var indices: Array[int] = []
	for i in _coin_spawns.size():
		indices.append(i)
	indices.shuffle()

	for i in count:
		_spawn_coin_at_index(indices[i])

func _spawn_coin_at_index(index: int) -> void:
	if index in _active_spawn_indices:
		return
	var coin := COIN_SCENE.instantiate()
	coin.global_position = _coin_spawns[index]
	coin.collected.connect(_on_coin_collected.bind(index))
	coin_container.add_child(coin)
	_active_spawn_indices.append(index)

func _on_coin_collected(spawn_index: int) -> void:
	if not _game_running:
		return
	score += 1
	score_label.text = "Coins: %d" % score
	_active_spawn_indices.erase(spawn_index)

	# Spawn a replacement coin at a random free spot
	_spawn_replacement_coin()

func _spawn_replacement_coin() -> void:
	var free_indices: Array[int] = []
	for i in _coin_spawns.size():
		if i not in _active_spawn_indices:
			free_indices.append(i)

	if free_indices.is_empty():
		return

	free_indices.shuffle()
	_spawn_coin_at_index(free_indices[0])

func _process(delta: float) -> void:
	if not _game_running:
		return

	time_remaining -= delta
	timer_label.text = "Time: %d" % max(ceili(time_remaining), 0)

	if time_remaining <= 0.0:
		_end_game()

func _end_game() -> void:
	_game_running = false
	time_remaining = 0.0
	timer_label.text = "Time: 0"

	# Clear remaining coins
	for coin in coin_container.get_children():
		coin.queue_free()

	# Show "Time's Up!" briefly, then go to results
	countdown_label.text = "Time's Up!"
	countdown_label.visible = true
	await get_tree().create_timer(2.0).timeout

	# Store score for the results screen to read
	GameManager.time_attack_last_score = score
	UiManager.go_to_scene("res://Scenes/UI/TimeAttackResults/time_attack_results.tscn")
