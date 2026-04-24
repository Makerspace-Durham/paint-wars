extends Control

@onready var prompt_label: Label = $VBoxContainer/PromptLabel
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _can_proceed: bool = false

func _ready() -> void:
	anim_player.play("prompt_blink")
	# Small delay so input isn't caught immediately on scene load
	await get_tree().create_timer(0.5).timeout
	_can_proceed = true

func _input(event: InputEvent) -> void:
	if not _can_proceed:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_proceed()
	elif event is InputEventMouseButton and event.pressed:
		_proceed()
	elif event is InputEventJoypadButton and event.pressed:
		_proceed()

func _proceed() -> void:
	_can_proceed = false
	UiManager.go_to_scene("res://Scenes/UI/MainMenu/main_menu.tscn")
