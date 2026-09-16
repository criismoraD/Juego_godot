shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// Enredadera colgante para el nivel del rio.
// La parte superior queda fija (colgada) y la inferior se mece con el viento.
// Suavizado tipo bokeh para integrarla como vegetación de fondo.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(1.0, 0.96, 0.9, 0.92);
uniform float blur_amount : hint_range(0.0, 8.0) = 2.4;

uniform float wind_speed : hint_range(0.1, 6.0) = 1.4;
uniform float wind_strength : hint_range(0.0, 0.3) = 0.05;
uniform float flutter_speed : hint_range(0.1, 10.0) = 2.8;
uniform float flutter_strength : hint_range(0.0, 0.1) = 0.015;

void vertex() {
	// Arriba fijo (UV.y = 0.0), abajo libre (UV.y = 1.0)
	float sway_factor = pow(clamp(UV.y, 0.0, 1.0), 1.5);

	float t = TIME * wind_speed;
	float main_sway = sin(t) * wind_strength;
	float flutter = cos(TIME * flutter_speed) * flutter_strength;

	VERTEX.x += (main_sway + flutter) * sway_factor;
	VERTEX.z += flutter * 0.6 * sway_factor;
	VERTEX.y -= abs(main_sway) * 0.15 * sway_factor;
}

void fragment() {
	vec2 uv = UV;
	vec2 tex_size = vec2(textureSize(albedo_texture, 0));
	vec2 ps = (1.0 / tex_size) * blur_amount;

	// Muestreo suave tipo bokeh / difuminado de fondo
	vec4 col = texture(albedo_texture, uv) * 0.28;
	col += texture(albedo_texture, uv + vec2(ps.x, 0.0)) * 0.14;
	col += texture(albedo_texture, uv - vec2(ps.x, 0.0)) * 0.14;
	col += texture(albedo_texture, uv + vec2(0.0, ps.y)) * 0.14;
	col += texture(albedo_texture, uv - vec2(0.0, ps.y)) * 0.14;
	col += texture(albedo_texture, uv + vec2(ps.x, ps.y) * 0.707) * 0.08;
	col += texture(albedo_texture, uv - vec2(ps.x, ps.y) * 0.707) * 0.08;

	ALPHA_SCISSOR_THRESHOLD = 0.05;
	ALBEDO = col.rgb * tint_color.rgb;
	ALPHA = col.a * tint_color.a;
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;
}
