shader_type canvas_item;

uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.38;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.70;
uniform vec4 vignette_color : source_color = vec4(0.28, 0.04, 0.42, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	float vignette = smoothstep(0.5 - vignette_intensity, 0.5 + vignette_intensity, dist);
	COLOR = vec4(vignette_color.rgb, vignette * vignette_opacity * COLOR.a);
}
