shader_type canvas_item;

uniform float threshold : hint_range(-1.2, 1.2) = 0.33;
uniform float transition_width : hint_range(0.0, 0.5) = 0.12;
uniform sampler2D mask_texture : filter_linear_mipmap, repeat_disable;

void fragment() {
	// Leer valor de la máscara (blanco en la izquierda, negro en la derecha)
	float mask = texture(mask_texture, UV).r;
	
	// Si threshold es alto (por encima de 1.05), forzar a ser completamente transparente
	if (threshold >= 1.05) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		// Calcular opacidad usando smoothstep en base al threshold y el ancho de transición
		float alpha = 1.0 - smoothstep(threshold - transition_width, threshold + transition_width, mask);
		alpha = clamp(alpha, 0.0, 1.0);
		
		// Cortinilla negra con opacidad modulada por la máscara
		COLOR = vec4(0.0, 0.0, 0.0, alpha);
	}
}
