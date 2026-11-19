// Opaque-looking, alpha-blended particles: landing dust puffs, rock debris and petals (T-D27).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://game/view/shaders/vfx_noise.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 0 dust puff, 1 rock chunk, 2 petal.
uniform int shape : hint_range(0, 2) = 0;
uniform float start_scale : hint_range(0.0, 8.0) = 0.6;
uniform float end_scale : hint_range(0.0, 8.0) = 1.4;
uniform float opacity : hint_range(0.0, 1.0) = 0.8;
// Darker toon edge on chunks and petals.
uniform float edge_shade : hint_range(0.0, 1.0) = 0.55;

varying float age;
varying float seed;

void vertex() {
	age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	float size = mix(start_scale, end_scale, 1.0 - pow(1.0 - age, 2.0));
	seed = vfx_hash11(float(INSTANCE_ID) * 1.37 + INSTANCE_CUSTOM.x * 13.0);
	float spin = seed * TAU + age * (seed - 0.5) * 12.0;
	vec3 x_axis = INV_VIEW_MATRIX[0].xyz;
	vec3 y_axis = INV_VIEW_MATRIX[1].xyz;
	vec3 rx = x_axis * cos(spin) + y_axis * sin(spin);
	vec3 ry = -x_axis * sin(spin) + y_axis * cos(spin);
	float s = length(MODEL_MATRIX[0].xyz) * size;
	mat4 world = mat4(vec4(rx * s, 0.0), vec4(ry * s, 0.0), vec4(INV_VIEW_MATRIX[2].xyz, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float alpha;
	float shade = 1.0;
	if (shape == 0) {
		float wobble = vfx_noise3(vec3(p * 3.0, seed * 9.0 + age * 2.0));
		alpha = 1.0 - smoothstep(0.45 + 0.35 * wobble, 0.95, r);
		shade = mix(1.0, 0.8, smoothstep(0.0, 0.9, p.y));
		alpha *= 1.0 - age;
	} else if (shape == 1) {
		// Five-sided chunk with a flat-shaded lower half.
		float ang = atan(p.y, p.x);
		float sides = 5.0;
		float poly = cos(PI / sides) / cos(mod(ang + seed * TAU, TAU / sides) - PI / sides);
		alpha = step(r, poly * 0.8);
		shade = step(0.0, p.y + p.x * 0.3) * (1.0 - edge_shade) + edge_shade;
		shade = mix(shade, 1.0, 0.25);
		alpha *= 1.0 - smoothstep(0.75, 1.0, age);
	} else {
		// Petal: a teardrop with a notch, darker toward the tip.
		vec2 q = vec2(p.x * 1.7, p.y);
		float drop = length(q + vec2(0.0, 0.25 * (1.0 - q.y)));
		float notch = 1.0 - smoothstep(0.0, 0.12, length(vec2(q.x * 1.5, q.y - 0.95)));
		alpha = step(drop, 0.8) * (1.0 - notch);
		shade = mix(1.0, 1.0 - edge_shade, smoothstep(-0.6, 0.8, -p.y));
		alpha *= 1.0 - smoothstep(0.7, 1.0, age);
	}
	ALBEDO = tint.rgb * COLOR.rgb * shade;
	ALPHA = clamp(alpha * opacity * tint.a, 0.0, 1.0);
}
