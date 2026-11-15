extends CharacterBody2D

const WALK_SPEED := 300.0
const RUN_SPEED := 440.0
const JUMP_VELOCITY := -675.0
const GRAVITY := 1450.0
const PLATFORM_LAYER := 1
const GROUND_LAYER := 4
const WORLD_MASK := PLATFORM_LAYER | GROUND_LAYER
const MELEE_TIME := 0.34
const FIREBALL_TIME := 0.56
const LIGHTNING_TIME := 0.36
const LIGHTNING_SHEET := preload("res://Animation Sheets/Lightning Beam.png")
const IDLE_FRAMES := [
	Rect2i(139, 40, 112, 91), Rect2i(278, 38, 115, 93), Rect2i(421, 38, 112, 90),
	Rect2i(559, 38, 110, 89), Rect2i(698, 39, 110, 91), Rect2i(835, 41, 108, 87),
]
const WALK_FRAMES := [
	Rect2i(138, 186, 114, 86), Rect2i(279, 185, 122, 89), Rect2i(418, 185, 113, 89),
	Rect2i(558, 186, 110, 85), Rect2i(699, 183, 110, 91), Rect2i(837, 182, 117, 92),
]
const RUN_FRAMES := [
	Rect2i(126, 309, 125, 85), Rect2i(271, 312, 133, 87), Rect2i(412, 313, 125, 82),
	Rect2i(550, 309, 129, 85), Rect2i(688, 312, 123, 81), Rect2i(833, 315, 129, 80),
]
const JUMP_FRAMES := [
	Rect2i(137, 448, 114, 86), Rect2i(284, 438, 109, 87), Rect2i(420, 426, 115, 84),
	Rect2i(564, 435, 114, 86), Rect2i(695, 447, 128, 89), Rect2i(841, 452, 141, 88),
]
const CAST_FRAMES := [
	Rect2i(120, 574, 98, 76), Rect2i(218, 590, 82, 59),
	Rect2i(351, 582, 57, 67), Rect2i(453, 574, 107, 78),
]
const MELEE_FRAMES := [CAST_FRAMES[0], CAST_FRAMES[1], CAST_FRAMES[3]]
const LIGHTNING_FRAMES := [Rect2i(123, 593, 84, 58), Rect2i(894, 581, 106, 73)]

@onready var sprite: Sprite2D = $Sprite2D
@onready var default_sheet: Texture2D = sprite.texture
var facing := 1.0
var controls_enabled := false
var animation_time := 0.0
var attack_animation_time := 0.0
var attack_animation_type := ""
var hurt_flash_time := 0.0
var drop_through_time := 0.0
var drop_start_y := 0.0
var jump_key_was_pressed := false
var landing_time := 0.0

func _ready() -> void:
	_set_frame(IDLE_FRAMES[0])

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
	var jump_key_pressed := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var jump_just_pressed := Input.is_action_just_pressed("jump") or (jump_key_pressed and not jump_key_was_pressed)
	jump_key_was_pressed = jump_key_pressed
	var dropping_requested := Input.is_action_pressed("drop") and jump_just_pressed and is_on_floor()
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif dropping_requested:
		drop_start_y = global_position.y
		drop_through_time = 1.0
		collision_mask = GROUND_LAYER
		velocity.y = 80.0
	elif jump_just_pressed:
		velocity.y = JUMP_VELOCITY
	var was_on_floor := is_on_floor()
	move_and_slide()
	landing_time = maxf(0.0, landing_time - delta)
	if is_on_floor() and not was_on_floor:
		landing_time = 0.09
	if drop_through_time > 0.0:
		drop_through_time -= delta
		if is_on_floor() or global_position.y >= drop_start_y + 36.0 or drop_through_time <= 0.0:
			collision_mask = WORLD_MASK
			drop_through_time = 0.0
	animation_time += delta
	if attack_animation_time > 0.0:
		attack_animation_time = maxf(0.0, attack_animation_time - delta)
		if attack_animation_time == 0.0:
			attack_animation_type = ""
	hurt_flash_time = maxf(0.0, hurt_flash_time - delta)
	if hurt_flash_time == 0.0:
		modulate = Color.WHITE
	_update_animation(direction, sprinting)

func _set_frame(frame: Rect2i) -> void:
	sprite.region_rect = Rect2(frame)
	sprite.offset = Vector2(0.0, -frame.size.y * 0.5)

func _update_animation(direction: float, sprinting: bool) -> void:
	if attack_animation_time > 0.0 and attack_animation_type == "lightning":
		sprite.texture = LIGHTNING_SHEET
		_set_frame(LIGHTNING_FRAMES[0 if attack_animation_time > 0.26 else 1])
		return
	sprite.texture = default_sheet
	if attack_animation_time > 0.0:
		var casting := attack_animation_type == "fireball"
		var frames := CAST_FRAMES if casting else MELEE_FRAMES
		var duration := FIREBALL_TIME if casting else MELEE_TIME
		var progress := 1.0 - attack_animation_time / duration
		_set_frame(frames[clampi(int(progress * frames.size()), 0, frames.size() - 1)])
	elif not is_on_floor():
		var frame := clampi(int(remap(velocity.y, JUMP_VELOCITY, -JUMP_VELOCITY, 0.0, 5.0)), 0, 4)
		_set_frame(JUMP_FRAMES[frame])
	elif landing_time > 0.0:
		_set_frame(JUMP_FRAMES[5])
	elif absf(direction) < 0.01:
		_set_frame(IDLE_FRAMES[int(animation_time * 4.0) % IDLE_FRAMES.size()])
	elif sprinting:
		_set_frame(RUN_FRAMES[int(animation_time * 14.0) % RUN_FRAMES.size()])
	else:
		_set_frame(WALK_FRAMES[int(animation_time * 11.0) % WALK_FRAMES.size()])

func play_attack_animation() -> void:
	attack_animation_type = "melee"
	attack_animation_time = MELEE_TIME

func play_fireball_animation() -> void:
	attack_animation_type = "fireball"
	attack_animation_time = FIREBALL_TIME

func play_lightning_animation() -> void:
	attack_animation_type = "lightning"
	attack_animation_time = LIGHTNING_TIME

func reset_animation_state() -> void:
	attack_animation_time = 0.0
	attack_animation_type = ""
	drop_through_time = 0.0
	jump_key_was_pressed = false
	collision_mask = WORLD_MASK
	landing_time = 0.0
	sprite.texture = default_sheet
	_set_frame(IDLE_FRAMES[0])

func take_knockback(direction: float) -> void:
	velocity.x = direction * 190.0
	velocity.y = -165.0
	modulate = Color(1.0, 0.48, 0.48)
	hurt_flash_time = 0.22
