shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);

uniform float wind_speed : hint_range(0.0, 15.0) = 4.0;
uniform float wind_strength : hint_range(0.0, 2.0) = 0.15;
uniform float wave_frequency : hint_range(0.0, 20.0) = 5.0;
uniform vec3 wind_direction = vec3(0.0, 0.0, 1.0); // Dirección del viento en espacio local

// Si la parte unida al mástil es el lado derecho (UV.x = 1.0), activa esta opción.
// Si es el lado izquierdo (UV.x = 0.0), déjala desactivada.
uniform bool invert_pinning = false;
// Controla qué tan rápido o lento se transiciona desde la parte sujeta a la móvil.
uniform float pinning_exponent : hint_range(1.0, 5.0) = 1.5;

void vertex() {
	// Factor de sujeción (pinning): 
	// 0.0 en el poste (no se mueve), 1.0 en la punta libre (se mueve al máximo)
	float pin = invert_pinning ? (1.0 - UV.x) : UV.x;
	float weight = pow(pin, pinning_exponent);
	
	// Función de onda basada en el tiempo, la altura del estandarte (Y) y el ancho (X/Z)
	float time = TIME * wind_speed;
	
	// Onda principal (onda viajera a lo largo de la tela)
	float wave = sin(VERTEX.y * wave_frequency - time) * cos(UV.x * wave_frequency * 0.5 - time);
	
	// Onda secundaria para simular micro-arrugas y turbulencia
	float micro_wave = sin(VERTEX.y * wave_frequency * 2.5 + time * 1.5) * 0.2;
	
	float final_wave = (wave + micro_wave) * wind_strength * weight;
	
	// Desplazamos los vértices en la dirección del viento + un desplazamiento normal para dar volumen
	vec3 movement = (wind_direction + NORMAL * 0.2) * final_wave;
	VERTEX += movement;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb * albedo_color.rgb;
	ALPHA = tex.a * albedo_color.a;
	
	// Sombreado correcto para ambas caras (invertir normales en la cara trasera si es necesario)
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
