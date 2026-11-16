extends Area2D

signal picked_up(pickup: Area2D)
signal expired(pickup: Area2D)

enum Kind { FIREBALL, LIGHTNING, HEALING }

const FIREBALL_SHEET := preload("res://assets/combat/Fireball Pickup.png")
const LIGHTNING_SHEET := preload("res://assets/combat/Lightning Pickup.png")
const HEALING_SHEET := preload("res://assets/combat/Healing Cross.png")
const HEALING_SHADER := preload("res://shaders/healing_pickup.gdshader")
const SHEET_SHADER := preload("res://shaders/slime_sheet.gdshader")
const ICON_REGION := Rect2(142, 62, 153, 131)
const LIGHTNING_ICON_REGION := Rect2(139, 193, 109, 96)
const FRAME_ORIGIN := Vector2(100, 16)
const FRAME_STEP := Vector2(366, 247)
const FRAME_SIZE := Vector2(254, 220)
const COLUMNS := 4
const FRAME_COUNT := 16
const LIGHTNING_FRAMES := [138, 282, 422, 561, 703, 846]
const HEALING_IDLE_CENTERS := [151, 280, 459, 586, 703, 819, 936]
const HEALING_PULSE_CENTERS := [160, 309, 458, 609, 765]
const HEALING_COLLECT_CENTERS := [160, 309, 458, 609, 765, 920]
const HEALING_IDLE_LOOPS := 2
const HEALING_COLLECT_FPS := 12.0

@onready var sprite: Sprite2D = $Sprite2D
var lifetime := 18.0
var age := 0.0
var base_y := 0.0
var kind := Kind.FIREBALL
var collected := false
var collect_age := 0.0

func _ready() -> void:
	add_to_group("dungeon_pickups")
	match kind:
		Kind.FIREBALL:
			sprite.texture = FIREBALL_SHEET
			sprite.scale = Vector2.ONE * 0.32
		Kind.LIGHTNING:
			sprite.texture = LIGHTNING_SHEET
			sprite.scale = Vector2.ONE * 0.5
			sprite.material = lightning_material()
		Kind.HEALING:
			sprite.texture = HEALING_SHEET
			sprite.scale = Vector2.ONE * 0.56
			var material := ShaderMaterial.new()
			material.shader = HEALING_SHADER
			sprite.material = material
	sprite.region_enabled = true
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_set_frame(0)
	base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if collected:
		collect_age += delta
		var frame := int(collect_age * HEALING_COLLECT_FPS)
		if frame >= HEALING_COLLECT_CENTERS.size():
			queue_free()
		else:
			_set_healing_collect_frame(frame)
		return
	age += delta
	lifetime -= delta
	position.y = base_y + sin(age * 3.0) * 6.0
	_set_frame(int(age * 10.0))
	if lifetime <= 0.0:
		expired.emit(self)
		queue_free()

func _set_frame(frame: int) -> void:
	match kind:
		Kind.FIREBALL:
			frame %= FRAME_COUNT
			@warning_ignore("integer_division")
			var cell := Vector2(frame % COLUMNS, frame / COLUMNS)
			sprite.region_rect = Rect2(FRAME_ORIGIN + cell * FRAME_STEP, FRAME_SIZE)
		Kind.LIGHTNING:
			sprite.region_rect = Rect2(LIGHTNING_FRAMES[frame % LIGHTNING_FRAMES.size()], 190, 112, 101)
		Kind.HEALING:
			var idle_frames := HEALING_IDLE_CENTERS.size() * HEALING_IDLE_LOOPS
			frame %= idle_frames + HEALING_PULSE_CENTERS.size()
			if frame < idle_frames:
				var center: int = HEALING_IDLE_CENTERS[frame % HEALING_IDLE_CENTERS.size()]
				sprite.region_rect = Rect2(center - 42, 86, 84, 92)
			else:
				var center: int = HEALING_PULSE_CENTERS[frame - idle_frames]
				sprite.region_rect = Rect2(center - 62, 232, 124, 118)

func _set_healing_collect_frame(frame: int) -> void:
	var center: int = HEALING_COLLECT_CENTERS[frame]
	sprite.region_rect = Rect2(center - 62, 394, 124, 120)

static func lightning_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHEET_SHADER
	material.set_shader_parameter("matte_lightness", Vector2(0.91, 0.98))
	material.set_shader_parameter("matte_chroma", Vector2(0.014, 0.05))
	material.set_shader_parameter("trim_pale_edge", false)
	return material

func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return
	collected = true
	picked_up.emit(self)
	if kind != Kind.HEALING:
		set_process(false)
		queue_free()
		return
	set_deferred("monitoring", false)
	_set_healing_collect_frame(0)
