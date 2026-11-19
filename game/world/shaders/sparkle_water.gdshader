// Toon water for fountain bowls and streams: banded ripples (rings in pools, scrolling
// bands in streams) with twinkling sparkles.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 shallow_color : source_color = vec4(0.45, 0.88, 0.92, 1.0);
uniform vec4 deep_color : source_color = vec4(0.22, 0.6, 0.78, 1.0);
uniform vec4 sparkle_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 0: still pool, rings around the mesh origin. > 0: stream flowing along UV.y.
uniform float flow_speed = 0.0;
uniform float light_level = 1.0;

varying vec3 local_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float band;
	vec2 grid;
	if (flow_speed > 0.0) {
		float across = abs(UV.x - 0.5) * 2.0;
		band = step(0.6, fract(UV.y * 0.35 - TIME * flow_speed + 0.15 * sin(UV.x * 9.0)));
		band = max(band, step(0.82, across));
		grid = vec2(UV.x * 4.0, UV.y * 1.5 - TIME * flow_speed * 4.0);
	} else {
		float r = length(local_pos.xz);
		band = step(0.62, fract(r * 0.9 - TIME * 0.45));
		grid = local_pos.xz * 2.2;
	}
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, band);
	// Sparkles: a few cells blink on and off at their own pace.
	vec2 cell = floor(grid);
	float h = hash12(cell);
	float blink = step(0.9, fract(TIME * (0.4 + h) + h * 7.0)) * step(0.72, h);
	vec2 f = fract(grid) - 0.5;
	float star = step(abs(f.x) + abs(f.y), 0.16);
	col = mix(col, sparkle_color.rgb, blink * star);
	ALBEDO = col * light_level;
}
