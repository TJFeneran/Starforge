shader_type spatial;
render_mode unshaded, specular_disabled;

uniform vec4 amber : source_color = vec4(1.0, 0.48, 0.12, 1.0);
uniform vec4 white_hot : source_color = vec4(1.0, 0.94, 0.75, 1.0);
uniform float pulse : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	float center = pow(max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 0.65);
	vec3 heat = mix(amber.rgb, white_hot.rgb, center);
	ALBEDO = heat;
	EMISSION = heat * (1.6 + pulse * 0.55);
}
