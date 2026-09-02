shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Material gelatinoso del Limo Cuadrado:
// - Textura base del limo SIN alterar.
// - Capa Slime superpuesta de forma ADITIVA (solo ilumina, nunca oscurece):
//   fluye hacia abajo en bucle (scroll UV) simulando líquido viscoso,
//   con transparencia total en la parte superior del cuerpo.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D slime_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float slime_intensity : hint_range(0.0, 1.0) = 0.45; // Fuerza de la capa viscosa
uniform float flow_speed : hint_range(0.0, 1.0) = 0.12; // Velocidad del flujo hacia abajo
uniform float flow_scale : hint_range(0.5, 6.0) = 1.6; // Repeticiones verticales del flujo
uniform float smoothness : hint_range(0.05, 0.9) = 0.4; // Ancho del fundido superior

void fragment() {
	vec3 base = texture(albedo_texture, UV).rgb;

	// UV de la capa slime: scroll vertical infinito hacia abajo (flujo en bucle)
	vec2 slime_uv = vec2(UV.x, UV.y * flow_scale - TIME * flow_speed);
	vec4 slime = texture(slime_texture, slime_uv);

	// Gradiente vertical: opaco abajo, totalmente transparente arriba
	float grad = smoothstep(1.0, 1.0 - smoothness, UV.y);

	// Máscara: zonas con alpha de la textura slime + fundido superior + intensidad
	float mask = slime.a * grad * slime_intensity;

	// Capa ADITIVA: aporta el color/brillo de la baba sobre la base intacta
	vec3 col = base + slime.rgb * mask;

	ALBEDO = col;
	ROUGHNESS = 0.4;
}
