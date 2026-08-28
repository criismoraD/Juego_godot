shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform sampler2D textura_pez : source_color, filter_linear_mipmap;
uniform float velocidad_nado : hint_range(0.0, 20.0) = 5.5;
uniform float amplitud_cola : hint_range(0.0, 0.4) = 0.12;
uniform float longitud_onda : hint_range(0.1, 15.0) = 5.0;
uniform float aleteo_aletas : hint_range(0.0, 0.1) = 0.03;
uniform float frecuencia_aletas : hint_range(0.0, 30.0) = 9.0;
uniform vec4 tinte_subacuatico : source_color = vec4(0.35, 0.65, 0.72, 1.0);
uniform float opacidad_bajo_agua : hint_range(0.0, 1.0) = 0.75;
uniform float brillo : hint_range(0.1, 3.0) = 0.55;
uniform float intensidad_caustica : hint_range(0.0, 0.5) = 0.12;

void vertex() {
	// Con el mesh invertido horizontalmente para mirar a la izquierda:
	// UV.x = 1 corresponde a la Cabeza (firme)
	// UV.x = 0 corresponde a la Cola (máxima ondulación)
	float factor_cola = pow(clamp(1.0 - UV.x, 0.0, 1.0), 1.6);

	// Ondulación lateral principal de nado (eje Z local)
	float onda_nado = sin(TIME * velocidad_nado + UV.x * longitud_onda);
	VERTEX.z += onda_nado * amplitud_cola * factor_cola;

	// Sutil cabeceo vertical coordinado con el nado (eje Y local)
	float onda_vertical = cos(TIME * velocidad_nado + UV.x * longitud_onda);
	VERTEX.y += onda_vertical * (amplitud_cola * 0.18) * factor_cola;

	// Sutil aleteo rápido en aleta dorsal (arriba) y aletas ventrales (abajo)
	float factor_aletas = smoothstep(0.45, 0.0, UV.y) + smoothstep(0.65, 1.0, UV.y);
	VERTEX.z += sin(TIME * frecuencia_aletas + (1.0 - UV.x) * 5.0) * aleteo_aletas * factor_aletas;
}

void fragment() {
	vec4 color_tex = texture(textura_pez, UV);
	
	if (color_tex.a < 0.05) {
		discard;
	}

	// Reflejos sutiles de cáusticas de agua en movimiento sobre el lomo
	float caustica = 1.0 + intensidad_caustica * sin(TIME * 2.5 + UV.x * 10.0 + UV.y * 7.0);

	ALBEDO = color_tex.rgb * tinte_subacuatico.rgb * brillo * caustica;
	ALPHA = color_tex.a * opacidad_bajo_agua;
}

