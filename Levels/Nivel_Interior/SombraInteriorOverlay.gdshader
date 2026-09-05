shader_type canvas_item;
render_mode blend_mix;

// Shader de mascara de oscurecimiento / vineta para el interior de la torre.
// Multiplica el color de la pantalla por la mascara dibujada, oscureciendo las zonas deseadas
// sin afectar las areas iluminadas ni interferir con la interfaz de usuario.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D mask_texture : filter_linear_mipmap, repeat_disable;
uniform float shadow_intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 shadow_tint : source_color = vec4(0.92, 0.88, 1.0, 1.0);

void fragment() {
	vec4 screen = texture(screen_texture, SCREEN_UV);
	vec4 mask = texture(mask_texture, UV);

	// Tinte sutil en las zonas de sombra para mantener la coherencia con el ambiente morado
	vec3 tinted_mask = mix(mask.rgb * shadow_tint.rgb, mask.rgb, 0.3);
	vec3 multiplied = screen.rgb * tinted_mask;

	COLOR = vec4(mix(screen.rgb, multiplied, shadow_intensity), 1.0);
}
