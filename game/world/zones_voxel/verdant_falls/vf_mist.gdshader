// Mist and spray: see-through voxel puffs, light and warm, softer at the edges.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

uniform vec3 mist_color : source_color = vec3(0.93, 0.93, 0.89);
uniform float opacity = 0.35;
uniform float light_level = 1.0;
uniform float fade_near = 6.0;

void fragment() {
	float rim = abs(dot(NORMAL, VIEW));
	float near = smoothstep(0.0, fade_near, -VERTEX.z);
	ALBEDO = mist_color * light_level * (0.92 + 0.08 * NORMAL.y);
	ALPHA = opacity * mix(0.5, 1.0, rim) * near;
}
