shader_type canvas_item;
render_mode blend_add;

uniform vec4 ray_color : source_color = vec4(1.0, 0.90, 0.72, 0.22);
uniform float ray_density : hint_range(1.0, 10.0) = 4.2;
uniform float angle : hint_range(-2.0, 2.0) = -0.58;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec2 uv = UV;

	float diag = uv.x + uv.y * angle;

	float beam1 = noise(vec2(diag * ray_density, 0.23));
	float beam2 = noise(vec2(diag * (ray_density * 2.3), 0.67));
	float beam3 = noise(vec2(diag * (ray_density * 0.6), 0.41));
	float rays = beam1 * 0.50 + beam2 * 0.32 + beam3 * 0.18;

	rays = smoothstep(0.36, 0.76, rays);

	float falloff = clamp(1.15 - (uv.x * 0.40 + uv.y * 0.50), 0.0, 1.0);

	float edge = sin(uv.x * 3.14159265) * sin(uv.y * 3.14159265);
	edge = clamp(edge * 2.2, 0.0, 1.0);

	float intensity = rays * falloff * edge * ray_color.a;

	COLOR = vec4(ray_color.rgb * intensity, 1.0);
}
