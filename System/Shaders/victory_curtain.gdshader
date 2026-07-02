shader_type canvas_item;

// Cortinilla de fin de nivel con borde tipo "brochazo" (pintura al pincel).
// El borde avanza/retrocede de forma irregular a lo largo del eje vertical,
// simulando las marcas de las cerdas de una brocha, en lugar de un degradé suave.
uniform float threshold : hint_range(-1.2, 1.2) = 0.33;
uniform sampler2D ramp_texture : filter_linear, repeat_disable;

// --- Parámetros del brochazo (con defaults, no rompen GameUI.gd) ---
// Amplitud de la irregularidad vertical del borde (qué tanto avanza/retrocede).
uniform float brush_jitter : hint_range(0.0, 0.4) = 0.06;
// Escala vertical del patrón de cerdas (frecuencia de las marcas).
// Duplicada respecto a la versión anterior: ondas la mitad de cortas (longitud de onda reducida a la mitad).
uniform float brush_scale : hint_range(10.0, 400.0) = 220.0;
// Ancho de la zona de transición (menor = corte más definido).
uniform float edge_softness : hint_range(0.01, 0.2) = 0.045;
// Intensidad de los "huecos" de pintura cerca del borde (0 = ninguno, 1 = máximo).
uniform float gap_intensity : hint_range(0.0, 1.0) = 0.65;

// --- Ruido procedural barato (value noise + FBM) ---
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);  // smoothstep
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM de pocas octavas: textura orgánica para las cerdas y la pintura.
float fbm(vec2 p) {
	float v = value_noise(p) * 0.5;
	v += value_noise(p * 2.1) * 0.25;
	v += value_noise(p * 4.3) * 0.125;
	return v;
}

void fragment() {
	if (threshold >= 1.05) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		// --- 1. Borde tipo brochazo ---
		// El ruido se muestrea solo en Y: variación vertical (marcas de cerdas)
		// que desplaza el threshold efectivo. El borde avanza/retrocede irregularmente.
		float brush = fbm(vec2(UV.y * brush_scale, 0.0));
		float edge_jitter = (brush - 0.5) * brush_jitter;
		float effective_threshold = threshold + edge_jitter;

		// Transición estrecha: corte definido, no difuminado.
		float progress = (UV.x - effective_threshold) / edge_softness;
		float alpha = clamp(progress, 0.0, 1.0);

		// Suavizado mínimo del corte mediante la rampa.
		vec4 ramp_color = texture(ramp_texture, vec2(alpha, 0.5));

		// --- 2. Textura de pintura (motas/cerdas) ---
		// Patrón fino estirado en X para simular las marcas de una brocha.
		float stroke_tex = fbm(UV * vec2(120.0, 220.0));

		// Cerca del borde creamos "huecos" donde la pintura no cubrió,
		// tipico de un brochazo (alpha bajo = cerca del borde).
		float edge_factor = clamp((1.0 - alpha) * 3.0, 0.0, 1.0);
		float gap = smoothstep(0.35, 0.6, stroke_tex);
		float final_alpha = ramp_color.a * mix(1.0, gap, edge_factor * gap_intensity);

		// Ligero grano en todo el cuerpo para textura de pintura.
		float body_grain = fbm(UV * vec2(80.0, 160.0));
		final_alpha *= mix(0.96, 1.0, body_grain);

		COLOR = vec4(0.0, 0.0, 0.0, clamp(final_alpha, 0.0, 1.0));
	}
}
