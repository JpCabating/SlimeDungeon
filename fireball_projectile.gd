extends Area2D

const PROJECTILE_SHEET := preload("res://Animation Sheets/Slime Dungeon Animation.png")
const SHEET_SHADER := preload("res://slime_sheet.gdshader")
const SPEED := 560.0
const FLIGHT_FRAMES := [Rect2(680, 590, 97, 54), Rect2(785, 590, 103, 54)]
const IMPACT_FRAME := Rect2(893, 565, 107, 86)
const EMBER_COLORS := [Color(1.0, 0.42, 0.12), Color(1.0, 0.78, 0.30), Color(1.0, 0.95, 0.62)]

@onready var sprite: Sprite2D = $Sprite2D
var direction := 1.0
var lifetime := 1.8
var age := 0.0

func _ready() -> void:
	add_to_group("fireball_projectiles")
	sprite.texture = PROJECTILE_SHEET
	sprite.region_enabled = true
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sheet_material := ShaderMaterial.new()
	sheet_material.shader = SHEET_SHADER
	sheet_material.set_shader_parameter("matte_chroma", Vector2(0.065, 0.16))
	sheet_material.set_shader_parameter("matte_lightness", Vector2(0.50, 0.83))
	sprite.material = sheet_material
	sprite.flip_h = direction < 0.0
	sprite.region_rect = FLIGHT_FRAMES[0]
	body_entered.connect(_on_body_entered)
	var embers := CPUParticles2D.new()
	embers.name = "EmberTrail"
	embers.position = Vector2(-20.0 * direction, 0.0)
	embers.amount = 22
	embers.lifetime = 0.3
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 5.0
	embers.direction = Vector2(-direction, 0.0)
	embers.spread = 32.0
	embers.gravity = Vector2.ZERO
	embers.initial_velocity_min = 18.0
	embers.initial_velocity_max = 65.0
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 3.5
	var ember_gradient := Gradient.new()
	ember_gradient.set_color(0, EMBER_COLORS[0])
	ember_gradient.set_color(1, Color(1.0, 0.95, 0.62, 0.0))
	ember_gradient.add_point(0.5, EMBER_COLORS[1])
	embers.color_ramp = ember_gradient
	add_child(embers)
	embers.emitting = true

func _physics_process(delta: float) -> void:
	age += delta
	lifetime -= delta
	position.x += direction * SPEED * delta
	sprite.region_rect = FLIGHT_FRAMES[int(age * 12.0) % FLIGHT_FRAMES.size()]
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and not bool(body.get("is_dead")):
		_spawn_impact()
		body.call("take_damage", 999, direction)
		queue_free()

func _spawn_impact() -> void:
	var flash := Sprite2D.new()
	flash.texture = PROJECTILE_SHEET
	flash.region_enabled = true
	flash.region_rect = IMPACT_FRAME
	flash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flash.material = sprite.material
	flash.z_index = 6
	get_parent().add_child(flash)
	flash.global_position = global_position
	var fade := flash.create_tween()
	fade.tween_property(flash, "modulate:a", 0.0, 0.22)
	fade.tween_callback(flash.queue_free)
	var burst := CPUParticles2D.new()
	burst.name = "FireballImpact"
	burst.global_position = global_position
	burst.z_index = 6
	burst.amount = 24
	burst.lifetime = 0.32
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2(0.0, 210.0)
	burst.initial_velocity_min = 85.0
	burst.initial_velocity_max = 230.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 5.0
	burst.color = Color(1.0, 0.58, 0.18)
	get_parent().add_child(burst)
	burst.finished.connect(burst.queue_free)
	burst.emitting = true
