shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// === PARÁMETROS UNIFORMES ===
uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform float edge_thickness : hint_range(0.0, 0.3) = 0.06;
uniform vec4 glow_color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 20.0) = 8.0;
uniform float noise_scale : hint_range(1.0, 100.0) = 15.0;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform vec4 modulate_color : source_color = vec4(1.0);

varying vec2 local_coord;

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

void vertex() {
    local_coord = VERTEX.xy;
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
        vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
        vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
        MODEL_MATRIX[3]
    );
    MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
    if (dissolve_amount >= 0.999) {
        discard;
    }
    
    vec4 tex_color = texture(albedo_texture, UV) * modulate_color;
    if (tex_color.a <= 0.02) {
        discard;
    }
    
    if (dissolve_amount <= 0.001) {
        ALBEDO = tex_color.rgb;
        ALPHA = tex_color.a;
    } else {
        // Patrón de ruido FBM estable en coordenadas locales
        vec2 noise_uv = local_coord * noise_scale;
        float noise_value = fbm(noise_uv);
        
        // Añadir leve gradiente para que la disolución tenga dirección orgánica ascendente
        noise_value = noise_value * 0.7 + (local_coord.y + 0.5) * 0.3;
        
        // Descartar píxeles disueltos
        if (noise_value < dissolve_amount) {
            discard;
        }
        
        // === BORDE BRILLANTE INCANDESCENTE (CELESTE) ===
        float edge_lower = dissolve_amount;
        float edge_upper = dissolve_amount + edge_thickness;
        float edge_mask = 0.0;
        if (noise_value > edge_lower && noise_value < edge_upper) {
            edge_mask = 1.0 - (noise_value - edge_lower) / edge_thickness;
            edge_mask = smoothstep(0.0, 1.0, edge_mask);
        }
        
        // Incandescencia general y de borde
        float global_glow = dissolve_amount * 1.5;
        vec3 base_col = mix(tex_color.rgb, glow_color.rgb, global_glow * 0.35);
        vec3 border_glow = glow_color.rgb * glow_intensity;
        vec3 final_rgb = mix(base_col, border_glow, edge_mask);
        
        ALBEDO = final_rgb;
        ALPHA = clamp(tex_color.a + edge_mask * 0.6, 0.0, 1.0);
    }
}
