// Emissive lava: slow flowing crust cells over a bright core, hidden outside its zone.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;
#include "res://game/world/shaders/zone_plane.gdshaderinc"

uniform vec4 core_color : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 crust_color : source_color = vec4(0.35, 0.06, 0.03, 1.0);
uniform float glow = 1.6;
uniform vec2 flow = vec2(0.6, 0.35);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (zone_weight(world_pos.xz) < 0.4 || outside_clip(world_pos.xz)) {
		discard;
	}
	vec2 p = world_pos.xz / 7.0 + flow * TIME * 0.15;
	float n = value_noise(p) * 0.65 + value_noise(p * 2.7 - TIME * 0.1) * 0.35;
	float crust = step(0.55, n);
	float pulse = 0.85 + 0.15 * sin(TIME * 1.7 + n * 6.0);
	vec3 col = mix(core_color.rgb * glow * pulse, crust_color.rgb, crust);
	ALBEDO = col;
}
