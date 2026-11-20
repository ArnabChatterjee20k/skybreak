// The Great Falls: a white curtain in voxel-stepped bands (0.7 m cells),
// scrolling down, ragged stepped edges, foam at the foot.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform vec3 water_color : source_color = vec3(0.78, 0.86, 0.86);
uniform vec3 streak_color : source_color = vec3(0.97, 0.98, 0.97);
uniform vec3 shade_color : source_color = vec3(0.6, 0.7, 0.72);
uniform float light_level = 1.0;
uniform float t = 0.0;
uniform float speed = 0.5;
uniform vec2 size_m = vec2(60.0, 120.0);
uniform float cell_m = 0.7;
uniform float layer = 0.0;

float h1(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void fragment() {
	vec2 m = UV * size_m;
	float col = floor(m.x / cell_m);
	float row = floor(m.y / cell_m);
	float off = h1(col + layer * 17.0);
	float v = (row * cell_m) / size_m.y;
	float flow = fract(v * 6.0 - t * speed * (0.8 + off * 0.5) + off);
	float streak = step(0.5, flow);
	float fine = step(0.75, h1(col * 7.0 + floor(row - t * 30.0)));
	vec3 c = mix(water_color, streak_color, streak * 0.75 + fine * 0.2);
	// Darker vertical seams where the curtain thins.
	c = mix(c, shade_color, step(0.85, h1(col * 3.0 + 1.0)) * 0.5 * (1.0 - v));
	c = mix(c, streak_color, smoothstep(0.86, 1.0, v));
	// Ragged stepped sides.
	float edge_cells = 3.0 + 4.0 * h1(row * 0.37 + col);
	float from_edge = min(col, floor(size_m.x / cell_m) - col);
	float a = step(edge_cells * 0.5, from_edge) * (0.86 + 0.14 * streak);
	ALBEDO = c * light_level;
	ALPHA = a;
}
