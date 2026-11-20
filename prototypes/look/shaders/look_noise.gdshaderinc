// Shared noise for the look prototypes.
float lk_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 lk_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float lk_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(lk_hash12(i), lk_hash12(i + vec2(1.0, 0.0)), u.x),
		mix(lk_hash12(i + vec2(0.0, 1.0)), lk_hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float lk_fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		s += a * lk_noise(p);
		p = r * p * 2.03 + 17.1;
		a *= 0.5;
	}
	return s;
}

// Directional streaks, like dry-brush strokes along `dir`.
float lk_strokes(vec2 p, vec2 dir, float len) {
	vec2 q = vec2(dot(p, dir), dot(p, vec2(-dir.y, dir.x)));
	return lk_noise(vec2(q.x / len, q.y * 0.9) + lk_noise(p * 0.2) * 1.5);
}

// Distance to the nearest Voronoi edge (cells).
float lk_cell_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 nearest = vec2(0.0);
	vec2 cell = vec2(0.0);
	float best = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 r = g + 0.15 + 0.7 * lk_hash22(i + g) - f;
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
			vec2 r = g + 0.15 + 0.7 * lk_hash22(i + g) - f;
			edge = min(edge, dot(0.5 * (nearest + r), normalize(r - nearest)));
		}
	}
	return edge;
}

vec3 lk_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
