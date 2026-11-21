shader_type spatial;
// Shattered Mesa floor and treads: smooth triangles on the sim's 2 m grid, with
// the look per T1 voxel: macro colour (1 m texture: sand, dunes, washes,
// caprock, talus shade) times per-cell noise, wind ripples, pebbles and mud
// cracks in washes. Skirts (UV.y = 1) under tread edges: a caprock band on
// high treads, then the strata.
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://game/world/zones_voxel/shattered_mesa/mesa_strata.gdshaderinc"

uniform sampler2D macro_tex : filter_linear, source_color;
uniform vec2 macro_origin;
uniform vec2 macro_size;
uniform float cell = 0.088;
uniform float floor_gain = 0.64;
uniform vec3 pebble : source_color = vec3(0.6, 0.45, 0.37);
uniform vec3 crack : source_color = vec3(0.62, 0.52, 0.42);

varying vec3 world_pos;
varying vec3 world_n;
varying vec2 skirt;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	skirt = UV;
}

vec2 v_point(vec2 cell_id) {
	return cell_id + vec2(s_hash(ivec3(ivec2(cell_id), 31)), s_hash(ivec3(ivec2(cell_id), 37))) * 0.8 + 0.1;
}

// Distance from p to the nearest Voronoi edge (F2 - F1), in cells.
float voronoi_edge(vec2 p) {
	vec2 b = floor(p);
	float f1 = 9.0;
	float f2 = 9.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			float d = length(v_point(b + vec2(float(i), float(j))) - p);
			if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
		}
	}
	return f2 - f1;
}

vec2 voronoi_id(vec2 p) {
	vec2 b = floor(p);
	float f1 = 9.0;
	vec2 id = b;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = b + vec2(float(i), float(j));
			float d = length(v_point(c) - p);
			if (d < f1) { f1 = d; id = c; }
		}
	}
	return id;
}

void fragment() {
	vec3 n = normalize(world_n);
	vec3 albedo;
	float ao = 1.0;
	if (skirt.y > 0.5) {
		vec3 p = world_pos - n * 0.175;
		float from_top = skirt.x - world_pos.y;
		ivec3 ci = ivec3(floor(p / 0.35));
		if (skirt.x > 30.0 && from_top < 1.4) {
			albedo = s_linear(caprock) * (0.92 + 0.16 * s_hash(ci));
			albedo *= 1.0 + 0.18 * (1.0 - smoothstep(0.0, 0.35, from_top));
		} else {
			albedo = strata_wall(p, n, 0.35) * (0.95 + 0.1 * s_hash(ci));
		}
		// Shade under the lip.
		albedo *= 1.0 - 0.3 * smoothstep(1.3, 1.6, from_top) * (1.0 - smoothstep(1.6, 2.6, from_top));
	} else {
		vec2 uv = (world_pos.xz - macro_origin) / macro_size;
		vec4 m = texture(macro_tex, uv);
		albedo = m.rgb * floor_gain;
		ivec2 c = ivec2(floor(world_pos.xz / cell));
		float h = s_hash(ivec3(c.x, 0, c.y));
		albedo *= 1.0 + (h * 2.0 - 1.0) * 0.03;
		float sandy = 1.0 - smoothstep(26.0, 32.0, world_pos.y);
		// Wind ripples: rows of cells across the wind, slightly lighter and darker.
		float r = dot(vec2(c), normalize(vec2(0.8, 0.6))) / 3.0;
		float rip = step(0.5, fract(r + 0.15 * sin(float(c.y) * 0.07)));
		albedo *= 1.0 + sandy * (1.0 - m.a) * (rip * 0.035 - 0.017);
		// Pebbles: lone darker cells, a few lighter.
		float pb = s_hash(ivec3(c.x, 5, c.y));
		if (pb < (0.006 + 0.03 * m.a) * sandy) {
			albedo = mix(albedo, s_linear(pebble) * (0.8 + 0.4 * h), 0.75);
		} else if (pb > 0.996) {
			albedo *= 1.1;
		}
		// Mud cracks in dry washes: cell edges of a jittered 0.8 m Voronoi (F2 - F1).
		if (m.a > 0.5) {
			float e = voronoi_edge((floor(world_pos.xz / cell) + 0.5) * cell / 0.8);
			if (e < 0.08) {
				albedo = mix(albedo, s_linear(crack), 0.4);
			} else {
				albedo *= 1.0 + 0.04 * s_hash(ivec3(ivec2(floor(world_pos.xz / 0.8)), 3));
			}
		}
		// Caprock on high treads: fractured into 2.5 m slabs with dark joints,
		// each slab its own tone.
		float hard = smoothstep(30.0, 34.0, world_pos.y);
		if (hard > 0.0) {
			vec2 q = (floor(world_pos.xz / cell) + 0.5) * cell / 2.5;
			float e2 = voronoi_edge(q);
			vec2 id = voronoi_id(q);
			float tone = s_hash(ivec3(ivec2(id * 7.0), 13));
			albedo *= mix(1.0, 0.9 + 0.2 * tone, hard);
			if (e2 < 0.035) {
				albedo *= mix(1.0, 0.62, hard);
			} else if (e2 < 0.07) {
				albedo *= mix(1.0, 1.08, hard);
			}
		}
		// Lichen spots on high caprock (the accent, rare).
		if (world_pos.y > 34.0 && s_hash(ivec3(c.x / 4, 9, c.y / 4)) < 0.008 && h < 0.3) {
			albedo = mix(albedo, s_linear(lichen), 0.6);
		}
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = albedo * ao;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
