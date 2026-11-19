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

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	float up = EYEDIR.y;
	vec3 col = mix(horizon_color.rgb, top_color.rgb, smoothstep(0.0, 0.45, up));
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
