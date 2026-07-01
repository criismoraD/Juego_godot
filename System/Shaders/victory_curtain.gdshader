shader_type canvas_item;

uniform float threshold : hint_range(-1.2, 1.2) = 0.33;
uniform sampler2D ramp_texture : filter_linear, repeat_disable;

void fragment() {
	if (threshold >= 1.05) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		// Distorsion organica muy barata en el borde para simular pinceladas (reducido a un cuarto)
		float noise_offset = sin(UV.y * 14.0) * 0.005 + cos(UV.y * 32.0) * 0.0025;
		
		// Invertido: la derecha es negra (UV.x > threshold) y la izquierda es transparente
		float progress = (UV.x - threshold + noise_offset) / 0.12;
		float alpha = clamp(progress, 0.0, 1.0);
		
		// Obtener opacidad desde la rampa
		vec4 ramp_color = texture(ramp_texture, vec2(alpha, 0.5));
		COLOR = vec4(0.0, 0.0, 0.0, ramp_color.a);
	}
}
