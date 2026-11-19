// Toon lake: banded ripples and a foam line where the shore rises to the surface.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;
#include "res://game/world/shaders/zone_plane.gdshaderinc"

uniform vec4 shallow_color : source_color = vec4(0.25, 0.7, 0.75, 1.0);
uniform vec4 deep_color : source_color = vec4(0.08, 0.3, 0.45, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform float light_level = 1.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (zone_weight(world_pos.xz) < 0.4 || outside_clip(world_pos.xz)) {
		discard;
	}
	float depth = world_pos.y - terrain_height(world_pos.xz);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, smoothstep(1.0, 8.0, depth));
	float ripple = value_noise(world_pos.xz / 6.0 + vec2(TIME * 0.3, TIME * 0.2));
	col = mix(col, shallow_color.rgb * 1.25, step(0.72, ripple));
	float foam = 1.0 - step(0.9 + 0.5 * value_noise(world_pos.xz / 3.0 + TIME * 0.4), depth);
	col = mix(col, foam_color.rgb, foam);
	ALBEDO = col * light_level;
}
