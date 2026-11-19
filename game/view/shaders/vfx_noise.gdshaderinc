// Cheap texture-free hash and value noise shared by the VFX shaders.

float vfx_hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float vfx_hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vfx_hash31(vec3 p) {
	vec3 p3 = fract(p * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vfx_noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(vfx_hash11(i), vfx_hash11(i + 1.0), f);
}

float vfx_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = vfx_hash31(i);
	float b = vfx_hash31(i + vec3(1.0, 0.0, 0.0));
	float c = vfx_hash31(i + vec3(0.0, 1.0, 0.0));
	float d = vfx_hash31(i + vec3(1.0, 1.0, 0.0));
	float e = vfx_hash31(i + vec3(0.0, 0.0, 1.0));
	float g = vfx_hash31(i + vec3(1.0, 0.0, 1.0));
	float h = vfx_hash31(i + vec3(0.0, 1.0, 1.0));
	float k = vfx_hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

// Exactly 3 octaves, unrolled: the per-pixel noise budget.
float vfx_fbm3(vec3 p) {
	float n = 0.5 * vfx_noise3(p);
	n += 0.25 * vfx_noise3(p * 2.03 + vec3(17.1, 4.3, 9.7));
	n += 0.125 * vfx_noise3(p * 4.01 + vec3(31.7, 11.9, 2.1));
	return n / 0.875;
}
