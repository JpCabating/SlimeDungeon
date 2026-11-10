extends Area2D

signal picked_up(pickup: Area2D)
signal expired(pickup: Area2D)

const FIREBALL_SHEET := preload("res://Animation Sheets/Fireball Idle.png")

@onready var sprite: Sprite2D = $Sprite2D
var lifetime := 18.0
var age := 0.0
var base_y := 0.0

func _ready() -> void:
	add_to_group("fireball_pickups")
	sprite.texture = FIREBALL_SHEET
	sprite.region_enabled = true
	sprite.centered = true
	base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	age += delta
	lifetime -= delta
	position.y = base_y + sin(age * 3.0) * 6.0
	var frame := int(age * 10.0) % 8
	sprite.region_rect = Rect2(12 + frame * 72, 174, 64, 64)
	if lifetime <= 0.0:
		expired.emit(self)
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		picked_up.emit(self)
		queue_free()
