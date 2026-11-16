extends Node2D

const PLAYER_FOOT_OFFSET := 2.0
const FLOOR_NAMES := ["floor", "floor2", "floor3"]
const CAMERA_MARGIN := 18.0
const FOREST_ARENA := preload("res://forest_arena.gd")
const FOREST_SCENE := preload("res://forest_arena.tscn")
const SLIME_SCRIPT := preload("res://player.gd")
const ENEMY_SCRIPT := preload("res://enemy.gd")
const GRAVE_LORD := preload("res://grave_lord.gd")
const GRAVE_LORD_HUD := preload("res://grave_lord_hud.gd")
const PICKUP_SCRIPT := preload("res://fireball_pickup.gd")
const Pickup := PICKUP_SCRIPT.Kind
const PROJECTILE_SCRIPT := preload("res://fireball_projectile.gd")
const LIGHTNING_SHEET := preload("res://Animation Sheets/Lightning Beam.png")
const LIGHTNING_REGION := Rect2(307, 581, 578, 82)
const LIGHTNING_RANGE := 565.0
const LIGHTNING_DAMAGE := 4
const HUD_FRAME := preload("res://Animation Sheets/Dungeon HUD Frame.png")
const HUD_FRAME_SHADER := preload("res://dungeon_hud_frame.gdshader")
const ENEMIES_PER_WAVE := 10
const ENEMY_TYPES := ["skeleton", "slime", "brute"]
const ENEMY_NAMES := ["Skeleton", "SlimeWarrior", "SlimeBrute"]
const ENEMY_CAPSULES := [Vector2(28, 60), Vector2(32, 68), Vector2(43, 98)]
const FOREST_ENEMY_SHEET := "res://Forest Tree Monster and Stone Golem.jpg"
const FOREST_ENEMY_TYPES := ["tree_monster", "rock_golem"]
const FOREST_ENEMY_NAMES := ["TreeMonster", "StoneGolem"]
const FOREST_ENEMY_CAPSULES := [Vector2(38, 115), Vector2(48, 132)]
const PLAYER_MAX_HEALTH := 5
const ATTACK_DAMAGE := 2
const ATTACK_RANGE := 142.0
const ATTACK_COOLDOWN := 0.48
const PICKUP_RADIUS := 30.0

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var enemy_root: Node2D = $WorldEnemies
@onready var dungeon_tile: Node2D = $DungeonTile
@onready var backdrop: Sprite2D = $DungeonTile/DungeonArt
@onready var tile_size: Vector2 = backdrop.get_rect().size * backdrop.scale
var active_tiles: Dictionary[int, Node2D] = {}
var boss: GRAVE_LORD
var boss_hud: GRAVE_LORD_HUD
var boss_walls: StaticBody2D
var boss_arena_center := 0.0
var health_bar: ProgressBar
var status_label: Label
var combat_hud: TextureRect
var spell_icon: TextureRect
var spell_label: Label
var switch_hint: Label
var spell_frames: Array[AtlasTexture] = []
var lightning_icon_material: ShaderMaterial
var lightning_beam_material: ShaderMaterial
var menu_overlay: Control
var arena_error: Label
var end_overlay: Control
var how_to_overlay: Control
var wave_option: OptionButton
var arena_cards := ButtonGroup.new()
var forest_arena: FOREST_ARENA
var forest_enemy_sheet: Texture2D
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
var spell_charges: Array[int] = [0, 0]
var selected_spell := Pickup.FIREBALL
var lightning_unlocked := false
var spell_cooldown := 0.0
var pickup_timers: Array[float] = [0.0, 0.0, 0.0]
var active_pickups: Dictionary[int, Area2D] = {}
var current_level := 1
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	_ensure_key_binding("move_left", KEY_LEFT)
	_ensure_key_binding("move_right", KEY_RIGHT)
	_ensure_key_binding("jump", KEY_W)
	_ensure_key_binding("jump", KEY_UP)
	_ensure_key_binding("jump", KEY_SPACE)
	_ensure_key_binding("drop", KEY_S)
	_ensure_key_binding("drop", KEY_DOWN)
	_ensure_key_binding("attack", KEY_J)
	_ensure_key_binding("previous_spell", KEY_Q)
	_ensure_key_binding("next_spell", KEY_E)
	rng.randomize()
	$HUD.visible = true
	player.visible = true
	player.add_to_group("player")
	_frame_dungeon()
	_update_scrolling()
	get_viewport().size_changed.connect(_frame_dungeon)
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

