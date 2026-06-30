shader_type canvas_item;

uniform float threshold : hint_range(-1.2, 1.2) = 0.33;
uniform float edge_softness : hint_range(0.01, 0.3) = 0.08;

// Pseudo-random hash
float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

// Smooth value noise
float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), u);
}

void fragment() {
	// Threshold alto = completamente invisible (antes de animar)
	if (threshold >= 1.05) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		float edge = threshold;

		// Ondulaciones organicas suaves en el borde
		edge += sin(UV.y * 12.0) * 0.015;
		edge += cos(UV.y * 28.0) * 0.008;

		// Ruido de pincelada a multiples frecuencias para irregularidad
		edge += (noise(UV.y * 80.0) - 0.5) * 0.025;
		edge += (noise(UV.y * 200.0) - 0.5) * 0.012;
		edge += (noise(UV.y * 500.0) - 0.5) * 0.006;

		// Transicion suave difusa (sin linea dorada)
		float alpha = smoothstep(edge + edge_softness, edge - edge_softness * 0.3, UV.x);

		COLOR = vec4(0.0, 0.0, 0.0, alpha);
	}
}
