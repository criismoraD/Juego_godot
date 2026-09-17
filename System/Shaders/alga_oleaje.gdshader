shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Oleaje de alga para el nivel del rio.
// La base queda fija (abajo, UV.y = 1.0) y la punta se mueve (arriba, UV.y = 0.0).

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float oleaje_speed : hint_range(0.1, 6.0) = 1.5;
uniform float oleaje_strength : hint_range(0.0, 0.3) = 0.08;
uniform float rizo_speed : hint_range(0.1, 10.0) = 3.0;
uniform float rizo_strength : hint_range(0.0, 0.1) = 0.02;

void vertex() {
	// Abajo fijo (UV.y = 1.0), arriba libre (UV.y = 0.0)
	float sway_factor = pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.5);

	float t = TIME * oleaje_speed + float(NODE_POSITION_WORLD.x) * 0.15;
	float main_sway = sin(t) * oleaje_strength;
	float flutter = cos(TIME * rizo_speed + float(NODE_POSITION_WORLD.z) * 0.2) * rizo_strength;

	VERTEX.x += (main_sway + flutter) * sway_factor;
	VERTEX.z += flutter * 0.6 * sway_factor;
}

void fragment() {
	vec4 col = texture(albedo_texture, UV);
	ALPHA_SCISSOR_THRESHOLD = 0.05;
	ALBEDO = col.rgb * tint_color.rgb;
	ALPHA = col.a * tint_color.a;
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;
}
