shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float desenfoque : hint_range(0.0, 10.0) = 3.5;
uniform vec4 tinte : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float opacidad : hint_range(0.0, 1.0) = 1.0;
uniform float desvanecer_borde_inferior : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	vec2 tex_size = vec2(textureSize(screen_texture, 0));
	vec2 pixel_size = 1.0 / max(tex_size, vec2(1.0));

	// Nivel de mipmap base para aceleración por hardware
	float lod = desenfoque * 0.45;
	float dispersion = desenfoque * 1.8;

	// Muestreo circular en 13 puntos para máxima suavidad sin ruido
	vec4 color = textureLod(screen_texture, SCREEN_UV, lod) * 0.22;
	float peso_total = 0.22;

	// Anillo 1 (4 muestras ortogonales)
	const vec2 r1[4] = vec2[](
		vec2(1.0, 0.0),
		vec2(-1.0, 0.0),
		vec2(0.0, 1.0),
		vec2(0.0, -1.0)
	);
	for (int i = 0; i < 4; i++) {
		vec2 offset = r1[i] * pixel_size * dispersion * 0.5;
		color += textureLod(screen_texture, SCREEN_UV + offset, lod) * 0.12;
		peso_total += 0.12;
	}

	// Anillo 2 (8 muestras diagonales y extendidas)
	const vec2 r2[8] = vec2[](
		vec2(0.7071, 0.7071),
		vec2(-0.7071, 0.7071),
		vec2(0.7071, -0.7071),
		vec2(-0.7071, -0.7071),
		vec2(1.414, 0.0),
		vec2(-1.414, 0.0),
		vec2(0.0, 1.414),
		vec2(0.0, -1.414)
	);
	for (int i = 0; i < 8; i++) {
		vec2 offset = r2[i] * pixel_size * dispersion;
		color += textureLod(screen_texture, SCREEN_UV + offset, lod) * 0.0375;
		peso_total += 0.0375;
	}

	color /= max(peso_total, 0.0001);

	// Gradiente suave en el borde inferior (UV.y = 1.0 en QuadMesh) para fundir con el agua
	float factor_vertical = 1.0;
	if (desvanecer_borde_inferior > 0.001) {
		factor_vertical = 1.0 - smoothstep(1.0 - desvanecer_borde_inferior, 1.0, UV.y);
	}

	ALBEDO = color.rgb * tinte.rgb;
	ALPHA = clamp(opacidad * tinte.a * factor_vertical, 0.0, 1.0);
}
