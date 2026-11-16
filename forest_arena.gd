extends Node2D

const ARENA_SIZE := Vector2(1024, 559)
# Platform coordinates are measured from the top-left corner of the artwork.
# Each Vector3 stores the left edge, right edge, and standing height.
const FLOOR_HEIGHTS := [187.0, 322.0, 464.0]
const CANOPY_WALKWAY := Vector3(112, 900, 187)
const MIDDLE_PLATFORMS := [
	Vector3(0, 344, 322), Vector3(575, 775, 317), Vector3(886, 1024, 321)
]
const GROUND := Vector3(0, 1024, 464)
const SIDE_STEPS := [
	Vector3(0, 85, 112), Vector3(85, 109, 126),
	Vector3(109, 128, 144), Vector3(128, 148, 161),
	Vector3(872, 894, 161), Vector3(894, 914, 144),
	Vector3(914, 938, 126), Vector3(938, 1024, 112)
]
const HIGH_BRANCH := Vector3(683, 854, 51)
const ART := preload("res://Animation Sheets/Forest Level BG.jpg")
const ENEMY_EDGE_MARGIN := 24.0
const ENEMY_SPAWN_SPACING := 44.0

var mirrored := false

func _ready() -> void:
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add_platform("StonePath", GROUND, false)
	_add_platform("CanopyWalkway", CANOPY_WALKWAY, true)
	for index in MIDDLE_PLATFORMS.size():
		_add_platform("MiddleLedge%d" % index, MIDDLE_PLATFORMS[index], true)
	for index in SIDE_STEPS.size():
		_add_platform("CanopyStep%d" % index, SIDE_STEPS[index], true)
	_add_platform("HighBranch", HIGH_BRANCH, true)

func _add_platform(node_name: String, platform: Vector3, one_way: bool) -> void:
	var span := _platform_span(platform)
	var thickness := 10.0 if one_way else 44.0
	var body := StaticBody2D.new()
	body.name = node_name
	body.collision_layer = 1 if one_way else 4
	body.collision_mask = 0
	body.position = Vector2((span.x + span.y) * 0.5, platform.z + thickness * 0.5)
	var surface := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(span.y - span.x, thickness)
	surface.shape = rectangle
	surface.one_way_collision = one_way
	body.add_child(surface)
	add_child(body)

func _platform_span(platform: Vector3) -> Vector2:
	var span := Vector2(platform.x, platform.y) - Vector2.ONE * (ARENA_SIZE.x * 0.5)
	if mirrored:
		return Vector2(-span.y, -span.x)
	return span

func _nearest_platform(level: int, reference_x: float) -> Vector3:
	if level == 2:
		return GROUND
	if level == 0:
		return CANOPY_WALKWAY
	var nearest: Vector3 = MIDDLE_PLATFORMS[0]
	var nearest_distance := INF
	for platform: Vector3 in MIDDLE_PLATFORMS:
		var span := _platform_span(platform)
		var local_x := reference_x - global_position.x
		var distance := absf(local_x - clampf(local_x, span.x, span.y))
		if distance < nearest_distance:
			nearest = platform
			nearest_distance = distance
	return nearest

func spawn_span(level: int, reference_x: float) -> Vector2:
	return _platform_span(_nearest_platform(level, reference_x)) + Vector2.ONE * global_position.x

func spawn_floor_y(level: int, spawn_x: float) -> float:
	return _nearest_platform(level, spawn_x).z

func enemy_spawn_x(level: int, player_x: float, preferred_side: float, group_index: int) -> float:
	var span := spawn_span(level, player_x)
	var left := span.x + ENEMY_EDGE_MARGIN
	var right := span.y - ENEMY_EDGE_MARGIN
	var edge := right if preferred_side > 0.0 else left
	if absf(edge - player_x) < ENEMY_SPAWN_SPACING * 2.0:
		edge = left if preferred_side > 0.0 else right
	var inward := 1.0 if edge == left else -1.0
	return clampf(edge + inward * group_index * ENEMY_SPAWN_SPACING, left, right)

func _draw() -> void:
	if mirrored:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	var frame := Rect2(Vector2(-ARENA_SIZE.x * 0.5, 0), ARENA_SIZE)
	draw_texture_rect(ART, frame, false)
