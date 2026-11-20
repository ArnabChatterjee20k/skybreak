shader_type sky;
// Zone sky for the voxel look-dev: a gradient from the zone's sky_top to
// sky_horizon colours, the fog colour below the horizon (the cloud sea), and a
// large soft sun disc (dusk) or a small moon (night).

uniform vec3 top_color : source_color = vec3(0.6, 0.36, 0.68);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.6, 0.46);
uniform vec3 below_color : source_color = vec3(0.98, 0.66, 0.6);
uniform float sun_size = 0.035;
uniform bool moon = false;

void sky() {
	float h = EYEDIR.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	col = mix(col, below_color, smoothstep(0.0, -0.12, h));
	if (LIGHT0_ENABLED) {
		float d = distance(EYEDIR, LIGHT0_DIRECTION);
		if (moon) {
			col += vec3(0.9, 0.92, 1.0) * (1.0 - smoothstep(0.018, 0.022, d)) * 0.8;
		} else if (sun_size > 0.0) {
			// Soft disc plus a warm halo.
			col += LIGHT0_COLOR * (1.0 - smoothstep(sun_size * 0.7, sun_size, d)) * 1.6;
			col += LIGHT0_COLOR * exp(-d * 9.0) * 0.35;
		}
	}
	COLOR = col;
}
