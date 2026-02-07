shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// === PARÁMETROS UNIFORMES ===
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_thickness : hint_range(0.0, 0.2) = 0.05;
uniform vec4 glow_color : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float glow_intensity : hint_range(0.0, 20.0) = 8.0;
uniform float noise_scale : hint_range(1.0, 100.0) = 20.0;
uniform sampler2D albedo_texture : source_color;
uniform vec3 albedo_tint : source_color = vec3(1.0);

// === FUNCIONES DE RUIDO ===
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    return value;
}

void fragment() {
    // Textura base
    vec4 tex_color = texture(albedo_texture, UV);
    ALBEDO = tex_color.rgb * albedo_tint;
    
    // Patrón de ruido para disolución
    vec2 noise_uv = UV * noise_scale;
    float noise_value = fbm(noise_uv);
    
    // Añadir gradiente vertical (disuelve desde abajo)
    noise_value = noise_value * 0.6 + UV.y * 0.4;
    
    // === ALPHA SCISSOR ===
    // Si el ruido es menor que dissolve_amount, el píxel se descarta
    float alpha = step(dissolve_amount, noise_value);
    
    // === BORDE BRILLANTE ===
    // El borde es donde el ruido está justo por encima del umbral
    float edge_lower = dissolve_amount;
    float edge_upper = dissolve_amount + edge_thickness;
    
    // Crear máscara del borde
    float edge_mask = 0.0;
    if (noise_value > edge_lower && noise_value < edge_upper) {
        // Gradiente suave en el borde
        edge_mask = 1.0 - (noise_value - edge_lower) / edge_thickness;
        edge_mask = smoothstep(0.0, 1.0, edge_mask);
    }
    
    // === INCANDESCENCIA GLOBAL ===
    // El modelo brilla más a medida que se disuelve
    float global_glow = dissolve_amount * 1.5;
    ALBEDO = mix(ALBEDO, glow_color.rgb, global_glow * 0.3);
    
    // === EMISIÓN ===
    vec3 edge_emission = glow_color.rgb * edge_mask * glow_intensity;
    vec3 base_emission = glow_color.rgb * global_glow * 0.5;
    EMISSION = edge_emission + base_emission;
    
    // === ALPHA (Scissor Mode) ===
    // Usamos ALPHA_SCISSOR_THRESHOLD en lugar de descartar manualmente
    ALPHA = alpha;
    ALPHA_SCISSOR_THRESHOLD = 0.5;
}
