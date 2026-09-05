shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D mask_texture : filter_linear, repeat_disable;

// Control de intensidad de desaturación en los bordes
uniform float desaturation_strength : hint_range(0.0, 1.0) = 0.70;

// Curva de transición de la máscara
uniform float mask_curve : hint_range(0.2, 3.0) = 1.0;

// Oscurecimiento sutil en bordes para acentuar el viñeteado cinematográfico
uniform float edge_darken : hint_range(0.0, 1.0) = 0.08;

// Tinte opcional en los bordes (blanco neutro por defecto)
uniform vec4 edge_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 screen_col = texture(screen_texture, SCREEN_UV);
	vec4 mask_col = texture(mask_texture, UV);

	// En la máscara de referencia: 1.0 (blanco) en el centro, < 1.0 (gris oscuro) en los bordes
	float mask_val = clamp(mask_col.r, 0.0, 1.0);
	
	// Factor de borde: 0.0 en el centro, aumentando hacia los extremos
	float edge_factor = 1.0 - mask_val;
	edge_factor = pow(edge_factor, mask_curve);
	edge_factor = clamp(edge_factor, 0.0, 1.0);

	// Cálculo de luminancia estándar (Rec. 709)
	float lum = dot(screen_col.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 grayscale = vec3(lum);

	// Reducir la saturación en los bordes
	float sat = clamp(1.0 - (edge_factor * desaturation_strength), 0.0, 1.0);
	vec3 result = mix(grayscale, screen_col.rgb, sat);

	// Tinte y oscurecimiento sutil en bordes
	result *= mix(vec3(1.0), edge_tint.rgb, edge_factor);
	result = mix(result, result * (1.0 - edge_darken), edge_factor);

	COLOR = vec4(result, screen_col.a);
}
