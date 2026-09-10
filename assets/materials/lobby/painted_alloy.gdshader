shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Architecture only: clean satin alloy, with brushing along each member's length.
// Detail lives primarily in the anisotropic highlight, not dark albedo scratches.
uniform vec4 paint_color : source_color = vec4(0.80, 0.79, 0.74, 1.0);
uniform float anisotropy : hint_range(0.0, 1.0) = 0.65;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.39;
instance uniform vec3 half_extents = vec3(0.0);
varying vec2 brush_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), u.x), u.y);
}

float filtered_brush(vec2 p, vec2 frequency) {
	vec2 sample_position = p * frequency;
	// Fade unresolved striations to their mean before they become pixel noise.
	float footprint = max(length(dFdx(sample_position)), length(dFdy(sample_position)));
	float visibility = 1.0 - smoothstep(0.25, 0.9, footprint);
	return (noise(sample_position) - 0.5) * visibility;
}

void vertex() {
	// Build a consistent tangent frame instead of using the BoxMesh UV atlas.
	vec3 face = abs(NORMAL);
	vec3 lengths = half_extents * (vec3(1.0) - face);
	vec3 along = vec3(1.0, 0.0, 0.0);
	if (lengths.y >= lengths.x && lengths.y >= lengths.z) {
		along = vec3(0.0, 1.0, 0.0);
	} else if (lengths.z >= lengths.x) {
		along = vec3(0.0, 0.0, 1.0);
	}
	TANGENT = along;
	BINORMAL = normalize(cross(NORMAL, along));
	brush_position = vec2(dot(VERTEX, BINORMAL), dot(VERTEX, TANGENT));
}

void fragment() {
	float fine = filtered_brush(brush_position, vec2(180.0, 1.5));
	float satin = filtered_brush(brush_position, vec2(38.0, 0.7));
	// No chipped-edge mask, black speckles, or noisy normal perturbation.
	ALBEDO = paint_color.rgb * (1.0 + satin * 0.018 + fine * 0.008);
	METALLIC = 0.35;
	ROUGHNESS = base_roughness + satin * 0.045 + fine * 0.025;
	ANISOTROPY = anisotropy;
	ANISOTROPY_FLOW = vec2(1.0, 0.0);
}
