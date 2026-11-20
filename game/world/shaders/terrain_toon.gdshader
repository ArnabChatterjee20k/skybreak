// Toon terrain: lifts the shared chunk grid to the baked heightmap; flat-shaded zone ground
// with crisp stylised detail, inked cliff lips and silhouettes, and a 3-band light ramp.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D heightmap : filter_nearest, repeat_disable;
uniform sampler2D zone_weights_a : filter_linear, repeat_disable;
uniform sampler2D zone_weights_b : filter_linear, repeat_disable;
uniform vec2 map_origin = vec2(-1024.0);
uniform float cell_size = 2.0;
uniform int map_samples = 1025;
uniform int weight_samples = 257;
// Cells between vertices at this LOD.
uniform int lod_step = 1;
uniform float skirt_depth = 6.0;

// Per zone, sRGB: low colour, high colour, cliff rock, (ramp low m, ramp high m, strata, pattern).
uniform vec4 zone_low[6];
uniform vec4 zone_high[6];
uniform vec4 zone_rock[6];
uniform vec4 zone_params[6];

uniform vec4 shadow_tint : source_color = vec4(0.74, 0.72, 0.86, 1.0);
uniform float shadow_threshold = 0.04;
uniform float highlight_threshold = 0.3;
uniform float mid_band_level = 0.8;
uniform float band_softness = 0.02;
// Direct sun scale: with the ambient fill, lit ground lands near its palette colour.
uniform float sun_scale = 0.5;
uniform vec4 ink_color : source_color = vec4(0.12, 0.08, 0.14, 1.0);
// Slope (1 - normal.y) where ground turns to cliff.
uniform float cliff_slope = 0.3;

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

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// Antialiased step: 0 below edge, 1 above, about one pixel wide.
float aa_step(float edge, float x) {
	float w = max(fwidth(x), 1e-4);
	return clamp((x - edge) / w + 0.5, 0.0, 1.0);
}

// 1 where the detail is large enough on screen to draw without shimmering, 0 when it would alias.
float detail_fade(vec2 cells) {
	float px = length(fwidth(cells));
	return 1.0 - smoothstep(0.08, 0.22, px);
}

// Distance (cells) to the nearest Voronoi edge: stylised cracked ground.
float crack_distance(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 nearest = vec2(0.0);
	vec2 cell = vec2(0.0);
	float best = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + 0.15 + 0.7 * hash22(i + g) - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				nearest = r;
				cell = g;
			}
		}
	}
	float edge = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			if (g == cell) {
				continue;
			}
			vec2 r = g + 0.15 + 0.7 * hash22(i + g) - f;
			edge = min(edge, dot(0.5 * (nearest + r), normalize(r - nearest)));
		}
	}
	return edge;
}

// Scattered round clumps (grass tufts, pebbles): 1 inside a clump, plus a darker lower rim.
vec2 clumps(vec2 p, float density, float radius) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float on = step(1.0 - density, hash12(i + 17.0));
	vec2 c = 0.25 + 0.5 * hash22(i + 3.0);
	vec2 d = (f - c) * vec2(1.0, 1.6);
	float r = radius * (0.7 + 0.6 * hash12(i + 9.0));
	float body = 1.0 - aa_step(r, length(d));
	float rim = 1.0 - aa_step(r, length(d - vec2(0.0, -0.18 * r)));
	return vec2(body, max(rim - body, 0.0)) * on;
}

