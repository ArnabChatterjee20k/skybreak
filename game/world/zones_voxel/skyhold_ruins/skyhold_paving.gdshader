shader_type spatial;
// Skyhold Ruins paved island tops: the kit's voxel terrain shader plus a
// flagstone pass on the shown faces, evaluated per T1 cell (8.8 cm) in the
// island's frame: staggered rows of flags, a ring-paved central plaza, a
// marble stylobate band under the colonnade, 1-cell joints with moss, a
// per-flag tone and tilt. The column colour (T2) carries moss patches and AO.
// Voxel terrain (VoxelHeightfield): faces are merged strips, but every pixel
// finds its own cell from the world position, so the look stays per voxel:
// - the column colour (baked AO, painted detail) from colour_tex, with a
//   per-cell value noise;
// - a bevel highlight on convex cell edges (a lower neighbour) and a soft
//   shadow at the foot of a step (a higher neighbour), from level_tex;
// - walls: a grass lip on the top cell, then planar rock strata below.
// Undersides (down): strata slabs in two alternating rock tones with a dark
// seam at each slab's foot, darkening with depth into the clouds.
render_mode diffuse_burley, specular_schlick_ggx;

uniform float cell = 0.088;
uniform vec2 field_origin;
uniform ivec2 field_size;
uniform sampler2D colour_tex : filter_nearest;
uniform sampler2D level_tex : filter_nearest;
uniform bool down = false;
uniform bool smooth_top = false;
uniform vec3 soil_color : source_color = vec3(0.36, 0.27, 0.21);
uniform float crack_amount = 0.6;

uniform vec3 rock_color : source_color = vec3(0.79, 0.6, 0.56);
uniform vec3 rock_shadow : source_color = vec3(0.54, 0.38, 0.36);
uniform vec3 under_color : source_color = vec3(0.6, 0.56, 0.52);
uniform vec3 under_alt : source_color = vec3(0.5, 0.44, 0.39);
uniform vec3 under_deep : source_color = vec3(0.26, 0.21, 0.24);
uniform float under_top = 285.0;
uniform float under_depth = 74.0;
uniform float strata_cells = 3.0;
uniform float noise_amount = 0.05;
uniform float bevel_width = 0.18;
uniform float edge_lift = 0.22;
uniform float bevel_tilt = 0.5;
uniform float step_ao = 0.35;
uniform float roughness_value = 0.9;

uniform bool paving = false;
uniform vec2 isle_centre;
uniform float isle_yaw = 0.0;
uniform float isle_radius = 30.0;
uniform float pave_cell = 0.088;
uniform vec3 joint_color : source_color = vec3(0.45, 0.38, 0.3);
uniform vec3 joint_moss : source_color = vec3(0.48, 0.54, 0.35);
uniform vec3 marble_color : source_color = vec3(0.9, 0.86, 0.78);

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

// Rock strata at height y: slabs of strata_cells cells alternate between two
// tones (hashed per slab), a dark seam at each slab's foot, deeper rock darker.
vec3 strata(float y, float seam) {
	float slab_h = cell * strata_cells;
	float fy = y / slab_h;
	int slab = int(floor(fy));
	float k = hash3(ivec3(slab, 0, 7));
	vec3 tone = mix(under_color, under_alt, step(0.5, k)) * (0.92 + 0.16 * hash3(ivec3(slab, 1, 9)));
	float depth = clamp((under_top - y) / under_depth, 0.0, 1.0);
	tone = mix(tone, under_deep, pow(depth, 1.3) * 0.85);
	float foot = 1.0 - smoothstep(0.0, 0.12, fract(fy));
	return tone * (1.0 - 0.3 * foot * seam);
}

