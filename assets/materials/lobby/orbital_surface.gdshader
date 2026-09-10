shader_type spatial;
render_mode unshaded;

uniform vec3 rock_color : source_color = vec3(0.54, 0.58, 0.63);
uniform vec3 sun_direction = vec3(-0.3, 0.6, 0.7);
uniform bool gas_giant = false;
varying vec3 sphere_position;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y), mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float value = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 5; i++) {
		value += weight * noise3(p);
		p = p * 2.07 + vec3(13.1, 7.3, 5.7);
		weight *= 0.5;
	}
	return value;
}
void vertex() { sphere_position = VERTEX; }
void fragment() {
	vec3 n = normalize(sphere_position);
	float terrain = fbm(n * 9.0);
	float detail = fbm(n * 90.0);
	float craters = 0.0;
	// Neighbour-cell crater rims follow the sphere in 3D, with no UV seams.
	vec3 p = n * 19.0;
	vec3 cell = floor(p);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 c = cell + vec3(float(x), float(y), float(z));
				vec3 center = c + vec3(hash(c), hash(c + 31.0), hash(c + 71.0));
				float r = length(p - center) / mix(0.16, 0.5, hash(c + 19.0));
				craters += 0.16 * exp(-pow((r - 0.88) * 9.0, 2.0)) - 0.18 * (1.0 - smoothstep(0.45, 0.85, r));
			}
		}
	}
	vec3 color = rock_color * (0.42 + terrain * 0.75 + detail * 0.22 + craters);
	if (gas_giant) {
		float bands = sin(n.y * 90.0 + fbm(n * 6.0) * 16.0);
		color = mix(vec3(0.14, 0.23, 0.29), rock_color, smoothstep(-0.8, 0.9, bands)) * (0.7 + detail * 0.35);
	}
	float sunlight = smoothstep(-0.06, 0.12, dot(n, normalize(sun_direction))) * max(0.0, dot(n, normalize(sun_direction)));
	ALBEDO = color * (0.015 + sunlight * 1.65);
}
