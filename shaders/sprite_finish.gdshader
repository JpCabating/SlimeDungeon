shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.96, 0.98, 1.0, 0.96);
uniform vec4 shadow_color : source_color = vec4(0.015, 0.025, 0.045, 0.44);
uniform float outline_width = 1.25;
uniform float shadow_offset = 2.5;

float sample_alpha(sampler2D tex, vec2 uv) {
	return texture(tex, uv).a;
}

void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float center_alpha = texture(TEXTURE, UV).a;
	float width_pixels = outline_width;
	float around = 0.0;
	around = max(around, sample_alpha(TEXTURE, UV + vec2(pixel.x, 0.0) * width_pixels));
	around = max(around, sample_alpha(TEXTURE, UV - vec2(pixel.x, 0.0) * width_pixels));
	around = max(around, sample_alpha(TEXTURE, UV + vec2(0.0, pixel.y) * width_pixels));
	around = max(around, sample_alpha(TEXTURE, UV - vec2(0.0, pixel.y) * width_pixels));
	around = max(around, sample_alpha(TEXTURE, UV + pixel * width_pixels));
	around = max(around, sample_alpha(TEXTURE, UV - pixel * width_pixels));
	around = max(around, sample_alpha(TEXTURE, UV + vec2(pixel.x, -pixel.y) * width_pixels));
	around = max(around, sample_alpha(TEXTURE, UV + vec2(-pixel.x, pixel.y) * width_pixels));
	float outline_alpha = max(around - center_alpha, 0.0) * outline_color.a;
	vec2 shadow_uv = UV - vec2(0.0, pixel.y * shadow_offset);
	float shadow_alpha = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			shadow_alpha += sample_alpha(TEXTURE, shadow_uv + vec2(float(x), float(y)) * pixel) / 9.0;
		}
	}
	shadow_alpha *= shadow_color.a;
	float final_alpha = max(center_alpha, max(outline_alpha, shadow_alpha));
	vec3 behind = mix(shadow_color.rgb, outline_color.rgb, outline_alpha / max(outline_alpha + shadow_alpha, 0.001));
	vec3 final_rgb = mix(behind, source.rgb, center_alpha);
	COLOR = vec4(final_rgb, final_alpha);
}
