// Full-screen anime overlays (T-D27): burst lines, impact frame, KO colour pop, white flash.
shader_type canvas_item;

#include "res://game/view/shaders/vfx_noise.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// 0 burst lines, 1 impact frame (two-tone ink), 2 colour pop, 3 flash.
uniform int mode : hint_range(0, 3) = 0;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// Screen UV the burst converges on.
uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 ink : source_color = vec4(0.05, 0.03, 0.08, 1.0);

void fragment() {
	vec2 p = UV - center;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(p);
	if (mode == 0) {
		float slots = 90.0;
		float a = (atan(p.y, p.x) / TAU + 0.5) * slots;
		float slot = floor(a);
		float frame = floor(TIME * 24.0);
		float pick = vfx_hash21(vec2(slot, frame));
		float on = step(pick, 0.55);
		// Lines stay in the outer band: the fighters around the centre are never crossed.
		float start = 0.34 + 0.2 * vfx_hash21(vec2(slot + 31.0, frame)) + 0.2 * (1.0 - amount);
		float taper = smoothstep(start, start + 0.2, r);
		float width = 0.18 * taper;
		float line = 1.0 - smoothstep(width, width + 0.1, abs(fract(a) - 0.5));
		COLOR = vec4(color.rgb, on * line * taper * amount * color.a);
	} else if (mode == 1) {
		// Two-tone manga frame: bright parts go to the hit colour, the rest to ink.
		vec3 scene = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
		float lum = dot(scene, vec3(0.299, 0.587, 0.114));
		float lit = step(0.62, lum + 0.12 * (1.0 - smoothstep(0.0, 0.3, r)));
		vec3 frame_color = mix(ink.rgb, mix(color.rgb, vec3(1.0), 0.6), lit);
		// Partial: the contact area around the centre keeps its real colours.
		COLOR = vec4(frame_color, amount * smoothstep(0.16, 0.42, r));
	} else if (mode == 2) {
		// KO colour pop: punchy contrast toward the sky tint, vignette in ink.
		vec3 scene = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
		float lum = dot(scene, vec3(0.299, 0.587, 0.114));
		vec3 graded = mix(vec3(lum), scene, 1.6);
		graded = mix(graded, graded * color.rgb * 1.6, 0.55);
		graded = (graded - 0.5) * 1.25 + 0.5;
		float vignette = smoothstep(0.35, 0.95, r);
		graded = mix(graded, ink.rgb, vignette * 0.7);
		COLOR = vec4(clamp(graded, 0.0, 1.0), amount);
	} else {
		// Edge flash: clear in the middle where the fighters are, brightest at the frame.
		COLOR = vec4(color.rgb, amount * smoothstep(0.22, 0.75, r));
	}
}
