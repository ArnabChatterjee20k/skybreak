// Look prototype: painted 2.5D backdrop: sky gradient, sun glow, three ridge layers
// fading into haze (or floating island silhouettes), soft cloud bands.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
#include "res://prototypes/look/shaders/look_noise.gdshaderinc"

uniform vec3 sky_top : source_color = vec3(0.2, 0.15, 0.35);
uniform vec3 sky_low : source_color = vec3(1.0, 0.55, 0.35);
uniform vec3 far_color : source_color = vec3(0.8, 0.45, 0.4);
uniform vec3 near_color : source_color = vec3(0.25, 0.15, 0.18);
uniform vec3 glow_color : source_color = vec3(1.0, 0.45, 0.12);
uniform float islands = 0.0;

float ridge(float x, float seed, float height, float rough) {
	float h = lk_fbm(vec2(x * 3.0 + seed, seed)) * rough + (1.0 - rough) * 0.5;
	float spikes = pow(lk_noise(vec2(x * 14.0 + seed * 3.0, 0.5)), 3.0) * 0.25 * (1.0 - islands);
	return height + (h - 0.5) * 0.35 + spikes;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec3 col = mix(sky_low, sky_top, smoothstep(0.15, 0.95, uv.y));
	// Sun glow low on the horizon.
	float sun = exp(-length((uv - vec2(0.62, 0.32)) * vec2(1.6, 2.6)) * 3.0);
	col += sky_low * sun * 0.9;
	// Cloud bands.
	float cl = lk_fbm(vec2(uv.x * 4.0, uv.y * 14.0));
	col = mix(col, mix(sky_low, vec3(1.0), 0.4), smoothstep(0.55, 0.75, cl) * smoothstep(0.25, 0.6, uv.y) * 0.5);
	// Ridge layers back to front.
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float base = 0.48 - fi * 0.12;
		float edge = ridge(uv.x * (1.0 + fi * 0.6), 11.0 + fi * 7.0, base, 1.0);
		float depth = fi / 2.0;
		vec3 layer = mix(far_color, near_color, depth * depth);
		// Painted texture inside each layer.
		float t = lk_strokes(uv * vec2(80.0, 40.0), vec2(0.9, 0.44), 3.0);
		layer *= 0.9 + 0.2 * t;
		// Lit crest.
		float crest = smoothstep(edge - 0.02, edge, uv.y) * 0.3;
		if (islands > 0.5) {
			// Floating islands: lens shapes above the haze.
			vec2 cell = vec2(uv.x * (4.0 + fi * 2.0), uv.y * 3.0 + fi);
			vec2 id = floor(cell);
			vec2 f = fract(cell) - vec2(0.5, 0.5);
			float r = 0.18 + 0.15 * lk_hash12(id + fi);
			float top = f.y > 0.0 ? f.y * 6.0 : -f.y * 1.4;
			float isl = step(length(vec2(f.x, top * r * 1.5)), r) * step(0.55, lk_hash12(id * 1.7 + fi));
			col = mix(col, layer * mix(1.0, 1.25, step(0.0, f.y)), isl * smoothstep(0.35, 0.5, uv.y));
			edge -= 0.12;
		}
		float inside = 1.0 - smoothstep(edge - 0.003, edge + 0.003, uv.y);
		col = mix(col, layer, inside);
		// Haze at each layer's foot.
		col = mix(col, far_color, inside * smoothstep(edge - 0.08, base - 0.25, uv.y) * 0.0);
	}
	// Lava glow from below (Rift) or bright haze (Gardens).
	col += glow_color * smoothstep(0.3, 0.0, uv.y) * 0.5;
	ALBEDO = col;
}
