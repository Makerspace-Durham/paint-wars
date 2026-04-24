extends CharacterBody2D

# -- Nodes --
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var stun_timer: Timer = $StunTimer
@onready var flag_indicator: Label = $FlagIndicator

# -- Movement Constants --
const WALK_SPEED: float = 120.0
const RUN_SPEED: float = 220.0
const JUMP_FORCE: float = -380.0
const GRAVITY: float = 900.0
const GLIDE_GRAVITY: float = 120.0
const MAX_FALL_SPEED: float = 600.0
const GLIDE_MAX_FALL_SPEED: float = 60.0

# -- State --
var is_stunned: bool = false
var is_gliding: bool = false
var was_in_air: bool = false
var jump_held: bool = false

# -- Spray --
var can_spray: bool = true
var _spray_cooldown_timer: Timer

# -- CTF --
var is_carrying_flag: bool = false
var _carried_flag: Node = null

@onready var spray_hitbox: Area2D = $SprayHitbox

func _ready() -> void:
	stun_timer.timeout.connect(_on_stun_timer_timeout)

func _physics_process(delta: float) -> void:
	if is_stunned:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		_apply_gravity(delta)
		move_and_slide()
		_handle_spray()
		return

	_handle_movement()
	_handle_jump(delta)
	_apply_gravity(delta)
	_clamp_fall_speed()
	move_and_slide()
	_update_facing()

# -- Movement --

func _handle_movement() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var speed := WALK_SPEED

	if Input.is_action_pressed("run") and not is_carrying_flag:
		speed = RUN_SPEED

	if direction != 0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)

func _handle_jump(delta: float) -> void:
	jump_held = Input.is_action_pressed("jump")

	if is_on_floor():
		is_gliding = false
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_FORCE
	else:
		# Begin gliding if jump is held while airborne and falling
		if jump_held and velocity.y > 0:
			is_gliding = true
		elif not jump_held:
			is_gliding = false

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var grav := GLIDE_GRAVITY if is_gliding else GRAVITY
		velocity.y += grav * delta

func _clamp_fall_speed() -> void:
	var max_fall := GLIDE_MAX_FALL_SPEED if is_gliding else MAX_FALL_SPEED
	velocity.y = min(velocity.y, max_fall)

func _update_facing() -> void:
	if velocity.x < 0:
		animated_sprite.flip_h = true
		spray_hitbox.position.x = -20
	elif velocity.x > 0:
		animated_sprite.flip_h = false
		spray_hitbox.position.x = 20

# -- Stun --

func apply_stun() -> void:
	if is_stunned:
		return
	is_stunned = true
	velocity = Vector2.ZERO
	stun_timer.start(Constants.STUN_DURATION)
	anim_player.play("stun_tint")
	EventBus.player_stunned.emit(get_multiplayer_authority())

	# Drop flag if carrying
	if is_carrying_flag and _carried_flag:
		_carried_flag.drop_flag()
		set_carrying_flag(false)

func _on_stun_timer_timeout() -> void:
	is_stunned = false
	anim_player.play("clear_tint")

# -- Animation --

func _process(_delta: float) -> void:
	if is_stunned:
		_play_anim("hurt")
		return
	_update_animation()

func _update_animation() -> void:
	var anim := _get_target_animation()
	_play_anim(anim)

func _get_target_animation() -> String:
	# Airborne
	if not is_on_floor():
		if is_gliding:
			return "glide"
		elif velocity.y < 0:
			return "jump"
		else:
			return "fall"

	# Grounded
	if velocity.x == 0:
		return "idle"

	# Flag carrier uses walk speed only, no running
	if Input.is_action_pressed("run") and not is_carrying_flag:
		return "run"

	return "walk"

func _play_anim(anim_name: String) -> void:
	if animated_sprite.animation == anim_name:
		return
	animated_sprite.play(anim_name)

func play_spray_animation() -> void:
	if is_stunned:
		return
	animated_sprite.play("spray")
	await animated_sprite.animation_finished
	# State machine resumes naturally on next _process tick

# -- Spray --

func _handle_spray() -> void:
	if is_carrying_flag:
		return
	if Input.is_action_just_pressed("spray") and can_spray:
		_execute_spray()

func _execute_spray() -> void:
	can_spray = false
	play_spray_animation()
	_spray_cooldown_timer.start(Constants.SPRAY_COOLDOWN)

	# Only server authoritative hit detection
	if not multiplayer.is_server():
		_request_spray.rpc_id(1)
		return

	_check_spray_hits()

func _check_spray_hits() -> void:
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
	pass # Hits are checked on demand in _check_spray_hits, not on enter

func _on_spray_cooldown_timeout() -> void:
	can_spray = true

func set_carrying_flag(carrying: bool, flag: Node = null) -> void:
	is_carrying_flag = carrying
	_carried_flag = flag if carrying else null
	# Notify spray handler to block spraying while carrying
	_sync_carrying_flag.rpc(carrying)

# -- RPCs --

@rpc("any_peer", "reliable")
func _request_spray() -> void:
	if not multiplayer.is_server():
		return
	_check_spray_hits()

@rpc("authority", "call_local", "reliable")
func _sync_carrying_flag(carrying: bool) -> void:
	is_carrying_flag = carrying
	flag_indicator.visible = carrying
