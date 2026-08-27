shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(1.0, 0.96, 0.90, 0.92);
uniform float blur_amount : hint_range(0.0, 8.0) = 2.4;

uniform float wind_speed : hint_range(0.1, 6.0) = 1.6;
uniform float wind_strength : hint_range(0.0, 0.2) = 0.035;
uniform float flutter_speed : hint_range(0.1, 10.0) = 3.2;
uniform float flutter_strength : hint_range(0.0, 0.1) = 0.012;

void vertex() {
	// Base fija en el suelo (UV.y = 1.0) y copa flexible (UV.y = 0.0)
	float wind_weight = clamp(1.0 - UV.y, 0.0, 1.0);
	float sway_factor = pow(wind_weight, 1.4);

	float t = TIME * wind_speed;
	float main_sway = sin(t) * wind_strength;
	float flutter = cos(TIME * flutter_speed) * flutter_strength;

	VERTEX.x += (main_sway + flutter) * sway_factor;
	VERTEX.y -= abs(main_sway) * 0.12 * sway_factor;
}

void fragment() {
	vec2 uv = UV;
	vec2 tex_size = vec2(textureSize(albedo_texture, 0));
	vec2 ps = (1.0 / tex_size) * blur_amount;

	// Muestreo suave tipo bokeh / difuminado de primer plano
	vec4 col = texture(albedo_texture, uv) * 0.28;
	col += texture(albedo_texture, uv + vec2(ps.x, 0.0)) * 0.14;
	col += texture(albedo_texture, uv - vec2(ps.x, 0.0)) * 0.14;
	col += texture(albedo_texture, uv + vec2(0.0, ps.y)) * 0.14;
	col += texture(albedo_texture, uv - vec2(0.0, ps.y)) * 0.14;
	col += texture(albedo_texture, uv + vec2(ps.x, ps.y) * 0.707) * 0.08;
	col += texture(albedo_texture, uv - vec2(ps.x, ps.y) * 0.707) * 0.08;

	ALBEDO = col.rgb * tint_color.rgb;
	ALPHA = col.a * tint_color.a;
	ROUGHNESS = 0.95;
	SPECULAR = 0.0;
}