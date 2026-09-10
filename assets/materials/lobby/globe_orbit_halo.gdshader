shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, specular_disabled;

uniform vec4 halo_color : source_color = vec4(0.35, 0.82, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(0.55, 0.9, 0.78, 1.0);
uniform float energy = 1.8;
uniform float soft_edge = 0.95;
uniform float pulse_speed = 0.35;

void fragment() {
	// Soft tube falloff — center stays bright, edges dissolve into bloom.
	float tube = abs(UV.y - 0.5) * 2.0;
	float along = 0.75 + 0.25 * sin(UV.x * TAU * 3.0 + TIME * pulse_speed);
	float glow = pow(clamp(1.0 - tube / max(soft_edge, 0.001), 0.0, 1.0), 2.8);
	float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.4);
	float pulse = 0.88 + 0.12 * sin(TIME * pulse_speed * TAU);
	vec3 color = mix(halo_color.rgb, accent_color.rgb, fresnel * 0.65 + UV.x * 0.1);
	color *= (glow * 1.8 + fresnel * 0.55) * energy * pulse * along;
	ALBEDO = color;
	EMISSION = color * 2.4;
	ALPHA = clamp(glow * 0.35 + fresnel * 0.2, 0.0, 0.55);
}
