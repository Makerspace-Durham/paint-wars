extends CharacterBody2D

# -- Shared with player.gd --
const WALK_SPEED: float = 120.0
const RUN_SPEED: float = 220.0
const JUMP_FORCE: float = -380.0
const GRAVITY: float = 900.0
const GLIDE_GRAVITY: float = 120.0
const MAX_FALL_SPEED: float = 600.0
const GLIDE_MAX_FALL_SPEED: float = 60.0

# -- Nodes --
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var stun_timer: Timer = $StunTimer
@onready var spray_hitbox: Area2D = $SprayHitbox
@onready var bot_timer: Timer = $BotTimer
@onready var flag_indicator: Label = $FlagIndicator

# -- State --
var team: int = Constants.TEAM_B
var current_state: BotState = BotState.IDLE
var target_position: Vector2 = Vector2.ZERO
var target_node: Node = null
var is_stunned: bool = false
var is_gliding: bool = false
var is_carrying_flag: bool = false
var _carried_flag: Node = null
var can_spray: bool = true
var _spray_cooldown_timer: Timer

enum BotState {
	IDLE,
	MOVING_TO_TARGET,
	CAPTURING,
	CHASING_FLAG,
	RETURNING_FLAG,
	DEFENDING,
	ENGAGING_ENEMY
}

func _ready() -> void:
	stun_timer.timeout.connect(_on_stun_timer_timeout)
	bot_timer.wait_time = Constants.BOT_DECISION_RATE
	bot_timer.timeout.connect(_on_decision_tick)
	bot_timer.start()

	_spray_cooldown_timer = Timer.new()
	_spray_cooldown_timer.one_shot = true
	_spray_cooldown_timer.timeout.connect(_on_spray_cooldown_timeout)
	add_child(_spray_cooldown_timer)

	spray_hitbox.body_entered.connect(_on_spray_hitbox_body_entered)
	add_to_group("players")

func _on_decision_tick() -> void:
	if is_stunned:
		return
	_update_moving_targets()
	_make_decision()

func _update_moving_targets() -> void:
	match current_state:
		BotState.ENGAGING_ENEMY:
			if target_node and is_instance_valid(target_node):
				target_position = target_node.global_position
		BotState.CHASING_FLAG:
			if target_node and is_instance_valid(target_node):
				target_position = target_node.global_position
		BotState.DEFENDING:
			if target_node and is_instance_valid(target_node):
				target_position = target_node.global_position

func _make_decision() -> void:
	# Check for nearby enemies to engage first
	var nearby_enemy := _get_nearest_enemy()
	if nearby_enemy and not is_carrying_flag:
		var dist := global_position.distance_to(nearby_enemy.global_position)
		if dist <= Constants.BOT_SPRAY_RANGE:
			current_state = BotState.ENGAGING_ENEMY
			target_node = nearby_enemy
			return

	# Mode specific decision
	match GameManager.current_mode:
		Constants.GameMode.CONQUEST:
			_decide_conquest()
		Constants.GameMode.CAPTURE_THE_FLAG:
			_decide_ctf()

func _get_nearest_enemy() -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for player in get_tree().get_nodes_in_group("players"):
		if player == self:
			continue
		var player_data := Constants.get_player(player.get_multiplayer_authority())
		if player_data.get("team", -1) == team:
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = player
	return nearest

# -- Physics --

func _physics_process(delta: float) -> void:
	if is_stunned:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		_apply_gravity(delta)
		move_and_slide()
		_update_animation()
		return

	_handle_bot_movement(delta)
	_apply_gravity(delta)
	_clamp_fall_speed()
	move_and_slide()
	_handle_bot_actions()
	_update_facing()
	_update_animation()

# -- Movement --

func _handle_bot_movement(_delta: float) -> void:
	match current_state:
		BotState.IDLE:
			velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		BotState.MOVING_TO_TARGET, \
		BotState.CAPTURING, \
		BotState.CHASING_FLAG, \
		BotState.RETURNING_FLAG, \
		BotState.DEFENDING:
			_move_toward_target()
		BotState.ENGAGING_ENEMY:
			_engage_enemy()

