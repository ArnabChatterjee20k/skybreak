// Aura lightning: a thin jagged arc that crackles between two points on the body, re-rolled every flash.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://game/view/shaders/vfx_noise.gdshaderinc"

// Per aura (each FighterAura owns a copy; GLES3 caps instance uniforms).
uniform vec4 tint : source_color = vec4(1.0, 0.62, 0.22, 1.0);
uniform float intensity : hint_range(0.0, 8.0) = 1.6;
// Per arc, so arcs flash at different moments and places.
uniform float seed : hint_range(0.0, 100.0) = 0.0;
// 0 off to 1 fully on; also raises how often an arc is lit.
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// Flashes per second, and the share of flashes that light up at full strength.
uniform float rate : hint_range(0.5, 30.0) = 7.0;
uniform float duty : hint_range(0.0, 1.0) = 0.55;
// Body the arcs crawl over (metres, around the node origin): radius, half height, arc length.
uniform float body_radius : hint_range(0.05, 1.5) = 0.42;
uniform float body_half_height : hint_range(0.1, 2.0) = 0.85;
uniform float arc_length : hint_range(0.05, 2.0) = 0.55;
// Ribbon width in metres; the bright core is a quarter of it.
uniform float width : hint_range(0.002, 0.3) = 0.05;
uniform float max_hdr : hint_range(0.5, 4.0) = 2.0;

varying float lit;
varying float along;

vec3 on_body(float a, float h, float r) {
	return vec3(cos(a) * r, h, sin(a) * r);
}

void vertex() {
	float slot = floor(TIME * rate + seed * 3.7);
	float flash = fract(TIME * rate + seed * 3.7);
	float h1 = vfx_hash11(slot * 1.31 + seed * 17.0);
	float h2 = vfx_hash11(slot * 2.77 + seed * 29.0);
	float h3 = vfx_hash11(slot * 4.19 + seed * 41.0);
	float h4 = vfx_hash11(slot * 5.83 + seed * 53.0);
	float shown = step(h4, duty * strength);
	float angle = h1 * TAU;
	float y0 = mix(-0.75, 0.95, h2) * body_half_height;
	vec3 a = on_body(angle, y0, body_radius * (0.9 + 0.3 * h3));
	vec3 b = on_body(angle + (h3 - 0.5) * 1.8, y0 + (h2 - 0.35) * arc_length * 1.6, body_radius * (1.05 + 0.35 * h1));
	vec3 wa = (MODEL_MATRIX * vec4(a, 1.0)).xyz;
	vec3 wb = (MODEL_MATRIX * vec4(b, 1.0)).xyz;
	along = VERTEX.y;
	vec3 span = wb - wa;
	vec3 mid = mix(wa, wb, along);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - mid);
	vec3 side = cross(span, to_cam);
	side = length(side) > 1e-5 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	vec3 bend = normalize(cross(to_cam, side));
	// Jagged: two noise octaves re-rolled 30 times a second, pinned at both ends.
	float crackle = floor(TIME * 30.0);
	float pin = sin(along * PI);
	float jag = (vfx_noise1(along * 7.0 + crackle * 1.7 + seed * 11.0) - 0.5) * 0.5
		+ (vfx_noise1(along * 23.0 + crackle * 3.3 + seed * 5.0) - 0.5) * 0.2;
	float lift = (vfx_noise1(along * 5.0 + crackle * 2.1 + seed * 7.0) - 0.5) * 0.3;
	float len = length(span);
	vec3 world = mid + (side * jag + bend * lift) * len * pin;
	lit = shown * (1.0 - smoothstep(0.25, 0.85, flash));
	world += side * VERTEX.x * width * (0.4 + 0.6 * pin);
	MODELVIEW_MATRIX = VIEW_MATRIX;
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX);
	VERTEX = world;
	NORMAL = to_cam;
}

void fragment() {
	if (lit <= 0.001) {
		discard;
	}
	float d = abs(UV.x - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.0, 0.25, d);
	float glow = pow(1.0 - d, 2.0) * 0.45;
	vec3 hot = mix(tint.rgb, vec3(1.0), core * 0.85);
	ALBEDO = max(min(hot * (core + glow) * lit * intensity, vec3(max_hdr)), vec3(0.0));
}
