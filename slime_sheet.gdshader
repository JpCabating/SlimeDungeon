shader_type canvas_item;

uniform bool trim_pale_edge = true;
uniform vec2 matte_chroma = vec2(0.05, 0.18);
uniform vec2 matte_lightness = vec2(0.56, 0.87);
uniform vec3 preserve_core = vec3(-1.0, -1.0, 0.0);
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

float matte_amount(vec3 color) {
	float lightest = max(color.r, max(color.g, color.b));
	float darkest = min(color.r, min(color.g, color.b));
	float chroma = lightest - darkest;
	return smoothstep(matte_lightness.x, matte_lightness.y, darkest) * (1.0 - smoothstep(matte_chroma.x, matte_chroma.y, chroma));
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float matte = matte_amount(source.rgb);
	if (preserve_core.z > 0.0 && distance(UV, preserve_core.xy) < preserve_core.z) {
		matte = 0.0;
	}
	float opacity = 1.0 - matte;
	vec3 color = clamp((source.rgb - vec3(matte)) / max(opacity, 0.001), 0.0, 1.0);
	if (trim_pale_edge) {
		vec2 dx = vec2(TEXTURE_PIXEL_SIZE.x, 0.0);
		vec2 dy = vec2(0.0, TEXTURE_PIXEL_SIZE.y);
		float adjacent_matte = max(matte_amount(texture(TEXTURE, UV + dx).rgb), matte_amount(texture(TEXTURE, UV - dx).rgb));
		adjacent_matte = max(adjacent_matte, max(matte_amount(texture(TEXTURE, UV + dy).rgb), matte_amount(texture(TEXTURE, UV - dy).rgb)));
		float edge = smoothstep(0.15, 0.8, adjacent_matte);
		float brightness = max(color.r, max(color.g, color.b));
		opacity *= 1.0 - edge * smoothstep(0.32, 0.68, brightness);
		color *= 1.0 - edge * 0.3;
	}
	COLOR = vec4(color, source.a * opacity) * sprite_tint;
}
