extends CharacterBody2D

enum Pose { IDLE, WALK, RUN, ATTACK, HURT, DIE }

const ENEMY_SHEET := preload("res://Animation Sheets/Dungeon Enemy Warriors.png")
const BRUTE_SHEET := preload("res://Animation Sheets/Slime Brute.png")
const SHEET_SHADER := preload("res://slime_sheet.gdshader")
const SLIME_SCRIPT := preload("res://player.gd")
const WALK_SPEED := 92.0
const ATTACK_TIME := 0.4
const HURT_TIME := 0.16
const DEATH_TIME := 0.65

# Each row gives the top, foot line, and horizontal frame boundaries.
const SKELETON_ROWS := [
	[5, 55, [152, 204, 262, 321, 377, 429]],
	[56, 102, [151, 210, 272, 331, 387, 446, 512, 574]],
	[103, 143, [148, 210, 273, 333, 389, 452, 516, 582]],
	[143, 189, [148, 209, 272, 332, 387, 449, 519, 595, 666, 737, 789, 835]],
	[189, 233, [152, 211, 273, 326]],
	[240, 273, [144, 215, 288, 361, 420, 472, 506]],
]
const SLIME_ROWS := [
	[293, 333, [145, 207, 273, 340, 407, 472]],
	[342, 375, [145, 206, 275, 335, 412, 483, 552]],
	[384, 416, [143, 206, 271, 343, 418, 495, 573]],
	[420, 460, [143, 204, 273, 343, 412, 496, 590, 711, 879]],
	[469, 507, [143, 204, 271, 342, 410]],
	[516, 548, [143, 206, 274, 342, 414, 496, 578]],
]
const BRUTE_WALK := [125, 209, [135, 222, 322, 404, 499, 599, 696, 794]]
const BRUTE_ROWS := [
	[17, 105, [130, 234, 340, 446, 551, 654]],
	BRUTE_WALK,
	BRUTE_WALK,
	[226, 348, [131, 222, 316, 408, 500, 600, 700, 801, 915]],
	[373, 458, [130, 219, 309, 401, 492]],
	[480, 559, [130, 220, 308, 393, 480, 568, 657, 755, 855]],
]

const FOREST_FRAME_REFERENCE := Vector2(1024, 559)
const TREE_WALK := [72, 123, [132, 198, 274, 352, 430, 506, 577, 647, 715, 775, 839, 905]]
const TREE_ROWS := [
	[5, 69, [130, 202, 280, 357, 433, 507, 582]],
	TREE_WALK,
	TREE_WALK,
	[124, 183, [132, 202, 287, 360, 438, 516, 598, 675, 755, 841, 926]],
	[194, 275, [132, 201, 282, 353]],
	[194, 276, [352, 426, 505, 582, 657, 736, 818, 893, 982]],
]
const GOLEM_WALK := [348, 396, [129, 202, 277, 354, 429, 505, 584, 650, 733, 813, 892]]
const GOLEM_ROWS := [
	[286, 346, [128, 200, 276, 353, 429, 505, 582]],
	GOLEM_WALK,
	GOLEM_WALK,
	[398, 447, [129, 203, 280, 359, 436, 504, 587, 666, 752, 844, 914]],
	[448, 499, [129, 201, 276, 351, 428, 504, 576, 654, 737, 808]],
	[499, 551, [129, 202, 278, 353, 432, 507, 583, 661, 744, 829, 914, 996]],
]

@onready var sprite: Sprite2D = $Sprite2D
var forest_sheet: Texture2D
var frame_coordinate_scale := Vector2.ONE
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
var attack_duration := ATTACK_TIME
var attack_interval := 1.05
var attack_reach := 58.0
var attack_hits_after_windup := false
var heavy_hit_pending := false
var moving_frame_anchor := 22.0
var knockback_speed := 200.0
var death_timer := 0.0
var hurt_timer := 0.0
var animation_rows: Array

