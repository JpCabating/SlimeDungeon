extends Node2D

const DUNGEON_FLOOR_Y := 280.0
const ENEMY_SCRIPT := preload("res://enemy.gd")
const PICKUP_SCRIPT := preload("res://fireball_pickup.gd")
const PROJECTILE_SCRIPT := preload("res://fireball_projectile.gd")
const ENEMIES_PER_WAVE := 10
const PLAYER_MAX_HEALTH := 5
const ATTACK_DAMAGE := 2
const ATTACK_RANGE := 142.0
const ATTACK_COOLDOWN := 0.48

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var enemy_root: Node2D = $WorldEnemies
@onready var backdrop_tiles: Array[Sprite2D] = [
	$Background/TileLeft2,
	$Background/TileLeft1,
	$Background/TileCenter,
	$Background/TileRight1,
	$Background/TileRight2,
]
@onready var hearts_label: Label = $HUD/Controls

var status_label: Label
var fireball_label: Label
var menu_overlay: Control
var end_overlay: Control
var wave_option: OptionButton
var end_title: Label
var end_message: Label
var phase := "menu"
var game_active := false
var total_waves := 3
var current_wave := 0
var spawned_this_wave := 0
var defeated_this_wave := 0
var player_health := PLAYER_MAX_HEALTH
var spawn_timer := 0.0
var damage_cooldown := 0.0
var attack_cooldown := 0.0
var transition_after_spawn := false
var next_spawn_side := 1.0
var fireball_charges := 0
var fireball_cooldown := 0.0
var pickup_spawn_timer := 0.0
var active_fireball_pickup: Area2D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	_ensure_key_binding("move_left", KEY_LEFT)
	_ensure_key_binding("move_right", KEY_RIGHT)
	_ensure_key_binding("jump", KEY_W)
	_ensure_key_binding("jump", KEY_UP)
	_ensure_key_binding("attack", KEY_J)
	rng.randomize()
	player.add_to_group("player")
	_layout_background()
	get_viewport().size_changed.connect(_layout_background)
	camera.make_current()
	player.set("controls_enabled", false)
	_build_hud()
	_build_main_menu()
	_build_end_overlay()
	_update_hud()

func _ensure_key_binding(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)

func _layout_background() -> void:
	var texture := backdrop_tiles[0].texture
	var tile_scale := get_viewport_rect().size.y / float(texture.get_height())
	var floor_offset := (DUNGEON_FLOOR_Y - texture.get_height() * 0.5) * tile_scale
	camera.global_position.y = player.global_position.y - floor_offset
	for tile in backdrop_tiles:
		tile.scale = Vector2.ONE * tile_scale

func _process(delta: float) -> void:
	camera.global_position.x = player.global_position.x
	var texture := backdrop_tiles[0].texture
	var tile_scale := get_viewport_rect().size.y / float(texture.get_height())
	var tile_width := texture.get_width() * tile_scale
	var base := floori(player.global_position.x / tile_width)
	for index in range(backdrop_tiles.size()):
		var tile_index := base + index - 2
		backdrop_tiles[index].global_position = Vector2(tile_index * tile_width, camera.global_position.y)
	if not game_active:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	damage_cooldown = maxf(0.0, damage_cooldown - delta)
	fireball_cooldown = maxf(0.0, fireball_cooldown - delta)
	if not is_instance_valid(active_fireball_pickup) and fireball_charges == 0:
		pickup_spawn_timer -= delta
		if pickup_spawn_timer <= 0.0:
			_spawn_fireball_pickup()
	if spawn_timer > 0.0:
		spawn_timer -= delta
	if spawn_timer <= 0.0:
		if transition_after_spawn:
			transition_after_spawn = false
			if current_wave >= total_waves:
				_finish_game(true)
			else:
				_begin_wave(current_wave + 1)
		elif spawned_this_wave < ENEMIES_PER_WAVE:
			_spawn_enemy_group()
	_update_hud()
func _unhandled_input(event: InputEvent) -> void:
	if not game_active:
		return
	if event.is_action_pressed("fireball"):
		_cast_fireball()
		get_viewport().set_input_as_handled()
		return
	if attack_cooldown > 0.0:
		return
	var pressed_attack := event.is_action_pressed("attack")
	if event is InputEventMouseButton:
		pressed_attack = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if pressed_attack:
		_attack()
		get_viewport().set_input_as_handled()
