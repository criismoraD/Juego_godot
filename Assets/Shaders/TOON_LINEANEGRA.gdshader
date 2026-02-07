shader_type spatial;
render_mode unshaded, cull_front; // cull_front es el secreto: oculta las caras de enfrente

uniform float thickness : hint_range(0.0, 0.1, 0.0001) = 0.001; // Grosor de la línea
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0); // Color negro

void vertex() {
    // Expandimos los vértices hacia afuera siguiendo su normal
    VERTEX += NORMAL * thickness;
}

void fragment() {
    // Pintamos todo de negro plano
    ALBEDO = outline_color.rgb;
}