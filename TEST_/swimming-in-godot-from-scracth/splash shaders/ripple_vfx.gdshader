shader_type spatial;
render_mode blend_add, unshaded, cull_disabled;

uniform sampler2D ripple_texture : source_color; // Add this
uniform vec4 color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float thickness : hint_range(0.0, 0.5) = 0.1;
uniform float radius : hint_range(0.0, 1.0) = 0.5;
uniform float feather : hint_range(0.0, 0.5) = 0.1;

void fragment() {
    float dist = distance(UV, vec2(0.5));
    
    // 1. Existing Ring Math
    float ring = smoothstep(radius - thickness - feather, radius - thickness, dist) 
               - smoothstep(radius, radius + feather, dist);
    
    // 2. Sample the Texture
    // Using UV * 2.0 to tile it, and adding some scrolling if you want
    vec4 tex = texture(ripple_texture, UV);
    
    // 3. The Edge Fade (Fixes the "Box" issue from before)
    float edge_fade = clamp(1.0 - dist * 1.2, 0.0, 1.0);
    
    ALBEDO = tex.rgb * color.rgb;
    // Multiply the ring by the texture and the edge fade
    ALPHA = ring * tex.r * color.a;
}