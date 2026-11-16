extends StaticBody2D

signal health_changed(value: int)
signal defeated

const SPRITE_SHADER := preload("res://grave_lord_sprite.gdshader")
const MAX_HEALTH := 48
const WINDUP_TIME := 0.85
const WARNING_SHEET := preload("res://Animation Sheets/Boss Cues.png")
const WARNING_COLUMNS := 4
const WARNING_ROW_TOPS := [60.0, 263.0, 469.0]
const WARNING_FRAME_SIZE := Vector2(543.0, 196.0)
const MISSILE_SPEED := 660.0
# Scale from the artwork inside the padded frame to preserve the boss silhouette size.
const SKULL_REFERENCE_HEIGHT := 194.0
const IDLE_FRAMES := [
	preload("res://grave_lord_frames/idle/01.png"),
	preload("res://grave_lord_frames/idle/02.png"),
	preload("res://grave_lord_frames/idle/03.png"),
	preload("res://grave_lord_frames/idle/04.png"),
	preload("res://grave_lord_frames/idle/05.png"),
	preload("res://grave_lord_frames/idle/06.png"),
	preload("res://grave_lord_frames/idle/07.png"),
	preload("res://grave_lord_frames/idle/08.png"),
	preload("res://grave_lord_frames/idle/09.png"),
	preload("res://grave_lord_frames/idle/10.png"),
	preload("res://grave_lord_frames/idle/11.png"),
	preload("res://grave_lord_frames/idle/12.png"),
]
const SCREAM_FRAMES := [
	preload("res://grave_lord_frames/scream_attack/01.png"),
	preload("res://grave_lord_frames/scream_attack/02.png"),
	preload("res://grave_lord_frames/scream_attack/03.png"),
	preload("res://grave_lord_frames/scream_attack/04.png"),
	preload("res://grave_lord_frames/scream_attack/05.png"),
	preload("res://grave_lord_frames/scream_attack/06.png"),
	preload("res://grave_lord_frames/scream_attack/07.png"),
	preload("res://grave_lord_frames/scream_attack/08.png"),
	preload("res://grave_lord_frames/scream_attack/09.png"),
]
const DEATH_FRAMES := [
	preload("res://grave_lord_frames/death/01.png"),
	preload("res://grave_lord_frames/death/02.png"),
	preload("res://grave_lord_frames/death/03.png"),
	preload("res://grave_lord_frames/death/04.png"),
	preload("res://grave_lord_frames/death/05.png"),
	preload("res://grave_lord_frames/death/06.png"),
	preload("res://grave_lord_frames/death/07.png"),
	preload("res://grave_lord_frames/death/08.png"),
	preload("res://grave_lord_frames/death/09.png"),
	preload("res://grave_lord_frames/death/10.png"),
	preload("res://grave_lord_frames/death/11.png"),
	preload("res://grave_lord_frames/death/12.png"),
	preload("res://grave_lord_frames/death/13.png"),
	preload("res://grave_lord_frames/death/14.png"),
]
const MISSILE_FRAMES := [
	preload("res://grave_lord_frames/projectile/01.png"),
	preload("res://grave_lord_frames/projectile/02.png"),
	preload("res://grave_lord_frames/projectile/03.png"),
	preload("res://grave_lord_frames/projectile/04.png"),
	preload("res://grave_lord_frames/projectile/05.png"),
	preload("res://grave_lord_frames/projectile/06.png"),
]

var target: CharacterBody2D
var controller: Node
var floors: Array[float]
var health := MAX_HEALTH
var is_dead := false
var hit_edge := 175.0
var height := 440.0
var arena_right := 1200.0
var age := 0.0
var next_attack := 2.3
var attack_lanes: Array[float] = []
var windup := 0.0
var hit_flash := 0.0
var sprite: Sprite2D
var warnings: Array[Sprite2D] = []
var missiles: Array[Sprite2D] = []

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("enemies")
	var hitbox := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(hit_edge * 2.0, floors[2] - floors[0] + 102.0)
	hitbox.shape = rectangle
	hitbox.position.y = (floors[0] + floors[2]) * 0.5 - 51.0 - position.y
	add_child(hitbox)

	sprite = Sprite2D.new()
	sprite.texture = IDLE_FRAMES[0]
	var material := ShaderMaterial.new()
	material.shader = SPRITE_SHADER
	sprite.material = material
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * height / SKULL_REFERENCE_HEIGHT
	sprite.offset.x = -12.0
	add_child(sprite)
	sprite.modulate.a = 0.0
	sprite.position.x = -100.0
	var entrance := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entrance.tween_property(sprite, "position:x", 0.0, 0.9)
	entrance.tween_property(sprite, "modulate:a", 1.0, 0.85)

	for index in range(2):
		var warning := Sprite2D.new()
		warning.name = "AttackCue%d" % (index + 1)
		warning.texture = WARNING_SHEET
		warning.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		warning.region_enabled = true
		warning.region_filter_clip_enabled = true
		warning.scale = Vector2(arena_right - hit_edge, 72.0) / WARNING_FRAME_SIZE
		warning.modulate.a = 0.88
		warning.z_index = 1
		warning.hide()
		add_child(warning)
		warnings.append(warning)

