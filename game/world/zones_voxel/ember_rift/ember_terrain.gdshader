shader_type spatial;
// Ember Rift terrain over a VoxelHeightfield (same bind() interface as the
// kit's voxel_terrain.gdshader): per-cell column colour with noise, bevels
// and step AO; walls pick ash lip, umber crust (banks), charcoal basalt with
// hashed joints, or an obsidian cap band by height; the colour's alpha is the
// baked lava bounce, emitted in amber scaled by bounce_energy (per preset).
// lava_mode turns the whole field into stepped glowing lava (the Breach fall).
render_mode diffuse_burley, specular_schlick_ggx;

uniform float cell = 0.088;
uniform vec2 field_origin;
uniform ivec2 field_size;
uniform sampler2D colour_tex : filter_nearest;
uniform sampler2D level_tex : filter_nearest;
uniform bool down = false;
uniform bool smooth_top = false;

uniform vec3 crust_color : source_color = vec3(0.29, 0.188, 0.157);
uniform vec3 crust_shadow : source_color = vec3(0.165, 0.102, 0.086);
uniform vec3 basalt_color : source_color = vec3(0.243, 0.227, 0.251);
uniform vec3 basalt_shadow : source_color = vec3(0.141, 0.129, 0.165);
uniform vec3 obsidian_color : source_color = vec3(0.165, 0.129, 0.157);
uniform vec3 obsidian_glint : source_color = vec3(0.478, 0.416, 0.471);
uniform vec3 bounce_color : source_color = vec3(1.0, 0.55, 0.2);
uniform float bank_top = 40.0;
uniform float cap_from = 128.0;
uniform float joint_metres = 1.3;
uniform float noise_amount = 0.05;
uniform float bevel_width = 0.18;
uniform float edge_lift = 0.22;
uniform float bevel_tilt = 0.5;
uniform float step_ao = 0.4;
uniform float roughness_value = 0.9;
uniform float bounce_energy = 0.0;
uniform bool lava_mode = false;
uniform float lava_glow = 1.0;
uniform float time_s = 0.0;

varying vec3 world_pos;
varying vec3 world_n;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash3(ivec3 c) {
	uint h = uint(c.x) * 73856093u ^ uint(c.y) * 19349663u ^ uint(c.z) * 83492791u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h & 65535u) / 65535.0;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

float level_of(ivec2 col) {
	if (col.x < 0 || col.y < 0 || col.x >= field_size.x || col.y >= field_size.y) {
		return down ? 1.0e6 : -1.0e6;
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
	int cy = int(floor(p.y / cell));
	vec4 texel = texelFetch(colour_tex, col, 0);
	float level = level_of(col);
	int noise_y = abs(n.y) > 0.5 ? int(level) : cy;
	float noise = hash3(ivec3(col.x, noise_y, col.y)) * 2.0 - 1.0;
	vec3 albedo;
	vec3 tilt = vec3(0.0);
	float edge = 0.0;
	float ao = 1.0;
	vec3 local = vec3(g.x - float(col.x), world_pos.y / cell - floor(p.y / cell), g.y - float(col.y));
	local = clamp(local, 0.0, 1.0);
	float glow_extra = 0.0;
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
		ao = 1.0 - step_ao * max(max(fx0, fx1), max(fz0, fz1));
		if (smooth_top) {
			edge = 0.0;
			tilt = vec3(0.0);
			ao = 1.0;
		}
		albedo = to_linear(texel.rgb);
	} else if (n.y < -0.5) {
		albedo = basalt_shadow * 0.5;
	} else {
		float from_top = (level * cell - world_pos.y) / cell;
		// Joints: per column (the merged run's cell along the wall) a hashed
		// course height, so stacked basalt reads as drums, not one extrusion.
		vec2 along = floor(vec2(p.x + p.z, 0.0) / (cell * 3.0));
		float course_h = joint_metres * (0.7 + 0.6 * hash3(ivec3(int(along.x), 0, 5)));
		float fy = (world_pos.y + hash3(ivec3(int(along.x), 1, 5)) * course_h) / course_h;
		float joint = 1.0 - smoothstep(0.0, 0.07, fract(fy));
		float band = hash3(ivec3(int(along.x), int(floor(fy)), 3));
		vec3 rock;
		if (world_pos.y < bank_top) {
			rock = mix(crust_shadow, crust_color, 0.45 + 0.55 * band);
			// Pinprick glow cracks low on the banks, right above the lava.
			float pin = step(0.985, hash3(ivec3(col.x, cy, col.y))) * (1.0 - smoothstep(31.0, 33.5, world_pos.y));
			glow_extra = pin;
		} else if (world_pos.y > cap_from) {
			rock = mix(obsidian_color, obsidian_color * 1.25, band);
			edge = max(edge, 0.0);
		} else {
			rock = mix(basalt_shadow, basalt_color, 0.4 + 0.6 * band);
		}
		rock *= 1.0 - joint * 0.45;
		vec3 lip = to_linear(texel.rgb) * 0.8;
		albedo = from_top < 1.0 ? lip : rock;
		edge = ramp(clamp(from_top, 0.0, 1.0));
		ao = mix(0.72, 1.0, clamp(1.0 - from_top / 14.0, 0.0, 1.0));
		tilt = vec3(0.0, 1.0, 0.0);
		if (world_pos.y > cap_from && from_top < 1.0) {
			albedo = mix(albedo, obsidian_glint * obsidian_glint, 0.5);
		}
	}
	albedo *= 1.0 + noise * noise_amount;
	albedo *= 1.0 + edge * edge_lift;
	vec3 nw = normalize(n + tilt * edge * bevel_tilt);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = roughness_value;
	SPECULAR = 0.25;
	float bounce = texel.a;
	if (lava_mode) {
		// Stepped molten cells: amber cores, darker crust flecks drifting down.
		float drift = hash3(ivec3(col.x, int(floor(world_pos.y / cell + time_s * 2.0)), col.y));
		vec3 hot = mix(vec3(0.91, 0.32, 0.05), vec3(1.0, 0.62, 0.18), drift);
		float crust = step(0.8, drift);
		ALBEDO = mix(hot * 0.2, crust_shadow, crust);
		EMISSION = hot * (1.0 - crust * 0.85) * lava_glow * (0.85 + 0.3 * edge);
	} else {
		ALBEDO = albedo * ao;
		AO = ao;
		AO_LIGHT_AFFECT = 0.3;
		EMISSION = albedo * bounce_color * (bounce * bounce * bounce_energy) + vec3(1.0, 0.55, 0.15) * glow_extra * lava_glow;
	}
}
