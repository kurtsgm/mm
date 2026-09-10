shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	ALBEDO = vec3(0.10, 0.075, 0.05);
	ALPHA = (1.0 - smoothstep(0.15, 1.0, radius)) * 0.28;
}
