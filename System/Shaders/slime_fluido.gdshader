shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Material gelatinoso del Limo Cuadrado:
// - Textura base del limo SIN alterar.
// - Capa Slime superpuesta ADITIVA que fluye hacia abajo en bucle.
//   Dos capas desfasadas medio tile con cross-fade: la costura vertical
//   del tile nunca es visible (cuando una capa llega a su borde, la otra
//   está en mitad del tile y domina la mezcla).
// - Fundido total en la parte superior (transparente arriba).

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D slime_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float slime_intensity : hint_range(0.0, 1.0) = 0.45; // Fuerza de la capa viscosa
uniform float flow_speed : hint_range(0.0, 1.0) = 0.12; // Velocidad del flujo hacia abajo
uniform float flow_scale : hint_range(0.5, 6.0) = 1.6; // Repeticiones verticales del flujo
uniform float smoothness : hint_range(0.05, 0.9) = 0.4; // Ancho del fundido superior
uniform float seam_blend : hint_range(0.05, 0.5) = 0.25; // Ancho del cross-fade de costura

void fragment() {
	vec3 base = texture(albedo_texture, UV).rgb;

	// Coordenada de flujo: cae continuamente (bucle infinito)
	float flow = UV.y * flow_scale - TIME * flow_speed;

	// Dos muestras desfasadas medio tile + cross-fade triangular:
	// la costura de cada capa queda enmascarada por la otra.
	float phase = fract(flow);
	// Peso de la capa A: 1 en el centro del tile, 0 en su borde (costura)
	float w = smoothstep(0.0, seam_blend, phase) * smoothstep(1.0, 1.0 - seam_blend, phase);
	vec2 uv_a = vec2(UV.x, flow);
	vec2 uv_b = vec2(UV.x, flow + 0.5);
	vec4 s_a = texture(slime_texture, uv_a);
	vec4 s_b = texture(slime_texture, uv_b);
	vec4 slime = mix(s_b, s_a, w);

	// Gradiente vertical: opaco abajo, totalmente transparente arriba
	float grad = smoothstep(1.0, 1.0 - smoothness, UV.y);

	// Máscara final: color del slime + fundidos
	float mask = slime.a * grad * slime_intensity;

	// Capa ADITIVA: aporta el brillo viscoso de la baba sin oscurecer nunca
	vec3 col = base + slime.rgb * mask;

	ALBEDO = col;
	ROUGHNESS = 0.4;
}
