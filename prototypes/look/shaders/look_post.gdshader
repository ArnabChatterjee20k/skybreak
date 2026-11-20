// Look prototype: full-screen post pass (canvas layer under the HUD, after the whole 3D
// frame incl. VFX). Colour grade, anime impact frame (fighters around the hit keep colour,
// the rest turns two-tone with radial lines), speed lines, painterly Kuwahara + paper grain.
shader_type canvas_item;
#include "res://prototypes/look/shaders/look_noise.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
// Screen-height fraction around the hit that keeps its colour in an impact frame.
uniform float impact_keep = 0.2;
uniform float saturation = 1.0;
uniform vec3 lift = vec3(0.0);
uniform vec3 gain = vec3(1.0);
uniform float contrast = 1.0;
uniform float vignette = 0.0;
uniform vec3 vignette_color : source_color = vec3(0.1, 0.05, 0.15);
// Impact frame.
uniform float impact = 0.0;
uniform vec2 impact_uv = vec2(0.5);
uniform vec3 impact_dark : source_color = vec3(0.05, 0.02, 0.06);
uniform vec3 impact_light : source_color = vec3(1.0, 0.97, 0.92);
uniform vec3 impact_tint : source_color = vec3(1.0, 0.35, 0.15);
// Speed lines toward a point (dash, beam).
uniform float speed_lines = 0.0;
uniform vec2 speed_uv = vec2(0.5);
// Painterly.
uniform int kuwahara_radius = 0;
uniform float paper = 0.0;
uniform float edge_ink = 0.0;


vec3 kuwahara(vec2 uv, vec2 px, int r) {
	vec3 mean[4];
	vec3 sq[4];
	for (int k = 0; k < 4; k++) {
		mean[k] = vec3(0.0);
		sq[k] = vec3(0.0);
	}
	float count = float((r + 1) * (r + 1));
	for (int j = 0; j <= r; j++) {
		for (int i = 0; i <= r; i++) {
			vec3 a = textureLod(screen_tex, uv + vec2(-float(i), -float(j)) * px, 0.0).rgb;
			vec3 b = textureLod(screen_tex, uv + vec2(float(i), -float(j)) * px, 0.0).rgb;
			vec3 c = textureLod(screen_tex, uv + vec2(-float(i), float(j)) * px, 0.0).rgb;
			vec3 d = textureLod(screen_tex, uv + vec2(float(i), float(j)) * px, 0.0).rgb;
			mean[0] += a; sq[0] += a * a;
			mean[1] += b; sq[1] += b * b;
			mean[2] += c; sq[2] += c * c;
			mean[3] += d; sq[3] += d * d;
		}
	}
	vec3 best = vec3(0.0);
	float best_var = 1e9;
	for (int k = 0; k < 4; k++) {
		vec3 m = mean[k] / count;
		vec3 v = abs(sq[k] / count - m * m);
		float s = v.r + v.g + v.b;
		if (s < best_var) {
			best_var = s;
			best = m;
		}
	}
	return best;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 vp = 1.0 / SCREEN_PIXEL_SIZE;
	vec3 col = textureLod(screen_tex, uv, 0.0).rgb;
	if (kuwahara_radius > 0) {
		// Brush direction wobble so the filter reads as strokes, not blur.
		vec2 wob = (vec2(lk_noise(uv * 90.0), lk_noise(uv * 90.0 + 7.0)) - 0.5) * px * 1.5;
		col = kuwahara(uv + wob, px, kuwahara_radius);
	}
	if (edge_ink > 0.0) {
		// Luminance edges, a light ink line like a brush outline.
		float lc = dot(col, vec3(0.3, 0.59, 0.11));
		float lx = dot(textureLod(screen_tex, uv + vec2(px.x * 1.5, 0.0), 0.0).rgb, vec3(0.3, 0.59, 0.11));
		float ly = dot(textureLod(screen_tex, uv + vec2(0.0, px.y * 1.5), 0.0).rgb, vec3(0.3, 0.59, 0.11));
		float e = abs(lx - lc) + abs(ly - lc);
		col = mix(col, col * vec3(0.45, 0.36, 0.45), smoothstep(0.08, 0.25, e) * edge_ink);
	}
	// Grade.
	float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(l), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col = col * gain + lift * (1.0 - col);
	vec2 c = uv - 0.5;
	col = mix(col, vignette_color, clamp(dot(c, c) * 2.2 * vignette, 0.0, 1.0));
	if (paper > 0.0) {
		float grain = lk_noise(uv * vp / 2.5) * 0.6 + lk_noise(uv * vp / 14.0) * 0.4;
		col *= 1.0 + (grain - 0.5) * 0.08 * paper;
	}
	// Speed lines: thin white streaks converging on speed_uv, clear in the middle.
	vec2 sd = (uv - speed_uv) * vec2(vp.x / vp.y, 1.0);
	float sr = length(sd);
	float sa = atan(sd.y, sd.x);
	if (speed_lines > 0.0) {
		float lines = smoothstep(0.82, 0.95, lk_noise(vec2(sa * 60.0, 0.5)) * 0.6 + lk_noise(vec2(sa * 180.0, 3.0)) * 0.4);
		float ring = smoothstep(0.32, 0.7, sr);
		col = mix(col, vec3(1.0), lines * ring * speed_lines * 0.75);
	}
	if (impact > 0.0) {
		vec2 d = (uv - impact_uv) * vec2(vp.x / vp.y, 1.0);
		float r = length(d);
		float a = atan(d.y, d.x);
		float behind = smoothstep(impact_keep, impact_keep * 1.5, r);
		float lum = dot(col, vec3(0.3, 0.55, 0.15));
		vec3 two_tone = mix(impact_dark, impact_tint * 0.55, smoothstep(0.25, 0.6, lum));
		vec3 bg = two_tone;
		float lines = smoothstep(0.7, 0.9, lk_noise(vec2(a * 45.0, 1.0)) * 0.55 + lk_noise(vec2(a * 140.0, 5.0)) * 0.45);
		lines *= smoothstep(impact_keep * 1.2, impact_keep * 2.2, r);
		bg = mix(bg, impact_light, lines * 0.9);
		// Foreground: punchier, warm-flashed near the hit.
		vec3 fg = col * 1.12 + impact_tint * 0.12 * (1.0 - smoothstep(0.0, 0.25, r));
		vec3 frame = mix(fg, bg, behind);
		// Hot white star at the contact point.
		float star = (1.0 - smoothstep(0.0, 0.06 + 0.05 * lk_noise(vec2(a * 6.0, 2.0)), r));
		frame = mix(frame, impact_light, star);
		col = mix(col, frame, impact);
	}
	COLOR = vec4(col, 1.0);
}
