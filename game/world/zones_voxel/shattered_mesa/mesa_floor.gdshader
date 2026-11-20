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
uniform float floor_gain = 0.74;
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
		// Mud cracks in dry washes: polygon edges on a jittered 0.7 m grid.
		if (m.a > 0.5) {
			vec2 q = world_pos.xz / 0.7;
			vec2 qi = floor(q);
			vec2 f = fract(q) + (vec2(s_hash(ivec3(ivec2(qi), 1)), s_hash(ivec3(ivec2(qi), 2))) - 0.5) * 0.3;
			float e = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
			if (e < 0.09) {
				albedo = mix(albedo, s_linear(crack), 0.6);
			} else {
				albedo *= 1.04;
			}
		}
		// Lichen spots on high caprock (the accent, rare).
		if (world_pos.y > 34.0 && s_hash(ivec3(c.x / 4, 9, c.y / 4)) < 0.012 && h < 0.3) {
			albedo = mix(albedo, s_linear(lichen), 0.6);
		}
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = albedo * ao;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
