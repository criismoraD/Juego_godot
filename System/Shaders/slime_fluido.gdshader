shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Material gelatinoso del Limo Cuadrado:
// - Base: textura difusa del limo.
// - Capa Slime superpuesta con transparencia creciente hacia arriba:
//   la textura "fluye" hacia abajo en bucle (scroll UV) simulando
//   líquido viscoso escurriéndose por el cuerpo.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D slime_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 slime_tint : source_color = vec4(0.4, 1.0, 0.5, 1.0);
uniform float slime_intensity : hint_range(0.0, 1.0) = 0.55; // Fuerza de la capa viscosa
uniform float flow_speed : hint_range(0.0, 1.0) = 0.12; // Velocidad del flujo hacia abajo
uniform float flow_scale : hint_range(0.5, 6.0) = 1.6; // Repeticiones verticales del flujo
uniform float smoothness : hint_range(0.05, 0.9) = 0.35; // Suavizado del gradiente superior
uniform float emission_energy : hint_range(0.0, 3.0) = 0.35;

void fragment() {
	vec4 base = texture(albedo_texture, UV);

	// UV de la capa slime: scroll vertical infinito hacia abajo (flujo en bucle)
	vec2 slime_uv = vec2(UV.x, UV.y * flow_scale - TIME * flow_speed);
	vec4 slime = texture(slime_texture, slime_uv);

	// Gradiente vertical: opaca abajo, transparente arriba
	// (v_top = 1 en la parte superior del modelo)
	float grad = smoothstep(1.0, 1.0 - smoothness, UV.y);
	// Capa más fuerte en las zonas claras de la textura de slime
	float slime_mask = slime.a * grad * slime_intensity;

	vec3 col = mix(base.rgb, slime_tint.rgb, slime_mask);
	// Multiplicar por el canal de la textura de slime para conservar sus variaciones
	col += slime.rgb * slime_mask * 0.6;

	ALBEDO = col;
	ALPHA = base.a;
	ROUGHNESS = 0.35 - slime_mask * 0.2; // La baba brilla un poco más
	SPECULAR = 0.4;
	EMISSION = slime_tint.rgb * slime_mask * emission_energy;
}
