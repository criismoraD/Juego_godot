shader_type spatial;

group_uniforms Textures_Stone;
uniform sampler2D albedo_texture : source_color;
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D displacement_texture;

group_uniforms Textures_Grass;
uniform sampler2D grass_albedo_texture : source_color;
uniform sampler2D grass_normal_texture : hint_normal;
uniform sampler2D grass_displacement_texture;

group_uniforms Settings;
instance uniform float displacement_scale_y : hint_range(0.0, 1.0) = 0.1;
instance uniform float displacement_scale_xz : hint_range(0.0, 1.0) = 0.1;

// Scales separated for Sides (Stone) and Top (Grass)
instance uniform vec2 uv_scale_sides = vec2(2.0, 2.0);
instance uniform vec2 uv_scale_top = vec2(2.0, 2.0);
instance uniform vec2 uv_offset = vec2(0.0, 0.0);
instance uniform float uv_rotation_degrees : hint_range(0.0, 360.0) = 0.0;

// Controls how far the grass extends down the sides
instance uniform float blend_sharpness : hint_range(0.1, 20.0) = 5.0; 

instance uniform float roughness : hint_range(0.0, 1.0) = 0.8;
instance uniform float metallic : hint_range(0.0, 1.0) = 0.0;
instance uniform float normal_intensity : hint_range(0.0, 2.0) = 1.0;
instance uniform float bevel_radius = 0.0;

varying vec2 uv_stone_side_x;
varying vec2 uv_stone_side_z;
varying vec2 uv_grass_top;
varying vec2 uv_grass_side_x;
varying vec2 uv_grass_side_z;

varying float top_mix;
varying vec3 triplanar_powers;

group_uniforms Scaling;
instance uniform vec3 mesh_size = vec3(2.0, 2.0, 2.0);

vec2 rotate_uv(vec2 uv, float deg) {
	float rad = radians(deg);
	float c = cos(rad);
	float s = sin(rad);
	return vec2(
		uv.x * c - uv.y * s,
		uv.x * s + uv.y * c
	);
}

void vertex() {
	// Use explicit mesh dimensions for scaling
	vec3 world_scale = mesh_size;

	// Calculate Triplanar Blend Weights based on world normals
	// We use this to blend the textures on the respective faces
	vec3 w = abs(NORMAL);
	w = w / (w.x + w.y + w.z); // Normalize
	w = pow(w, vec3(4.0)); // Sharp blend to avoid ghosting
	triplanar_powers = w / (w.x + w.y + w.z); // Renormalize

	// HEIGHT-BASED BLENDING (For Material Mixing)
	float half_height = mesh_size.y * 0.5;
	float dist_from_top = half_height - VERTEX.y;
	top_mix = clamp(1.0 - (dist_from_top * blend_sharpness), 0.0, 1.0);
	top_mix = smoothstep(0.0, 1.0, top_mix);
	
	// --- UV CALCULATIONS ---
	
	// 1. Stone (Sides primarily) - Biplanar (X and Z faces)
	uv_stone_side_x = rotate_uv(VERTEX.zy * uv_scale_sides + uv_offset, uv_rotation_degrees);
	uv_stone_side_z = rotate_uv(VERTEX.xy * uv_scale_sides + uv_offset, uv_rotation_degrees);
	
	// 2. Grass (Top primarily, but needs Triplanar to not streak on sides)
	// TOP Face
	uv_grass_top = rotate_uv(VERTEX.xz * uv_scale_top + uv_offset, uv_rotation_degrees);
	// SIDE Faces (using Top Scale)
	uv_grass_side_x = rotate_uv(VERTEX.zy * uv_scale_top + uv_offset, uv_rotation_degrees);
	uv_grass_side_z = rotate_uv(VERTEX.xy * uv_scale_top + uv_offset, uv_rotation_degrees);

	// --- BEVEL LOGIC ---
	if (bevel_radius > 0.001) {
		vec3 half_size = mesh_size * 0.5;
		vec3 inner_half_size = max(half_size - vec3(bevel_radius), vec3(0.0));
		vec3 q = clamp(VERTEX, -inner_half_size, inner_half_size);
		vec3 diff = VERTEX - q;
		if (length(diff) > 0.0001) {
			VERTEX = q + normalize(diff) * bevel_radius;
			NORMAL = normalize(diff);
			// Re-calculate weights for accurate normal mapping on bevel
			vec3 bw = abs(NORMAL);
			bw = bw / (bw.x + bw.y + bw.z);
			bw = pow(bw, vec3(4.0));
			triplanar_powers = bw / (bw.x + bw.y + bw.z);
		}
	}

	// --- DISPLACEMENT ---
	
	// Stone Side Sampling (Biplanar)
	// We mix X and Z based on the normal's horizontal components
	float side_balance = abs(NORMAL.x) / (abs(NORMAL.x) + abs(NORMAL.z) + 0.0001);
	float h_stone_x = texture(displacement_texture, uv_stone_side_x).r;
	float h_stone_z = texture(displacement_texture, uv_stone_side_z).r;
	float h_stone = mix(h_stone_z, h_stone_x, side_balance);
	
	// Grass Triplanar Sampling
	float h_grass_y = texture(grass_displacement_texture, uv_grass_top).r;
	float h_grass_x = texture(grass_displacement_texture, uv_grass_side_x).r;
	float h_grass_z = texture(grass_displacement_texture, uv_grass_side_z).r;
	float h_grass = h_grass_y * triplanar_powers.y + h_grass_x * triplanar_powers.x + h_grass_z * triplanar_powers.z;
	
	// Final Blend
	float height = mix(h_stone, h_grass, top_mix);
	
	// Apply
	VERTEX += normalize(VERTEX) * height * mix(displacement_scale_xz, displacement_scale_y, abs(NORMAL.y));
}

