shader_type spatial;
render_mode cull_back;

uniform vec4 face_color : source_color = vec4(0.075, 0.11, 0.16, 1.0);
uniform float metalness = 0.65;
uniform float edge_width = 0.018;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 p = UV;
	float grain = hash(floor(p * vec2(1000.0, 180.0)));
	float brushed = sin(p.y * 1800.0 + sin(p.x * 40.0) * 0.8) * 0.5 + 0.5;
	float scratch = step(0.985, hash(vec2(floor(p.y * 600.0), 9.0))) * step(0.48, sin(p.x * 19.0 + p.y * 4.0));
	float edge = min(min(p.x, 1.0 - p.x), min(p.y, 1.0 - p.y));
	float wear = (1.0 - smoothstep(0.0, edge_width, edge)) * (0.3 + grain * 0.7);
	ALBEDO = face_color.rgb * (0.88 + brushed * 0.10 + grain * 0.12) + vec3(scratch * 0.035 + wear * 0.12);
	METALLIC = metalness;
	ROUGHNESS = clamp(0.48 + grain * 0.17 - scratch * 0.12, 0.0, 1.0);
	// Very subtle lift, not a luminous sign; remains readable in the dark bay.
	EMISSION = face_color.rgb * 0.16;
}
