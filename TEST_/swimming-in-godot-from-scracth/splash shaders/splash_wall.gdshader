// NOTE: Shader updated to support CPUParticles3D Color Ramps and Alpha Fading.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);

uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);

uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	
	// INSTANCE_CUSTOM.y is the normalized lifetime of the particle (0.0 to 1.0)
	float life = INSTANCE_CUSTOM.y;
	
	// Y-AXIS: 0 -> 1 -> 0 (A bell curve/sin wave)
	float scale_y = sin(life * PI); 
	
	// XZ-AXIS: 1 -> 2 (Linear expansion)
	float scale_xz = mix(1.0, 2.0, life);
	
	// Apply the scales to the vertex positions
	VERTEX.x *= scale_xz;
	VERTEX.z *= scale_xz;
	VERTEX.y *= scale_y;
}

void fragment() {
	vec2 base_uv = UV;

	vec4 albedo_tex = texture(texture_albedo, base_uv);
	
	// MODIFICATION: Multiply by COLOR.rgb to allow the Color Ramp to tint the splash
	ALBEDO = albedo.rgb * albedo_tex.rgb * COLOR.rgb;

	float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	SPECULAR = specular;

	vec4 roughness_texture_channel = vec4(1.0, 0.0, 0.0, 0.0);
	float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	
	// MODIFICATION: Multiply by COLOR.a to allow the Color Ramp's alpha to fade the splash
	ALPHA = albedo.a * albedo_tex.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}