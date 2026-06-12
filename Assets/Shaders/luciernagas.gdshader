shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec4 firefly_color : source_color = vec4(0.85, 0.9, 0.2, 1.0); // Warm yellow-green
uniform float grid_size : hint_range(1.0, 100.0) = 15.0;
uniform float firefly_size : hint_range(0.001, 0.1) = 0.015;
uniform float glow_strength : hint_range(0.1, 10.0) = 2.0;
uniform float drift_speed : hint_range(0.1, 5.0) = 0.4;
uniform float blink_speed : hint_range(0.5, 10.0) = 1.5;
uniform float drift_amplitude : hint_range(0.05, 0.5) = 0.25;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV * grid_size;
	vec2 ipos = floor(uv);
	vec2 fpos = fract(uv);
	
	float total_glow = 0.0;
	
	// 3x3 search window to allow fireflies to drift across cell borders smoothly
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 cell = ipos + neighbor;
			float h = hash(cell);
			
			// Spawn probability: only spawn a firefly in ~40% of the cells
			if (h < 0.6) continue;
			
			// Random movement offset
			float time_offset = h * 6.28;
			vec2 offset = vec2(
				sin(TIME * drift_speed + time_offset),
				cos(TIME * drift_speed * 1.1 + time_offset * 1.5)
			) * drift_amplitude;
			
			// Position of the firefly in the neighbor cell coordinate space
			vec2 pos = neighbor + vec2(0.5) + offset;
			float dist = distance(fpos, pos);
			
			// Blinking animation
			float blink = sin(TIME * blink_speed + time_offset * 3.0);
			// Rescale blink to spend more time on/off and look natural
			blink = smoothstep(-0.4, 0.4, blink); 
			
			// Glow calculation
			float glow = exp(-dist / firefly_size) * blink;
			total_glow += glow;
		}
	}
	
	vec4 final_color = firefly_color * total_glow * glow_strength;
	ALBEDO = final_color.rgb;
	ALPHA = clamp(total_glow * firefly_color.a, 0.0, 1.0);
}
