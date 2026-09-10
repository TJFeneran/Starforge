shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float soft = exp(-r * r * 5.5) * smoothstep(0.12, 0.5, r);
	float rays = pow(max(0.0, sin(angle * 13.0 + sin(angle * 7.0 + TIME * 0.4) * 1.8 - TIME * 0.35)), 10.0);
	float envelope = (1.0 - smoothstep(0.5, 1.0, r));
	float pulse = 0.85 + 0.15 * sin(TIME * 1.7);
	ALBEDO = vec3(0.0);
	EMISSION = vec3(1.0, 0.52, 0.10) * 2.2;
	ALPHA = (soft * 0.34 + rays * soft * 0.5) * envelope * pulse;
}
