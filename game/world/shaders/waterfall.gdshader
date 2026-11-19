// Waterfall curtain: streaks scrolling down, white foam at the bottom.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

uniform vec4 water_color : source_color = vec4(0.75, 0.92, 1.0, 1.0);
uniform vec4 streak_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float speed = 0.9;
uniform float light_level = 1.0;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void fragment() {
	float column = floor(UV.x * 28.0);
	float offset = hash11(column);
	float streak = step(0.55, fract(UV.y * 3.0 - TIME * speed * (0.8 + offset * 0.5) + offset));
	vec3 col = mix(water_color.rgb, streak_color.rgb, streak * 0.7);
	col = mix(col, streak_color.rgb, smoothstep(0.85, 1.0, UV.y));
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	ALBEDO = col * light_level;
	ALPHA = edge * (0.8 + 0.2 * streak);
}