// Flag pattern at a T1 cell centre: x = flag id hash, y = joint (0/1),
// z = marble band (0/1), w = flag tilt hash.
vec4 flag_at(vec2 w) {
	vec2 q = w - isle_centre;
	float cs = cos(isle_yaw);
	float sn = sin(isle_yaw);
	vec2 l = vec2(q.x * cs - q.y * sn, q.x * sn + q.y * cs);
	float r = length(q);
	float j = pave_cell;
	float plaza = max(isle_radius * 0.24, 5.0);
	float band = abs(r - isle_radius * 0.72);
	if (r < plaza) {
		float ring_w = 1.1;
		float ring = floor(r / ring_w);
		float segs = max(6.0, floor(ring * 6.5));
		float a = (atan(q.y, q.x) + 3.14159265) / 6.2831853 * segs + ring * 0.37;
		float joint = step(fract(r / ring_w) * ring_w, j) + step(fract(a) * (6.2831853 * max(r, 0.5) / segs), j);
		return vec4(hash3(ivec3(int(ring), int(floor(a)), 5)), min(joint, 1.0), step(ring, 0.5), hash3(ivec3(int(ring), int(floor(a)), 6)));
	}
	if (abs(r - plaza) < 0.42) {
		return vec4(0.5, step(abs(r - plaza), j * 0.5), 1.0, 0.5);
	}
	if (band < 1.9) {
		// Stylobate band: long marble slabs along the ring.
		float a = (atan(q.y, q.x) + 3.14159265) * isle_radius * 0.72 / 1.9;
		float joint = step(fract(a) * 1.9, j) + step(abs(band - 1.9), j * 0.8);
		return vec4(hash3(ivec3(int(floor(a)), 3, 7)), min(joint, 1.0), 1.0, hash3(ivec3(int(floor(a)), 4, 7)));
	}
	// Rows run along the voxel grid (world x), so joints stay straight cells.
	float row_h = 0.968;
	float row = floor(w.y / row_h);
	float flag_w = 1.232 + 0.528 * floor(hash3(ivec3(int(row), 0, 9)) * 3.0) / 2.0;
	float u = w.x / flag_w + hash3(ivec3(int(row), 1, 9)) * 3.0;
	float joint = step(fract(w.y / row_h) * row_h, j * 0.99) + step(fract(u) * flag_w, j * 0.99);
	return vec4(hash3(ivec3(int(row), int(floor(u)), 11)), min(joint, 1.0), 0.0, hash3(ivec3(int(row), int(floor(u)), 12)));
}

float ramp(float t) {
	return 1.0 - smoothstep(0.0, bevel_width, t);
}

