shader_type canvas_item;

varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 step_size = TEXTURE_PIXEL_SIZE * 4.0;
	float inner_alpha = source.a;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			inner_alpha = min(inner_alpha, texture(TEXTURE, UV + vec2(float(x), float(y)) * step_size).a);
		}
	}

	float darkest = min(source.r, min(source.g, source.b));
	float lightest = max(source.r, max(source.g, source.b));
	float pale = smoothstep(0.57, 0.74, darkest);
	float neutral = 1.0 - smoothstep(0.045, 0.14, lightest - darkest);
	float edge = 1.0 - smoothstep(0.08, 0.80, inner_alpha);
	edge = max(edge, 1.0 - smoothstep(0.45, 0.95, source.a));
	float fringe = pale * neutral * edge;
	// Match the cool dungeon shadows while retaining the violet spell glow.
	float violet = smoothstep(0.06, 0.26, source.b - source.g);
	vec3 grade = mix(vec3(0.80, 0.83, 0.86), vec3(0.96, 0.93, 1.0), violet);
	vec3 color = source.rgb * grade * (1.0 - fringe * 0.50);
	COLOR = vec4(color, source.a * (1.0 - fringe)) * sprite_tint;
}
