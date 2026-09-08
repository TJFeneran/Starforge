shader_type particles;
render_mode disable_force, disable_velocity;

// Deterministic trajectories remain inside a 0.85 m cylinder. No attraction overshoot.
float hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

void start() {
	CUSTOM.x = hash(float(INDEX) + 1.0) * 6.283185;
	CUSTOM.y = 0.0;
	CUSTOM.z = 0.55 + hash(float(INDEX) + 9.0) * 0.25;
}

void process() {
	CUSTOM.y += DELTA / LIFETIME;
	float t = clamp(CUSTOM.y, 0.0, 1.0);
	float radius = mix(CUSTOM.z, 0.12, t);
	float angle = CUSTOM.x + t * 1.7;
	TRANSFORM[3].xyz = vec3(cos(angle) * radius, mix(2.25, 3.55, t), sin(angle) * radius);
	float size = smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.75, 1.0, t));
	TRANSFORM[0].xyz = vec3(size, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, size * 1.8, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, size);
	COLOR = vec4(1.0, 0.69, 0.27, 1.0);
}
