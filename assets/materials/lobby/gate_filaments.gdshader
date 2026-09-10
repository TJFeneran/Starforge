shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

void fragment() {
	float edge = pow(max(1.0 - abs(UV.y * 2.0 - 1.0), 0.0), 1.5);
	float runner = pow(0.5 + 0.5 * sin(UV.x * 6.283185 - TIME * 1.9 + COLOR.r * 5.0), 7.0);
	float breaks = smoothstep(-0.65, 0.05, sin(UV.x * 31.4159 + TIME * 0.7 + COLOR.r * 4.0));
	ALBEDO = vec3(0.0);
	EMISSION = mix(vec3(1.0, 0.32, 0.035), vec3(1.0, 0.94, 0.65), runner) * (2.0 + runner * 5.0);
	ALPHA = edge * breaks * (0.28 + runner * 0.7);
}
