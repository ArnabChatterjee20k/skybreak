shader_type spatial;
// Shattered Mesa cliffs (a VoxelHeightfield of band-snapped rock columns): the
// kit terrain shader's per-cell look (bevel highlight on convex edges, step AO
// at concave feet, baked AO from colour_tex) with the zone's strata on walls
// and sand-dusted ledges on the setbacks.
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://game/world/zones_voxel/shattered_mesa/mesa_strata.gdshaderinc"

uniform float cell = 0.35;
uniform vec2 field_origin;
uniform ivec2 field_size;
uniform sampler2D colour_tex : filter_nearest;
uniform sampler2D level_tex : filter_nearest;
uniform bool down = false;
uniform bool smooth_top = false;
uniform vec3 ledge_sand : source_color = vec3(0.84, 0.74, 0.6);
uniform float noise_amount = 0.05;
uniform float bevel_width = 0.2;
uniform float edge_lift = 0.2;
uniform float bevel_tilt = 0.5;
uniform float step_ao = 0.35;

varying vec3 world_pos;
varying vec3 world_n;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float level_of(ivec2 col) {
	if (col.x < 0 || col.y < 0 || col.x >= field_size.x || col.y >= field_size.y) {
		return -1.0e6;
	}
	return texelFetch(level_tex, col, 0).r;
}

float ramp(float t) {
	return 1.0 - smoothstep(0.0, bevel_width, t);
}

void fragment() {
	vec3 n = normalize(world_n);
	vec3 p = world_pos - n * cell * 0.5;
	vec2 g = (p.xz - field_origin) / cell;
	ivec2 col = clamp(ivec2(floor(g)), ivec2(0), field_size - 1);
	vec4 texel = texelFetch(colour_tex, col, 0);
	float level = level_of(col);
	ivec3 ci = ivec3(floor(p / cell));
	float noise = s_hash(ci) * 2.0 - 1.0;
	vec3 local = clamp(vec3(g.x - float(col.x), 0.0, g.y - float(col.y)), 0.0, 1.0);
	vec3 albedo;
	vec3 tilt = vec3(0.0);
	float edge = 0.0;
	float ao = texel.r;
	if (n.y > 0.5) {
		float lx0 = level_of(col + ivec2(-1, 0));
		float lx1 = level_of(col + ivec2(1, 0));
		float lz0 = level_of(col + ivec2(0, -1));
		float lz1 = level_of(col + ivec2(0, 1));
		float ex0 = step(0.5, level - lx0) * ramp(local.x);
		float ex1 = step(0.5, level - lx1) * ramp(1.0 - local.x);
		float ez0 = step(0.5, level - lz0) * ramp(local.z);
		float ez1 = step(0.5, level - lz1) * ramp(1.0 - local.z);
		edge = max(max(ex0, ex1), max(ez0, ez1));
		tilt = vec3(ex1 - ex0, 0.0, ez1 - ez0);
		float fx0 = step(0.5, lx0 - level) * (1.0 - smoothstep(0.0, 0.6, local.x));
		float fx1 = step(0.5, lx1 - level) * (1.0 - smoothstep(0.0, 0.6, 1.0 - local.x));
		float fz0 = step(0.5, lz0 - level) * (1.0 - smoothstep(0.0, 0.6, local.z));
		float fz1 = step(0.5, lz1 - level) * (1.0 - smoothstep(0.0, 0.6, 1.0 - local.z));
		ao *= 1.0 - step_ao * max(max(fx0, fx1), max(fz0, fz1));
		// Ledges: the band's top colour dusted with blown sand.
		vec3 under = strata_wall(world_pos - vec3(0.0, cell * 0.5, 0.0), vec3(1.0, 0.0, 0.0), cell);
		float dust = 0.45 + 0.4 * s_hash(ci + ivec3(0, 0, 71));
		albedo = mix(under, s_linear(ledge_sand), dust);
	} else if (n.y < -0.5) {
		albedo = s_linear(caprock) * 0.5;
	} else {
		albedo = strata_wall(p, n, cell);
		float top_y = level * cell;
		float from_top = (top_y - world_pos.y) / cell;
		edge = ramp(clamp(from_top, 0.0, 1.0));
		tilt = vec3(0.0, 1.0, 0.0);
	}
	albedo *= 1.0 + noise * noise_amount;
	albedo *= 1.0 + edge * edge_lift;
	vec3 nw = normalize(n + tilt * edge * bevel_tilt);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALBEDO = albedo * ao;
	AO = ao;
	AO_LIGHT_AFFECT = 0.3;
	ROUGHNESS = 0.92;
	SPECULAR = 0.22;
}
