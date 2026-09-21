shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 albedo;
uniform sampler2D texture_albedo;
uniform float scroll_speed = 2.0;

void fragment() {
	// We offset the V (Y) coordinate of the UV by TIME to make it scroll
	vec2 moving_uv = UV;
	moving_uv.y -= TIME * scroll_speed;
	
	vec4 tex = texture(texture_albedo, moving_uv);
	
	ALBEDO = albedo.rgb;
	
	// Use the Red channel of your spiky texture for transparency
	// We multiply by (1.0 - UV.y) so the pillar is more solid at the bottom 
	// and breaks apart/disappears toward the tip.
	ALPHA = albedo.a * tex.r * (1.0 - UV.y);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}