func _frame_dungeon() -> void:
	if is_instance_valid(forest_arena):
		var fit: Vector2 = get_viewport_rect().size / FOREST_ARENA.ARENA_SIZE
		camera.global_position.y = FOREST_ARENA.ARENA_SIZE.y * 0.5
		camera.zoom = Vector2.ONE * minf(fit.x, fit.y)
		return
	var fit := get_viewport_rect().size / (tile_size + Vector2.ONE * CAMERA_MARGIN * 2.0)
	camera.global_position.y = backdrop.global_position.y
	camera.zoom = Vector2.ONE * minf(1.0, minf(fit.x, fit.y))

func _tile_index_at(world_x: float) -> int:
	if is_instance_valid(forest_arena):
		return floori(world_x / FOREST_ARENA.ARENA_SIZE.x + 0.5)
	return floori((world_x - backdrop.global_position.x) / tile_size.x + 0.5)

func _update_scrolling() -> void:
	if is_instance_valid(boss_walls):
		camera.global_position.x = boss_arena_center
		return
	camera.global_position.x = player.global_position.x
	var view_half_width := get_viewport_rect().size.x / (2.0 * camera.zoom.x)
	var first_tile := _tile_index_at(camera.global_position.x - view_half_width) - 1
	var last_tile := _tile_index_at(camera.global_position.x + view_half_width) + 1
	var needed_tiles: Dictionary[int, bool] = {}
	for tile_index in range(first_tile, last_tile + 1):
		needed_tiles[tile_index] = true
	# Enemies can fall behind the camera when the slime runs ahead.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_tile := _tile_index_at(enemy.global_position.x)
		for tile_index in range(enemy_tile - 1, enemy_tile + 2):
			needed_tiles[tile_index] = true
	for tile_index in needed_tiles:
		if tile_index == 0 or active_tiles.has(tile_index):
			continue
		var tile: Node2D
		if is_instance_valid(forest_arena):
			tile = _new_forest_tile(tile_index)
		else:
			tile = dungeon_tile.duplicate() as Node2D
			tile.name = "DungeonTile_%d" % tile_index
			tile.position.x += tile_index * tile_size.x
			add_child(tile)
		active_tiles[tile_index] = tile
	for tile_index in active_tiles.keys():
		if not needed_tiles.has(tile_index):
			active_tiles[tile_index].queue_free()
			active_tiles.erase(tile_index)

func _level_floor_y(level_index: int) -> float:
	if is_instance_valid(forest_arena):
		return forest_arena.floor_height(level_index)
	var floor_shape := dungeon_tile.get_node(FLOOR_NAMES[level_index] + "/CollisionShape2D") as CollisionShape2D
	var rectangle := floor_shape.shape as RectangleShape2D
	return floor_shape.global_position.y - rectangle.size.y * 0.5

func get_level_floor_y(level_index: int) -> float:
	return _level_floor_y(level_index)

func get_level_for_surface(world_position: Vector2) -> int:
	for level_index in range(FLOOR_NAMES.size() - 1):
		if world_position.y <= _level_floor_y(level_index) + 1.0:
			return level_index
	return FLOOR_NAMES.size() - 1

