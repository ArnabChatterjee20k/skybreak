// Look prototype: props (rocks, trees, islands) with painted variation: a top-lit
// gradient, colour mottling and soft strata instead of flat fills.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
#include "res://prototypes/look/shaders/look_noise.gdshaderinc"

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float strata = 0.0;
uniform float strata_spacing = 4.0;
uniform float windows = 0.0;
uniform vec4 window_color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength = 0.0;
uniform float night_emission = 0.0;
uniform float night = 0.0;
uniform vec4 shadow_tint : source_color = vec4(0.6, 0.56, 0.8, 1.0);
uniform float sun_scale = 0.5;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float rim_strength = 0.15;
uniform float painterly = 0.0;
// 1 on walkable ground meshes (island tops): upward faces use the painted ground palette.
uniform float ground_mode = 0.0;
uniform vec3 ground_a : source_color = vec3(0.38, 0.62, 0.32);
uniform vec3 ground_b : source_color = vec3(0.66, 0.78, 0.38);
uniform vec3 ground_c : source_color = vec3(0.25, 0.48, 0.40);
uniform vec2 arena_centre = vec2(0.0);
uniform float arena_radius = 30.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = albedo_color.rgb * COLOR.rgb;
	vec3 n = normalize(world_normal);
	vec2 tri = abs(n.y) > 0.6 ? world_pos.xz : (abs(n.x) > abs(n.z) ? world_pos.zy : world_pos.xy);
	float m = lk_fbm(tri / 3.0);
	float s = lk_strokes(tri, normalize(vec2(1.0, 0.25 + n.x * 0.3)), 2.0);
	col *= 0.82 + 0.3 * m;
	col *= mix(1.0, 0.88 + 0.22 * s, 0.5 + 0.5 * painterly);
	// Top-lit gradient: upward faces lighter, undersides cooler.
	col *= mix(vec3(0.82, 0.84, 0.95), vec3(1.08, 1.05, 1.0), n.y * 0.5 + 0.5);
	if (ground_mode > 0.5 && n.y > 0.55) {
		vec2 p = world_pos.xz;
		float big = lk_fbm(p / 40.0);
		float mid = lk_fbm(p / 9.0 + 4.0);
		vec3 g = mix(ground_a, ground_b, smoothstep(0.35, 0.7, big));
		g = mix(g, ground_c, smoothstep(0.5, 0.8, mid) * 0.6);
		float st = lk_strokes(p, normalize(vec2(0.7, 0.7) + (lk_noise(p / 20.0) - 0.5)), 1.6);
		g *= 0.84 + 0.3 * st;
		float worn = 1.0 - smoothstep(0.5, 1.1, length(p - arena_centre) / arena_radius + (mid - 0.5) * 0.6);
		g = mix(g, g * vec3(1.12, 1.08, 0.95), worn * 0.5);
		col = mix(col, g, smoothstep(0.55, 0.75, n.y));
	}
	if (strata > 0.0) {
		float band = smoothstep(0.3, 0.7, lk_noise(vec2(world_pos.y / strata_spacing * 2.0, (world_pos.x + world_pos.z) / 30.0)));
		col *= mix(1.0, 0.82 + 0.25 * band, strata);
	}
	vec3 glow = emission_color.rgb * (emission_strength + night_emission * night) * mix(vec3(1.0), COLOR.rgb, step(0.001, night_emission));
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float facing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = glow + rim_color.rgb * smoothstep(0.78, 0.9, facing) * rim_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	vec3 light_in = LIGHT_COLOR / PI * sun_scale;
	if (LIGHT_IS_DIRECTIONAL) {
		float cel = smoothstep(0.05, 0.16, ndl * ATTENUATION);
		float wrap = clamp((ndl + 0.4) / 1.4, 0.0, 1.0) * mix(0.35, 1.0, ATTENUATION);
		float lit = mix(cel, wrap * wrap * 1.1, painterly);
		DIFFUSE_LIGHT += light_in * mix(shadow_tint.rgb, vec3(1.0), lit);
	} else {
		DIFFUSE_LIGHT += light_in * clamp(ndl, 0.0, 1.0) * ATTENUATION;
	}
}
