shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 amber : source_color = vec4(1.0, 0.46, 0.065, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.9, 0.48, 1.0);

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.7);
	float taper = pow(max(sin(UV.y * 3.14159265), 0.0), 0.7);
	float wave = sin(UV.x * 43.9823 + UV.y * 15.0 - TIME * 2.0);
	float strands = pow(max(wave, 0.0), 14.0);
	float veins = pow(max(sin(UV.x * 81.6814 - UV.y * 25.0 + TIME * 1.3), 0.0), 22.0);
	float breath = 0.82 + 0.18 * sin(TIME * 1.7);
	float field = rim * (0.15 + strands * 0.6 + veins * 0.3) * taper * breath;
	ALBEDO = vec3(0.0);
	EMISSION = mix(amber.rgb, hot.rgb, strands * 0.55) * 3.8;
	ALPHA = clamp(field, 0.0, 0.8);
}