func _process(delta: float) -> void:
	_update_scrolling()
	if not game_active:
		return
	if player.is_on_floor():
		current_level = get_level_for_surface(player.global_position)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	damage_cooldown = maxf(0.0, damage_cooldown - delta)
	spell_cooldown = maxf(0.0, spell_cooldown - delta)
	for kind in pickup_timers.size():
		if not _pickup_needed(kind):
			continue
		pickup_timers[kind] -= delta
		if pickup_timers[kind] <= 0.0:
			_spawn_pickup(kind)
	if is_instance_valid(boss):
		return
	if spawn_timer > 0.0:
		spawn_timer -= delta
	if spawn_timer <= 0.0:
		if transition_after_spawn:
			transition_after_spawn = false
			if current_wave >= total_waves:
				if is_instance_valid(forest_arena):
					_finish_game(true)
				else:
					_start_boss_fight()
			else:
				_begin_wave(current_wave + 1)
		elif spawned_this_wave < ENEMIES_PER_WAVE:
			_spawn_enemy_group()
	_update_hud()
func _unhandled_input(event: InputEvent) -> void:
	if not game_active:
		return
	if event.is_action_pressed("previous_spell") or event.is_action_pressed("next_spell"):
		if lightning_unlocked:
			selected_spell = Pickup.LIGHTNING if selected_spell == Pickup.FIREBALL else Pickup.FIREBALL
			_update_spell_icon()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("fireball"):
		_cast_selected_spell()
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
	combat_hud = TextureRect.new()
	combat_hud.name = "CombatHUD"
	combat_hud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	combat_hud.stretch_mode = TextureRect.STRETCH_SCALE
	combat_hud.texture = HUD_FRAME
	combat_hud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	combat_hud.position = Vector2(10, 3)
	combat_hud.size = Vector2(292, 159)
	combat_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_material := ShaderMaterial.new()
	frame_material.shader = HUD_FRAME_SHADER
	combat_hud.material = frame_material
	$HUD.add_child(combat_hud)
	health_bar = ProgressBar.new()
	health_bar.name = "LifeBar"
	health_bar.position = Vector2(57, 52)
	health_bar.size = Vector2(177, 18)
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.min_value = 0
	health_bar.max_value = PLAYER_MAX_HEALTH
	health_bar.value = player_health
	health_bar.show_percentage = false
	var life_background := StyleBoxFlat.new()
	life_background.bg_color = Color(0.09, 0.12, 0.16, 0.96)
	life_background.set_corner_radius_all(7)
	life_background.set_border_width_all(2)
	life_background.border_color = Color(0.77, 0.83, 0.89, 0.85)
	health_bar.add_theme_stylebox_override("background", life_background)
	var life_fill := StyleBoxFlat.new()
	life_fill.bg_color = Color(0.88, 0.18, 0.25)
	life_fill.set_corner_radius_all(5)
	health_bar.add_theme_stylebox_override("fill", life_fill)
	combat_hud.add_child(health_bar)
	var fireball_frame := AtlasTexture.new()
	fireball_frame.atlas = PICKUP_SCRIPT.FIREBALL_SHEET
	fireball_frame.region = PICKUP_SCRIPT.ICON_REGION
	var lightning_frame := AtlasTexture.new()
	lightning_frame.atlas = PICKUP_SCRIPT.LIGHTNING_SHEET
	lightning_frame.region = PICKUP_SCRIPT.LIGHTNING_ICON_REGION
	spell_frames = [fireball_frame, lightning_frame]
	lightning_icon_material = PICKUP_SCRIPT.lightning_material()
	lightning_beam_material = PICKUP_SCRIPT.lightning_material()
	lightning_beam_material.set_shader_parameter("preserve_core", Vector3(350.0 / 1024.0, 622.0 / 683.0, 0.026))
	spell_icon = TextureRect.new()
	spell_icon.name = "SpellIcon"
	spell_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spell_icon.position = Vector2(58, 76)
	spell_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spell_icon.size = Vector2(31, 27)
	spell_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spell_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_hud.add_child(spell_icon)
	spell_label = Label.new()
	spell_label.position = Vector2(95, 77)
	spell_label.add_theme_font_size_override("font_size", 18)
	combat_hud.add_child(spell_label)
	switch_hint = Label.new()
	switch_hint.text = "Q  /  E"
	switch_hint.position = Vector2(189, 80)
	switch_hint.add_theme_font_size_override("font_size", 13)
	combat_hud.add_child(switch_hint)
	_update_spell_icon()
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
	combat_hud.visible = false
	status_label.visible = false

