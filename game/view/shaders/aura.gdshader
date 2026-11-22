// Inner aura shell hugging the body: hot fresnel tongues at the silhouette, clear where it faces the camera.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

#include "res://game/view/shaders/vfx_noise.gdshaderinc"

// Per fighter: each FighterAura owns a copy of this material (GLES3 caps instance uniforms).
uniform vec4 color : source_color = vec4(1.0, 0.62, 0.22, 1.0);
// 0 off, 1 charging ki, 2 transformed, 3 ultimate; values in between blend.
uniform float power_level : hint_range(0.0, 3.0) = 0.0;
// HDR ceiling, so bloom never turns the shell into a white blob.
uniform float max_hdr : hint_range(0.5, 4.0) = 1.2;

uniform float intensity : hint_range(0.0, 8.0) = 1.0;
uniform float flame_speed : hint_range(0.0, 8.0) = 1.6;
// Metres the top of the shell stretches upward at level 1 (more at higher levels).
uniform float flame_height : hint_range(0.0, 2.0) = 0.45;
uniform float flicker : hint_range(0.0, 1.0) = 0.25;
// Metres the shell is pushed out along its normals.
uniform float grow : hint_range(0.0, 0.5) = 0.12;
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.5;
// Flame noise cells per metre, across.
uniform float flame_scale : hint_range(0.5, 12.0) = 7.0;
// Vertical noise squash: lower makes taller, thinner tongues.
uniform float tongue_stretch : hint_range(0.05, 1.0) = 0.14;
// Noise cut at the feet and at the top; higher cuts more, so tongues thin out and break up as they rise.
uniform float root_threshold : hint_range(0.0, 1.0) = 0.4;
uniform float tip_threshold : hint_range(0.0, 1.0) = 0.66;
// Edge width of each tongue in noise units: small = crisp tongues, large = soft.
uniform float tongue_softness : hint_range(0.01, 0.5) = 0.07;
// Extra brightness and whiteness at the base of the tongues along the silhouette.
uniform float root_glow : hint_range(0.0, 4.0) = 0.7;
// Faces turned toward the camera more than this (0 edge-on, 1 head-on) show no glow.
uniform float center_clear : hint_range(0.0, 1.0) = 0.55;
// Thin continuous line along the silhouette under the tongues.
uniform float rim_base : hint_range(0.0, 1.0) = 0.0;
// Shell height in metres, before grow; maps the feet to 0 and the head to 1 for the erosion.
uniform float body_height : hint_range(0.5, 4.0) = 1.85;

varying vec3 local_pos;
varying float lift;

void vertex() {
	float level = clamp(power_level, 0.0, 3.0);
	float on = smoothstep(0.0, 1.0, level);
	float high = smoothstep(2.0, 3.0, level);
	float height_gain = 1.0 + 0.7 * smoothstep(1.0, 2.0, level) + 0.8 * high;
	local_pos = VERTEX;
	float up = max(NORMAL.y, 0.0);
	lift = up * up;
	float lick = vfx_noise3(vec3(VERTEX.xz * 2.5, TIME * flame_speed * 1.5));
	VERTEX += NORMAL * grow * (0.6 + 0.4 * on + 0.6 * high);
	// The upper half leans into a teardrop whose tip licks up and down.
	VERTEX.y += lift * flame_height * height_gain * on * (0.55 + 0.45 * lick);
}

void fragment() {
	float level = clamp(power_level, 0.0, 3.0);
	float on = smoothstep(0.0, 1.0, level);
	float high = smoothstep(1.0, 3.0, level);
	float speed = flame_speed * (1.0 + 0.6 * high);
	float edge = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(edge, fresnel_power);
	// 0 on faces pointing at the camera, so the body shows through clean.
	float side = smoothstep(0.0, max(1.0 - center_clear, 1e-3), edge);
	side *= side;
	// 0 at the feet, 1 at the head and teardrop tip.
	float h = clamp(local_pos.y / body_height + 0.5, 0.0, 1.0);
	h = clamp(0.75 * h + 0.45 * lift, 0.0, 1.0);
	// Cheap sideways sway (no extra noise octave) so tongues lean and wave.
	float sway = 0.06 * sin(local_pos.y * 4.0 - TIME * speed * 1.3 + local_pos.z * 3.0);
	vec3 q = vec3((local_pos.x + sway) * flame_scale,
		local_pos.y * flame_scale * tongue_stretch - TIME * speed,
		(local_pos.z - sway) * flame_scale);
	float n = vfx_fbm3(q);
	// Erosion: the cut rises with height, so solid roots split into thin tongues with gaps between.
	float cut = mix(root_threshold, tip_threshold, h) - 0.05 * high;
	float tongues = smoothstep(cut, cut + tongue_softness, n);
	float root = 1.0 - smoothstep(0.0, 0.5, h);
	float flick = 1.0 - flicker * vfx_noise1(TIME * 18.0 + local_pos.y * 2.0);
	float flame = tongues * side * (0.55 + root_glow * root) * (0.8 + 0.5 * high);
	// The silhouette line also breaks with the tongues, so no smooth glassy outline.
	float amount = (flame + rim * rim_base * (0.25 + 0.75 * tongues)) * flick * on;
	float white = clamp(tongues * side * (0.25 * root + 0.5 * rim) * (0.3 + 0.5 * high), 0.0, 1.0);
	vec3 hot = mix(color.rgb, vec3(1.0), white);
	// Never negative: an additive layer must only ever brighten what is behind it.
	ALBEDO = max(min(hot * amount * intensity, vec3(max_hdr)), vec3(0.0));
}
