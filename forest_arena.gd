extends Node2D

const ARENA_SIZE := Vector2(1024, 559)
const ENEMY_EDGE_MARGIN := 24.0
const ENEMY_SPAWN_SPACING := 44.0

@onready var tiers: Array[StaticBody2D] = [$UpperPlatforms, $MiddlePlatforms, $Ground]

func floor_height(level: int) -> float:
	var height := -INF
	for bounds in _surface_bounds(level):
		height = maxf(height, bounds.position.y)
	return height

func _surface_bounds(level: int) -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for child in tiers[level].get_children():
		var surface := child as CollisionShape2D
		if surface == null or surface.disabled or surface.shape == null:
			continue
		bounds.append(surface.global_transform * surface.shape.get_rect())
	return bounds

func _nearest_surface(level: int, reference_x: float) -> Rect2:
	var surfaces := _surface_bounds(level)
	if surfaces.is_empty():
		surfaces = _surface_bounds(2)
	var nearest := Rect2(Vector2(reference_x, ARENA_SIZE.y), Vector2.ZERO)
	var nearest_distance := INF
	for bounds in surfaces:
		var distance := absf(reference_x - clampf(reference_x, bounds.position.x, bounds.end.x))
		if distance < nearest_distance:
			nearest = bounds
			nearest_distance = distance
	return nearest

func spawn_span(level: int, reference_x: float) -> Vector2:
	var bounds := _nearest_surface(level, reference_x)
	return Vector2(bounds.position.x, bounds.end.x)

func spawn_floor_y(level: int, spawn_x: float) -> float:
	return _nearest_surface(level, spawn_x).position.y

func enemy_spawn_x(level: int, player_x: float, preferred_side: float, group_index: int) -> float:
	var span := spawn_span(level, player_x)
	var margin := minf(ENEMY_EDGE_MARGIN, (span.y - span.x) * 0.5)
	var left := span.x + margin
	var right := span.y - margin
	var edge := right if preferred_side > 0.0 else left
	if absf(edge - player_x) < ENEMY_SPAWN_SPACING * 2.0:
		edge = left if preferred_side > 0.0 else right
	var inward := 1.0 if edge == left else -1.0
	return clampf(edge + inward * group_index * ENEMY_SPAWN_SPACING, left, right)
