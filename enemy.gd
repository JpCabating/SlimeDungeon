extends CharacterBody2D

const ENEMY_SHEET := preload("res://Dungeon Enemies Clean.png")
const WALK_SPEED := 92.0
const GRAVITY := 1450.0

@onready var sprite: Sprite2D = $Sprite2D
var controller: Node
var target: CharacterBody2D
var enemy_type := "skeleton"
var health := 3
var contact_damage := 1
var movement_speed := WALK_SPEED
var is_dead := false
var facing := -1.0
var animation_time := 0.0
var attack_timer := 0.0
var attack_cooldown := 0.0
var death_timer := 0.0
var hurt_timer := 0.0

func _ready() -> void:
	add_to_group("enemies")
	sprite.texture = ENEMY_SHEET
	sprite.region_enabled = true
	sprite.centered = true
	if enemy_type == "orc":
		health = 5
		contact_damage = 2
		movement_speed = 64.0
		sprite.region_rect = Rect2(0, 430, 96, 100)
	else:
		health = 3
		sprite.region_rect = Rect2(0, 0, 96, 100)

func _physics_process(delta: float) -> void:
	if is_dead:
		death_timer += delta
		var dead_frame := mini(int(death_timer * 7.0), 3)
		if enemy_type == "orc":
			sprite.region_rect = Rect2(dead_frame * 98, 670, 96, 96)
		else:
			var skeleton_dead_frame := mini(int(death_timer * 7.0), 4)
			sprite.region_rect = Rect2(500 + skeleton_dead_frame * 98, 306, 96, 100)
		if death_timer >= 0.65:
			queue_free()
		return
	if not is_instance_valid(target) or not is_instance_valid(controller):
		return
	if hurt_timer > 0.0:
		hurt_timer -= delta
		if hurt_timer <= 0.0:
			sprite.modulate = Color.WHITE
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	animation_time += delta
	velocity.y += GRAVITY * delta
	var distance_x := target.global_position.x - global_position.x
	if absf(distance_x) > 58.0:
		facing = signf(distance_x)
		velocity.x = facing * movement_speed
		sprite.flip_h = facing < 0.0
	else:
		velocity.x = 0.0
		if attack_cooldown <= 0.0 and bool(controller.get("game_active")):
			attack_timer = 0.40
			attack_cooldown = 1.25 if enemy_type == "orc" else 1.05
			controller.call("damage_player", contact_damage, signf(global_position.x - target.global_position.x))
	move_and_slide()
	_update_animation(distance_x)

func _update_animation(distance_x: float) -> void:
	if attack_timer > 0.0:
		var frame := clampi(int((0.40 - attack_timer) * 17.5), 0, 6) if enemy_type == "orc" else clampi(int((0.40 - attack_timer) * 20.0), 0, 7)
		var row_y := 552 if enemy_type == "orc" else 207
		sprite.region_rect = Rect2(frame * 98, row_y, 96, 100)
	elif enemy_type == "orc":
		var frame := int(animation_time * (5.5 if absf(distance_x) > 58.0 else 2.0)) % 14
		sprite.region_rect = Rect2(frame * 98, 430, 96, 100)
	elif absf(distance_x) > 58.0:
		var frame := int(animation_time * 9.0) % 13
		sprite.region_rect = Rect2(frame * 98, 107, 96, 100)
	else:
		var frame := int(animation_time * 2.2) % 9
		sprite.region_rect = Rect2(frame * 98, 0, 96, 100)

func take_damage(amount: int, knockback_direction: float) -> void:
	if is_dead:
		return
	health -= amount
	velocity.x = knockback_direction * (160.0 if enemy_type == "orc" else 200.0)
	sprite.modulate = Color(1.25, 0.75, 0.55)
	hurt_timer = 0.16
	if health <= 0:
		is_dead = true
		velocity = Vector2.ZERO
		if is_instance_valid(controller):
			controller.call("enemy_defeated")
