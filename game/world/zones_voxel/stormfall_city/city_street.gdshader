shader_type spatial;
// Stormfall City's ground, painted per T1 cell (8.8 cm) from the 48 m block /
// 12 m street grid: wet asphalt with puddles, dashes, crossings and Split Bolt
// manhole covers; kerbs, gutters and paving slabs; stepped stone courses on the
// canal embankments and district retaining slopes; the canal's dark water with
// rain rings. The mesh follows the sim's heightmap exactly; all detail is colour.

uniform float cell = 0.088;
uniform float block = 48.0;
uniform float street_lo = 12.0;
uniform float street_hi = 24.0;
uniform vec2 zone_centre = vec2(-10.0, 480.0);
uniform float clock = 0.0;
uniform float wet = 1.0;

varying vec3 world_pos;
varying vec3 world_n;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

float hash3(ivec3 c) {
	uint h = uint(c.x) * 73856093u ^ uint(c.y) * 19349663u ^ uint(c.z) * 83492791u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h & 65535u) / 65535.0;
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash3(ivec3(ivec2(i), 1));
	float b = hash3(ivec3(ivec2(i + vec2(1, 0)), 1));
	float c = hash3(ivec3(ivec2(i + vec2(0, 1)), 1));
	float d = hash3(ivec3(ivec2(i + vec2(1, 1)), 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// The Split Bolt: a bolt splitting into two branches inside a hexagon, in a
// 0.8 m cover; q in -1..1.
float split_bolt(vec2 q) {
	vec2 a = abs(q);
	float hex = max(a.x * 0.866 + a.y * 0.5, a.y);
	float ring = step(0.78, hex) * step(hex, 0.92);
	float stem = step(abs(q.x - 0.35 * q.y - 0.05), 0.09) * step(-0.05, q.y) * step(q.y, 0.6);
	float b1 = step(abs(q.x + 0.6 * (q.y + 0.05) + 0.02), 0.08) * step(q.y, 0.0) * step(-0.6, q.y);
	float b2 = step(abs(q.x - 0.5 * (q.y + 0.05) - 0.06), 0.08) * step(q.y, 0.0) * step(-0.6, q.y);
	return max(ring, max(stem, max(b1, b2)));
}

void fragment() {
	vec3 n = normalize(world_n);
	vec3 p = world_pos;
	ivec2 cc = ivec2(floor(p.xz / cell));
	float noise = hash3(ivec3(cc, 3)) * 2.0 - 1.0;
	vec2 m = mod(p.xz, block);
	bool sx = m.x >= street_lo && m.x < street_hi;
	bool sz = m.y >= street_lo && m.y < street_hi;
	// Distance into the street from its nearest edge (m), per axis.
	float ex = sx ? min(m.x - street_lo, street_hi - m.x) : -min(abs(m.x - street_lo), abs(m.x - street_hi));
	float ez = sz ? min(m.y - street_lo, street_hi - m.y) : -min(abs(m.y - street_lo), abs(m.y - street_hi));
	vec3 col;
	float rough = 0.3;
	float spec = 0.55;
	float amount = 0.025;
	vec3 nrm = n;
	// Canal: centre line and distance (local z = 20 + 25 sin(0.012 lx)).
	float lx = p.x - zone_centre.x;
	float canal_z = zone_centre.y + 20.0 + 25.0 * sin(lx * 0.012);
	float dc = abs(p.z - canal_z);
	if (dc < 21.0 && p.y < 5.9 && n.y > 0.9) {
		// Canal water: blue-black mirror, rain rings, a slow current.
		vec2 wq = p.xz + vec2(clock * 0.35, 0.0);
		col = to_linear(vec3(0.07, 0.085, 0.1)) * (0.9 + 0.2 * vnoise(wq * 0.15));
		rough = 0.03;
		spec = 0.9;
		vec2 rc = floor(p.xz / 1.3);
		float ph = hash3(ivec3(ivec2(rc), 77));
		vec2 rp = (fract(p.xz / 1.3) - 0.5) * 1.3;
		float age = fract(clock * 0.9 + ph);
		float r = length(rp);
		float ring = exp(-pow((r - age * 0.6) * 22.0, 2.0)) * (1.0 - age);
		nrm = normalize(n + vec3(rp.x, 0.0, rp.y) * ring * 0.6);
		col *= 1.0 + ring * 0.4;
		amount = 0.0;
	} else if (n.y < 0.86) {
		// Steep: stone courses (35 cm), staggered blocks with dark mortar; the
		// canal walls darker and greener near the water line.
		float course = floor(p.y / 0.35);
		float along = (abs(n.x) > abs(n.z) ? p.z : p.x) / 0.7 + 0.5 * mod(course, 2.0);
		float joint = max(step(fract(p.y / 0.35), 0.13), step(fract(along), 0.07));
		float tone = hash3(ivec3(int(floor(along)), int(course), 9));
		bool canal = dc < 24.0;
		vec3 stone = canal ? vec3(0.36, 0.35, 0.33) : vec3(0.37, 0.38, 0.41);
		col = to_linear(stone) * (0.82 + 0.3 * tone);
		col = mix(col, to_linear(vec3(0.13, 0.13, 0.14)), joint * 0.8);
		if (canal) {
			col = mix(col, to_linear(vec3(0.16, 0.19, 0.15)), smoothstep(7.5, 5.0, p.y) * 0.7);
		}
		// Rust drips under the top edge.
		col *= 1.0 - 0.18 * step(0.9, hash3(ivec3(int(floor(along * 2.0)), 0, 5))) * smoothstep(13.0, 9.0, p.y);
		rough = 0.7;
		spec = 0.35;
		amount = 0.05;
	} else if (sx || sz) {
		// Asphalt.
		col = to_linear(vec3(0.165, 0.173, 0.204));
		float patchy = vnoise(p.xz * 0.08) * 0.6 + vnoise(p.xz * 0.31) * 0.4;
		col *= 0.88 + 0.22 * patchy;
		rough = 0.24;
		// Gutter: one dark cell row along each kerb.
		float edge = min(sx ? ex : 99.0, sz ? ez : 99.0);
		if (sx != sz && edge < cell * 2.0) {
			col *= 0.55;
			rough = 0.05;
		}
		// Centre dashes (3 m on, 3 m off) and crossings before each junction.
		float cx = abs(m.x - (street_lo + street_hi) * 0.5);
		float cz = abs(m.y - (street_lo + street_hi) * 0.5);
		vec3 paint = to_linear(vec3(0.62, 0.62, 0.58));
		float worn = step(0.35, vnoise(p.xz * 1.7));
		if (sx && !sz && cx < cell * 1.0 && mod(p.z, 6.0) < 3.0) { col = mix(col, paint, 0.75 * worn); }
		if (sz && !sx && cz < cell * 1.0 && mod(p.x, 6.0) < 3.0) { col = mix(col, paint, 0.75 * worn); }
		if (sx && !sz && ez > -3.2 && ez < -0.6 && mod(m.x, 1.2) < 0.6) { col = mix(col, paint, 0.6 * worn); }
		if (sz && !sx && ex > -3.2 && ex < -0.6 && mod(m.y, 1.2) < 0.6) { col = mix(col, paint, 0.6 * worn); }
		// Manhole cover with the Split Bolt, in each junction (T0 cells).
		if (sx && sz) {
			vec2 q = (vec2(m.x, m.y) - vec2(15.5, 20.5)) / 0.4;
			if (length(q) < 1.0) {
				vec2 qc = floor(q * 0.4 / 0.022) * 0.022 / 0.4;
				col = to_linear(vec3(0.2, 0.19, 0.18)) * (1.0 + 0.6 * split_bolt(qc));
				rough = 0.35;
			}
		}
		// Cracks: hashed runs of dark cells.
		float crack = step(0.985, hash3(ivec3(cc.x / 3, cc.y, 4))) * step(0.5, vnoise(p.xz * 0.2));
		col *= 1.0 - 0.4 * crack;
	} else {
		// Pavement: a 2.4 m ring of 60 cm slabs, a light kerb, plaza tiles inside.
		float into = min(min(abs(m.x - street_lo), abs(m.x - street_hi)), min(abs(m.y - street_lo), abs(m.y - street_hi)));
		bool kerb = into < cell * 2.5;
		float slab = into < 2.4 ? 0.6 : 1.2;
		vec2 sq = floor(p.xz / slab);
		float joint = max(step(fract(p.x / slab), cell / slab), step(fract(p.z / slab), cell / slab));
		float tone = hash3(ivec3(ivec2(sq), 11));
		col = to_linear(vec3(0.33, 0.34, 0.37)) * (0.86 + 0.22 * tone);
		col = mix(col, to_linear(vec3(0.16, 0.16, 0.18)), joint * 0.7);
		if (kerb) {
			col = to_linear(vec3(0.42, 0.43, 0.47)) * (0.95 + 0.1 * tone);
			rough = 0.4;
		} else {
			rough = 0.42;
		}
		// Litter and leaves: rare warm or pale cells.
		float h = hash3(ivec3(cc, 21));
		if (h > 0.996) { col = to_linear(vec3(0.5, 0.47, 0.42)); }
		amount = 0.03;
	}
	if (n.y > 0.86 && (dc >= 21.0 || p.y >= 5.9)) {
		// Puddles: big soft patches go black and mirror-like.
		float pud = vnoise(p.xz * 0.11 + 7.0) * 0.7 + vnoise(p.xz * 0.5) * 0.3;
		float k = smoothstep(0.6, 0.66, pud) * wet;
		col = mix(col, col * 0.45, k);
		rough = mix(rough, 0.03, k);
		spec = mix(spec, 0.9, k);
	}
	col *= 1.0 + noise * amount;
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
