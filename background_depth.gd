extends Node2D

var elapsed := 0.0

func _draw() -> void:
	var view_size := get_viewport_rect().size
	var half := view_size * 0.5
	# Dim distant arches add a second plane behind the dungeon wall art.
	for index in range(5):
		var x := (float(index) - 2.0) * view_size.x * 0.34
		var height := view_size.y * (0.48 + float(index % 2) * 0.08)
		var arch := PackedVector2Array([
			Vector2(x - 72.0, half.y + height),
			Vector2(x - 72.0, half.y - height * 0.35),
			Vector2(x - 50.0, half.y - height * 0.82),
			Vector2(x, half.y - height),
			Vector2(x + 50.0, half.y - height * 0.82),
			Vector2(x + 72.0, half.y - height * 0.35),
			Vector2(x + 72.0, half.y + height),
		])
		draw_colored_polygon(arch, Color(0.035, 0.055, 0.09, 0.20))
		var edge := PackedVector2Array([
			Vector2(x - 62.0, half.y + height),
			Vector2(x - 62.0, half.y - height * 0.34),
			Vector2(x - 43.0, half.y - height * 0.76),
			Vector2(x, half.y - height * 0.93),
			Vector2(x + 43.0, half.y - height * 0.76),
			Vector2(x + 62.0, half.y - height * 0.34),
			Vector2(x + 62.0, half.y + height),
		])
		draw_polyline(edge, Color(0.17, 0.25, 0.35, 0.16), 2.0, true)
	# Slow ember motes move at different rates to make the camera depth visible.
	for index in range(34):
		var seed := float(index)
		var x := fposmod(seed * 127.1 + sin(elapsed * (0.18 + seed * 0.003)) * 30.0, view_size.x) - half.x
		var y := fposmod(seed * 71.7 - elapsed * (5.0 + fposmod(seed, 4.0)), view_size.y) - half.y
		var radius := 1.2 + fposmod(seed, 3.0) * 0.45
		var pulse := 0.35 + 0.35 * sin(elapsed * 1.8 + seed)
		draw_circle(Vector2(x, y), radius * 3.0, Color(0.42, 0.64, 0.84, pulse * 0.10))
		draw_circle(Vector2(x, y), radius, Color(0.72, 0.83, 0.91, pulse * 0.34))
