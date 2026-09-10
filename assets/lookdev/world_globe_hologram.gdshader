shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_opaque, specular_disabled;

// Starforge visual bible palette roles, driven as morphing fields — not a flat cyan wash.
uniform vec4 ocean_color : source_color = vec4(0.04, 0.18, 0.28, 1.0);
uniform vec4 land_color : source_color = vec4(0.16, 0.42, 0.38, 1.0);
uniform vec4 desert_color : source_color = vec4(0.65, 0.42, 0.22, 1.0);
uniform vec4 ice_color : source_color = vec4(0.72, 0.88, 0.96, 1.0);
uniform vec4 magma_color : source_color = vec4(1.0, 0.55, 0.14, 1.0);
uniform vec4 plasma_color : source_color = vec4(0.50, 0.88, 0.78, 1.0);
uniform vec4 violet_color : source_color = vec4(0.45, 0.18, 0.78, 1.0);
uniform vec4 grid_color : source_color = vec4(0.32, 0.78, 1.0, 1.0);
uniform float grid_density = 16.0;
uniform float grid_width = 0.010;
uniform float scanline_density = 96.0;
uniform float scanline_strength = 0.12;
uniform float hologram_strength = 2.6;
uniform float star_density = 48.0;
uniform float rotation_speed = 0.028;
uniform float flicker_strength = 0.05;
uniform float morph_speed = 0.22;
uniform float atmosphere_strength = 1.35;
uniform float iridescence = 0.85;
uniform float displacement = 0.018;

varying vec3 v_local;
varying vec3 v_world_normal;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
			mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
			mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise3(p);
		p = vec3(
			dot(p, vec3(0.80, 0.60, 0.00)),
			dot(p, vec3(-0.48, 0.64, 0.60)),
			dot(p, vec3(0.36, -0.48, 0.80))) * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

float line_mask(float value, float width) {
	float d = abs(fract(value) - 0.5);
	return 1.0 - smoothstep(width, width + 0.008, d);
}

vec3 palette_cycle(float t) {
	// Continuous spectral morph across forge / frontier / celestial roles.
	vec3 a = ocean_color.rgb;
	vec3 b = land_color.rgb;
	vec3 c = magma_color.rgb;
	vec3 d = violet_color.rgb;
	vec3 e = plasma_color.rgb;
	float w0 = smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.2, 0.45, t));
	float w1 = smoothstep(0.2, 0.45, t) * (1.0 - smoothstep(0.4, 0.65, t));
	float w2 = smoothstep(0.4, 0.65, t) * (1.0 - smoothstep(0.6, 0.85, t));
	float w3 = smoothstep(0.6, 0.85, t) * (1.0 - smoothstep(0.8, 1.0, t));
	float w4 = smoothstep(0.8, 1.0, t) + (1.0 - smoothstep(0.0, 0.15, t));
	float wsum = max(w0 + w1 + w2 + w3 + w4, 0.001);
	return (a * w0 + b * w1 + c * w2 + d * w3 + e * w4) / wsum;
}

vec3 thin_film(vec3 view_dir, vec3 normal, float thickness) {
	float ndv = clamp(dot(normal, view_dir), 0.0, 1.0);
	float phase = thickness * (1.2 - ndv) * 12.566;
	return 0.5 + 0.5 * vec3(
		sin(phase),
		sin(phase + 2.094),
		sin(phase + 4.189));
}

