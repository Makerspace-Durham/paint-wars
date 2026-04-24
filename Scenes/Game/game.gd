extends Node2D

const CONQUEST_MAP = preload("res://Scenes/Game/Maps/conquest_map.tscn")
const CTF_MAP = preload("res://Scenes/Game/Maps/ctf_map.tscn")

@onready var map_container: Node2D = $MapContainer

func _ready() -> void:
	_load_map()

func _load_map() -> void:
	var map_scene: PackedScene
	match GameManager.current_mode:
		Constants.GameMode.CONQUEST:
			map_scene = CONQUEST_MAP
		Constants.GameMode.CAPTURE_THE_FLAG:
			map_scene = CTF_MAP

	if map_scene:
		var map := map_scene.instantiate()
		map_container.add_child(map)
