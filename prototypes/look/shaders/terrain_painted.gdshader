// Look prototype: painted terrain. Same chunk/heightmap inputs as terrain_toon, but the
// ground is a hand-painted palette per zone: big soft colour masses, brush strokes,
// worn paths, glowing seams in the Rift, no ink lines. `painterly` 0 = anime (cel light),
// 1 = soft wrap light and heavier strokes.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
#include "res://prototypes/look/shaders/look_noise.gdshaderinc"

uniform sampler2D heightmap : filter_nearest, repeat_disable;
uniform sampler2D zone_weights_a : filter_linear, repeat_disable;
uniform sampler2D zone_weights_b : filter_linear, repeat_disable;
uniform vec2 map_origin = vec2(-1024.0);
uniform float cell_size = 2.0;
uniform int map_samples = 1025;
uniform int weight_samples = 257;
uniform int lod_step = 1;
uniform float skirt_depth = 6.0;
uniform vec4 zone_low[6];
uniform vec4 zone_high[6];
uniform vec4 zone_rock[6];
uniform vec4 zone_params[6];

uniform float painterly = 0.0;
uniform vec3 ground_a : source_color = vec3(0.36, 0.22, 0.17);
uniform vec3 ground_b : source_color = vec3(0.55, 0.36, 0.24);
uniform vec3 ground_c : source_color = vec3(0.22, 0.15, 0.16);
uniform vec3 rock_a : source_color = vec3(0.30, 0.20, 0.20);
uniform vec3 rock_b : source_color = vec3(0.62, 0.40, 0.28);
uniform vec3 seam_color : source_color = vec3(1.0, 0.45, 0.1);
uniform float seam_amount = 0.0;
uniform vec3 shadow_tint : source_color = vec3(0.42, 0.36, 0.62);
uniform float sun_scale = 0.62;
// Fight centre (xz): a worn, lighter arena floor around it.
uniform vec2 arena_centre = vec2(0.0);
uniform float arena_radius = 30.0;
uniform float base_height = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

float height_sample(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(map_samples - 1));
	return texelFetch(heightmap, p, 0).r;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ivec2 idx = ivec2(round((wp.xz - map_origin) / cell_size));
	float h = height_sample(idx);
	float hl = height_sample(idx - ivec2(lod_step, 0));
	float hr = height_sample(idx + ivec2(lod_step, 0));
	float hu = height_sample(idx - ivec2(0, lod_step));
	float hd = height_sample(idx + ivec2(0, lod_step));
	NORMAL = normalize(vec3(hl - hr, 2.0 * float(lod_step) * cell_size, hu - hd));
	VERTEX.y = h - UV.x * skirt_depth * float(lod_step);
	world_pos = vec3(wp.x, VERTEX.y, wp.z);
	world_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec2 p = world_pos.xz;
	float px = length(fwidth(p));
	float big = lk_fbm(p / 70.0);
	float mid = lk_fbm(p / 13.0 + 4.0);
	float fine = lk_fbm(p / 2.2 + 9.0);
	float fine_fade = 1.0 - smoothstep(0.15, 0.6, px);
	vec2 dir = normalize(vec2(0.8, 0.6) + (lk_noise(p / 30.0) - 0.5) * 1.2);
	float stroke = lk_strokes(p, dir, mix(3.5, 2.2, painterly));
	// Ground: three painted masses, blended softly.
	vec3 g = mix(ground_a, ground_b, smoothstep(0.35, 0.68, big));
	g = mix(g, ground_c, smoothstep(0.5, 0.75, mid) * 0.7);
	g *= mix(1.0, 0.86 + 0.28 * stroke, mix(0.55, 1.0, painterly) * fine_fade);
	g *= mix(1.0, 0.9 + 0.2 * fine, fine_fade);
	// Worn arena floor: lighter and smoother near the fight.
	float d_arena = length(p - arena_centre) / arena_radius;
	float worn = (1.0 - smoothstep(0.45, 1.05, d_arena + (mid - 0.5) * 0.5));
	g = mix(g, g * vec3(1.16, 1.1, 1.02), worn * 0.6);
	// Valleys darker (painted occlusion), crests catch light.
	float crest = clamp((world_pos.y - base_height) / 40.0, 0.0, 1.0);
	g *= mix(0.85, 1.08, crest);
	// Rock on slopes.
	float slope = 1.0 - n.y;
	float rock_mix = smoothstep(0.22, 0.4, slope + (mid - 0.5) * 0.2);
	float rock_n = lk_fbm(vec2(p.x + p.y, world_pos.y * 2.0) / 30.0);
	vec3 r = mix(rock_a, rock_b, clamp(rock_n * 0.6 + crest * 0.5, 0.0, 1.0));
	float vert = lk_fbm(vec2((p.x - p.y) * 0.25, world_pos.y * 0.03));
	r *= mix(1.0, 0.8 + 0.35 * vert, fine_fade * 0.5 + 0.5);
	vec3 col = mix(g, r, rock_mix);
	// Seams of glowing lava, thin and far apart, with an ashy halo.
	vec3 glow = vec3(0.0);
	if (seam_amount > 0.0) {
		float e = lk_cell_edge(p / 26.0 + vec2(lk_noise(p / 9.0)) * 0.35);
		float keep = smoothstep(0.62, 0.72, lk_noise(p / 60.0 + 3.0)) * (1.0 - rock_mix);
		float core = 1.0 - smoothstep(0.004, 0.012, e);
		float halo = 1.0 - smoothstep(0.012, 0.05, e);
		col = mix(col, col * vec3(0.55, 0.45, 0.45), halo * keep * 0.6);
		glow = seam_color * (core * 2.5 + halo * 0.15) * keep * seam_amount;
	}
	ALBEDO = col;
	EMISSION = glow;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	vec3 light_in = LIGHT_COLOR / PI * sun_scale;
	if (LIGHT_IS_DIRECTIONAL) {
		float cel = smoothstep(0.02, 0.12, ndl * ATTENUATION);
		float wrap = clamp((ndl + 0.35) / 1.35, 0.0, 1.0) * mix(0.35, 1.0, ATTENUATION);
		float lit = mix(cel, wrap * wrap * 1.1, painterly);
		DIFFUSE_LIGHT += light_in * mix(shadow_tint, vec3(1.0), lit);
	} else {
		DIFFUSE_LIGHT += light_in * clamp(ndl, 0.0, 1.0) * ATTENUATION;
	}
}