func _move_toward_target() -> void:
	if target_position == Vector2.ZERO:
		current_state = BotState.IDLE
		return

	var direction = sign(target_position.x - global_position.x)
	var dist := global_position.distance_to(target_position)

	if dist <= Constants.BOT_REACH_THRESHOLD:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		_on_target_reached()
		return

	# Run if carrying flag or far from target
	var speed := RUN_SPEED if not is_carrying_flag else WALK_SPEED
	velocity.x = direction * speed
	_handle_bot_jump()

func _engage_enemy() -> void:
	if not target_node or not is_instance_valid(target_node):
		current_state = BotState.IDLE
		target_node = null
		return

	target_position = target_node.global_position
	var direction = sign(target_position.x - global_position.x)
	var dist := global_position.distance_to(target_position)

	# Close enough to spray, stop and spray
	if dist <= Constants.BOT_SPRAY_RANGE:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		return

	velocity.x = direction * RUN_SPEED
	_handle_bot_jump()

# -- Jumping --

func _handle_bot_jump() -> void:
	if not is_on_floor():
		return

	# Jump if target is significantly above
	var y_diff := target_position.y - global_position.y
	if y_diff < Constants.BOT_JUMP_THRESHOLD:
		velocity.y = JUMP_FORCE

func _handle_bot_glide() -> void:
	# Glide if falling and target is far horizontally
	if not is_on_floor() and velocity.y > 0:
		var h_dist= abs(target_position.x - global_position.x)
		if h_dist > 100.0:
			is_gliding = true
			return
	is_gliding = false

# -- Gravity --

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		_handle_bot_glide()
		var grav := GLIDE_GRAVITY if is_gliding else GRAVITY
		velocity.y += grav * delta

func _clamp_fall_speed() -> void:
	var max_fall := GLIDE_MAX_FALL_SPEED if is_gliding else MAX_FALL_SPEED
	velocity.y = min(velocity.y, max_fall)

# -- Facing --

func _update_facing() -> void:
	if velocity.x < 0:
		animated_sprite.flip_h = true
		spray_hitbox.position.x = -20
	elif velocity.x > 0:
		animated_sprite.flip_h = false
		spray_hitbox.position.x = 20

# -- Actions --

func _handle_bot_actions() -> void:
	match current_state:
		BotState.ENGAGING_ENEMY:
			_try_spray()

func _try_spray() -> void:
	if not can_spray or is_carrying_flag:
		return
	if not target_node or not is_instance_valid(target_node):
		return
	var dist := global_position.distance_to(target_node.global_position)
	if dist <= Constants.BOT_SPRAY_RANGE:
		_execute_spray()

func _execute_spray() -> void:
	can_spray = false
	_spray_cooldown_timer.start(Constants.SPRAY_COOLDOWN)
	for body in spray_hitbox.get_overlapping_bodies():
		if body == self:
			continue
		if body.has_method("apply_stun"):
			body.apply_stun()
			EventBus.player_sprayed.emit(
				body.get_multiplayer_authority(),
				get_multiplayer_authority()
			)

func _on_spray_hitbox_body_entered(_body: Node) -> void:
	pass

func _on_spray_cooldown_timeout() -> void:
	can_spray = true

# -- Target Reached --

func _on_target_reached() -> void:
	match current_state:
		BotState.CAPTURING:
			pass # Paint spot handles capture logic
		BotState.DEFENDING:
			current_state = BotState.IDLE
		_:
			current_state = BotState.IDLE

func apply_stun() -> void:
	if is_stunned:
		return
	is_stunned = true
	velocity = Vector2.ZERO
	stun_timer.start(Constants.STUN_DURATION)
	anim_player.play("stun_tint")
	EventBus.player_stunned.emit(get_multiplayer_authority())

	if is_carrying_flag and _carried_flag:
		_carried_flag.drop_flag()
		set_carrying_flag(false)