func _update_hud() -> void:
	health_bar.value = player_health
	spell_label.text = "× %d" % spell_charges[selected_spell]
	status_label.text = "WAVE %d / %d     ENEMIES %d / %d" % [current_wave, total_waves, defeated_this_wave, ENEMIES_PER_WAVE]

func _update_spell_icon() -> void:
	var is_lightning := selected_spell == Pickup.LIGHTNING
	spell_icon.texture = spell_frames[selected_spell]
	spell_icon.material = lightning_icon_material if is_lightning else null
	spell_label.modulate = Color(0.64, 0.88, 1.0) if is_lightning else Color(1.0, 0.78, 0.44)
	spell_label.text = "× %d" % spell_charges[selected_spell]
	switch_hint.visible = lightning_unlocked
func _build_main_menu() -> void:
	menu_overlay = _make_overlay("SLIME DUNGEON", "Choose an arena and survive every wave.")
	var box := menu_overlay.get_node("Center/Panel/Content") as VBoxContainer
	var panel := box.get_parent() as PanelContainer
	panel.custom_minimum_size.x = 560
	panel.add_theme_stylebox_override("panel", _arena_card_style(Color("#111821"), Color("#394854"), 18))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	box.add_child(cards)
	var dungeon_card := _add_arena_card(cards, "Dungeon", backdrop.texture)
	var forest_preview := FOREST_SCENE.instantiate()
	var forest_art := forest_preview.get_node("Artwork") as Sprite2D
	_add_arena_card(cards, "Forest", forest_art.texture)
	forest_preview.free()
	dungeon_card.set_pressed_no_signal(true)
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
	start_button.text = "START GAME"
	start_button.custom_minimum_size.y = 52
	start_button.pressed.connect(_start_selected_game)
	box.add_child(start_button)
	arena_error = Label.new()
	arena_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	arena_error.add_theme_color_override("font_color", Color("#ffc488"))
	arena_error.hide()
	box.add_child(arena_error)
	arena_cards.pressed.connect(func(_card: BaseButton) -> void: arena_error.hide())
	var how_to_button := Button.new()
	how_to_button.text = "HOW TO PLAY"
	how_to_button.custom_minimum_size.y = 46
	how_to_button.pressed.connect(_show_how_to_play)
	box.add_child(how_to_button)
	menu_overlay.visible = true
	_build_how_to_overlay()

func _add_arena_card(row: HBoxContainer, arena_name: String, art: Texture2D) -> Button:
	var card := Button.new()
	card.name = arena_name
	card.text = arena_name
	card.toggle_mode = true
	card.button_group = arena_cards
	card.custom_minimum_size = Vector2(0, 142)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_font_size_override("font_size", 19)
	card.add_theme_stylebox_override("normal", _arena_card_style(Color("#1b2631"), Color("#455665")))
	card.add_theme_stylebox_override("hover", _arena_card_style(Color("#263744"), Color("#8498a2")))
	card.add_theme_stylebox_override("pressed", _arena_card_style(Color("#344333"), Color("#d4be72")))
	card.add_theme_stylebox_override("hover_pressed", _arena_card_style(Color("#40513d"), Color("#ead48a")))
	card.add_theme_stylebox_override("focus", _arena_card_style(Color.TRANSPARENT, Color("#f5edd6")))
	row.add_child(card)

	var preview := TextureRect.new()
	preview.texture = art
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 8
	preview.offset_top = 8
	preview.offset_right = -8
	preview.offset_bottom = -40
	return card

