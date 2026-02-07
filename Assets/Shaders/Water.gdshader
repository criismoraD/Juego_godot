shader_type spatial;

// Parameterizing for user control
group_uniforms Water_Characteristics;
uniform vec3 albedo : source_color = vec3(0.061, 0.349, 0.340);
uniform vec3 albedo_shallow : source_color = vec3(0.0, 0.6, 0.4);
uniform float beer_factor : hint_range(0.0, 20.0) = 0.45;
uniform float transmission_alpha_factor : hint_range(0.0, 1.0) = 0.37;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.0;

group_uniforms Wave_Settings;
uniform sampler2D texture_normal; // Medium details
uniform vec2 wave_direction = vec2(1.0, 0.1);
uniform float time_scale : hint_range(0.0, 0.2, 0.005) = 0.025;
uniform float noise_scale : hint_range(0.0, 25.0) = 3.5;
uniform float wave_height : hint_range(0.0, 2.0) = 0.112;

group_uniforms Displacement_Settings;
uniform sampler2D displacement_texture; // Vertex displacement (use Simplex/Perlin)
uniform vec2 displacement_scale = vec2(0.1, 0.5);
uniform float displacement_speed : hint_range(0.0, 0.5) = 0.02;

group_uniforms Z_Mask_Gradient;
uniform float z_min = -10.0;
uniform float z_max = 10.0;

group_uniforms Foam_Settings;
uniform float foam_level : hint_range(0.0, 5.0) = 0.5;
uniform vec4 foam_col : source_color = vec4(1.0);
uniform sampler2D foam_noise; // Dissolve pattern
uniform float foam_noise_scale : hint_range(0.0, 20.0) = 5.0;
uniform float foam_dissolve : hint_range(0.0, 1.0) = 0.3;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

group_uniforms Whitecaps_Settings;
uniform float crest_threshold : hint_range(0.0, 0.5) = 0.08;
uniform float crest_intensity : hint_range(0.0, 1.0) = 0.5;

group_uniforms Caustics_Settings;
uniform sampler2D caustics_texture;
uniform float caustics_scale : hint_range(0.0, 10.0) = 2.0;
uniform float caustics_speed : hint_range(0.0, 0.2) = 0.03;
uniform float caustics_intensity : hint_range(0.0, 1.0) = 0.15;

varying float z_mask;
varying float vertex_height;

void vertex() {
	// Gradient mask based on local Z
	z_mask = smoothstep(z_min, z_max, VERTEX.z);
	
	// Sample displacement texture with its own scale and speed
	vec2 disp_uv = UV * displacement_scale + TIME * displacement_speed;
	float noise_val = textureLod(displacement_texture, disp_uv, 0.0).r;
	
	// Apply mask to wave height
	float height = (noise_val * 2.0 - 1.0) * wave_height * z_mask;
	vertex_height = height; // Pass to fragment for whitecaps
	
	VERTEX.y += height;
}

void fragment() {
	// TIME calculations for moving normals
	vec2 time = (TIME * wave_direction) * time_scale;
	
	// Single texture normal
	vec3 normal_map = texture(texture_normal, UV * noise_scale + time).rgb;
	
	// Base Color
	METALLIC = metallic;
	ROUGHNESS = roughness;
	NORMAL_MAP = normal_map;
	
	// Depth / Foam Logic
	float depth = texture(depth_texture, SCREEN_UV).r;
	
	// Reconstruct view space depth
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	
	// Calculate difference between water surface and object depth
	float diff = linear_depth - (-VERTEX.z);
	
	// Beer's Law (Absorption)
	float depth_transmission = exp(-diff * beer_factor);
	depth_transmission = clamp(depth_transmission, 0.0, 1.0);
	
	// ===== ORGANIC FOAM WITH NOISE DISSOLVE =====
	float foam_noise_val = texture(foam_noise, UV * foam_noise_scale + time * 0.5).r;
	float foam_edge = foam_level + foam_dissolve * (foam_noise_val * 2.0 - 1.0);
	float foam_factor = smoothstep(foam_edge, foam_edge * 0.5, diff);
	foam_factor *= foam_noise_val; // Add holes/irregularity
	
	// ===== WHITECAPS ON WAVE CRESTS =====
	float crest_factor = smoothstep(crest_threshold * 0.5, crest_threshold, vertex_height);
	crest_factor *= crest_intensity;
	
	// ===== ANIMATED CAUSTICS (DUAL LAYER MIN BLEND) =====
	// World-space XZ projection for scale independence
	vec2 world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * caustics_scale;
	float caustic1 = texture(caustics_texture, world_uv + TIME * caustics_speed).r;
	float caustic2 = texture(caustics_texture, world_uv * 1.2 - TIME * caustics_speed * 0.8).r;
	float caustics = min(caustic1, caustic2) * caustics_intensity;
	
	// Apply Absorption to Albedo
	vec3 water_col = mix(albedo, albedo_shallow, depth_transmission);
	
	// Add caustics to water color (more visible in shallow areas)
	water_col += caustics * depth_transmission;
	
	// Combine foam and whitecaps
	float total_foam = max(foam_factor, crest_factor);
	
	// Applying foam
	ALBEDO = mix(water_col, foam_col.rgb, total_foam * foam_col.a);
	
	// Transparency
	ALPHA = clamp(1.0 - transmission_alpha_factor * depth_transmission, 0.0, 1.0); 
	ALPHA = mix(ALPHA, 1.0, total_foam);
	
	// Apply Z Mask to Opacity
	ALPHA *= z_mask;
}