func _build_hud() -> void:
	hearts_label.offset_left = 22
	hearts_label.offset_top = 16
	hearts_label.offset_right = 350
	hearts_label.offset_bottom = 56
	hearts_label.add_theme_font_size_override("font_size", 28)
	hearts_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.34))
	fireball_label = Label.new()
	fireball_label.position = Vector2(22, 58)
	fireball_label.size = Vector2(330, 34)
	fireball_label.add_theme_font_size_override("font_size", 18)
	fireball_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.44))
	$HUD.add_child(fireball_label)
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status_label.offset_left = -460
	status_label.offset_top = 20
	status_label.offset_right = -24
	status_label.offset_bottom = 58
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 21)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	$HUD.add_child(status_label)
	hearts_label.visible = false
	fireball_label.visible = false
	status_label.visible = false

func _update_hud() -> void:
	hearts_label.text = "♥ ".repeat(player_health) + "♡ ".repeat(PLAYER_MAX_HEALTH - player_health)
	fireball_label.text = "FIREBALL × %d   [RMB]" % fireball_charges
	status_label.text = "WAVE %d / %d     ENEMIES %d / %d" % [current_wave, total_waves, defeated_this_wave, ENEMIES_PER_WAVE]
func _build_main_menu() -> void:
	menu_overlay = _make_overlay("SLIME DUNGEON", "Fight through waves of dungeon enemies.\nMove: A / D or arrows    Attack: J or click\nJump: Space / W / ↑    Run: Shift\nFireball pickup: 3 shots · press RMB")
	var box := menu_overlay.get_node("Center/Panel/Content") as VBoxContainer
	var count_label := Label.new()
	count_label.text = "NUMBER OF WAVES"
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 18)
	box.add_child(count_label)
	wave_option = OptionButton.new()
	wave_option.add_item("1 wave · 10 enemies")
	wave_option.set_item_metadata(0, 1)
	wave_option.add_item("3 waves · 30 enemies")
	wave_option.set_item_metadata(1, 3)
	wave_option.add_item("5 waves · 50 enemies")
	wave_option.set_item_metadata(2, 5)
	wave_option.add_item("10 waves · 100 enemies")
	wave_option.set_item_metadata(3, 10)
	wave_option.select(1)
	box.add_child(wave_option)
	var start_button := Button.new()
	start_button.text = "ENTER THE DUNGEON"
	start_button.custom_minimum_size.y = 52
	start_button.pressed.connect(_start_selected_game)
	box.add_child(start_button)
	menu_overlay.visible = true

func _build_end_overlay() -> void:
	end_overlay = _make_overlay("", "")
	var box := end_overlay.get_node("Center/Panel/Content") as VBoxContainer
	end_title = Label.new()
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.add_theme_font_size_override("font_size", 34)
	box.add_child(end_title)
	end_message = Label.new()
	end_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_message.add_theme_font_size_override("font_size", 19)
	box.add_child(end_message)
	var restart := Button.new()
	restart.text = "PLAY AGAIN"
	restart.custom_minimum_size.y = 50
	restart.pressed.connect(_restart_game)
	box.add_child(restart)
	var menu_button := Button.new()
	menu_button.text = "MAIN MENU"
	menu_button.custom_minimum_size.y = 46
	menu_button.pressed.connect(_return_to_menu)
	box.add_child(menu_button)
	end_overlay.visible = false

func _make_overlay(title_text: String, subtitle_text: String) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	$HUD.add_child(overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.045, 0.82)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(470, 420)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	if not title_text.is_empty():
		var title := Label.new()
		title.text = title_text
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 34)
		content.add_child(title)
	if not subtitle_text.is_empty():
		var subtitle := Label.new()
		subtitle.text = subtitle_text
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 18)
		content.add_child(subtitle)
	return overlay

func _start_selected_game() -> void:
	total_waves = int(wave_option.get_selected_metadata())
	_start_game()

func _restart_game() -> void:
	_start_game()