func _on_stun_timer_timeout() -> void:
	is_stunned = false
	anim_player.play("clear_tint")

func set_carrying_flag(carrying: bool, flag: Node = null) -> void:
	is_carrying_flag = carrying
	_carried_flag = flag if carrying else null
	flag_indicator.visible = carrying

func _update_animation() -> void:
	if is_stunned:
		_play_anim("hurt")
		return

	if not is_on_floor():
		if is_gliding:
			_play_anim("glide")
		elif velocity.y < 0:
			_play_anim("jump")
		else:
			_play_anim("fall")
		return

	if velocity.x == 0:
		_play_anim("idle")
		return

	if abs(velocity.x) >= RUN_SPEED:
		_play_anim("run")
	else:
		_play_anim("walk")

func _play_anim(anim_name: String) -> void:
	if animated_sprite.animation == anim_name:
		return
	animated_sprite.play(anim_name)

# -- Conquest --

func _decide_conquest() -> void:
	# If an enemy is nearby, engage first
	var nearby_enemy := _get_nearest_enemy()
	if nearby_enemy:
		var dist := global_position.distance_to(nearby_enemy.global_position)
		if dist <= Constants.BOT_SPRAY_RANGE * 2.0:
			current_state = BotState.ENGAGING_ENEMY
			target_node = nearby_enemy
			return

	# Find best paint spot to target
	var target_spot := _get_best_paint_spot()
	if target_spot:
		current_state = BotState.CAPTURING
		target_node = target_spot
		target_position = target_spot.global_position
		return

	current_state = BotState.IDLE

func _get_best_paint_spot() -> Node:
	var spots := get_tree().get_nodes_in_group("paint_spots")
	var best: Node = null
	var best_score: float = -INF

	for spot in spots:
		# Prioritize neutral spots, then enemy owned spots
		var spot_score: float = 0.0
		if spot.owning_team == -1:
			spot_score = 100.0
		elif spot.owning_team != team:
			spot_score = 50.0
		else:
			continue # Skip own spots

		# Closer spots get a small bonus
		var dist := global_position.distance_to(spot.global_position)
		spot_score -= dist * 0.01

		if spot_score > best_score:
			best_score = spot_score
			best = spot

	return best

# -- CTF --

func _decide_ctf() -> void:
	# If already carrying flag, return it to base
	if is_carrying_flag:
		var base := _get_own_base()
		if base:
			current_state = BotState.RETURNING_FLAG
			target_position = base.global_position
		return

	# If own flag is missing, defend/retrieve it
	var own_flag := _get_own_flag()
	if own_flag and not own_flag.is_at_home:
		# If enemy is carrying our flag, engage them
		if own_flag.carrier and own_flag.carrier.get("team", -1) != team:
			current_state = BotState.ENGAGING_ENEMY
			target_node = own_flag.carrier
			return
		# Flag is on ground, go retrieve it
		current_state = BotState.DEFENDING
		target_position = own_flag.global_position
		return

	# Go after enemy flag
	var enemy_flag := _get_enemy_flag()
	if enemy_flag:
		# If someone on our team already has it, defend them
		if enemy_flag.carrier:
			var carrier_data := Constants.get_player(
				enemy_flag.carrier.get_multiplayer_authority()
			)
			if carrier_data.get("team", -1) == team:
				current_state = BotState.DEFENDING
				target_node = enemy_flag.carrier
				target_position = enemy_flag.carrier.global_position
				return

		current_state = BotState.CHASING_FLAG
		target_position = enemy_flag.global_position
		target_node = enemy_flag
		return

	current_state = BotState.IDLE

func _get_enemy_flag() -> Node:
	for flag in get_tree().get_nodes_in_group("flags"):
		if flag.team != team:
			return flag
	return null

func _get_own_flag() -> Node:
	for flag in get_tree().get_nodes_in_group("flags"):
		if flag.team == team:
			return flag
	return null

func _get_own_base() -> Node:
	for base in get_tree().get_nodes_in_group("bases"):
		if base.team == team:
			return base
	return null