void fragment() {
	vec3 n = normalize(world_n);
	// A point just inside the face picks the cell the face belongs to.
	vec3 p = world_pos - n * cell * 0.5;
	vec2 g = (p.xz - field_origin) / cell;
	ivec2 col = clamp(ivec2(floor(g)), ivec2(0), field_size - 1);
	int cy = int(floor(p.y / cell));
	vec4 texel = texelFetch(colour_tex, col, 0);
	float level = level_of(col);
	// Shown faces hash their column's level, not the pixel's height: on a
	// smooth top the height crosses cell boundaries and would draw contour rings.
	int noise_y = abs(n.y) > 0.5 ? int(level) : cy;
	float noise = hash3(ivec3(col.x, noise_y, col.y)) * 2.0 - 1.0;
	vec3 albedo;
	vec3 tilt = vec3(0.0);
	float edge = 0.0;
	float ao = 1.0;
	// Position inside the cell, 0..1 on each axis.
	vec3 local = vec3(g.x - float(col.x), world_pos.y / cell - floor(p.y / cell), g.y - float(col.y));
	local = clamp(local, 0.0, 1.0);
	float sgn = down ? -1.0 : 1.0;
	if (n.y * sgn > 0.5) {
		// Shown face (lawn top, or underside bottom).
		float lx0 = level_of(col + ivec2(-1, 0));
		float lx1 = level_of(col + ivec2(1, 0));
		float lz0 = level_of(col + ivec2(0, -1));
		float lz1 = level_of(col + ivec2(0, 1));
		// Convex: the neighbour drops away (lower top / higher bottom).
		float ex0 = step(0.5, (level - lx0) * sgn) * ramp(local.x);
		float ex1 = step(0.5, (level - lx1) * sgn) * ramp(1.0 - local.x);
		float ez0 = step(0.5, (level - lz0) * sgn) * ramp(local.z);
		float ez1 = step(0.5, (level - lz1) * sgn) * ramp(1.0 - local.z);
		edge = max(max(ex0, ex1), max(ez0, ez1));
		tilt = vec3(ex1 - ex0, 0.0, ez1 - ez0);
		// Concave: a step rises beside this cell: shade its foot.
		float fx0 = step(0.5, (lx0 - level) * sgn) * (1.0 - smoothstep(0.0, 0.6, local.x));
		float fx1 = step(0.5, (lx1 - level) * sgn) * (1.0 - smoothstep(0.0, 0.6, 1.0 - local.x));
		float fz0 = step(0.5, (lz0 - level) * sgn) * (1.0 - smoothstep(0.0, 0.6, local.z));
		float fz1 = step(0.5, (lz1 - level) * sgn) * (1.0 - smoothstep(0.0, 0.6, 1.0 - local.z));
		ao = 1.0 - step_ao * max(max(fx0, fx1), max(fz0, fz1));
		if (smooth_top && !down) {
			edge = 0.0;
			tilt = vec3(0.0);
			ao = 1.0;
		}
		if (down) {
			albedo = strata(world_pos.y + cell * 0.5, 0.0);
		} else if (paving) {
			// One flag colour per T1 cell (the voxel look), from the pattern.
			vec2 fc = (floor(world_pos.xz / pave_cell) + 0.5) * pave_cell;
			vec4 f = flag_at(fc);
			vec3 base = to_linear(texel.rgb);
			vec3 stone = mix(base, base * marble_color / max(to_linear(vec3(0.8, 0.75, 0.64)), vec3(0.01)), f.z);
			stone *= 0.9 + 0.2 * f.x;
			stone = mix(stone, stone * vec3(1.02, 1.0, 0.95), step(0.8, f.x));
			ivec2 pc = ivec2(floor(world_pos.xz / pave_cell));
			float h = hash3(ivec3(pc.x, 17, pc.y));
			float moss_k = texel.a;
			vec3 joint = mix(joint_color, joint_moss, step(0.55 - moss_k * 0.5, h));
			float far_k = 1.0 - smoothstep(25.0, 110.0, length(world_pos - CAMERA_POSITION_WORLD));
			albedo = mix(stone, mix(stone * 0.8, joint * (0.85 + 0.3 * h), far_k), f.y);
			// Wild cells in the joints: tiny white and butter flowers.
			if (f.y > 0.5 && h > 0.985 - moss_k * 0.03) {
				albedo = h > 0.993 ? vec3(0.83, 0.8, 0.72) : vec3(0.78, 0.69, 0.32);
			}
			noise = hash3(ivec3(pc.x, int(level), pc.y)) * 2.0 - 1.0;
			// Each flag tilts a hair, so the sun picks out the paving.
			tilt = vec3(f.w - 0.5, 0.0, fract(f.w * 7.13) - 0.5) * (1.0 - f.y);
			edge = 0.12;
		} else {
			albedo = to_linear(texel.rgb);
		}
	} else if (n.y * sgn < -0.5) {
		// The hidden face never shows; if it does, keep it dark.
		albedo = under_deep;
	} else {
		// A wall. Lawn: the top cell is the grass lip, below it rock strata.
		float from_top = (level * cell - world_pos.y) * sgn / cell;
		float band = hash3(ivec3(0, int(floor(world_pos.y / (cell * strata_cells))), 3));
		// Vertical cracks: runs of cells in a hashed column that go dark.
		vec2 run = floor(vec2(p.x + p.z, p.y) / (cell * vec2(1.0, 6.0)));
		float crack = step(1.0 - 0.06 * crack_amount, hash3(ivec3(int(run.x), int(run.y), 11)));
		if (down) {
			albedo = strata(world_pos.y, 1.0);
			albedo *= 1.0 - crack * 0.45;
			// The step's lower edge (the convex one) catches light.
			edge = ramp(clamp(-from_top, 0.0, 1.0));
		} else {
			vec3 grass = to_linear(texel.rgb) * 0.82;
			vec3 rock = mix(rock_shadow, rock_color, 0.5 + 0.5 * band) * (1.0 - crack * 0.4);
			// Grass lip, then a dark soil band with roots, then stone strata.
			float soil_cells = 0.6 / cell;
			albedo = from_top < 1.0 ? grass : (from_top < soil_cells ? soil_color * (0.85 + 0.3 * band) : rock);
			edge = ramp(clamp(from_top, 0.0, 1.0));
			ao = mix(0.8, 1.0, clamp(1.0 - from_top / 18.0, 0.0, 1.0));
		}
		tilt = vec3(0.0, sgn, 0.0);
	}
	albedo *= 1.0 + noise * noise_amount;
	albedo *= 1.0 + edge * edge_lift;
	vec3 nw = normalize(n + tilt * edge * bevel_tilt);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALBEDO = albedo * ao;
	AO = ao;
	AO_LIGHT_AFFECT = 0.3;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.25;
}
