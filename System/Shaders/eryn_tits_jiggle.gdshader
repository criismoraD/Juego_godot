shader_type canvas_item;

// Controlador de deformación sutil de bamboleo para la capa Eryntits3
uniform float deformacion_x : hint_range(-2.0, 2.0) = 0.0;
uniform float deformacion_y : hint_range(-2.0, 2.0) = 0.0;
uniform float amplitud_uv : hint_range(0.0, 0.2) = 0.038;
uniform float amplitud_y : hint_range(0.0, 0.2) = 0.040;
uniform float factor_lado_derecho : hint_range(1.0, 3.0) = 1.8;

void fragment() {
	// Máscara horizontal asimétrica:
	// - Borde izquierdo (UV.x = 0): Anclaje suave para no despegar el tirante del hombro/brazo
	// - Lado derecho (UV.x > 0.4): Mayor holgura y movimiento visible del contorno del pecho derecho
	float mask_izq = smoothstep(0.0, 0.12, UV.x);
	float mask_der = 1.0 - smoothstep(0.86, 1.05, UV.x) * 0.22;
	float mask_x = mask_izq * mask_der;

	// Máscara vertical:
	// - Anclaje en la parte superior (UV.y = 0) para que los tirantes no se separen de los hombros
	// - Libertad elástica en el cuerpo y borde inferior del pecho para rebotar arriba y abajo
	float mask_arr = smoothstep(0.0, 0.14, UV.y);
	float mask_aba = 1.0 - smoothstep(0.84, 1.05, UV.y) * 0.22;
	float mask_y = mask_arr * mask_aba;

	float prod = clamp(mask_x * mask_y, 0.0, 1.0);
	float mascara = prod > 0.0 ? pow(prod, 0.8) : 0.0;

	// Ponderación asimétrica: mayor amplitud y libertad en el pecho derecho prominente (perspectiva 3/4)
	float peso_derecho = mix(1.0, factor_lado_derecho, smoothstep(0.35, 0.80, UV.x));
	float factor_total = mascara * peso_derecho;

	vec2 uv_deformada = UV;
	// Desplazamiento horizontal (bamboleo lateral)
	uv_deformada.x -= deformacion_x * amplitud_uv * factor_total;
	// Desplazamiento vertical (rebote elástico de arriba a abajo)
	uv_deformada.y -= deformacion_y * amplitud_y * factor_total;
	uv_deformada = clamp(uv_deformada, vec2(0.0), vec2(1.0));

	COLOR = texture(TEXTURE, uv_deformada) * COLOR;
}
