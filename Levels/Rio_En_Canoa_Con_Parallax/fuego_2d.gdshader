shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float blur_amount : hint_range(0.0, 8.0) = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV;
	vec2 tex_size = vec2(textureSize(albedo_texture, 0));
	vec2 ps = (1.0 / tex_size) * blur_amount;

	if (blur_amount <= 0.01) {
		vec4 col = texture(albedo_texture, uv);
		ALBEDO = col.rgb * tint_color.rgb;
		ALPHA = col.a * tint_color.a;
	} else {
		vec4 col = texture(albedo_texture, uv) * 0.28;
		col += texture(albedo_texture, clamp(uv + vec2(ps.x, 0.0), vec2(0.0), vec2(1.0))) * 0.14;
		col += texture(albedo_texture, clamp(uv - vec2(ps.x, 0.0), vec2(0.0), vec2(1.0))) * 0.14;
		col += texture(albedo_texture, clamp(uv + vec2(0.0, ps.y), vec2(0.0), vec2(1.0))) * 0.14;
		col += texture(albedo_texture, clamp(uv - vec2(0.0, ps.y), vec2(0.0), vec2(1.0))) * 0.14;
		col += texture(albedo_texture, clamp(uv + vec2(ps.x, ps.y) * 0.707, vec2(0.0), vec2(1.0))) * 0.08;
		col += texture(albedo_texture, clamp(uv - vec2(ps.x, ps.y) * 0.707, vec2(0.0), vec2(1.0))) * 0.08;

		ALBEDO = col.rgb * tint_color.rgb;
		ALPHA = col.a * tint_color.a;
	}
}
