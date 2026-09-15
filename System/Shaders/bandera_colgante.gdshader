shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Ondeado de estandarte colgante para el nivel del rio.
// La parte superior queda fija (colgada) y la inferior se mueve con el viento.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float wind_speed : hint_range(0.1, 6.0) = 1.8;
uniform float wind_strength : hint_range(0.0, 0.3) = 0.06;
uniform float flutter_speed : hint_range(0.1, 10.0) = 3.6;
uniform float flutter_strength : hint_range(0.0, 0.1) = 0.02;

void vertex() {
	// Arriba fijo (UV.y = 0.0), abajo libre (UV.y = 1.0)
	float sway_factor = pow(clamp(UV.y, 0.0, 1.0), 1.5);

	float t = TIME * wind_speed;
	float main_sway = sin(t) * wind_strength;
	float flutter = cos(TIME * flutter_speed) * flutter_strength;

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
