shader_type canvas_item;

uniform float radio_apertura : hint_range(0.0, 1.5) = 1.5;
uniform vec2 centro = vec2(0.5, 0.5);
uniform vec4 color_cortinilla : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float suavizado : hint_range(0.0, 0.1) = 0.01;

void fragment() {
	vec2 resolucion = 1.0 / SCREEN_PIXEL_SIZE;
	float aspecto = resolucion.x / resolucion.y;
	vec2 uv_corregida = vec2(SCREEN_UV.x * aspecto, SCREEN_UV.y);
	vec2 centro_corregido = vec2(centro.x * aspecto, centro.y);
	
	float dist = distance(uv_corregida, centro_corregido);
	float mascara = smoothstep(radio_apertura - suavizado, radio_apertura + suavizado, dist);
	
	COLOR = vec4(color_cortinilla.rgb, color_cortinilla.a * mascara);
}
