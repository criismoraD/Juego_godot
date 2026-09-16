shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// Máscara de recorte procedural para el interior del arco.
// Más oscura arriba (bajo el dintel) y se disipa hacia abajo,
// con bordes laterales suaves para un sombreado creíble.
// Al ser hija del arco, hereda todo su movimiento (parallax, cámara,
// animación): funciona igual en niveles estáticos y en movimiento.

uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float opacidad : hint_range(0.0, 1.0) = 0.55;
uniform float caida : hint_range(0.5, 4.0) = 1.6;
uniform float suavizado_lados : hint_range(0.05, 0.5) = 0.3;
uniform float suavizado_arriba : hint_range(0.0, 0.5) = 0.22;
uniform float suavizado_abajo : hint_range(0.0, 0.5) = 0.0;
uniform float invertir : hint_range(0.0, 1.0) = 0.0; // 1 = oscuro abajo (rocas), 0 = oscuro arriba (arcos)

void fragment() {
	// UV.y = 0 arriba, 1 abajo
	float base = mix(1.0 - UV.y, UV.y, invertir);
	float vertical = pow(clamp(base, 0.0, 1.0), caida);
	// Fundidos de bordes para que no se lean líneas duras (solo si > 0)
	if (suavizado_arriba > 0.001) {
		vertical *= smoothstep(0.0, suavizado_arriba, 1.0 - UV.y);
	}
	if (suavizado_abajo > 0.001) {
		vertical *= smoothstep(0.0, suavizado_abajo, UV.y);
	}
	float horizontal = smoothstep(0.0, suavizado_lados, UV.x) * smoothstep(1.0, 1.0 - suavizado_lados, UV.x);
	ALBEDO = color.rgb;
	ALPHA = vertical * horizontal * opacidad;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
