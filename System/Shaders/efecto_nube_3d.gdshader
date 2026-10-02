shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// Shader para recrear el efecto de nubes 2.5D/3D estilo Castlevania: Symphony of the Night.
// Las nubes viajan hacia la cámara en un loop continuo sobre un plano inclinado en perspectiva.
// Incluye recoloreo dinámico de dos tonos (ideal para atardecer naranja, noche violeta, etc.).

uniform sampler2D textura_nubes : source_color, repeat_enable, filter_linear_mipmap;

// Control de Color y Medidor de Tinte
uniform vec4 tinte_luz : source_color = vec4(1.0, 0.58, 0.18, 0.95);
uniform vec4 tinte_sombra : source_color = vec4(0.42, 0.16, 0.14, 0.95);
uniform float intensidad_color : hint_range(0.0, 3.0, 0.05) = 1.0;
uniform float modo_recoloreo : hint_range(0.0, 1.0, 0.05) = 1.0;
uniform float contraste : hint_range(0.5, 2.5, 0.05) = 1.0;

// Desplazamiento
uniform vec2 direccion_scroll = vec2(0.0, 1.0);
uniform float uv_offset = 0.0;
uniform vec2 uv_scale = vec2(2.5, 2.0);

// Desvanecimiento suave en bordes para fusionarse de forma atmosférica con el cielo
uniform bool habilitar_fade_bordes = true;
uniform float fade_horizonte_inicio : hint_range(0.0, 0.5) = 0.0;
uniform float fade_horizonte_fin : hint_range(0.0, 0.5) = 0.28;
uniform float fade_cercano_inicio : hint_range(0.5, 1.0) = 0.72;
uniform float fade_cercano_fin : hint_range(0.5, 1.0) = 1.0;
uniform float fade_lateral_margen : hint_range(0.0, 0.3) = 0.08;

void fragment() {
	vec2 uv_desplazada = UV * uv_scale - direccion_scroll * uv_offset;
	vec4 color_tex = texture(textura_nubes, uv_desplazada);
	
	// Luminancia perceptual de la textura para separar sombras de crestas iluminadas
	float lum = dot(color_tex.rgb, vec3(0.299, 0.587, 0.114));
	lum = clamp(pow(lum * 1.5, contraste), 0.0, 1.0);
	
	// Gradiente de dos tonos (luces naranjas doradas / sombras terracota o noche)
	vec3 color_gradiente = mix(tinte_sombra.rgb, tinte_luz.rgb, lum) * intensidad_color;
	
	// Mezcla entre multiplicación directa y recoloreo por gradiente de dos tonos
	vec3 rgb_final = mix(color_tex.rgb * tinte_luz.rgb * intensidad_color, color_gradiente, modo_recoloreo);
	
	float alpha_base = mix(tinte_sombra.a, tinte_luz.a, lum);
	float alpha_final = color_tex.a * alpha_base;
	
	if (habilitar_fade_bordes) {
		float fade_longitudinal = smoothstep(fade_horizonte_inicio, fade_horizonte_fin, UV.y)
			* (1.0 - smoothstep(fade_cercano_inicio, fade_cercano_fin, UV.y));
		
		float fade_lateral = smoothstep(0.0, fade_lateral_margen, UV.x)
			* (1.0 - smoothstep(1.0 - fade_lateral_margen, 1.0, UV.x));
		
		alpha_final *= fade_longitudinal * fade_lateral;
	}
	
	ALBEDO = rgb_final;
	ALPHA = alpha_final;
}