func _start_game() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	_clear_ability_nodes()
	phase = "playing"
	game_active = true
	player_health = PLAYER_MAX_HEALTH
	fireball_charges = 0
	fireball_cooldown = 0.0
	pickup_spawn_timer = rng.randf_range(5.0, 9.0)
	current_wave = 0
	spawned_this_wave = 0
	defeated_this_wave = 0
	spawn_timer = 0.0
	damage_cooldown = 0.8
	attack_cooldown = 0.0
	transition_after_spawn = false
	next_spawn_side = 1.0
	player.global_position = Vector2(0, 576)
	player.velocity = Vector2.ZERO
	player.call("reset_animation_state")
	player.set("controls_enabled", true)
	menu_overlay.visible = false
	end_overlay.visible = false
	hearts_label.visible = true
	fireball_label.visible = true
	status_label.visible = true
	_begin_wave(1)
func _begin_wave(number: int) -> void:
	current_wave = number
	spawned_this_wave = 0
	defeated_this_wave = 0
	spawn_timer = 0.75
	_update_hud()

func _spawn_enemy_group() -> void:
	var remaining := ENEMIES_PER_WAVE - spawned_this_wave
	var group_size := mini(rng.randi_range(2, 3), remaining)
	for group_index in range(group_size):
		_spawn_enemy(group_index)
	next_spawn_side *= -1.0
	if spawned_this_wave < ENEMIES_PER_WAVE:
		spawn_timer = rng.randf_range(4.5, 6.0)

func _spawn_enemy(group_index: int) -> void:
	if not game_active:
		return
	var enemy := CharacterBody2D.new()
	var enemy_is_orc := spawned_this_wave % 2 == 1
	var enemy_name_prefix := "Orc_" if enemy_is_orc else "Skeleton_"
	enemy.name = enemy_name_prefix + str(spawned_this_wave + 1).pad_zeros(2)
	enemy.set_script(ENEMY_SCRIPT)
	enemy.set("controller", self)
	enemy.set("target", player)
	enemy.set("enemy_type", "orc" if enemy_is_orc else "skeleton")
	enemy.position = player.global_position + Vector2(next_spawn_side * (430.0 + group_index * 90.0), 0.0)
	enemy.collision_layer = 1
	enemy.collision_mask = 1
	var body_shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 26.0 if enemy_is_orc else 22.0
	capsule.height = 64.0 if enemy_is_orc else 56.0
	body_shape.shape = capsule
	body_shape.position.y = -32.0 if enemy_is_orc else -28.0
	enemy.add_child(body_shape)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.centered = true
	sprite.position.y = -45.0 if enemy_is_orc else -43.0
	sprite.scale = Vector2(1.42, 1.42) if enemy_is_orc else Vector2(1.28, 1.28)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 430, 96, 100) if enemy_is_orc else Rect2(0, 0, 96, 100)
	enemy.add_child(sprite)
	enemy_root.add_child(enemy)
	enemy.add_to_group("enemies")
	spawned_this_wave += 1
	_update_hud()
func _attack() -> void:
	if not game_active or attack_cooldown > 0.0:
		return
	attack_cooldown = ATTACK_COOLDOWN
	player.call("play_attack_animation")
	var facing := float(player.get("facing"))
	var closest: Node
	var closest_distance := ATTACK_RANGE + 1.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if bool(enemy.get("is_dead")):
			continue
		var delta_position: Vector2 = enemy.global_position - player.global_position
		var forward_distance := delta_position.x * facing
		if forward_distance < -24.0 or forward_distance > ATTACK_RANGE or absf(delta_position.y) > 90.0:
			continue
		if forward_distance < closest_distance:
			closest_distance = forward_distance
			closest = enemy
	if is_instance_valid(closest):
		closest.call("take_damage", ATTACK_DAMAGE, facing)

