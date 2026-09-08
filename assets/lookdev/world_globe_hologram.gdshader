shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, specular_disabled;

uniform vec4 deep_color : source_color = vec4(0.01, 0.05, 0.12, 1.0);
uniform vec4 core_color : source_color = vec4(0.03, 0.42, 0.58, 1.0);
uniform vec4 nebula_color : source_color = vec4(0.45, 0.05, 0.85, 1.0);
uniform vec4 hot_color : source_color = vec4(0.55, 0.95, 1.0, 1.0);
uniform vec4 grid_color : source_color = vec4(0.18, 0.98, 0.95, 1.0);
uniform float grid_density = 14.0;
uniform float grid_width = 0.012;
uniform float scanline_density = 72.0;
uniform float scanline_strength = 0.22;
uniform float hologram_strength = 3.2;
uniform float star_density = 52.0;
uniform float rotation_speed = 0.035;
uniform float flicker_strength = 0.08;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * value_noise(p);
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

float line_mask(float value, float width) {
	float d = abs(fract(value) - 0.5);
	return 1.0 - smoothstep(width, width + 0.01, d);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	float ndv = max(dot(n, view_dir), 0.0);
	float rim = pow(1.0 - ndv, 2.2);
	float soft_rim = pow(1.0 - ndv, 1.15);

	vec2 uv = UV;
	uv.x += TIME * rotation_speed;

	// Abstract continent / nebula masses — unidentifiable, not Earth.
	float continents = fbm(uv * vec2(4.2, 3.1) + vec2(TIME * 0.01, 0.0));
	continents = smoothstep(0.42, 0.72, continents);
	float nebula = fbm(uv * vec2(7.5, 5.8) - vec2(0.0, TIME * 0.02));
	nebula = smoothstep(0.35, 0.85, nebula);

	// Navigational lat/long grid + a secondary finer overlay.
	float lat = line_mask(uv.y * grid_density, grid_width);
	float lon = line_mask(uv.x * grid_density * 1.45, grid_width);
	float fine = max(
		line_mask(uv.y * grid_density * 3.0, grid_width * 0.55),
		line_mask(uv.x * grid_density * 4.0, grid_width * 0.55)
	) * 0.35;
	float grid = max(max(lat, lon), fine);

	// Hex-ish lattice feel over the sphere for a non-standard map texture.
	vec2 hx = uv * vec2(grid_density * 1.8, grid_density * 1.1);
	hx.x += floor(hx.y) * 0.5;
	float hex = max(line_mask(hx.x, grid_width * 0.7), line_mask(hx.y, grid_width * 0.7)) * 0.45;
	grid = max(grid, hex);

	// Scanlines + sweeping hologram band.
	float scan = sin((uv.y + TIME * 0.11) * scanline_density) * 0.5 + 0.5;
	float band = smoothstep(0.0, 0.08, abs(fract(uv.y * 0.55 + TIME * 0.08) - 0.5));
	band = 1.0 - band;

	// Star / data nodes.
	vec2 star_uv = uv * star_density;
	vec2 star_cell = floor(star_uv);
	float star = step(0.988, hash21(star_cell));
	star *= 0.45 + 0.55 * sin(TIME * 3.2 + hash21(star_cell + 7.0) * 12.0);
	// Extra bright "city" nodes clustered on continent masses.
	float node = step(0.96, hash21(star_cell + 19.0)) * continents;

	float flicker = 1.0 + sin(TIME * 17.0) * flicker_strength
		+ sin(TIME * 41.0 + uv.x * 8.0) * flicker_strength * 0.5;

	vec3 color = deep_color.rgb;
	color = mix(color, core_color.rgb, continents * 0.85);
	color += nebula_color.rgb * nebula * 0.55;
	color += hot_color.rgb * (node * 1.6 + star * 1.1);
	color += grid_color.rgb * (grid * 1.9 + band * 0.55);
	color += grid_color.rgb * scan * scanline_strength;
	color += grid_color.rgb * (rim * 2.4 + soft_rim * 0.35);
	color *= flicker;

	float alpha = 0.18
		+ continents * 0.22
		+ nebula * 0.12
		+ grid * 0.38
		+ star * 0.22
		+ node * 0.28
		+ rim * 0.55
		+ band * 0.15;
	alpha = clamp(alpha, 0.08, 0.92);

	ALBEDO = color;
	EMISSION = color * hologram_strength;
	ALPHA = alpha;
}