void vertex() {
	v_local = VERTEX;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float breathe = fbm(normalize(VERTEX) * 3.0 + vec3(TIME * morph_speed * 0.35));
	float ridge = abs(fbm(normalize(VERTEX) * 7.0 - vec3(TIME * morph_speed * 0.2)) - 0.5);
	VERTEX += NORMAL * (breathe * 0.55 - ridge * 0.35) * displacement;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 view_dir = normalize(VIEW);
	float ndv = max(dot(n, view_dir), 0.0);
	float rim = pow(1.0 - ndv, 2.35);
	float soft_rim = pow(1.0 - ndv, 1.05);
	float core_glow = pow(ndv, 3.5);

	vec3 sphere = normalize(v_local);
	float t = TIME;

	// Domain-warped planet field — continents morph continuously in 3D.
	vec3 warp = vec3(
		fbm(sphere * 2.4 + vec3(t * morph_speed * 0.11, 0.0, 0.0)),
		fbm(sphere * 2.4 + vec3(17.1, t * morph_speed * 0.09, 3.2)),
		fbm(sphere * 2.4 + vec3(4.2, 8.8, t * morph_speed * 0.07)));
	vec3 land_p = sphere * 3.6 + (warp - 0.5) * 1.35 + vec3(t * rotation_speed, 0.0, 0.0);
	float land = fbm(land_p);
	float land_mask = smoothstep(0.42, 0.62, land);
	float coast = smoothstep(0.38, 0.48, land) * (1.0 - smoothstep(0.58, 0.72, land));

	float desert = smoothstep(0.62, 0.85, fbm(land_p * 1.7 + 9.0)) * land_mask;
	float ice = smoothstep(0.68, 0.88, abs(sphere.y)) * (0.25 + 0.75 * land_mask);
	float mountains = smoothstep(0.66, 0.92, fbm(land_p * 5.5)) * land_mask;

	// Magma / forge rivers that crawl and reconnect.
	float veins = fbm(sphere * 8.0 + vec3(t * morph_speed * 0.4, -t * morph_speed * 0.25, 2.0));
	float magma = smoothstep(0.66, 0.78, veins) * (0.25 + 0.75 * land_mask);
	magma += smoothstep(0.8, 0.93, abs(fbm(sphere * 14.0 - t * morph_speed * 0.5) - 0.5) * 2.0) * 0.4;

	// Storm / cloud bands with independent drift.
	float clouds = fbm(sphere * vec3(5.5, 2.2, 5.5) + vec3(t * 0.05, t * 0.02, -t * 0.03));
	clouds = smoothstep(0.58, 0.88, clouds) * (0.35 + 0.45 * (1.0 - land_mask * 0.5));

	// Nebula / aurora sheet that slides under the hologram shell.
	float aurora = fbm(sphere * 3.2 + vec3(-t * morph_speed * 0.15, t * morph_speed * 0.2, 5.0));
	aurora = pow(smoothstep(0.52, 0.92, aurora), 1.35);

	float spectrum = fract(fbm(sphere * 1.8 + t * morph_speed * 0.08) + t * morph_speed * 0.05);
	vec3 morph_tint = palette_cycle(spectrum);

	vec3 color = ocean_color.rgb * (0.55 + 0.45 * fbm(sphere * 6.0 + t * 0.03));
	color = mix(color, land_color.rgb, land_mask);
	color = mix(color, desert_color.rgb, desert * 0.7);
	color = mix(color, ice_color.rgb, ice * 0.85);
	color = mix(color, mix(land_color.rgb, ice_color.rgb, 0.35), mountains * 0.45);
	color = mix(color, magma_color.rgb, clamp(magma, 0.0, 1.0));
	color = mix(color, violet_color.rgb, aurora * 0.55);
	color = mix(color, plasma_color.rgb, clouds * 0.35);
	color = mix(color, morph_tint, 0.18 + 0.12 * sin(t * morph_speed + sphere.y * 4.0));
	color += magma_color.rgb * coast * 0.4;
	color += plasma_color.rgb * coast * 0.18;

	// Lat/long + hex navigational lattice on the shell.
	vec2 uv = vec2(atan(sphere.z, sphere.x) / TAU + 0.5 + t * rotation_speed, asin(clamp(sphere.y, -1.0, 1.0)) / PI + 0.5);
	float lat = line_mask(uv.y * grid_density, grid_width);
	float lon = line_mask(uv.x * grid_density * 1.55, grid_width * (0.7 + 0.6 * abs(sphere.y)));
	vec2 hx = uv * vec2(grid_density * 1.9, grid_density * 1.15);
	hx.x += floor(hx.y) * 0.5;
	float hex = max(line_mask(hx.x, grid_width * 0.65), line_mask(hx.y, grid_width * 0.65)) * 0.4;
	float grid = max(max(lat, lon), hex);
	grid *= 0.45 + 0.40 * land_mask + 0.30 * aurora;

	// Data nodes / settlement pulses.
	vec2 star_uv = uv * star_density;
	vec2 cell = floor(star_uv);
	float star = step(0.986, hash21(cell));
	star *= 0.4 + 0.6 * sin(t * 4.0 + hash21(cell + 3.1) * 14.0);
	float node = step(0.955, hash21(cell + 19.0)) * land_mask;
	node *= 0.5 + 0.5 * sin(t * 6.5 + hash21(cell + 41.0) * 20.0);

	float scan = sin((uv.y + t * 0.14) * scanline_density) * 0.5 + 0.5;
	float band = 1.0 - smoothstep(0.0, 0.07, abs(fract(uv.y * 0.7 + t * 0.09) - 0.5));

	vec3 film = thin_film(view_dir, n, 0.65 + 0.45 * fbm(sphere * 4.0 + t * 0.1));
	vec3 rim_color = mix(grid_color.rgb, film, iridescence * 0.75);
	rim_color = mix(rim_color, magma_color.rgb, magma * 0.45);
	rim_color = mix(rim_color, violet_color.rgb, aurora * 0.55);

	float flicker = 1.0
		+ sin(t * 19.0) * flicker_strength
		+ sin(t * 47.0 + uv.x * 10.0) * flicker_strength * 0.45;

	color += grid_color.rgb * grid * 0.95;
	color += plasma_color.rgb * (star * 0.9 + node * 1.35);
	color += rim_color * (rim * 1.35 * atmosphere_strength + soft_rim * 0.25);
	color += plasma_color.rgb * band * 0.28;
	color += grid_color.rgb * scan * scanline_strength * 0.65;
	color += morph_tint * core_glow * 0.18;
	color.r += rim * film.r * iridescence * 0.22;
	color.b += rim * film.b * iridescence * 0.28;
	color *= flicker;
	// Keep additive bloom from crushing the multi-color fields to white.
	color = min(color, vec3(1.35));

	float alpha = 0.22
		+ land_mask * 0.38
		+ desert * 0.12
		+ ice * 0.14
		+ magma * 0.35
		+ aurora * 0.28
		+ clouds * 0.16
		+ grid * 0.22
		+ star * 0.14
		+ node * 0.22
		+ rim * 0.42 * atmosphere_strength
		+ band * 0.08
		+ coast * 0.16;
	alpha = clamp(alpha, 0.18, 0.94);

	ALBEDO = color;
	EMISSION = color * hologram_strength;
	ALPHA = alpha;
}
