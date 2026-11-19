// Sea of clouds under the floating islands: soft posterized puffs drifting slowly.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
#include "res://game/world/shaders/zone_plane.gdshaderinc"

uniform vec4 lit_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform vec4 shade_color : source_color = vec4(0.72, 0.68, 0.8, 1.0);
uniform float light_level = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float w = smoothstep(0.35, 0.75, zone_weight(world_pos.xz));
	vec2 p = world_pos.xz / 45.0 + vec2(TIME * 0.01, TIME * 0.006);
	float n = value_noise(p) * 0.6 + value_noise(p * 2.3) * 0.3 + value_noise(p * 6.0) * 0.1;
	float band = floor(n * 3.0) / 2.0;
	ALBEDO = mix(shade_color.rgb, lit_color.rgb, band) * light_level;
	ALPHA = w * smoothstep(0.12, 0.32, n) * 0.95;
}
