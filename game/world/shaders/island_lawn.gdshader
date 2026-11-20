// Heartbloom island lawns: smooth dome light (no triangle-fan facets), crisp mown patches,
// grass tufts, blossom-petal drifts and a winding stepping-stone walk around each big island.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 petal_color : source_color = vec4(1.0, 0.7, 0.82, 1.0);
uniform vec4 petal_deep : source_color = vec4(0.93, 0.46, 0.66, 1.0);
uniform vec4 path_color : source_color = vec4(0.9, 0.8, 0.7, 1.0);
uniform vec4 path_edge : source_color = vec4(0.42, 0.3, 0.36, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.5, 0.52, 0.66, 1.0);
uniform float sun_scale = 0.5;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float rim_strength = 0.12;
// Island dome height over its radius (IslandField.DOME).
uniform float dome = 0.06;
// Islands at least this wide (m) get the stepping-stone walk.
uniform float path_min_radius = 14.0;

varying vec3 world_pos;
// Island centre (x, z), and (radius, phase); radius 0 marks the grass lip.
varying vec2 centre;
varying vec2 island;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	centre = UV;
	island = UV2;
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

float aa_step(float edge, float x) {
	float w = max(fwidth(x), 1e-4);
	return clamp((x - edge) / w + 0.5, 0.0, 1.0);
}

// 1 where detail of this cell size is big enough on screen not to shimmer.
float detail_fade(vec2 cells) {
	return 1.0 - smoothstep(0.08, 0.22, length(fwidth(cells)));
}

// Scattered round clumps: x = inside, y = darker lower rim.
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

void fragment() {
	vec3 col = COLOR.rgb;
	vec2 d = world_pos.xz - centre;
	if (island.x > 0.0) {
		// Analytic dome normal, so the light bands are round, not fan-shaped facets.
		vec3 n = normalize(vec3(2.0 * dome * d.x / island.x, 1.0, 2.0 * dome * d.y / island.x));
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
		// Large mown patches, two tones with crisp edges.
		float patches = aa_step(0.55, value_noise(world_pos.xz / 13.0 + island.y * 3.0));
		col *= mix(1.0, 0.9, patches);
		// Grass tufts.
		vec2 tuft = clumps(world_pos.xz / 2.2, 0.55, 0.22);
		float fade = detail_fade(world_pos.xz / 0.6);
		col = mix(col, col * vec3(1.16, 1.14, 0.92), tuft.x * fade);
		col = mix(col, col * 0.72, tuft.y * fade);
		// Blossom drifts: soft pink pools with scattered petals inside and around them.
		float drift = aa_step(0.64, value_noise(world_pos.xz / 5.5 + 31.0));
		col = mix(col, col * vec3(1.08, 0.96, 1.0), drift);
		vec2 petal = clumps(world_pos.xz / 0.9 + 5.0, mix(0.1, 0.75, drift), 0.2);
		float petal_fade = detail_fade(world_pos.xz / 0.25);
		vec3 petal_tint = mix(petal_color.rgb, petal_deep.rgb, step(0.5, hash12(floor(world_pos.xz / 1.1 + 5.0))));
		col = mix(col, petal_tint, petal.x * petal_fade);
		// Stepping-stone walk: a wobbly ring around big islands, stones on a gravel band.
		if (island.x >= path_min_radius) {
			float r = length(d);
			float a = atan(d.y, d.x);
			float ring = island.x * (0.6 + 0.06 * sin(2.0 * a + island.y * 2.0) + 0.03 * sin(5.0 * a + island.y));
			float off = abs(r - ring);
			float band = 1.0 - aa_step(1.5, off);
			float edge = (1.0 - aa_step(0.22, abs(off - 1.5))) * detail_fade(world_pos.xz / 0.5);
			vec2 stone = clumps(world_pos.xz / 1.5 + 2.0, 0.85, 0.34);
			vec3 gravel = mix(col, path_color.rgb * 0.82, 0.8);
			vec3 walk = mix(gravel, path_color.rgb, stone.x);
			walk = mix(walk, path_edge.rgb, stone.y * 0.6 * fade);
			col = mix(col, walk, band);
			col = mix(col, path_edge.rgb, edge * 0.7);
		}
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float facing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = rim_color.rgb * smoothstep(0.65, 0.75, facing) * rim_strength;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	vec3 light_in = LIGHT_COLOR / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		float x = n_dot_l * ATTENUATION;
		float lit = smoothstep(0.1, 0.14, x) * 0.8 + smoothstep(0.48, 0.52, x) * 0.2;
		DIFFUSE_LIGHT += light_in * sun_scale * mix(shadow_tint.rgb, vec3(1.0), lit);
	} else {
		DIFFUSE_LIGHT += light_in * smoothstep(0.1, 0.14, n_dot_l) * ATTENUATION;
	}
}