func _warning_frame(progress: float) -> Rect2:
	var frame_count := WARNING_COLUMNS * WARNING_ROW_TOPS.size()
	var frame := clampi(int(progress * frame_count), 0, frame_count - 1)
	var column := frame % WARNING_COLUMNS
	var row := floori(float(frame) / WARNING_COLUMNS)
	return Rect2(Vector2(column * WARNING_FRAME_SIZE.x, WARNING_ROW_TOPS[row]), WARNING_FRAME_SIZE)

func _begin_attack() -> void:
	var enraged := health <= MAX_HEALTH / 2.0
	next_attack = 1.20 if enraged else 1.80
	windup = WINDUP_TIME
	var floor_index := int(controller.call("get_level_for_surface", target.global_position))
	attack_lanes.assign([floors[floor_index] - 35.0 - global_position.y])
	if enraged:
		var adjacent_floor := 1 if floor_index != 1 else (0 if sin(age) >= 0.0 else 2)
		attack_lanes.append(floors[adjacent_floor] - 35.0 - global_position.y)
	for index in range(attack_lanes.size()):
		var lane := attack_lanes[index]
		var warning := warnings[index]
		warning.position = Vector2((hit_edge + arena_right) * 0.5, lane)
		warning.region_rect = _warning_frame(0.0)
		warning.show()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	age += delta
	sprite.position.y = sin(age * 2.2) * 11.0
	hit_flash = maxf(hit_flash - delta, 0.0)
	sprite.self_modulate = Color(1.0, 0.54, 0.55) if hit_flash > 0.0 else Color.WHITE
	if windup > 0.0:
		windup -= delta
		var frame_count := SCREAM_FRAMES.size()
		var progress := 1.0 - windup / WINDUP_TIME
		var frame := clampi(int(progress * frame_count), 0, frame_count - 1)
		var cue_frame := _warning_frame(progress)
		sprite.texture = SCREAM_FRAMES[frame]
		for index in range(attack_lanes.size()):
			warnings[index].region_rect = cue_frame
			if windup <= 0.0:
				warnings[index].hide()
				_launch_missile(attack_lanes[index])
	else:
		sprite.texture = IDLE_FRAMES[int(age * 9.0) % IDLE_FRAMES.size()]
		next_attack -= delta
		if next_attack <= 0.0:
			_begin_attack()

	for index in range(missiles.size() - 1, -1, -1):
		var missile := missiles[index]
		var previous_x := missile.global_position.x
		missile.position.x += MISSILE_SPEED * delta
		var frame := int((missile.position.x - hit_edge) / 42.0) % MISSILE_FRAMES.size()
		missile.texture = MISSILE_FRAMES[frame]
		var slime_center := target.global_position - Vector2(0.0, 31.0)
		var crossed_slime := slime_center.x >= previous_x - 36.0 and slime_center.x <= missile.global_position.x + 36.0
		if crossed_slime and absf(slime_center.y - missile.global_position.y) < 40.0:
			missile.queue_free()
			missiles.remove_at(index)
			controller.call("damage_player", 1, 1.0)
			if not bool(controller.get("game_active")):
				return
		elif missile.position.x > 1500.0:
			missile.queue_free()
			missiles.remove_at(index)

func _launch_missile(lane: float) -> void:
	var missile := Sprite2D.new()
	missile.name = "SoulMissile"
	missile.texture = MISSILE_FRAMES[0]
	missile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	missile.scale = Vector2.ONE * 0.9
	missile.offset.x = -24.0
	missile.material = sprite.material
	missile.position = Vector2(hit_edge, lane)
	add_child(missile)
	missiles.append(missile)

func take_damage(amount: int, _direction: float) -> void:
	if is_dead or age < 0.9:
		return
	health = maxi(0, health - mini(amount, 8))
	health_changed.emit(health)
	hit_flash = 0.12
	if health > 0:
		return
	is_dead = true
	set_deferred("collision_layer", 0)
	for warning in warnings:
		warning.hide()
	for missile in missiles:
		missile.queue_free()
	missiles.clear()
	var collapse := create_tween().set_parallel()
	var last_frame := DEATH_FRAMES.size() - 1
	collapse.tween_method(func(frame: float) -> void:
		sprite.texture = DEATH_FRAMES[int(frame)]
	, 0.0, float(last_frame), 0.8)
	collapse.tween_property(sprite, "modulate:a", 0.0, 0.25).set_delay(0.55)
	collapse.tween_property(sprite, "position:y", sprite.position.y + 56.0, 0.8)
	collapse.chain().tween_callback(func() -> void: defeated.emit())
