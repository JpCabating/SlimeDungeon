shader_type canvas_item;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float darkest = min(art.r, min(art.g, art.b));
	float chroma = max(art.r, max(art.g, art.b)) - darkest;
	float pale = smoothstep(0.58, 0.76, darkest) * (1.0 - smoothstep(0.10, 0.22, chroma));
	float glow = smoothstep(-0.012, 0.125, art.r - art.b);
	float highlight = smoothstep(0.91, 0.98, darkest);
	float matte = pale * (1.0 - max(glow, highlight));
	COLOR = vec4(art.rgb, art.a * (1.0 - matte));
}
