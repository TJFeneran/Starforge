shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float activation : hint_range(0.0, 1.0) = 0.0;
uniform float ignition : hint_range(0.0, 1.0) = 0.0;
uniform vec3 energy_color : source_color = vec3(0.035, 0.58, 1.0);
uniform vec3 inner_wisp_color : source_color = vec3(0.45, 0.8, 1.0);
uniform vec3 outer_wisp_color : source_color = vec3(1.0, 0.82, 0.3);

vec2 gradient(vec2 p) {
	// Hash without large sine products, then use unit gradients instead of
	// interpolated cell values so the smoke doesn't reveal square plateaus.
	vec3 h = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973));
	h += dot(h, h.yzx + 33.33);
	float angle = fract((h.x + h.y) * h.z) * 6.283185;
	return vec2(cos(angle), sin(angle));
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Quintic interpolation keeps both derivatives continuous at cell edges.
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float n = mix(
		mix(dot(gradient(i), f), dot(gradient(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(gradient(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
			dot(gradient(i + vec2(1.0)), f - vec2(1.0)), u.x), u.y);
	return 0.5 + n * 0.7;
}

float turbulence(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		// Fade unresolved octaves rather than letting them shimmer/checker.
		float footprint = max(length(dFdx(p)), length(dFdy(p)));
		float resolved = 1.0 - smoothstep(0.25, 0.75, footprint);
		value += mix(0.5, noise(p), resolved) * amplitude;
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + 4.7;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float growth = mix(0.035, 1.0, activation);
	float ring_radius = 0.64 * growth;
	// Sample rotating Cartesian domains: no seam where the polar angle wraps.
	vec2 orbit = vec2(cos(angle - TIME * 0.65), sin(angle - TIME * 0.65));
	float billow = turbulence(orbit * 4.8 + vec2(radius * 9.0 - TIME * 1.8, TIME * 0.45));
	vec2 flow = vec2(billow - 0.5, noise(p * 3.0 + TIME * 0.18) - 0.5);
	float detail = turbulence(p * 15.0 + orbit * 2.5 + flow * 3.0 - vec2(TIME * 0.7, TIME * 1.3));
	float distorted_radius = ring_radius + (billow - 0.5) * 0.11 * growth;
	float distance_to_ring = abs(radius - distorted_radius);
	float core = exp(-distance_to_ring * distance_to_ring / 0.00022);
	float halo = exp(-distance_to_ring * distance_to_ring / 0.0055);
	float smoke_band = exp(-pow((radius - ring_radius - 0.045) / 0.13, 2.0));
	float wisps = smoke_band * smoothstep(0.32, 0.76, billow + detail * 0.25);
	float thread_width = 0.018 + fwidth(detail);
	float threads = (1.0 - smoothstep(thread_width * 0.35, thread_width * 1.8, abs(detail - 0.49))) * smoke_band;
	float interior = (1.0 - smoothstep(ring_radius - 0.06, ring_radius, radius)) * activation;
	float inner_cloud = turbulence(p * 5.0 + vec2(TIME * 0.16, -TIME * 0.22));
	float flash_radius = ring_radius + (1.0 - ignition) * 0.24;
	float shockwave = exp(-pow((radius - flash_radius) / 0.018, 2.0)) * ignition;
	float edge_fade = 1.0 - smoothstep(0.88, 0.99, radius);
	float energy = core * 4.5 + halo * 0.65;
	// Radial light-blue-to-gold wisps; preserve the aperture and white-cyan core.
	float outer_smoke = smoothstep(distorted_radius, distorted_radius + 0.055, radius);
	float wisp_gradient = smoothstep(distorted_radius + 0.02, distorted_radius + 0.18, radius);
	vec3 wisp_color = mix(inner_wisp_color, outer_wisp_color, wisp_gradient);
	ALBEDO = vec3(0.004, 0.016, 0.035) * interior
		+ wisp_color * outer_smoke * 0.45;
	EMISSION = energy_color * (energy + shockwave * 3.0)
		+ wisp_color * (wisps * 1.3 + threads * 0.8)
		+ vec3(0.45, 0.85, 1.0) * core * (2.0 + ignition * 5.0)
		+ energy_color * interior * inner_cloud * 0.11;
	ALPHA = clamp(interior * 0.91 + core + halo * 0.5 + wisps * 0.9 + threads * 0.5 + shockwave, 0.0, 1.0)
		* edge_fade * smoothstep(0.0, 0.12, activation);
}
