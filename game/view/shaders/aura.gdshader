// Additive energy aura shell: fresnel glow plus upward-scrolling flame noise.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

#include "res://game/view/shaders/vfx_noise.gdshaderinc"

// Per fighter, set on the shell's MeshInstance3D so all fighters share one material.
instance uniform vec4 color : source_color = vec4(1.0, 0.62, 0.22, 1.0);
// 0 off, 1 charging ki, 2 transformed, 3 ultimate; values in between blend.
instance uniform float power_level : hint_range(0.0, 3.0) = 0.0;

uniform float intensity : hint_range(0.0, 8.0) = 1.0;
uniform float flame_speed : hint_range(0.0, 8.0) = 1.6;
// Metres the top of the shell stretches upward at level 1 (more at higher levels).
uniform float flame_height : hint_range(0.0, 2.0) = 0.45;
uniform float flicker : hint_range(0.0, 1.0) = 0.25;
// Metres the shell is pushed out along its normals.
uniform float grow : hint_range(0.0, 0.5) = 0.12;
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.5;
// Flame noise cells per metre.
uniform float flame_scale : hint_range(0.5, 12.0) = 7.0;

varying vec3 local_pos;

void vertex() {
	float level = clamp(power_level, 0.0, 3.0);
	float on = smoothstep(0.0, 1.0, level);
	float high = smoothstep(2.0, 3.0, level);
	float height_gain = 1.0 + 0.7 * smoothstep(1.0, 2.0, level) + 0.8 * high;
	local_pos = VERTEX;
	float up = max(NORMAL.y, 0.0);
	float lick = vfx_noise3(vec3(VERTEX.xz * 2.5, TIME * flame_speed * 1.5));
	VERTEX += NORMAL * grow * (0.6 + 0.4 * on + 0.6 * high);
	// The upper half leans into a teardrop whose tip licks up and down.
	VERTEX.y += up * up * flame_height * height_gain * on * (0.55 + 0.45 * lick);
}

void fragment() {
	float level = clamp(power_level, 0.0, 3.0);
	float on = smoothstep(0.0, 1.0, level);
	float high = smoothstep(1.0, 3.0, level);
	float speed = flame_speed * (1.0 + 0.6 * high);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, fresnel_power);
	// Flames live in a wider band than the thin glow line.
	float band = pow(1.0 - facing, fresnel_power * 0.3);
	// Noise is squashed vertically so it reads as rising tongues rather than blobs.
	vec3 q = vec3(local_pos.x * flame_scale, local_pos.y * flame_scale * 0.25 - TIME * speed, local_pos.z * flame_scale);
	float n = vfx_fbm3(q);
	// Contrast-stretched so the shell breaks into separate tongues with gaps between.
	float tongues = smoothstep(0.45 - 0.08 * high, 0.6, n);
	float flick = 1.0 - flicker * vfx_noise1(TIME * 18.0 + local_pos.y * 2.0);
	float amount = (band * tongues * (0.7 + 0.5 * high) + rim * 0.45) * flick * on;
	vec3 hot = mix(color.rgb, vec3(1.0), clamp(tongues * rim * (0.25 + 0.5 * high), 0.0, 1.0));
	ALBEDO = hot * amount * intensity;
}
