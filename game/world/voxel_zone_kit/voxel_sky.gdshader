shader_type sky;
// Zone sky (VoxelStage): a gradient from top to horizon, a white cloud sea
// below the horizon, soft puff clouds in a band above it, and a sun disc with
// a warm halo (or a small moon at night).

uniform vec3 top_color : source_color = vec3(0.53, 0.68, 0.9);
uniform vec3 horizon_color : source_color = vec3(0.96, 0.89, 0.78);
uniform vec3 below_color : source_color = vec3(0.96, 0.95, 0.95);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.98, 0.96);
uniform vec3 cloud_shadow : source_color = vec3(0.78, 0.76, 0.86);
uniform float cloud_cover = 0.45;
uniform float sun_size = 0.03;
uniform float halo = 0.35;
uniform bool moon = false;
uniform float star_amount = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	float h = EYEDIR.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.5));
	// The cloud sea: white, with a soft lit rim at the horizon.
	col = mix(col, below_color, smoothstep(0.0, -0.06, h));
	// Puff clouds: a flat layer seen in perspective, thinning to the zenith.
	if (h > 0.0) {
		vec2 uv = EYEDIR.xz / (h + 0.08) * 1.6;
		float d = fbm(uv + vec2(3.1, 0.4));
		float puff = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.18, d);
		float base = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.45, fbm(uv * 1.3 + vec2(0.0, 0.07)));
		vec3 c = mix(cloud_shadow, cloud_color, base);
		float fade = smoothstep(0.0, 0.05, h) * (1.0 - smoothstep(0.35, 0.8, h));
		col = mix(col, c, puff * fade * 0.92);
	}
	if (star_amount > 0.0 && h > 0.0) {
		vec2 g = floor(EYEDIR.xz / (h + 0.3) * 260.0);
		col += vec3(step(0.9975, hash(g)) * star_amount * smoothstep(0.05, 0.4, h));
	}
	if (LIGHT0_ENABLED) {
		float d = distance(EYEDIR, LIGHT0_DIRECTION);
		if (moon) {
			col += vec3(0.9, 0.92, 1.0) * (1.0 - smoothstep(0.018, 0.022, d)) * 0.9;
			col += vec3(0.5, 0.55, 0.8) * exp(-d * 14.0) * 0.12;
		} else if (sun_size > 0.0) {
			col += LIGHT0_COLOR * (1.0 - smoothstep(sun_size * 0.75, sun_size, d)) * 1.8;
			col += LIGHT0_COLOR * exp(-d * 7.0) * halo;
		}
	}
	COLOR = col;
}