func _ready() -> void:
	add_to_group("enemies")
	sprite.texture = ENEMY_SHEET
	sprite.region_enabled = true
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sheet_material := ShaderMaterial.new()
	sheet_material.shader = SHEET_SHADER
	sprite.material = sheet_material
	animation_rows = SKELETON_ROWS
	sprite.scale = Vector2.ONE * 1.7
	match enemy_type:
		"slime":
			health = 5
			contact_damage = 2
			movement_speed = 64.0
			attack_interval = 1.25
			moving_frame_anchor = 27.0
			knockback_speed = 160.0
			animation_rows = SLIME_ROWS
			sprite.scale = Vector2.ONE * 2.0
		"brute":
			attack_hits_after_windup = true
			health = 8
			contact_damage = 3
			movement_speed = 46.0
			attack_duration = 0.8
			attack_interval = 1.65
			attack_reach = 84.0
			moving_frame_anchor = 43.0
			knockback_speed = 110.0
			animation_rows = BRUTE_ROWS
			sprite.texture = BRUTE_SHEET
			sprite.scale = Vector2.ONE * 1.25
			sheet_material.set_shader_parameter("matte_chroma", Vector2(0.025, 0.075))
		"tree_monster":
			health = 5
			contact_damage = 2
			movement_speed = 76.0
			attack_duration = 0.68
			attack_interval = 1.35
			attack_reach = 80.0
			moving_frame_anchor = 24.0
			animation_rows = TREE_ROWS
			sprite.scale = Vector2.ONE * 1.35
		"rock_golem":
			attack_hits_after_windup = true
			health = 8
			contact_damage = 3
			movement_speed = 46.0
			attack_duration = 0.85
			attack_interval = 1.7
			attack_reach = 76.0
			moving_frame_anchor = 29.0
			knockback_speed = 110.0
			animation_rows = GOLEM_ROWS
			sprite.scale = Vector2.ONE * 1.65
	if forest_sheet != null:
		sprite.texture = forest_sheet
		frame_coordinate_scale = forest_sheet.get_size() / FOREST_FRAME_REFERENCE
		sprite.scale /= frame_coordinate_scale
		sheet_material.set_shader_parameter("matte_chroma", Vector2(0.075, 0.19))
		sheet_material.set_shader_parameter("matte_lightness", Vector2(0.47, 0.80))
	_set_frame(Pose.IDLE, 0.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		death_timer += delta
		_set_frame(Pose.DIE, death_timer / DEATH_TIME)
		if death_timer >= DEATH_TIME:
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
	velocity.y += SLIME_SCRIPT.GRAVITY * delta
	var distance_x := target.global_position.x - global_position.x
	var target_in_reach := absf(distance_x) <= attack_reach and absf(target.global_position.y - global_position.y) < 90.0
	var in_combat := bool(controller.get("game_active"))
	if attack_hits_after_windup and attack_timer > 0.0:
		velocity.x = 0.0
		if heavy_hit_pending and attack_timer <= attack_duration * 0.5:
			heavy_hit_pending = false
			if in_combat and target_in_reach and distance_x * facing >= 0.0:
				controller.call("damage_player", contact_damage, -facing)
	elif absf(distance_x) > attack_reach:
		facing = signf(distance_x)
		velocity.x = facing * movement_speed
	else:
		velocity.x = 0.0
		if target_in_reach and attack_cooldown <= 0.0 and in_combat:
			if not is_zero_approx(distance_x):
				facing = signf(distance_x)
			attack_timer = attack_duration
			attack_cooldown = attack_interval
			heavy_hit_pending = attack_hits_after_windup
			if not heavy_hit_pending:
				controller.call("damage_player", contact_damage, -signf(distance_x))
	move_and_slide()
	_update_animation(distance_x)

func _update_animation(distance_x: float) -> void:
	if hurt_timer > 0.0:
		_set_frame(Pose.HURT, 1.0 - hurt_timer / HURT_TIME)
	elif attack_timer > 0.0:
		_set_frame(Pose.ATTACK, 1.0 - attack_timer / attack_duration)
	elif absf(distance_x) > 210.0 and not attack_hits_after_windup:
		_set_frame(Pose.RUN, fposmod(animation_time * 1.8, 1.0))
	elif absf(distance_x) > attack_reach:
		_set_frame(Pose.WALK, fposmod(animation_time * 1.3, 1.0))
	else:
		_set_frame(Pose.IDLE, fposmod(animation_time * 0.65, 1.0))

func _set_frame(pose: Pose, progress: float) -> void:
	var row: Array = animation_rows[pose]
	var edges: Array = row[2]
	var frame_count := edges.size() - 1
	var index := clampi(int(progress * frame_count), 0, frame_count - 1)
	var x: float = edges[index]
	var size := Vector2(edges[index + 1] - x, row[1] - row[0])
	var anchor_x := size.x * 0.5
	if pose in [Pose.WALK, Pose.RUN, Pose.ATTACK]:
		anchor_x = minf(anchor_x, moving_frame_anchor)
	sprite.region_rect = Rect2(Vector2(x, row[0]) * frame_coordinate_scale, size * frame_coordinate_scale)
	sprite.offset = Vector2((size.x * 0.5 - anchor_x) * facing, -size.y * 0.5) * frame_coordinate_scale
	sprite.flip_h = facing < 0.0

func take_damage(amount: int, knockback_direction: float) -> void:
	if is_dead:
		return
	health -= amount
	if is_instance_valid(controller):
		controller.call("spawn_hit_particles", global_position + Vector2(0.0, -42.0), health <= 0)
	velocity.x = knockback_direction * knockback_speed
	sprite.modulate = Color(1.25, 0.75, 0.55)
	hurt_timer = HURT_TIME
	if health <= 0:
		is_dead = true
		velocity = Vector2.ZERO
		collision_layer = 0
		sprite.modulate = Color.WHITE
		_set_frame(Pose.DIE, 0.0)
		if is_instance_valid(controller):
			controller.call("enemy_defeated")
