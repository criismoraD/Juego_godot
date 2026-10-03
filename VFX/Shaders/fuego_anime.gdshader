shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// Fuego estilo anime (2.5D): versión spatial del shader canvas_item de
// profesorshader. Llama de dos capas (exterior + interior) con ruido,
// normales y distorsión; máscara opcional que estabiliza la base.
// Las texturas de ruido/normal usan fract() para repetir sin marcas de importación.

// === Interruptores (el lenguaje no tiene #define: se exponen como uniforms) ===
uniform bool usar_fps_personalizado = true;
uniform bool usar_mascara_exclusion = true;

// === Tiempo y movimiento ===
uniform float velocidad : hint_range(0.0, 3.0) = 0.5;
uniform float fps_efecto : hint_range(1.0, 60.0) = 12.0;

// === Escalas de muestreo ===
uniform float escala_normal_ext : hint_range(0.1, 8.0) = 1.5;
uniform float escala_normal_int : hint_range(0.1, 8.0) = 2.0;
uniform float escala_ruido_ext : hint_range(0.05, 4.0) = 0.4;
uniform float escala_ruido_int : hint_range(0.05, 4.0) = 0.2;
uniform float distorsion_ext : hint_range(0.0, 0.5) = 0.10;
uniform float distorsion_int : hint_range(0.0, 0.5) = 0.08;
uniform float fuerza_mascara : hint_range(0.0, 1.0) = 0.6;

// === Texturas (nulas = las genera FuegoAnime.gd por procedimiento) ===
uniform sampler2D draw_tex;
uniform sampler2D normal_tex;
uniform sampler2D noise_tex;
uniform sampler2D mask_tex;

// === Colores anime (borde -> base exterior, núcleo interior) ===
uniform vec4 color_exterior_a : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 color_exterior_b : source_color = vec4(1.0, 0.25, 0.0, 1.0);
uniform vec4 color_interior_a : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 color_interior_b : source_color = vec4(1.0, 1.0, 0.5, 1.0);

// === Salida ===
uniform float intensidad_brillo : hint_range(0.0, 4.0) = 1.0;
uniform float opacidad : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// UVs de cada capa
	vec2 uv_out = UV;
	vec2 uv_in = UV;

	float t = TIME;
	if (usar_fps_personalizado) {
		t = floor(TIME * fps_efecto) / max(fps_efecto, 0.01);
	}

	uv_out.y += t * velocidad;
	uv_in.y += (0.5 + t) * velocidad;

	// Ruido (fract para repetir sin marcas de importación)
	vec2 noi_out = (texture(noise_tex, fract(uv_out * escala_ruido_ext)).rg * 2.0) - 1.0;
	vec2 noi_in = (texture(noise_tex, fract(uv_in * escala_ruido_int)).rg * 2.0) - 1.0;

	// Mapa de normales
	vec4 nrm_out = texture(normal_tex, fract((uv_out * escala_normal_ext) + noi_out.xy));
	vec4 nrm_in = texture(normal_tex, fract((uv_in * escala_normal_int) + noi_in.xy));
	nrm_out.xyz = nrm_out.xyz * 2.0 - 1.0;
	nrm_in.xyz = nrm_in.xyz * 2.0 - 1.0;

	// UVs distorsionados
	vec2 distorted_uv_out = UV + vec2(nrm_out.x, -nrm_out.y) * distorsion_ext;
	vec2 distorted_uv_in = UV + vec2(nrm_in.x, -nrm_in.y) * distorsion_int;

	vec2 final_uv_out = distorted_uv_out;
	vec2 final_uv_in = distorted_uv_in;
	if (usar_mascara_exclusion) {
		float msk = texture(mask_tex, UV).r * fuerza_mascara;
		final_uv_out = mix(distorted_uv_out, UV, msk);
		final_uv_in = mix(distorted_uv_in, UV, msk);
	}

	// Máscaras exterior (R) e interior (G) de la silueta
	float outside = texture(draw_tex, final_uv_out).r;
	float inside = texture(draw_tex, final_uv_in).g;

	// Color final
	vec4 final_color = outside * mix(color_exterior_a, color_exterior_b, UV.y);
	final_color = mix(final_color, mix(color_interior_a, color_interior_b, UV.y), inside);

	ALBEDO = final_color.rgb * intensidad_brillo;
	ALPHA = clamp(final_color.a * opacidad, 0.0, 1.0);
}