// `glow` gets the city's fake wet-street neon reflections, drawn as emission.
vec3 zone_colour(int i, float h, float rock_mix, float lip, inout vec3 glow) {
	vec4 p = zone_params[i];
	float t = clamp((h - p.x) / max(p.y - p.x, 1.0), 0.0, 1.0);
	vec3 ground = mix(to_linear(zone_low[i].rgb), to_linear(zone_high[i].rgb), t);
	vec3 rock_base = to_linear(zone_rock[i].rgb);
	float ground_mask = 1.0 - rock_mix;
	int pattern = int(p.w + 0.5);
	// Large flat two-tone patches with crisp edges.
	float patches = aa_step(0.56, value_noise(world_pos.xz / 26.0 + float(i) * 7.0));
	ground *= mix(1.0, 0.86, patches);
	if (pattern == 1) {
		// City: darker streets on a 48 m block grid with a pale kerb line.
		vec2 g = abs(fract((world_pos.xz + 6.0) / 48.0) - 0.5) * 48.0;
		float m = min(g.x, g.y);
		float street = 1.0 - aa_step(6.0, m);
		float kerb = (1.0 - aa_step(0.35, abs(m - 6.0))) * detail_fade(world_pos.xz / 0.7);
		ground = mix(ground, ground * 0.6, street);
		ground = mix(ground, ground * 1.35, kerb);
		vec2 lane = abs(fract((world_pos.xz + 6.0) / 48.0 + 0.5) - 0.5) * 48.0;
		float dash = step(0.5, fract(dot(world_pos.xz, vec2(1.0)) / 6.0));
		float centre = (1.0 - aa_step(0.18, min(lane.x, lane.y))) * street * dash * detail_fade(world_pos.xz / 0.4);
		ground = mix(ground, vec3(0.75, 0.68, 0.35), centre * 0.7);
		// Wet streets: dark rain puddles holding long neon streaks, as if reflecting the signs.
		float puddle = aa_step(0.66, value_noise(world_pos.xz / 3.5 + 3.0)) * (1.0 - rock_mix);
		vec2 lot = floor((world_pos.xz + 6.0) / 12.0);
		float pick = hash12(lot);
		vec3 neon = pick < 0.5 ? vec3(1.0, 0.18, 0.7) : vec3(0.15, 0.9, 1.0);
		vec2 sp = vec2(world_pos.x / 0.9, world_pos.z / 6.0);
		float streak = aa_step(0.72, value_noise(sp + pick * 40.0)) * detail_fade(sp);
		ground = mix(ground, ground * vec3(0.42, 0.44, 0.58), puddle);
		glow = neon * puddle * (0.04 + 0.32 * streak) * detail_fade(world_pos.xz / 3.0);
	} else if (pattern == 2) {
		// Snow: wind-carved sastrugi ridges with blue-grey lee sides, faded where they would alias.
		float phase = dot(world_pos.xz, vec2(0.83, 0.56)) / 2.6 + value_noise(world_pos.xz / 9.0) * 4.0;
		float ridge = aa_step(0.6, sin(phase) * 0.5 + 0.5);
		float fade = 1.0 - smoothstep(0.15, 0.45, fwidth(phase));
		ground = mix(ground, ground * vec3(0.84, 0.88, 0.96), ridge * fade * 0.7);
	} else if (pattern == 3) {
		// Cracked hardpan: dark crack lines on 6 m plates, pebbles between.
		vec2 cp = world_pos.xz / 6.0;
		float crack = 1.0 - aa_step(0.035, crack_distance(cp));
		ground = mix(ground, ground * 0.62, crack * detail_fade(cp * 12.0));
		vec2 pebble = clumps(world_pos.xz / 2.2, 0.35, 0.12);
		float fade = detail_fade(world_pos.xz / 0.3);
		ground = mix(ground, ground * 1.18, pebble.x * fade);
		ground = mix(ground, ground * 0.7, pebble.y * fade);
	} else if (pattern == 4) {
		// Grass: tufts with a lit top and a dark lower edge, a few flowers.
		vec2 tuft = clumps(world_pos.xz / 2.4, 0.6, 0.24);
		float fade = detail_fade(world_pos.xz / 0.7);
		ground = mix(ground, ground * vec3(1.2, 1.18, 0.9), tuft.x * fade);
		ground = mix(ground, ground * 0.6, tuft.y * fade);
		vec2 flower = clumps(world_pos.xz / 3.1 + 11.0, 0.12, 0.07);
		ground = mix(ground, vec3(0.95, 0.85, 0.45), flower.x * detail_fade(world_pos.xz / 0.15));
	} else if (pattern == 5) {
		// Basalt: dark cooled plates with thick seams.
		vec2 cp = world_pos.xz / 4.5;
		float seam = 1.0 - aa_step(0.05, crack_distance(cp));
		ground = mix(ground, ground * 0.45, seam * detail_fade(cp * 10.0));
	}
	// Bright lip along the top of every cliff edge.
	ground = mix(ground, ground * 1.22, lip);
	// Cliffs: flat rock with a few crisp strata lines, faded before they would shimmer.
	float y = world_pos.y / 9.0 + value_noise(world_pos.xz / 40.0) * 0.6;
	float strata_line = 1.0 - aa_step(0.06, abs(fract(y) - 0.5) * 2.0 - 0.88);
	strata_line *= 1.0 - smoothstep(0.08, 0.25, fwidth(y));
	float tone = mix(1.0, 0.9, step(0.5, fract(y * 0.5)));
	vec3 rock = rock_base * mix(1.0, tone, p.z * 0.6);
	rock = mix(rock, rock * 0.6, strata_line * p.z);
	return mix(ground, rock, rock_mix);
}

