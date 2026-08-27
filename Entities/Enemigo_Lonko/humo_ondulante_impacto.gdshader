shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 smoke_color : source_color = vec4(0.42, 0.40, 0.38, 0.78);
uniform float speed : hint_range(0.5, 10.0) = 3.2;
uniform float wave_amplitude : hint_range(0.01, 0.5) = 0.12;
uniform float wave_freq : hint_range(1.0, 30.0) = 10.0;
uniform float column_width : hint_range(0.02, 0.5) = 0.09;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
uniform float growth : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	// Billboard facing camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
}

void fragment() {
	// UV.y: 0.0 es la cima (arriba), 1.0 es la base (suelo)
	float height_norm = 1.0 - UV.y;
	if (height_norm > growth) {
		discard;
	}

	// Ondulación serpenteante con armónicos múltiples para movimiento orgánico natural
	float w1 = sin(height_norm * wave_freq - TIME * speed) * wave_amplitude;
	float w2 = sin(height_norm * (wave_freq * 1.7) - TIME * (speed * 1.3) + 1.2) * (wave_amplitude * 0.45);
	float w3 = sin(height_norm * (wave_freq * 0.6) - TIME * (speed * 0.8)) * (wave_amplitude * 0.35);
	float total_wave = (w1 + w2 + w3) * pow(height_norm + 0.05, 0.65);

	float center_x = 0.5 + total_wave;
	// Grosor de la columna: delgada en la base del impacto y ensanchándose suavemente al subir
	float current_width = mix(column_width, column_width * 2.5, height_norm);

	float dist = abs(UV.x - center_x) / current_width;
	if (dist > 1.0) {
		discard;
	}

	// Gradiente suave de los bordes del humo
	float shape_alpha = smoothstep(1.0, 0.15, dist);
	// Desvanecimiento suave en la punta superior
	float top_fade = smoothstep(1.0, 0.55, height_norm);

	float final_alpha = shape_alpha * top_fade * smoke_color.a * fade_alpha;

	ALBEDO = smoke_color.rgb;
	ALPHA = clamp(final_alpha, 0.0, 1.0);
}
