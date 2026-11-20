// World sky: two-colour gradient, sun disc and glow, stars at night. Colours come from WorldAtmosphere.
// Fogs its own horizon so it looks the same in Forward+ and Compatibility.
shader_type sky;
render_mode disable_fog;

uniform vec4 top_color : source_color = vec4(0.25, 0.45, 0.85, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.7, 0.8, 0.95, 1.0);
uniform vec4 ground_color : source_color = vec4(0.3, 0.3, 0.32, 1.0);
uniform vec4 fog_color : source_color = vec4(0.7, 0.8, 0.9, 1.0);
// How far up (EYEDIR.y) the haze reaches.
uniform float haze_height = 0.12;
uniform float star_amount : hint_range(0.0, 1.0) = 0.0;
// Painted cloud bands (ART_BIBLE §5): soft streaks in the lower sky, lit toward the sun.
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.55;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x);
	float b = mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x);
	float c = mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x);
	float d = mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

void sky() {
	float up = EYEDIR.y;
	// Three stops: a bright band just over the horizon, the horizon colour, then the zenith.
	vec3 mid = mix(horizon_color.rgb, top_color.rgb, 0.35);
	vec3 col = mix(horizon_color.rgb, mid, smoothstep(0.02, 0.3, up));
	col = mix(col, top_color.rgb, smoothstep(0.3, 0.9, up));
	col = mix(col, horizon_color.rgb * 1.08 + vec3(0.02), (1.0 - smoothstep(0.0, 0.06, abs(up - 0.02))) * 0.5);
	if (cloud_amount > 0.0 && up > -0.02) {
		// Flattened, wind-stretched value noise: long painted streaks, thinning toward the zenith.
		vec3 q = EYEDIR / max(up + 0.12, 0.05) * vec3(1.2, 1.0, 3.2);
		float n = noise3(q * 1.3) * 0.6 + noise3(q * 3.1 + 7.0) * 0.3 + noise3(q * 7.0 + 3.0) * 0.1;
		float band = smoothstep(0.0, 0.08, up) * (1.0 - smoothstep(0.25, 0.55, up));
		float cloud = smoothstep(0.52, 0.68, n) * band * cloud_amount;
		float lit = LIGHT0_ENABLED ? max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0) : 0.0;
		vec3 cloud_col = mix(mix(horizon_color.rgb, vec3(1.0), 0.55), LIGHT0_COLOR, 0.15 * lit);
		vec3 shade = mix(cloud_col, top_color.rgb, 0.35);
		col = mix(col, mix(shade, cloud_col, smoothstep(0.6, 0.8, n)), cloud * 0.8);
	}
	col = mix(col, fog_color.rgb, (1.0 - smoothstep(0.0, haze_height, abs(up))) * 0.75);
	col = mix(col, ground_color.rgb, smoothstep(0.0, -0.08, up));
	if (LIGHT0_ENABLED) {
		float d = dot(EYEDIR, LIGHT0_DIRECTION);
		col += LIGHT0_COLOR * smoothstep(0.9995, 0.9998, d) * 2.0;
		col += LIGHT0_COLOR * pow(max(d, 0.0), 24.0) * 0.25;
	}
	if (star_amount > 0.0 && up > 0.0) {
		vec3 cell = floor(EYEDIR * 220.0);
		float star = step(0.9965, hash13(cell));
		col += vec3(star * star_amount * smoothstep(0.0, 0.25, up));
	}
	COLOR = col;
}
