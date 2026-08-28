shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled;

uniform vec4 color_inicio : source_color = vec4(1.0, 0.16, 0.05, 1.0);
uniform vec4 color_fin : source_color = vec4(0.92, 0.22, 0.08, 0.35);
uniform vec4 color_pulso : source_color = vec4(1.0, 0.08, 0.03, 1.0);
uniform float escala_punteado : hint_range(1.0, 50.0) = 15.0;
uniform float factor_relleno : hint_range(0.1, 0.9) = 0.55;
uniform float velocidad_pulso : hint_range(0.2, 5.0) = 0.85;
uniform float longitud_pulso : hint_range(0.01, 0.2) = 0.04;

void fragment() {
	// UV.x = distancia física en metros
	// UV.y = ancho normalizado de la cinta (0.0 a 1.0)
	// COLOR.r = porcentaje a lo largo de la trayectoria (0.0 base, 1.0 punta)
	// COLOR.a = alpha con fade-in suave de 1s y desvanecimiento final

	float progreso_total = COLOR.r;

	// 1. Punteado limpio de una sola línea central
	float patron = fract(UV.x * escala_punteado);
	float alpha_punteado = smoothstep(0.0, 0.08, patron) * smoothstep(factor_relleno, factor_relleno - 0.08, patron);

	// 2. Punto viajero rojo sutil que recorre la trayectoria en loop
	float pulso_pos = fract(TIME * velocidad_pulso);
	float dist_pulso = abs(progreso_total - pulso_pos);
	dist_pulso = min(dist_pulso, 1.0 - dist_pulso);
	float intensidad_pulso = smoothstep(longitud_pulso, 0.0, dist_pulso);

	// 3. Grosor en Y de UNA SOLA línea central limpia (0 en el centro, 1 en los bordes)
	float dist_centro_y = abs(UV.y - 0.5) * 2.0;
	float ancho_max = mix(0.72, 0.95, intensidad_pulso);
	float alpha_y = smoothstep(ancho_max, ancho_max - 0.28, dist_centro_y);

	// 4. Color: rojo vivo homogéneo con matiz sutil en el punto viajero
	vec4 col_base = mix(color_inicio, color_fin, clamp(progreso_total, 0.0, 1.0));
	vec4 col = mix(col_base, color_pulso, intensidad_pulso * 0.7);

	// 5. Alpha combinado
	float alpha_combinado = clamp(alpha_punteado + intensidad_pulso * 0.5, 0.0, 1.0);

	ALBEDO = col.rgb;
	ALPHA = col.a * alpha_combinado * alpha_y * COLOR.a;
}
