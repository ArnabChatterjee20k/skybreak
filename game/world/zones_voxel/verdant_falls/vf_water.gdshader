// Verdant Falls mirror lake: dark teal-green body, sky and falls mirrored
// analytically (no SSR), depth-faded over the shallow shelf, stepped ripples
// near the falls' foot.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled, unshaded;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 deep_color : source_color = vec3(0.165, 0.29, 0.282);
uniform vec3 shelf_color : source_color = vec3(0.55, 0.56, 0.44);
uniform vec3 sky_top : source_color = vec3(0.54, 0.69, 0.85);
uniform vec3 sky_horizon : source_color = vec3(0.91, 0.88, 0.78);
uniform vec3 cliff_color : source_color = vec3(0.13, 0.15, 0.14);
uniform vec3 falls_color : source_color = vec3(0.94, 0.96, 0.95);
uniform float light_level = 1.0;
uniform vec2 clip_centre;
uniform float clip_radius = 230.0;
// Falls: x centre, half width, z of the curtain, top height.
uniform vec4 falls = vec4(-660.0, 32.0, 300.0, 118.0);
uniform float cliff_z = 320.0;
uniform float cliff_top = 118.0;
uniform float t = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	if (distance(wpos.xz, clip_centre) > clip_radius) {
		discard;
	}
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float water_depth = max(0.0, -view.z - (-VERTEX.z));
	vec3 eye = normalize(wpos - CAMERA_POSITION_WORLD);
	// Stepped ripples: rings around the plunge pool, in 0.35 m cells.
	vec2 cellp = floor(wpos.xz / 0.35);
	float near_falls = smoothstep(90.0, 15.0, distance(wpos.xz, vec2(falls.x, falls.z + 8.0)));
	float ring = sin(distance(cellp * 0.35, vec2(falls.x, falls.z + 8.0)) * 1.3 - t * 3.0);
	vec3 n = normalize(vec3((hash2(cellp + floor(t * 4.0)) - 0.5) * 0.06 * near_falls + ring * 0.025 * near_falls,
		1.0, (hash2(cellp.yx + 3.1) - 0.5) * 0.02));
	vec3 r = reflect(eye, n);
	float up = clamp(r.y, 0.0, 1.0);
	vec3 refl = mix(sky_horizon, sky_top, pow(up, 0.6));
	// Mirror of the north cliff and the falls: intersect the reflected ray with
	// the cliff's plane, then the curtain.
	if (r.z < 0.0) {
		float d = (cliff_z - wpos.z) / r.z;
		vec3 hit = wpos + r * d;
		if (d > 0.0 && hit.y < cliff_top + 8.0 * sin(hit.x * 0.03)) {
			refl = cliff_color * (0.8 + 0.4 * hash2(floor(hit.xy / 1.4)));
			// The moss lip catches the light.
			refl = mix(refl, vec3(0.3, 0.42, 0.22), step(cliff_top - 4.0, hit.y) * 0.6);
		}
		float df = (falls.z - wpos.z) / r.z;
		vec3 hf = wpos + r * df;
		float halfw = falls.y * mix(1.2, 1.0, clamp(hf.y / falls.w, 0.0, 1.0));
		if (df > 0.0 && abs(hf.x - falls.x) < halfw && hf.y < falls.w && hash2(floor(wpos.xz / 0.7) + floor(t * 5.0)) < 0.75) {
			float col = floor((hf.x - falls.x) / 0.7);
			float streak = step(0.5, fract(hf.y / 6.0 + t * 0.9 + hash2(vec2(col, 1.0))));
			refl = mix(refl, mix(falls_color * 0.5, falls_color * 0.72, streak), 0.75 * smoothstep(230.0, 110.0, distance(wpos.xz, vec2(falls.x, falls.z))));
		}
	}
	float fres = 0.15 + 0.7 * pow(1.0 - clamp(-eye.y, 0.0, 1.0), 5.0);
	vec3 body = mix(shelf_color, deep_color, smoothstep(0.2, 3.5, water_depth));
	vec3 col = mix(body, refl, fres * 0.85);
	// Foam: a stepped white ring at the plunge pool and lines at the shore.
	float foam = smoothstep(42.0, 18.0, distance(wpos.xz, vec2(falls.x, falls.z + 6.0)));
	foam *= step(0.55, hash2(cellp + floor(t * 6.0)));
	foam = max(foam, step(water_depth, 0.12) * 0.7);
	col = mix(col, falls_color, foam * 0.8);
	ALBEDO = col * light_level;
	ALPHA = clamp(0.35 + water_depth * 0.45, 0.0, 0.97);
}
