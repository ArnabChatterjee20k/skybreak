// Toon props (rocks, buildings, trees, ice): banded light, instance colour, optional rock
// strata and lit windows that glow at night.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float strata = 0.0;
uniform float strata_spacing = 4.0;
uniform float windows = 0.0;
uniform vec4 window_color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength = 0.0;
// 0 day, 1 night: windows light up.
uniform float night = 0.0;
uniform vec4 shadow_tint : source_color = vec4(0.45, 0.42, 0.6, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float rim_strength = 0.25;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 col = albedo_color.rgb * COLOR.rgb;
	if (strata > 0.0) {
		float band = step(0.5, fract(world_pos.y / strata_spacing));
		col *= mix(1.0, 0.8 + 0.2 * band, strata);
	}
	vec3 glow = emission_color.rgb * emission_strength;
	if (windows > 0.0 && abs(world_normal.y) < 0.3) {
		// Window grid on walls: 4 m floors, 3 m bays.
		float along = abs(world_normal.x) > abs(world_normal.z) ? world_pos.z : world_pos.x;
		vec2 cell = vec2(along / 3.0, world_pos.y / 4.0);
		vec2 f = fract(cell);
		float pane = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.75);
		float on = step(0.55, hash12(floor(cell) + floor(world_pos.xz / 40.0)));
		col = mix(col, col * 0.55, pane * windows);
		glow += window_color.rgb * pane * on * night * windows * 1.6;
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float facing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = glow + rim_color.rgb * smoothstep(0.65, 0.75, facing) * rim_strength;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	vec3 light_in = LIGHT_COLOR / PI;
	if (LIGHT_IS_DIRECTIONAL) {
		float x = n_dot_l * ATTENUATION;
		float lit = smoothstep(0.1, 0.14, x) * 0.62 + smoothstep(0.48, 0.52, x) * 0.38;
		DIFFUSE_LIGHT += light_in * mix(shadow_tint.rgb, vec3(1.0), lit);
	} else {
		DIFFUSE_LIGHT += light_in * smoothstep(0.1, 0.14, n_dot_l) * ATTENUATION;
	}
}
