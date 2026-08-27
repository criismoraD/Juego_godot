shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform vec4 warm_tint : source_color = vec4(0.98, 0.74, 0.48, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.22, 0.14, 0.18, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.28;
uniform float saturation_boost : hint_range(0.8, 1.5) = 1.06;
uniform float contrast_boost : hint_range(0.8, 1.5) = 1.04;

vec3 blend_soft_light(vec3 base, vec3 blend) {
	return vec3(
		(blend.r < 0.5) ? (2.0 * base.r * blend.r + base.r * base.r * (1.0 - 2.0 * blend.r)) : (sqrt(base.r) * (2.0 * blend.r - 1.0) + 2.0 * base.r * (1.0 - blend.r)),
		(blend.g < 0.5) ? (2.0 * base.g * blend.g + base.g * base.g * (1.0 - 2.0 * blend.g)) : (sqrt(base.g) * (2.0 * blend.g - 1.0) + 2.0 * base.g * (1.0 - blend.g)),
		(blend.b < 0.5) ? (2.0 * base.b * blend.b + base.b * base.b * (1.0 - 2.0 * blend.b)) : (sqrt(base.b) * (2.0 * blend.b - 1.0) + 2.0 * base.b * (1.0 - blend.b))
	);
}

void fragment() {
	vec4 screen_color = texture(screen_texture, SCREEN_UV);

	float luma = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 target_tint = mix(shadow_tint.rgb, warm_tint.rgb, luma);
	vec3 graded = blend_soft_light(screen_color.rgb, target_tint);

	graded = mix(vec3(0.5), graded, contrast_boost);
	float graded_luma = dot(graded, vec3(0.299, 0.587, 0.114));
	graded = mix(vec3(graded_luma), graded, saturation_boost);

	COLOR = vec4(mix(screen_color.rgb, graded, intensity), screen_color.a);
}