void fragment() {
	// --- Stone Albedo (Biplanar) ---
	float side_balance = abs(NORMAL.x) / (abs(NORMAL.x) + abs(NORMAL.z) + 0.0001);
	vec3 col_stone_x = texture(albedo_texture, uv_stone_side_x).rgb;
	vec3 col_stone_z = texture(albedo_texture, uv_stone_side_z).rgb;
	vec3 col_stone = mix(col_stone_z, col_stone_x, side_balance);
	
	// --- Grass Albedo (Triplanar) ---
	vec3 col_grass_y = texture(grass_albedo_texture, uv_grass_top).rgb;
	vec3 col_grass_x = texture(grass_albedo_texture, uv_grass_side_x).rgb;
	vec3 col_grass_z = texture(grass_albedo_texture, uv_grass_side_z).rgb;
	vec3 col_grass = col_grass_y * triplanar_powers.y + col_grass_x * triplanar_powers.x + col_grass_z * triplanar_powers.z;
	
	// Blend
	ALBEDO = mix(col_stone, col_grass, top_mix);
	
	// --- Normals ---
	// (Simplified blending for performance, correct would be triplanar normal mapping)
	vec3 n_stone_x = texture(normal_texture, uv_stone_side_x).rgb;
	vec3 n_stone_z = texture(normal_texture, uv_stone_side_z).rgb;
	vec3 n_stone = mix(n_stone_z, n_stone_x, side_balance);
	
	vec3 n_grass_y = texture(grass_normal_texture, uv_grass_top).rgb;
	vec3 n_grass_x = texture(grass_normal_texture, uv_grass_side_x).rgb;
	vec3 n_grass_z = texture(grass_normal_texture, uv_grass_side_z).rgb;
	vec3 n_grass = n_grass_y * triplanar_powers.y + n_grass_x * triplanar_powers.x + n_grass_z * triplanar_powers.z;
	
	vec3 normal_sample = mix(n_stone, n_grass, top_mix);
	vec3 flat_normal = vec3(0.5, 0.5, 1.0);
	NORMAL_MAP = mix(flat_normal, normal_sample, normal_intensity);
	
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
