shader_type particles;
render_mode disable_force, disable_velocity;

float hash(float n) { return fract(sin(n * 127.1 + 311.7) * 43758.5453); }

void start() {
	CUSTOM = vec4(hash(float(INDEX) + 1.0) * 6.283185, 0.0, hash(float(INDEX) + 9.0), 0.0);
}

void process() {
	CUSTOM.y += DELTA / LIFETIME;
	float t = clamp(CUSTOM.y, 0.0, 1.0);
	float angle = CUSTOM.x + t * (2.5 + CUSTOM.z * 3.0);
	float radius = (0.62 + CUSTOM.z * 0.48) * sin(t * 2.3 + 0.45);
	TRANSFORM[3].xyz = vec3(cos(angle) * radius, mix(-1.25, 2.3, t), sin(angle) * radius * 0.8);
	float fade = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.7, 1.0, t));
	float size = fade * (0.55 + CUSTOM.z * 0.8);
	TRANSFORM[0].xyz = vec3(size, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, size * (2.0 + CUSTOM.z * 3.0), 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, size);
	COLOR = vec4(1.0, 0.48 + CUSTOM.z * 0.38, 0.12 + CUSTOM.z * 0.3, fade);
}
