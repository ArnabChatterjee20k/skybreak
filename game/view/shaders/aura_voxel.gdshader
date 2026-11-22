// Rising aura mote: a small glowing voxel cube that tumbles and shrinks away (its round halo is a second pass).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

#include "res://game/view/shaders/vfx_noise.gdshaderinc"

// Per aura (each FighterAura owns a copy; GLES3 caps instance uniforms).
uniform vec4 tint : source_color = vec4(1.0, 0.62, 0.22, 1.0);
uniform float intensity : hint_range(0.0, 8.0) = 1.2;
uniform float core_whiteness : hint_range(0.0, 1.0) = 0.6;
// Turns per second of the tumble.
uniform float spin : hint_range(0.0, 4.0) = 0.6;
uniform float max_hdr : hint_range(0.5, 4.0) = 1.8;

varying float age;
varying vec3 cube_pos;
varying float shade;

mat3 turn(vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	float k = 1.0 - c;
	return mat3(
		vec3(c + axis.x * axis.x * k, axis.y * axis.x * k + axis.z * s, axis.z * axis.x * k - axis.y * s),
		vec3(axis.x * axis.y * k - axis.z * s, c + axis.y * axis.y * k, axis.z * axis.y * k + axis.x * s),
		vec3(axis.x * axis.z * k + axis.y * s, axis.y * axis.z * k - axis.x * s, c + axis.z * axis.z * k));
}

void vertex() {
	age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	float seed = vfx_hash11(float(INSTANCE_ID) * 3.17 + INSTANCE_CUSTOM.x * 5.0);
	vec3 axis = normalize(vec3(seed - 0.5, 0.8, vfx_hash11(seed * 91.0) - 0.5));
	mat3 r = turn(axis, seed * TAU + TIME * TAU * spin * (0.6 + seed));
	cube_pos = VERTEX;
	float size = mix(1.0, 0.35, age * age) * smoothstep(0.0, 0.12, age);
	VERTEX = r * (VERTEX * size);
	vec3 n = r * NORMAL;
	NORMAL = n;
	// Faces toward the sky catch more glow, so the cube reads as a cube, not a dot.
	shade = 0.7 + 0.3 * n.y;
}

void fragment() {
	// Bright face centres, the energy colour toward the edges.
	vec3 a = abs(cube_pos) / max(max(abs(cube_pos.x), abs(cube_pos.y)), max(abs(cube_pos.z), 1e-4));
	float centre = 1.0 - smoothstep(0.35, 1.0, (a.x + a.y + a.z - 1.0) * 0.5);
	float life = 1.0 - smoothstep(0.6, 1.0, age);
	vec3 hot = mix(tint.rgb, vec3(1.0), clamp(core_whiteness * centre, 0.0, 1.0));
	ALBEDO = max(min(hot * shade * life * intensity, vec3(max_hdr)), vec3(0.0));
}
