shader_type particles;
render_mode disable_force, disable_velocity;

uniform bool burst = false;
uniform float activation = 0.0;
uniform float radius = 2.5;

float hash(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }

void start() {
	float seed = float(NUMBER) + float(RANDOM_SEED % uint(10000));
	CUSTOM = vec4(hash(seed + 1.0) * 6.283185, 0.0, hash(seed + 9.0), hash(seed + 17.0));
}

void process() {
	CUSTOM.y += DELTA / LIFETIME;
	float t = clamp(CUSTOM.y, 0.0, 1.0);
	float angle = CUSTOM.x + t * (0.7 + CUSTOM.z * 1.6);
	float r = radius + t * (0.12 + CUSTOM.z * (burst ? 1.25 : 0.5));
	TRANSFORM[3].xyz = vec3(cos(angle) * r, sin(angle) * r, 0.07 + sin(t * 3.0 + CUSTOM.x) * 0.12);
	float fade = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.35, 1.0, t)) * activation;
	float size = (0.5 + CUSTOM.w) * fade;
	TRANSFORM[0].xyz = vec3(size, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, size, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, size);
	COLOR = vec4(0.2 + CUSTOM.z * 0.6, 0.75 + CUSTOM.z * 0.25, 1.0, fade);
}
