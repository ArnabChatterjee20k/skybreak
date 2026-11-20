// Sea of clouds under the floating islands: opaque, crisp toon billows (lit sun side, a
// dusty-blue shade side, soft creases); no see-through holes onto the basin below (#99).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;
#include "res://game/world/shaders/zone_plane.gdshaderinc"

uniform vec4 lit_color : source_color = vec4(1.0, 0.95, 0.86, 1.0);
uniform vec4 mid_color : source_color = vec4(0.86, 0.85, 0.9, 1.0);
uniform vec4 shade_color : source_color = vec4(0.62, 0.66, 0.84, 1.0);
uniform vec4 crease_color : source_color = vec4(0.5, 0.52, 0.74, 1.0);
uniform float light_level = 1.0;
// Billow size in metres, and the sun's direction across the sea (x, z).
uniform float puff_size = 55.0;
uniform vec2 sun_dir = vec2(-0.7, 0.7);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float aa_step(float edge, float x) {
	float w = max(fwidth(x), 1e-4);
	return clamp((x - edge) / w + 0.5, 0.0, 1.0);
}

float puffs(vec2 p) {
	return value_noise(p) * 0.65 + value_noise(p * 2.6 + 5.3) * 0.35;
}

void fragment() {
	if (zone_weight(world_pos.xz) < 0.5) {
		discard;
	}
	float detail = 1.0 - smoothstep(0.02, 0.06, length(fwidth(world_pos.xz / puff_size)));
	vec2 p = world_pos.xz / puff_size + vec2(TIME * 0.005, TIME * 0.003);
	float n = puffs(p);
	float toward_sun = puffs(p + normalize(sun_dir) * 0.06);
	// Three crisp levels: low valleys, cloud tops, high billows.
	float top = aa_step(0.4, n);
	float high = aa_step(0.58, n);
	// Lit crescent on each billow's sun side, shade crescent on the far side.
	float slope = (n - toward_sun) * 12.0;
	float lit = aa_step(0.25, -slope) * top;
	float shade = aa_step(0.25, slope) * top * (1.0 - high * 0.5);
	vec3 col = mix(shade_color.rgb, mid_color.rgb, top);
	col = mix(col, lit_color.rgb, max(high, lit));
	col = mix(col, shade_color.rgb, shade * 0.8);
	// A darker crease where a billow rises out of the valley.
	float crease = (1.0 - aa_step(0.025, abs(n - 0.4))) * detail;
	col = mix(col, crease_color.rgb, crease * 0.6);
	ALBEDO = col * light_level;
}
