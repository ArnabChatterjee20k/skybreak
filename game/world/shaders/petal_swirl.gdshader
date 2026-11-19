// Petal whirlwind: petals orbit and rise inside a unit column (radius 1, height 1)
// that each instance transform scales and places. Pure vertex animation, no particles.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded, shadows_disabled;

uniform vec4 petal_color : source_color = vec4(1.0, 0.72, 0.84, 1.0);
uniform float petal_size = 0.45;
uniform float spin = 1.4;
uniform float rise = 0.11;
uniform float light_level = 1.0;

varying float fade;
varying vec3 tint;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void vertex() {
	float id = float(INSTANCE_ID);
	float h0 = hash11(id + 0.5);
	float t = fract(TIME * rise * (0.7 + 0.6 * hash11(id + 11.0)) + h0);
	float angle = TIME * spin * (0.8 + 0.5 * hash11(id + 23.0)) + h0 * 6.2832 + t * 7.0;
	float radius = mix(0.3, 1.0, t) * (0.75 + 0.25 * hash11(id + 37.0));
	vec3 centre = vec3(cos(angle) * radius, t, sin(angle) * radius);
	vec3 view_centre = (MODELVIEW_MATRIX * vec4(centre, 1.0)).xyz;
	float a = TIME * 3.0 + h0 * 6.2832;
	vec2 corner = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy;
	view_centre.xy += corner * petal_size;
	POSITION = PROJECTION_MATRIX * vec4(view_centre, 1.0);
	fade = smoothstep(0.0, 0.12, t) * smoothstep(1.0, 0.8, t);
	tint = mix(petal_color.rgb, vec3(1.0), hash11(id + 51.0) * 0.6);
}

void fragment() {
	// Petal shape: a pointed ellipse.
	vec2 p = (UV - 0.5) * 2.0;
	float shape = p.x * p.x * 2.2 + abs(p.y) * 1.1 + p.y * p.y * 0.4;
	if (shape > fade) {
		discard;
	}
	ALBEDO = tint * light_level;
}
