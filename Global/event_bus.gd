extends Node

# -- UI --
signal scene_change_requested(scene_path: String)
signal scores_synced(scores: Dictionary)

# -- Game --
signal game_started()
signal game_ended(winning_team: int)

# -- Network --
signal lobby_updated(players: Array)
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal host_disconnected()

# -- Player --
signal player_stunned(player_id: int)
signal player_sprayed(player_id: int, attacker_id: int)

# -- Conquest --
signal paint_spot_captured(spot_id: int, team: int)
signal score_updated(team: int, score: int)

# -- CTF --
signal flag_picked_up(player_id: int, team: int)
signal flag_dropped(player_id: int, team: int)
signal flag_captured(team: int)
signal ctf_captures_synced(captures: Dictionary)
