shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, blend_mix;

// Parámetros de la niebla
uniform vec4 fog_color : source_color = vec4(0.7, 0.8, 0.9, 0.3);
uniform float fog_density : hint_range(0.0, 2.0) = 0.5;
uniform float scroll_speed_x : hint_range(-0.5, 5) = 0.02;
uniform float scroll_speed_y : hint_range(-0.5, 5) = 0.01;

// Escala del noise
uniform float noise_scale : hint_range(0.1, 50.0) = 2.0;
uniform float noise_detail : hint_range(1.0, 8.0) = 4.0;
uniform float smoothness : hint_range(1.0, 5.0) = 2.0; // Nuevo: suavidad del ruido
uniform float vignette_radius : hint_range(0.0, 1.5) = 0.75; // Radio del viñeteado
uniform float vignette_softness : hint_range(0.0, 1.5) = 0.5; // Suavizado del viñeteado

// Función de interpolación suave quintica (más suave que cúbica)
vec2 quintic(vec2 x) {
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

// Ruido de gradiente (Perlin-like) - más suave que el ruido de valor
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float gradient_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Interpolación quintica para suavidad máxima
    vec2 u = quintic(f);
    
    // Gradientes en las 4 esquinas
    float a = dot(hash2(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0));
    float b = dot(hash2(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
    float c = dot(hash2(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
    float d = dot(hash2(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
    
    // Interpolación bilineal suave
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5 + 0.5;
}

// FBM con ruido de gradiente suave
float fbm(vec2 p, float detail_level) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    float max_value = 0.0;
    
    for (int i = 0; i < int(detail_level); i++) {
        value += amplitude * gradient_noise(p * frequency);
        max_value += amplitude;
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value / max_value; // Normalizar para evitar saturación
}

// Función de suavizado adicional (blur simple)
float smooth_fbm(vec2 uv, float detail_level, float blur_amount) {
    float result = 0.0;
    float total = 0.0;
    
    // Muestreo en cruz para suavizar
    for (float x = -1.0; x <= 1.0; x += 1.0) {
        for (float y = -1.0; y <= 1.0; y += 1.0) {
            float weight = 1.0 / (1.0 + length(vec2(x, y)));
            result += fbm(uv + vec2(x, y) * blur_amount, detail_level) * weight;
            total += weight;
        }
    }
    
    return result / total;
}

void fragment() {
    // Coordenadas UV con scroll animado
    vec2 uv = UV * noise_scale;
    uv.x += TIME * scroll_speed_x;
    uv.y += TIME * scroll_speed_y;
    
    // Calcular blur basado en smoothness
    float blur = 0.01 * smoothness;
    
    // Generar niebla con FBM suavizado
    float fog = smooth_fbm(uv, noise_detail, blur);
    
    // Segunda capa de niebla para más profundidad (offset diferente)
    vec2 uv2 = UV * noise_scale * 0.6;
    uv2.x -= TIME * scroll_speed_x * 0.7;
    uv2.y += TIME * scroll_speed_y * 1.3;
    float fog2 = smooth_fbm(uv2, noise_detail, blur);
    
    // Tercera capa muy suave para grandes masas
    vec2 uv3 = UV * noise_scale * 0.2;
    uv3.x += TIME * scroll_speed_x * 0.3;
    float fog3 = fbm(uv3, 3.0);
    
    // Combinar capas con diferentes pesos
    float combined_fog = fog * 0.4 + fog2 * 0.35 + fog3 * 0.25;
    
    // Aplicar densidad
    float alpha = combined_fog * fog_density * fog_color.a;
    
    // Suavizar bordes verticales
    float edge_fade = smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.7, UV.y);
    alpha *= edge_fade;

    // Aplicar Viñeteado
    float dist_center = distance(UV, vec2(0.5));
    float vignette = smoothstep(vignette_radius, vignette_radius - vignette_softness, dist_center);
    alpha *= vignette;
    
    // Color final
    ALBEDO = fog_color.rgb;
    ALPHA = clamp(alpha, 0.0, 1.0);
}
