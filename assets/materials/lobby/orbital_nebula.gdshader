shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, fog_disabled;

uniform vec3 cloud_color : source_color = vec3(0.16, 0.27, 0.38);
uniform float density = 0.5;
varying vec3 local_position;
varying vec3 local_camera;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i+vec3(1,0,0)), f.x), mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x), f.y), mix(mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x), mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	local_position = VERTEX;
	local_camera = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX * vec4(0, 0, 0, 1)).xyz;
}
void fragment() {
	vec3 ray = normalize(local_position - local_camera);
	float b = dot(local_camera, ray);
	float discriminant = b*b - dot(local_camera, local_camera) + 1.0;
	float total = 0.0;
	if (discriminant > 0.0) {
		float start = max(0.0, -b - sqrt(discriminant));
		float finish = -b + sqrt(discriminant);
		float step_size = (finish - start) / 28.0;
		for (int i = 0; i < 28; i++) {
			vec3 p = local_camera + ray * (start + (float(i) + 0.5) * step_size);
			float n = noise3(p * 5.0) * 0.58 + noise3(p * 12.0) * 0.28 + noise3(p * 29.0) * 0.14;
			float edge = 1.0 - smoothstep(0.55, 1.0, length(p));
			float filament = smoothstep(0.46, 0.72, n) * exp(-abs(p.y + sin(p.x * 4.0) * 0.18) * 5.0);
			total += filament * edge * step_size;
		}
	}
	ALBEDO = cloud_color * total * density;
	ALPHA = 1.0;
}
