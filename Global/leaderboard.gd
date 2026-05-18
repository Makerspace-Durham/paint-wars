extends Node

const LEADERBOARD_PATH: String = "user://time_attack_leaderboard.json"
const MAX_ENTRIES: int = 20

var entries: Array = []

func _ready() -> void:
	load_leaderboard()

# -- Public API --

func add_entry(player_name: String, score: int) -> int:
	"""Adds an entry, sorts, trims to top 20. Returns the rank (0-based), or -1 if not placed."""
	var entry := { "name": player_name, "score": score }
	entries.append(entry)
	entries.sort_custom(_compare_entries)

	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)

	save_leaderboard()

	# Return rank
	for i in entries.size():
		if entries[i] == entry:
			return i
	return -1

func get_entries() -> Array:
	return entries

func is_high_score(score: int) -> bool:
	if entries.size() < MAX_ENTRIES:
		return true
	return score > entries[entries.size() - 1]["score"]

# -- Persistence --

func save_leaderboard() -> void:
	var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE)
	if not file:
		push_error("Failed to save leaderboard: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(entries, "\t"))

func load_leaderboard() -> void:
	if not FileAccess.file_exists(LEADERBOARD_PATH):
		entries = []
		return

	var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to load leaderboard: %s" % FileAccess.get_open_error())
		entries = []
		return

	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		entries = parsed
		entries.sort_custom(_compare_entries)
	else:
		entries = []

# -- Sorting --

func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	return a["score"] > b["score"]

func delete_leaderboard() -> void:
	var file := FileAccess.open(LEADERBOARD_PATH, FileAccess.WRITE_READ)
	if file:
		DirAccess.remove_absolute(LEADERBOARD_PATH)
