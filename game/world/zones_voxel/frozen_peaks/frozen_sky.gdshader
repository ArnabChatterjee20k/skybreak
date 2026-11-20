shader_type sky;
// Frozen Peaks sky: the kit's sky (gradient, puff band, sun or moon) with a
// denser star field and the aurora: 2-3 folding curtains of voxel-stepped
// green light anchored over the Ice Crown. Same uniform names as the kit's
// voxel_sky, so VoxelStage drives it unchanged; the zone drives the aurora.

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
uniform float aurora_amount = 0.0;
uniform float aurora_time = 0.0;
// Azimuth (radians, atan2(z, x)) the aurora is centred on: the Ice Crown.
uniform float aurora_azimuth = -2.2;
uniform vec3 aurora_core : source_color = vec3(0.36, 0.88, 0.63);
uniform vec3 aurora_fade : source_color = vec3(0.16, 0.54, 0.44);

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

// One curtain: a ribbon whose foot folds slowly along the azimuth, with
// vertical rays. Azimuth and height are snapped to steps so the edges read
// as voxels, not gas.
float curtain(float az, float h, float seed, float t) {
	float a = floor(az * 160.0) / 160.0;
	float foot = 0.22 + 0.06 * seed + 0.07 * sin(a * 3.0 + t * 0.21 + seed * 4.0) + 0.04 * sin(a * 7.3 - t * 0.17 + seed);
	float hs = floor(h * 120.0) / 120.0;
	float above = hs - foot;
	// Bright lower hem, long soft fade upwards.
	float body = smoothstep(-0.012, 0.004, above) * exp(-max(above, 0.0) / (0.12 + 0.05 * seed));
	float rays = 0.55 + 0.45 * noise(vec2(a * 90.0 + seed * 13.0, t * 0.08));
	float fold = 0.6 + 0.4 * sin(a * 11.0 + t * 0.3 + seed * 2.0);
	return body * rays * fold;
}

void sky() {
	float h = EYEDIR.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.5));
	col = mix(col, below_color, smoothstep(0.0, -0.06, h));
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
		// Two layers: many faint 1-pixel stars, a few brighter ones.
		vec3 d = normalize(EYEDIR);
		vec2 g = floor(vec2(atan(d.z, d.x) * 900.0, asin(d.y) * 900.0));
		float s1 = step(0.992, hash(g));
		float s2 = step(0.9993, hash(g + vec2(17.0, 3.0)));
		float tw = 0.5 + 0.5 * hash(g + vec2(5.0, 9.0));
		col += vec3(0.85, 0.9, 1.0) * (s1 * 0.35 * tw + s2 * 1.1) * star_amount * smoothstep(0.02, 0.25, h);
	}
	if (aurora_amount > 0.0 && h > 0.0) {
		// Azimuth relative to the anchor, so atan's wrap sits opposite it (no seam).
		float az = mod(atan(EYEDIR.z, EYEDIR.x) - aurora_azimuth + PI, TAU) - PI;
		float da = abs(az);
		float spread = (1.0 - smoothstep(0.5, 1.5, da)) * smoothstep(0.02, 0.14, h);
		float a = curtain(az, h, 0.0, aurora_time) + 0.7 * curtain(az + 0.4, h, 1.0, aurora_time + 11.0)
			+ 0.45 * curtain(az - 0.3, h, 2.0, aurora_time + 23.0);
		float pulse = 0.85 + 0.15 * sin(aurora_time * 0.2);
		vec3 tint = mix(aurora_core, aurora_fade, smoothstep(0.24, 0.55, h));
		col += tint * clamp(a, 0.0, 1.4) * spread * aurora_amount * pulse;
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
