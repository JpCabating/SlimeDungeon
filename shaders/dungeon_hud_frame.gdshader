shader_type canvas_item;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float darkest = min(art.r, min(art.g, art.b));
	float chroma = max(art.r, max(art.g, art.b)) - darkest;
	bool inside = UV.x > 0.15 && UV.x < 0.86 && UV.y > 0.25 && UV.y < 0.75;
	float matte = (1.0 - smoothstep(0.035, 0.10, chroma)) * smoothstep(inside ? 0.53 : 0.76, inside ? 0.62 : 0.84, darkest);
	COLOR = vec4(mix(art.rgb, vec3(0.035, 0.047, 0.060), inside ? matte : 0.0), art.a * (inside ? 1.0 : 1.0 - matte));
}
