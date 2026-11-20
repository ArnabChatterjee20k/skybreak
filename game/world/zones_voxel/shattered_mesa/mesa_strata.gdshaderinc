// Shattered Mesa strata: 2.8 m bands of light salmon and dark rust sandstone
// (hashed per band, a few mid tones), cross-bedding lines, a dark seam at each
// band's foot, a lit lip at its top, desert varnish streaks running down from
// band tops, and chartreuse lichen on north (-Z) faces. All per T2 cell.
uniform float band = 2.8;
uniform vec3 band_light : source_color = vec3(0.784, 0.549, 0.439);
uniform vec3 band_dark : source_color = vec3(0.604, 0.329, 0.251);
uniform vec3 band_pale : source_color = vec3(0.835, 0.663, 0.553);
uniform vec3 caprock : source_color = vec3(0.431, 0.369, 0.329);
uniform vec3 varnish : source_color = vec3(0.29, 0.204, 0.157);
uniform vec3 lichen : source_color = vec3(0.706, 0.824, 0.235);

float s_hash(ivec3 c) {
	uint h = uint(c.x) * 73856093u ^ uint(c.y) * 19349663u ^ uint(c.z) * 83492791u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h & 65535u) / 65535.0;
}

vec3 s_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

// Wall colour (linear) at world position p (inside the face), normal n, cell size c.
vec3 strata_wall(vec3 p, vec3 n, float c) {
	ivec3 ci = ivec3(floor(p / c));
	float fy = p.y / band;
	int b = int(floor(fy));
	float k = s_hash(ivec3(b, 3, 17));
	vec3 tone = (b % 2 == 0) ? band_light : band_dark;
	if (k > 0.82) tone = band_pale;
	if (k < 0.12) tone = mix(band_dark, caprock, 0.35);
	tone = s_linear(tone) * (0.94 + 0.12 * s_hash(ivec3(b, 5, 23)));
	float along = abs(n.x) > 0.5 ? p.z : p.x;
	// Cross-bedding: thin sloping lines inside the band.
	float slope = (s_hash(ivec3(b, 7, 31)) - 0.5) * 0.5;
	float bed = fract((p.y + along * slope) / (c * 3.0));
	tone *= 1.0 - 0.07 * step(bed, 0.34) * step(0.5, s_hash(ivec3(b, 9, 41)));
	// Seam at the band foot, a lit lip at its top.
	float f = fract(fy);
	tone *= 1.0 - 0.32 * (1.0 - smoothstep(0.0, c * 1.2 / band, f));
	tone *= 1.0 + 0.12 * smoothstep(1.0 - c * 1.1 / band, 1.0, f);
	// Desert varnish: dark streaks down from a band top.
	int lane = int(floor(along / c));
	float v = s_hash(ivec3(lane, b, 51));
	float vlen = s_hash(ivec3(lane, b, 53));
	float from_top = (1.0 - f) * band;
	if (v < 0.16 && from_top < 1.0 + vlen * band * 1.6) {
		float fade = 1.0 - from_top / (1.0 + vlen * band * 1.6);
		tone = mix(tone, s_linear(varnish), 0.55 * fade);
	}
	// Lichen crusts on north faces, in clumps.
	if (n.z < -0.5) {
		ivec3 clump = ivec3(floor(p / (c * 4.0)));
		if (s_hash(clump + ivec3(0, 0, 61)) < 0.05 && s_hash(ci + ivec3(0, 0, 67)) < 0.55) {
			tone = s_linear(lichen) * (0.85 + 0.25 * s_hash(ci));
		}
	}
	return tone;
}
