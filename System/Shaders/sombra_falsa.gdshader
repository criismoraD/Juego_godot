shader_type canvas_item;

uniform sampler2D shadow_mask : hint_default_white, filter_linear;
uniform vec4 shadow_color : source_color = vec4(0.04, 0.05, 0.09, 1.0);
uniform float shadow_opacity : hint_range(0.0, 1.0) = 0.52;

void fragment() {
	float mask_val = texture(shadow_mask, UV).r;
	// En la máscara: negro (0.0) = sombra total, blanco (1.0) = luz
	float shadow_strength = 1.0 - mask_val;

	COLOR = vec4(shadow_color.rgb, shadow_strength * shadow_opacity);
}
