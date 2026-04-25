extends Node

# Teams
const TEAM_A: int = 0
const TEAM_B: int = 1

# Game Modes
enum GameMode { CONQUEST, CAPTURE_THE_FLAG }

# Conquest
const CONQUEST_WIN_SCORE: int = 100
const CONQUEST_PAINT_SPOTS: int = 3
const PLAYERS_PER_TEAM: int = 3
const CONQUEST_POINTS_PER_TICK: int = 1       # points awarded per tick
const CONQUEST_SCORE_TICK_RATE: float = 1.0   # seconds between point ticks

# CTF
const CTF_WIN_CAPTURES: int = 3

# Player
const SPRAY_COOLDOWN: float = 0.5       # seconds
const STUN_DURATION: float = 2.0        # seconds
const PAINT_DURATION: float = 3.0       # seconds (time to capture a spot)

# Network
const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 6

# Bot
const BOT_DECISION_RATE: float = 0.3      # seconds between decisions
const BOT_REACH_THRESHOLD: float = 8.0    # distance to consider target reached
const BOT_SPRAY_RANGE: float = 40.0       # distance to attempt spraying
const BOT_JUMP_THRESHOLD: float = -32.0   # y difference to trigger a jump

enum BotState {
	IDLE,
	MOVING_TO_TARGET,
	CAPTURING,          # Conquest only
	CHASING_FLAG,       # CTF only
	RETURNING_FLAG,     # CTF only
	DEFENDING,
	ENGAGING_ENEMY
}

# Player data — populated on connect, cleared on disconnect
var players: Dictionary = {}
# Structure: { peer_id: { "name": "", "team": -1, "is_bot": false } }

func register_player(peer_id: int, data: Dictionary) -> void:
	players[peer_id] = data

func remove_player(peer_id: int) -> void:
	players.erase(peer_id)

func get_player(peer_id: int) -> Dictionary:
	return players.get(peer_id, {})

func clear_players() -> void:
	players.clear()