func _arena_card_style(fill: Color, outline: Color, padding: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding if padding > 0 else 102.0
	style.content_margin_bottom = padding
	return style

func _build_how_to_overlay() -> void:
	how_to_overlay = _make_overlay("HOW TO PLAY", "Move: A / D or ← / →\nJump onto wooden ledges: Space / W / ↑\nDrop through a platform: S / ↓ + Space\nRun: hold Shift\nMelee: J or left click\nCollect fireball or lightning charges, then right click to cast\nAfter collecting lightning, switch attacks with Q or E\nCollect green crosses to restore health\nClear every wave. In the Dungeon, defeat the Grave-Lord to win.")
	var box := how_to_overlay.get_node("Center/Panel/Content") as VBoxContainer
	var close_button := Button.new()
	close_button.text = "BACK TO MENU"
	close_button.custom_minimum_size.y = 46
	close_button.pressed.connect(func() -> void: how_to_overlay.visible = false)
	box.add_child(close_button)
	how_to_overlay.visible = false

func _show_how_to_play() -> void:
	how_to_overlay.visible = true

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
	panel.custom_minimum_size = Vector2(500, 450)
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
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle.add_theme_font_size_override("font_size", 18)
		content.add_child(subtitle)
	return overlay

func _start_selected_game() -> void:
	var use_forest := arena_cards.get_pressed_button().name == &"Forest"
	forest_enemy_sheet = null
	if use_forest:
		if ResourceLoader.exists(FOREST_ENEMY_SHEET, "Texture2D"):
			forest_enemy_sheet = load(FOREST_ENEMY_SHEET) as Texture2D
		if forest_enemy_sheet == null:
			arena_error.text = "Missing Forest Tree Monster and Stone Golem.jpg."
			arena_error.show()
			return
	arena_error.hide()
	total_waves = int(wave_option.get_selected_metadata())
	_select_arena(use_forest)
	_start_game()

func _select_arena(use_forest: bool) -> void:
	if use_forest == is_instance_valid(forest_arena):
		return
	for tile in active_tiles.values():
		remove_child(tile)
		tile.queue_free()
	active_tiles.clear()
	if use_forest:
		dungeon_tile.hide()
		dungeon_tile.process_mode = Node.PROCESS_MODE_DISABLED
		forest_arena = _new_forest_tile(0)
	elif is_instance_valid(forest_arena):
		remove_child(forest_arena)
		forest_arena.queue_free()
		forest_arena = null
		dungeon_tile.process_mode = Node.PROCESS_MODE_INHERIT
		dungeon_tile.show()
	_frame_dungeon()

func _new_forest_tile(index: int) -> FOREST_ARENA:
	var tile := FOREST_SCENE.instantiate() as FOREST_ARENA
	tile.name = "ForestTile_%d" % index
	tile.position.x = index * FOREST_ARENA.ARENA_SIZE.x
	if posmod(index, 2) == 1:
		tile.transform = Transform2D(Vector2.LEFT, Vector2.DOWN, tile.position)
	add_child(tile)
	return tile

func _forest_tile_at_player() -> FOREST_ARENA:
	return active_tiles.get(_tile_index_at(player.global_position.x), forest_arena) as FOREST_ARENA

func _restart_game() -> void:
	_start_game()

func _start_game() -> void:
	_clear_boss_fight()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	_clear_ability_nodes()
	phase = "playing"
	game_active = true
	player_health = PLAYER_MAX_HEALTH
	spell_charges = [0, 0]
	selected_spell = Pickup.FIREBALL
	lightning_unlocked = false
	spell_cooldown = 0.0
	pickup_timers = [rng.randf_range(5.0, 9.0), rng.randf_range(8.0, 14.0), rng.randf_range(6.0, 12.0)]
	_update_spell_icon()
	current_wave = 0
	spawned_this_wave = 0
	defeated_this_wave = 0
	spawn_timer = 0.0
	damage_cooldown = 0.8
	attack_cooldown = 0.0
	transition_after_spawn = false
	next_spawn_side = 1.0
	current_level = 2 if is_instance_valid(forest_arena) else 1
	player.global_position = Vector2(0.0, _level_floor_y(current_level) - PLAYER_FOOT_OFFSET)
	_update_scrolling()
	player.velocity = Vector2.ZERO
	player.call("reset_animation_state")
	player.set_collision_mask_value(2, is_instance_valid(forest_arena))
	player.set("controls_enabled", true)
	player.visible = true
	menu_overlay.visible = false
	end_overlay.visible = false
	combat_hud.visible = true
	status_label.visible = true
	_begin_wave(1)
func _start_boss_fight() -> void:
	_clear_ability_nodes()
	var tile_index := _tile_index_at(player.global_position.x)
	boss_arena_center = backdrop.global_position.x + tile_index * tile_size.x
	var left := boss_arena_center - tile_size.x * 0.5
	var right := boss_arena_center + tile_size.x * 0.5
	var top := _level_floor_y(0)
	var bottom := _level_floor_y(2)
	var boss_x := left + 225.0

	boss = GRAVE_LORD.new()
	boss.name = "GraveLord"
	boss.position = Vector2(boss_x, (top + bottom) * 0.5 - 35.0)
	boss.height = bottom - top + 90.0
	boss.arena_right = right - boss_x - 22.0
	boss.floors = [top, _level_floor_y(1), bottom]
	boss.target = player
	boss.controller = self
	enemy_root.add_child(boss)

	# The left wall follows the boss's attackable edge so the slime can reach it from every floor.
	var fight_left := boss_x + boss.hit_edge
	boss_walls = StaticBody2D.new()
	boss_walls.name = "BossArenaWalls"
	boss_walls.collision_layer = SLIME_SCRIPT.GROUND_LAYER
	boss_walls.collision_mask = 0
	for wall_x: float in [fight_left - 10.0, right - 12.0]:
		var wall := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(20.0, 2200.0)
		wall.shape = rectangle
		wall.position = Vector2(wall_x, (top + bottom) * 0.5)
		boss_walls.add_child(wall)
	add_child(boss_walls)
	player.global_position.x = clampf(player.global_position.x, fight_left + 55.0, right - 66.0)
	camera.global_position.x = boss_arena_center

	boss_hud = GRAVE_LORD_HUD.new()
	boss_hud.name = "GraveLordHUD"
	$HUD.add_child(boss_hud)
	boss_hud.reveal(GRAVE_LORD.MAX_HEALTH)
	boss.health_changed.connect(boss_hud.update_health)
	boss.defeated.connect(func() -> void: _finish_game(true))
	status_label.hide()

func _clear_boss_fight() -> void:
	for node in [boss, boss_hud, boss_walls]:
		if is_instance_valid(node):
			node.queue_free()
	boss = null
	boss_hud = null
	boss_walls = null

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
	var use_forest_roster := is_instance_valid(forest_arena)
	var types := FOREST_ENEMY_TYPES if use_forest_roster else ENEMY_TYPES
	var names := FOREST_ENEMY_NAMES if use_forest_roster else ENEMY_NAMES
	var capsules := FOREST_ENEMY_CAPSULES if use_forest_roster else ENEMY_CAPSULES
	var type_index := spawned_this_wave % types.size()
	enemy.name = "%s_%02d" % [names[type_index], spawned_this_wave + 1]
	enemy.set_script(ENEMY_SCRIPT)
	enemy.set("controller", self)
	enemy.set("target", player)
	enemy.set("enemy_type", types[type_index])
	enemy.set("forest_sheet", forest_enemy_sheet)
	var spawn_x := player.global_position.x + next_spawn_side * (430.0 + group_index * 90.0)
	var spawn_y := _level_floor_y(current_level)
	if is_instance_valid(forest_arena) and current_level != 2:
		var tile := _forest_tile_at_player()
		spawn_x = tile.enemy_spawn_x(current_level, player.global_position.x, next_spawn_side, group_index)
		spawn_y = tile.spawn_floor_y(current_level, spawn_x)
	enemy.position = Vector2(spawn_x, spawn_y - PLAYER_FOOT_OFFSET)
	enemy.collision_layer = 2
	enemy.collision_mask = SLIME_SCRIPT.WORLD_MASK
	var body_shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	var capsule_size: Vector2 = capsules[type_index]
	capsule.height = capsule_size.y
	capsule.radius = capsule_size.x
	body_shape.shape = capsule
	body_shape.position.y = -capsule_size.y * 0.5
	enemy.add_child(body_shape)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
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
	if is_instance_valid(boss):
		var distance := player.global_position.x - (boss.global_position.x + boss.hit_edge)
		if facing < 0.0 and distance <= ATTACK_RANGE:
			boss.take_damage(ATTACK_DAMAGE, facing)
		return
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

func spawn_hit_particles(at_position: Vector2, is_death: bool = false) -> void:
	var particles := CPUParticles2D.new()
	particles.name = "HitParticles"
	particles.position = at_position
	particles.z_index = 5
	particles.amount = 18 if is_death else 9
	particles.lifetime = 0.42 if is_death else 0.28
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector2(0.0, -1.0)
	particles.spread = 180.0
	particles.gravity = Vector2(0.0, 260.0)
	particles.initial_velocity_min = 90.0 if is_death else 65.0
	particles.initial_velocity_max = 240.0 if is_death else 155.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.5 if is_death else 3.2
	particles.color = Color(0.56, 0.94, 0.40) if is_death else Color(1.0, 0.72, 0.42)
	add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true

func _cast_selected_spell() -> void:
	if spell_charges[selected_spell] <= 0 or spell_cooldown > 0.0:
		return
	spell_charges[selected_spell] -= 1
	var direction := float(player.get("facing"))
	if selected_spell == Pickup.LIGHTNING:
		spell_cooldown = 0.55
		_cast_lightning(direction)
	else:
		spell_cooldown = 0.30
		_cast_fireball(direction)
	if spell_charges[selected_spell] == 0:
		pickup_timers[selected_spell] = rng.randf_range(4.0, 7.0)
	_update_hud()

func _cast_fireball(direction: float) -> void:
	player.call("play_fireball_animation")
	var projectile := Area2D.new()
	projectile.name = "FireballProjectile"
	projectile.set_script(PROJECTILE_SCRIPT)
	projectile.set("direction", direction)
	projectile.position = player.global_position + Vector2(direction * 58.0, -52.0)
	projectile.collision_layer = 0
	projectile.collision_mask = 2
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

func _cast_lightning(direction: float) -> void:
	player.call("play_lightning_animation")
	var beam := Sprite2D.new()
	beam.name = "LightningBeam"
	beam.texture = LIGHTNING_SHEET
	beam.region_enabled = true
	beam.region_rect = LIGHTNING_REGION
	beam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	beam.material = lightning_beam_material
	beam.scale = Vector2(LIGHTNING_RANGE / LIGHTNING_REGION.size.x, 0.82)
	beam.flip_h = direction < 0.0
	beam.position = player.position + Vector2(direction * (38.0 + LIGHTNING_RANGE * 0.5), -36.0)
	beam.z_index = 6
	enemy_root.add_child(beam)
	beam.add_to_group("spell_effects")
	var fade := beam.create_tween()
	fade.tween_property(beam, "modulate:a", 0.0, 0.2).set_delay(0.12)
	fade.tween_callback(beam.queue_free)
	if is_instance_valid(boss):
		var distance := player.global_position.x - (boss.global_position.x + boss.hit_edge)
		if direction < 0.0 and distance <= LIGHTNING_RANGE + 38.0:
			boss.take_damage(LIGHTNING_DAMAGE, direction)
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = enemy.global_position - player.global_position
		var forward := offset.x * direction
		if forward >= 0.0 and forward <= LIGHTNING_RANGE + 38.0 and absf(offset.y) <= 66.0:
			enemy.call("take_damage", LIGHTNING_DAMAGE, direction)

func _pickup_needed(kind: int) -> bool:
	if is_instance_valid(active_pickups.get(kind)):
		return false
	if kind == Pickup.HEALING:
		return player_health < PLAYER_MAX_HEALTH
	return spell_charges[kind] == 0

func _spawn_pickup(kind: int) -> void:
	if not game_active or not _pickup_needed(kind):
		return
	var pickup := Area2D.new()
	pickup.name = ["FireballPickup", "LightningPickup", "HealingCross"][kind]
	pickup.set_script(PICKUP_SCRIPT)
	pickup.set("kind", kind)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var platform_top_y := _level_floor_y(current_level)
	var pickup_x := player.global_position.x + side * rng.randf_range(180.0, 360.0)
	if is_instance_valid(boss_walls):
		pickup_x = clampf(pickup_x, boss.global_position.x + boss.hit_edge + 80.0, boss_arena_center + tile_size.x * 0.5 - 75.0)
	if is_instance_valid(forest_arena) and current_level != 2:
		var tile := _forest_tile_at_player()
		var span := tile.spawn_span(current_level, player.global_position.x)
		var margin := minf(PICKUP_RADIUS + 8.0, (span.y - span.x) * 0.5)
		pickup_x = clampf(pickup_x, span.x + margin, span.y - margin)
		platform_top_y = tile.spawn_floor_y(current_level, pickup_x)
	pickup.global_position = Vector2(pickup_x, platform_top_y - PICKUP_RADIUS)
	pickup.collision_layer = 0
	pickup.collision_mask = 1
	var pickup_shape := CollisionShape2D.new()
	var pickup_circle := CircleShape2D.new()
	pickup_circle.radius = PICKUP_RADIUS
	pickup_shape.shape = pickup_circle
	pickup.add_child(pickup_shape)
	var pickup_sprite := Sprite2D.new()
	pickup_sprite.name = "Sprite2D"
	pickup.add_child(pickup_sprite)
	pickup.connect("picked_up", _on_pickup_collected.bind(kind))
	pickup.connect("expired", _on_pickup_expired.bind(kind))
	enemy_root.add_child(pickup)
	active_pickups[kind] = pickup

func _on_pickup_collected(pickup: Area2D, kind: int) -> void:
	if pickup != active_pickups.get(kind):
		return
	active_pickups.erase(kind)
	if kind == Pickup.HEALING:
		player_health = mini(PLAYER_MAX_HEALTH, player_health + 2)
		pickup_timers[kind] = rng.randf_range(8.0, 15.0)
	elif kind == Pickup.LIGHTNING:
		spell_charges[kind] = 2
		lightning_unlocked = true
		_update_spell_icon()
	else:
		spell_charges[kind] = 3
	_update_hud()

func _on_pickup_expired(pickup: Area2D, kind: int) -> void:
	if pickup == active_pickups.get(kind):
		active_pickups.erase(kind)
		pickup_timers[kind] = rng.randf_range(4.0, 7.0)

func _clear_ability_nodes() -> void:
	for group in [&"dungeon_pickups", &"fireball_projectiles", &"spell_effects"]:
		for node in get_tree().get_nodes_in_group(group):
			node.queue_free()
	active_pickups.clear()
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
	var fought_boss := is_instance_valid(boss)
	_clear_boss_fight()
	game_active = false
	_clear_ability_nodes()
	phase = "win" if won else "game_over"
	player.set("controls_enabled", false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	combat_hud.visible = false
	status_label.visible = false
	var arena_name := "Forest" if is_instance_valid(forest_arena) else "Dungeon"
	end_title.text = "%s CLEARED!" % arena_name.to_upper() if won else "GAME OVER"
	if fought_boss:
		end_message.text = "You defeated the Grave-Lord." if won else "You fell to the Grave-Lord."
	elif won:
		end_message.text = "You defeated all %d waves and %d enemies." % [total_waves, total_waves * ENEMIES_PER_WAVE]
	else:
		end_message.text = "You fell during wave %d.\nThe %s is still waiting." % [current_wave, arena_name.to_lower()]
	end_overlay.visible = true

func _return_to_menu() -> void:
	_clear_boss_fight()
	game_active = false
	_clear_ability_nodes()
	phase = "menu"
	player.set("controls_enabled", false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	end_overlay.visible = false
	menu_overlay.visible = true
	combat_hud.visible = false
	status_label.visible = false
	if is_instance_valid(forest_arena):
		_select_arena(false)
		player.global_position = Vector2(0.0, _level_floor_y(1) - PLAYER_FOOT_OFFSET)
		player.velocity = Vector2.ZERO
		_update_scrolling()
