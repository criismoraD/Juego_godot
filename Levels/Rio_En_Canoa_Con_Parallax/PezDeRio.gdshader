shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

// === UNIFORMS ===
uniform sampler2D textura_pez : source_color, filter_linear_mipmap;
uniform float velocidad_nado : hint_range(0.0, 20.0) = 6.0;
uniform float amplitud_cola : hint_range(0.0, 0.4) = 0.09;
uniform float longitud_onda : hint_range(0.1, 15.0) = 4.5;
uniform float curvatura_cuerpo : hint_range(0.0, 0.15) = 0.025;
uniform vec4 tinte_agua : source_color = vec4(0.85, 0.95, 1.0, 1.0);
uniform float intensidad_caustica : hint_range(0.0, 0.5) = 0.08;

void vertex() {
	// En el modelo 3D 'Pez de rio.glb':
	// Cabeza en Z = +0.5, Cola en Z = -0.5
	// factor_cola: 0.0 en la cabeza (firme), 1.0 en la aleta caudal (ondulación máxima)
	float factor_cola = pow(clamp((0.5 - VERTEX.z), 0.0, 1.0), 1.4);

	// Ondulación lateral en el eje X local (aleteo de lado a lado)
	float onda_nado = sin(TIME * velocidad_nado - VERTEX.z * longitud_onda);
	VERTEX.x += onda_nado * amplitud_cola * factor_cola;

	// Curvatura sinusoidal sutil del cuerpo para dar fluidez al avance
	VERTEX.x += sin(TIME * (velocidad_nado * 0.5)) * curvatura_cuerpo * factor_cola;

	// Sutil cabeceo vertical (eje Y) coordinado con el golpe de aleta
	float onda_vertical = cos(TIME * velocidad_nado - VERTEX.z * longitud_onda);
	VERTEX.y += onda_vertical * (amplitud_cola * 0.12) * factor_cola;
}

void fragment() {
	vec4 color_tex = texture(textura_pez, UV);
	
	// Caústicas sutiles de agua en movimiento sobre el lomo
	float caustica = 1.0 + intensidad_caustica * sin(TIME * 3.0 + VERTEX.x * 8.0 + VERTEX.z * 5.0);

	ALBEDO = color_tex.rgb * tinte_agua.rgb * caustica;
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
}