void fragment() {
	vec2 wuv = ((world_pos.xz - map_origin) / (cell_size * float(map_samples - 1)) * float(weight_samples - 1) + 0.5) / float(weight_samples);
	vec4 wa = texture(zone_weights_a, wuv);
	vec2 wb = texture(zone_weights_b, wuv).rg;
	float weights[6] = float[6](wa.r, wa.g, wa.b, wa.a, wb.r, wb.g);
	vec3 n = normalize(world_normal);
	float slope = 1.0 - n.y;
	float sw = max(fwidth(slope), 0.004);
	float rock_mix = clamp((slope - cliff_slope) / sw + 0.5, 0.0, 1.0);
	// Ink line where ground breaks into cliff, a lit lip just above it.
	float edge = 1.0 - smoothstep(sw * 0.8, sw * 1.8, abs(slope - cliff_slope));
	float lip = (1.0 - rock_mix) * (1.0 - smoothstep(0.0, 0.1, cliff_slope - slope)) * (1.0 - edge);
	vec3 col = vec3(0.0);
	vec3 glow = vec3(0.0);
	float total = 0.0;
	for (int i = 0; i < 6; i++) {
		if (weights[i] > 0.002) {
			vec3 zone_glow = vec3(0.0);
			col += weights[i] * zone_colour(i, world_pos.y, rock_mix, lip, zone_glow);
			glow += weights[i] * zone_glow;
			total += weights[i];
		}
	}
	col /= max(total, 0.001);
	// Silhouette ink on cliffs turning away from the camera.
	// Ink thins out with distance so the backdrop stays calm.
	float near = 1.0 - smoothstep(90.0, 260.0, length(VERTEX));
	float facing = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	float rim = (1.0 - smoothstep(0.12, 0.2, facing)) * rock_mix * near;
	vec3 ink = to_linear(ink_color.rgb);
	col = mix(col, ink, max(edge * mix(0.3, 0.85, near), rim * 0.7));
	ALBEDO = col;
	EMISSION = glow / max(total, 0.001);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

float band_ramp(float x) {
	float to_mid = smoothstep(shadow_threshold - band_softness, shadow_threshold + band_softness, x);
	float to_lit = smoothstep(highlight_threshold - band_softness, highlight_threshold + band_softness, x);
	return to_mid * mid_band_level + to_lit * (1.0 - mid_band_level);
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	vec3 light_in = LIGHT_COLOR / PI * sun_scale;
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = band_ramp(n_dot_l * ATTENUATION);
		DIFFUSE_LIGHT += light_in * mix(shadow_tint.rgb, vec3(1.0), lit);
	} else {
		DIFFUSE_LIGHT += light_in * band_ramp(n_dot_l) * ATTENUATION;
	}
}
