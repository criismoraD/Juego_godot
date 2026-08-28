shader_type spatial;
render_mode cull_front, unshaded;

global uniform bool Toon_Proyectiles_Enemigos_Activo = true;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width = 25.0; // Grosor en píxeles de pantalla

void vertex() {
	if (!Toon_Proyectiles_Enemigos_Activo) {
		VERTEX = vec3(0.0);
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	} else {
		vec4 clip_position = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
		vec3 clip_normal = mat3(PROJECTION_MATRIX) * (MODELVIEW_NORMAL_MATRIX * NORMAL);

		// Clamp depth to keep outline size consistent
		float depth_scale = clamp(clip_position.w, 0.5, 5.0);
		vec2 offset = vec2(0.0);
		float norm_len = length(clip_normal.xy);
		if (norm_len > 0.0001) {
			offset = (clip_normal.xy / norm_len) / VIEWPORT_SIZE * depth_scale * outline_width * 2.0;
		}

		clip_position.xy += offset;
		POSITION = clip_position;
	}
}

void fragment() {
	if (!Toon_Proyectiles_Enemigos_Activo) {
		discard;
	}
	ALBEDO = outline_color.rgb;
	if (outline_color.a < 1.0) {
		ALPHA = outline_color.a;
	}
}
