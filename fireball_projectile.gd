extends Area2D

const PROJECTILE_SHEET := preload("res://Animation Sheets/Fireball Projectile.png")
const SPEED := 560.0
const FRAME_HEIGHT := 54.25

@onready var sprite: Sprite2D = $Sprite2D
var direction := 1.0
var lifetime := 1.8
var age := 0.0

func _ready() -> void:
	add_to_group("fireball_projectiles")
	sprite.texture = PROJECTILE_SHEET
	sprite.region_enabled = true
	sprite.centered = true
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	age += delta
	lifetime -= delta
	position.x += direction * SPEED * delta
	sprite.flip_h = direction < 0.0
	var frame := int(age * 12.0) % 4
	sprite.region_rect = Rect2(0, frame * FRAME_HEIGHT, 99, FRAME_HEIGHT)
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and not bool(body.get("is_dead")):
		body.call("take_damage", 999, direction)
		queue_free()
