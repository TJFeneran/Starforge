shader_type spatial;

// World-space meters: resizing the hall never stretches its panel pattern.
uniform vec4 ceramic_color : source_color = vec4(0.64, 0.63, 0.56, 1.0);
uniform vec4 deck_color : source_color = vec4(0.105, 0.14, 0.18, 1.0);
uniform vec4 seam_color : source_color = vec4(0.035, 0.046, 0.06, 1.0);
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	float radius = length(p);
	// Broad pale approach and orbit lane, with dark recessed workshop decking.
	float approach = 1.0 - smoothstep(2.85, 2.9, abs(p.x));
	float orbit = smoothstep(4.1, 4.14, radius) * (1.0 - smoothstep(8.1, 8.14, radius));
	float ceramic = max(approach, orbit);
	float apron = 1.0 - smoothstep(3.8, 3.84, radius);
	ceramic = max(ceramic, apron);
	vec2 tile_size = mix(vec2(2.0, 1.0), vec2(2.0, 2.0), ceramic);
	vec2 cell = floor(p / tile_size);
	vec2 edge = min(fract(p / tile_size), 1.0 - fract(p / tile_size)) * tile_size;
	float line = 1.0 - smoothstep(0.009, 0.019, min(edge.x, edge.y));
	// Radial joints only on the central apron.
	float angle = atan(p.y, p.x);
	float radial_joint = 1.0 - smoothstep(0.006, 0.018, abs(sin(angle * 8.0)) * radius);
	line = mix(line, max(radial_joint, 1.0 - smoothstep(0.01, 0.025, abs(radius - 3.2))), apron);
	float grain = noise(p * 34.0);
	float broad = noise(p * 0.7);
	float wear = noise(p * vec2(15.0, 1.8)) * noise(p * 2.3);
	vec3 base = mix(deck_color.rgb, ceramic_color.rgb, ceramic);
	base *= 0.93 + hash(cell) * 0.09 + broad * 0.045;
	base += (grain - 0.5) * 0.016 + wear * 0.012;
	ALBEDO = mix(base, seam_color.rgb, line * 0.83);
	METALLIC = mix(0.55, 0.08, ceramic) * (1.0 - line);
	ROUGHNESS = clamp(mix(0.53, 0.74, ceramic) + (broad - 0.5) * 0.12 - wear * 0.07 + line * 0.15, 0.35, 0.92);
	// Subtle grain normal, not a noisy displacement surface.
	float dx = noise((p + vec2(0.006, 0.0)) * 34.0) - grain;
	float dy = noise((p + vec2(0.0, 0.006)) * 34.0) - grain;
	NORMAL_MAP = vec3(0.5 + dx * 0.09, 0.5 + dy * 0.09, 1.0);
}
