shader_type canvas_item;

uniform float threshold : hint_range(-1.2, 1.2) = 0.33;
uniform float wave_amplitude : hint_range(0.0, 0.2) = 0.02;
uniform float wave_frequency : hint_range(0.0, 100.0) = 15.0;
uniform float roughness : hint_range(0.0, 0.1) = 0.008;
uniform vec4 border_color : source_color = vec4(0.85, 0.65, 0.2, 1.0);
uniform float border_width : hint_range(0.0, 0.1) = 0.006;

// Simple pseudo-random noise function
float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), mix(hash(i + 1.0), hash(i + 2.0), u), u);
}

void fragment() {
	float edge = threshold;
	
	// Add some organic waves to the vertical line
	edge += sin(UV.y * wave_frequency) * wave_amplitude;
	edge += cos(UV.y * wave_frequency * 2.3) * wave_amplitude * 0.3;
	
	// Add high-frequency noise for the rough brush stroke look
	edge += (noise(UV.y * 150.0) - 0.5) * roughness;
	edge += (noise(UV.y * 350.0) - 0.5) * roughness * 0.4;
	
	if (UV.x < edge) {
		discard; // Left side is transparent (gameplay visible)
	} else if (UV.x < edge + border_width) {
		// Gold border representing the brush stroke highlight
		COLOR = border_color;
	} else {
		// Solid black curtain
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	}
}
