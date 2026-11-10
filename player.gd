extends CharacterBody2D

const WALK_SPEED := 300.0
const RUN_SPEED := 440.0
const JUMP_VELOCITY := -560.0
const GRAVITY := 1450.0
const MELEE_TIME := 0.34
const FIREBALL_TIME := 0.56
const SLIME_SHEET := preload("res://Slime Frames Clean.png")
const SLIME_SCALE := Vector2(1.35, 1.35)
const FRAME_SIZE := 96

@onready var sprite: Sprite2D = $Sprite2D
var facing := 1.0
var controls_enabled := false
var animation_time := 0.0
var attack_animation_time := 0.0
var attack_animation_type := ""
var hurt_flash_time := 0.0

func _ready() -> void:
	sprite.texture = SLIME_SHEET
	sprite.region_enabled = true
	sprite.centered = true
	sprite.scale = SLIME_SCALE

func _physics_process(delta: float) -> void:
	if not controls_enabled:
		velocity = Vector2.ZERO
		return
	var direction := Input.get_axis("move_left", "move_right")
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction += 1.0
	direction = clampf(direction, -1.0, 1.0)
	var sprinting := Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)
	velocity.x = direction * (RUN_SPEED if sprinting else WALK_SPEED)
	if direction != 0.0:
		facing = signf(direction)
		sprite.flip_h = facing < 0.0
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	move_and_slide()
	animation_time += delta
	if attack_animation_time > 0.0:
		attack_animation_time = maxf(0.0, attack_animation_time - delta)
		if attack_animation_time == 0.0:
			attack_animation_type = ""
	hurt_flash_time = maxf(0.0, hurt_flash_time - delta)
	if hurt_flash_time == 0.0:
		modulate = Color.WHITE
	_update_animation(direction, sprinting)

func _set_frame(row: int, frame: int) -> void:
	sprite.region_rect = Rect2(frame * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)

func _update_animation(direction: float, sprinting: bool) -> void:
	if attack_animation_time > 0.0:
		if attack_animation_type == "fireball":
			var elapsed := FIREBALL_TIME - attack_animation_time
			_set_frame(5, clampi(int(elapsed / FIREBALL_TIME * 6.0), 0, 5))
		else:
			var elapsed := MELEE_TIME - attack_animation_time
			_set_frame(4, clampi(int(elapsed / MELEE_TIME * 5.0), 0, 4))
	elif not is_on_floor():
		_set_frame(3, int(animation_time * 8.0) % 5)
	elif absf(direction) < 0.01:
		_set_frame(0, int(animation_time * 2.0) % 5)
	elif sprinting:
		_set_frame(2, int(animation_time * 11.0) % 5)
	else:
		_set_frame(1, int(animation_time * 8.0) % 5)

func play_attack_animation() -> void:
	attack_animation_type = "melee"
	attack_animation_time = MELEE_TIME

func play_fireball_animation() -> void:
	attack_animation_type = "fireball"
	attack_animation_time = FIREBALL_TIME

func reset_animation_state() -> void:
	attack_animation_time = 0.0
	attack_animation_type = ""
	sprite.texture = SLIME_SHEET
	sprite.scale = SLIME_SCALE

func take_knockback(direction: float) -> void:
	velocity.x = direction * 190.0
	velocity.y = -165.0
	modulate = Color(1.0, 0.48, 0.48)
	hurt_flash_time = 0.22
