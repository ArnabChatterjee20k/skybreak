// Toon terrain: lifts the shared chunk grid to the baked heightmap, colours by zone ramp,
// slope rock and strata, with posterized ground blotches so speed reads in flight.
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

// Per zone: low colour, high colour, cliff rock, (ramp low m, ramp high m, strata, pattern).
uniform vec4 zone_low[6];
uniform vec4 zone_high[6];
uniform vec4 zone_rock[6];
uniform vec4 zone_params[6];

uniform vec4 shadow_tint : source_color = vec4(0.45, 0.42, 0.6, 1.0);
uniform float shadow_threshold = 0.12;
uniform float highlight_threshold = 0.5;
uniform float mid_band_level = 0.62;
uniform float band_softness = 0.02;

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

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 zone_colour(int i, float h, float rock_mix, float blotch) {
	vec4 p = zone_params[i];
	float t = clamp((h - p.x) / max(p.y - p.x, 1.0), 0.0, 1.0);
	vec3 ground = mix(zone_low[i].rgb, zone_high[i].rgb, t);
	// Strata: horizontal bands on cliffs.
	float band = step(0.5, fract(world_pos.y / 6.0 + blotch * 0.35));
	vec3 rock = zone_rock[i].rgb * mix(1.0, 0.78 + 0.22 * band, p.z);
	vec3 col = mix(ground, rock, rock_mix);
	if (p.w > 1.5 && p.w < 2.5) {
		// Snow: wind-carved sastrugi ridges with blue-grey lee sides, faded out where
		// they would alias (far away) so the ground behind fighters stays calm.
		float phase = dot(world_pos.xz, vec2(0.83, 0.56)) / 2.6 + blotch * 7.0;
		float ridge = smoothstep(0.35, 0.95, sin(phase) * 0.5 + 0.5);
		float fade = 1.0 - smoothstep(0.15, 0.45, fwidth(phase));
		vec3 lee = col * vec3(0.8, 0.86, 0.97);
		col = mix(col, lee, ridge * fade * (1.0 - rock_mix) * 0.85);
		// Wind-scoured patches where older, greyer snow shows through.
		float scour = smoothstep(0.62, 0.7, value_noise(world_pos.xz / 23.0 + 3.1));
		col = mix(col, col * vec3(0.84, 0.87, 0.93), scour * (1.0 - rock_mix));
	} else if (p.w > 0.5) {
		// City: darker streets on a 48 m block grid.
		vec2 g = abs(fract((world_pos.xz + 6.0) / 48.0) - 0.5) * 48.0;
		float street = 1.0 - step(6.0, min(g.x, g.y));
		col = mix(col, col * 0.62, street * (1.0 - rock_mix));
	}
	return col;
}

void fragment() {
	vec2 wuv = ((world_pos.xz - map_origin) / (cell_size * float(map_samples - 1)) * float(weight_samples - 1) + 0.5) / float(weight_samples);
	vec4 wa = texture(zone_weights_a, wuv);
	vec2 wb = texture(zone_weights_b, wuv).rg;
	float weights[6] = float[6](wa.r, wa.g, wa.b, wa.a, wb.r, wb.g);
	vec3 n = normalize(world_normal);
	float slope = 1.0 - n.y;
	float rock_mix = smoothstep(0.22, 0.34, slope);
	// Posterized blotches at two scales.
	float blotch = value_noise(world_pos.xz / 9.0) * 0.6 + value_noise(world_pos.xz / 37.0) * 0.4;
	float poster = floor(blotch * 4.0) / 3.0;
	vec3 col = vec3(0.0);
	float total = 0.0;
	for (int i = 0; i < 6; i++) {
		if (weights[i] > 0.002) {
			col += weights[i] * zone_colour(i, world_pos.y, rock_mix, blotch);
			total += weights[i];
		}
	}
	col /= max(total, 0.001);
	col *= mix(0.88, 1.1, poster);
	ALBEDO = col;
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
	vec3 light_in = LIGHT_COLOR / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		float lit = band_ramp(n_dot_l * ATTENUATION);
		DIFFUSE_LIGHT += light_in * mix(shadow_tint.rgb, vec3(1.0), lit);
	} else {
		DIFFUSE_LIGHT += light_in * band_ramp(n_dot_l) * ATTENUATION;
	}
}
