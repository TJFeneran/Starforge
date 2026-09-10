shader_type canvas_item;
render_mode unshaded;

// Soft freeze blur: mip lod for broad softness, then a wide Gaussian for smooth falloff.
uniform sampler2D freeze_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float blur_lod = 2.25;
uniform float blur_spread = 3.25;
uniform float vignette = 0.5;
uniform float darken = 0.38;

void fragment() {
	vec2 texel = blur_spread / vec2(textureSize(freeze_tex, 0));
	// 9-tap Gaussian weights (sigma ~1.7), applied on both axes via diamond + cross samples.
	float w0 = 0.1963806;
	float w1 = 0.2967529;
	float w2 = 0.0943816;
	vec3 color = textureLod(freeze_tex, UV, blur_lod).rgb * w0;
	color += textureLod(freeze_tex, UV + vec2(texel.x, 0.0), blur_lod).rgb * w1;
	color += textureLod(freeze_tex, UV - vec2(texel.x, 0.0), blur_lod).rgb * w1;
	color += textureLod(freeze_tex, UV + vec2(0.0, texel.y), blur_lod).rgb * w1;
	color += textureLod(freeze_tex, UV - vec2(0.0, texel.y), blur_lod).rgb * w1;
	color += textureLod(freeze_tex, UV + texel, blur_lod).rgb * w2;
	color += textureLod(freeze_tex, UV - texel, blur_lod).rgb * w2;
	color += textureLod(freeze_tex, UV + vec2(texel.x, -texel.y), blur_lod).rgb * w2;
	color += textureLod(freeze_tex, UV + vec2(-texel.x, texel.y), blur_lod).rgb * w2;
	// Second, wider pass for cinematic softness without blocky mip stair-steps.
	vec2 wide = texel * 2.4;
	color = color * 0.62
		+ textureLod(freeze_tex, UV + vec2(wide.x, 0.0), blur_lod + 0.35).rgb * 0.095
		+ textureLod(freeze_tex, UV - vec2(wide.x, 0.0), blur_lod + 0.35).rgb * 0.095
		+ textureLod(freeze_tex, UV + vec2(0.0, wide.y), blur_lod + 0.35).rgb * 0.095
		+ textureLod(freeze_tex, UV - vec2(0.0, wide.y), blur_lod + 0.35).rgb * 0.095;
	float r = length(UV - vec2(0.5));
	float veil = mix(1.0 - darken, 1.0 - darken * 1.3, smoothstep(0.22, 0.98, r) * vignette);
	COLOR = vec4(color * veil, 1.0);
}