func _cast_fireball() -> void:
	if fireball_charges <= 0 or fireball_cooldown > 0.0:
		return
	fireball_charges -= 1
	fireball_cooldown = 0.30
	var direction := float(player.get("facing"))
	player.call("play_fireball_animation")
	var projectile := Area2D.new()
	projectile.name = "FireballProjectile"
	projectile.set_script(PROJECTILE_SCRIPT)
	projectile.set("direction", direction)
	projectile.position = player.global_position + Vector2(direction * 58.0, -52.0)
	projectile.collision_layer = 0
	projectile.collision_mask = 1
	var projectile_shape := CollisionShape2D.new()
	var projectile_circle := CircleShape2D.new()
	projectile_circle.radius = 18.0
	projectile_shape.shape = projectile_circle
	projectile.add_child(projectile_shape)
	var projectile_sprite := Sprite2D.new()
	projectile_sprite.name = "Sprite2D"
	projectile_sprite.scale = Vector2(1.2, 1.2)
	projectile.add_child(projectile_sprite)
	enemy_root.add_child(projectile)
	if fireball_charges == 0:
		pickup_spawn_timer = rng.randf_range(4.0, 7.0)
	_update_hud()

func _spawn_fireball_pickup() -> void:
	if not game_active or fireball_charges > 0 or is_instance_valid(active_fireball_pickup):
		return
	var pickup := Area2D.new()
	pickup.name = "FireballPickup"
	pickup.set_script(PICKUP_SCRIPT)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	pickup.global_position = player.global_position + Vector2(side * rng.randf_range(180.0, 360.0), -52.0)
	pickup.collision_layer = 0
	pickup.collision_mask = 1
	var pickup_shape := CollisionShape2D.new()
	var pickup_circle := CircleShape2D.new()
	pickup_circle.radius = 30.0
	pickup_shape.shape = pickup_circle
	pickup.add_child(pickup_shape)
	var pickup_sprite := Sprite2D.new()
	pickup_sprite.name = "Sprite2D"
	pickup_sprite.scale = Vector2(0.9, 0.9)
	pickup.add_child(pickup_sprite)
	pickup.connect("picked_up", Callable(self, "_on_fireball_pickup_collected"))
	pickup.connect("expired", Callable(self, "_on_fireball_pickup_expired"))
	enemy_root.add_child(pickup)
	active_fireball_pickup = pickup

func _on_fireball_pickup_collected(pickup: Area2D) -> void:
	if pickup != active_fireball_pickup:
		return
	active_fireball_pickup = null
	fireball_charges = 3
	pickup_spawn_timer = rng.randf_range(5.0, 8.0)
	_update_hud()

func _on_fireball_pickup_expired(pickup: Area2D) -> void:
	if pickup == active_fireball_pickup:
		active_fireball_pickup = null
		pickup_spawn_timer = rng.randf_range(4.0, 7.0)

func _clear_ability_nodes() -> void:
	for node in get_tree().get_nodes_in_group("fireball_pickups"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group("fireball_projectiles"):
		node.queue_free()
	active_fireball_pickup = null
func damage_player(amount: int, knockback_direction: float) -> void:
	if not game_active or damage_cooldown > 0.0:
		return
	damage_cooldown = 0.9
	player_health = maxi(0, player_health - amount)
	player.call("take_knockback", knockback_direction)
	_update_hud()
	if player_health <= 0:
		_finish_game(false)

func enemy_defeated() -> void:
	if not game_active:
		return
	defeated_this_wave += 1
	if defeated_this_wave >= ENEMIES_PER_WAVE:
		transition_after_spawn = true
		spawn_timer = 1.0
	_update_hud()
func _finish_game(won: bool) -> void:
	game_active = false
	_clear_ability_nodes()
	phase = "win" if won else "game_over"
	player.set("controls_enabled", false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	hearts_label.visible = false
	fireball_label.visible = false
	status_label.visible = false
	end_title.text = "DUNGEON CLEARED!" if won else "GAME OVER"
	if won:
		end_message.text = "You defeated all %d waves and %d enemies." % [total_waves, total_waves * ENEMIES_PER_WAVE]
	else:
		end_message.text = "You fell during wave %d.\nThe dungeon is still waiting." % current_wave
	end_overlay.visible = true

func _return_to_menu() -> void:
	game_active = false
	_clear_ability_nodes()
	phase = "menu"
	player.set("controls_enabled", false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	end_overlay.visible = false
	menu_overlay.visible = true
	hearts_label.visible = false
	fireball_label.visible = false
	status_label.visible = false
