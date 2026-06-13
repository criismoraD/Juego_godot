shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float opacidad : hint_range(0.0, 1.0) = 0.35;
uniform float suavizado : hint_range(0.0, 1.0) = 0.35;
uniform float corte_izq : hint_range(0.0, 1.0) = 0.0;
uniform float corte_der : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float alpha = 1.0 - smoothstep(1.0 - suavizado, 1.0, dist);
	
	if (uv.x < 0.0) {
		alpha *= mix(1.0, smoothstep(-1.0, 0.0, uv.x), corte_izq);
	} else {
		alpha *= mix(1.0, smoothstep(1.0, 0.0, uv.x), corte_der);
	}
	
	ALBEDO = vec3(0.0);
	ALPHA = alpha * opacidad;
}
