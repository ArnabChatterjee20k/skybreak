// Soft aura sprites: round mote halos, converging ki streaks, the pulsing ki orb and the floor shock ring.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://game/view/shaders/vfx_noise.gdshaderinc"

// Per aura (each FighterAura owns a copy; GLES3 caps instance uniforms).
uniform vec4 tint : source_color = vec4(1.0, 0.62, 0.22, 1.0);
uniform float intensity : hint_range(0.0, 8.0) = 1.0;
// 0 round halo, 1 converging streak (along the particle's Y = velocity), 2 pulsing orb, 3 floor ring and glow.
uniform int spark_shape : hint_range(0, 3) = 0;
uniform float core_whiteness : hint_range(0.0, 1.0) = 0.5;
// 0 off to 1 fully on (orb and floor ring; particles fade by age).
uniform float strength : hint_range(0.0, 1.0) = 1.0;
// Pulses per second of the orb and the floor rings.
uniform float pulse_rate : hint_range(0.0, 8.0) = 1.6;
// Metres the sprite is pulled toward the camera, so an orb at the chest sits in front of the body.
uniform float depth_offset : hint_range(0.0, 1.0) = 0.0;
// HDR ceiling, so bloom never blows out.
uniform float max_hdr : hint_range(0.5, 4.0) = 1.6;

varying float age;
varying float seed;

// One shock ring at `phase` (0 born at the feet, 1 gone at the edge), broken up by `grain`.
float floor_ring(float r, float phase, float grain) {
	float radius = mix(0.12, 0.95, phase);
	float width = mix(0.025, 0.07, phase);
	float ring = 1.0 - smoothstep(0.0, width, abs(r - radius));
	return ring * (0.6 + 0.4 * grain) * (1.0 - phase) * (1.0 - phase);
}

void vertex() {
	age = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	seed = vfx_hash11(float(INSTANCE_ID) * 7.31 + INSTANCE_CUSTOM.x * 3.0);
	if (spark_shape != 3) {
		float sx = length(MODEL_MATRIX[0].xyz);
		float sy = length(MODEL_MATRIX[1].xyz);
		vec3 x_axis = INV_VIEW_MATRIX[0].xyz;
		vec3 y_axis = INV_VIEW_MATRIX[1].xyz;
		vec3 z_axis = INV_VIEW_MATRIX[2].xyz;
		if (spark_shape == 1) {
			vec3 along = MODEL_MATRIX[1].xyz / max(sy, 1e-5);
			vec3 side = cross(along, normalize(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz));
			if (length(side) > 1e-4) {
				y_axis = along;
				x_axis = normalize(side);
				z_axis = cross(x_axis, y_axis);
			}
		}
		vec3 centre = MODEL_MATRIX[3].xyz + normalize(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz) * depth_offset;
		mat4 world = mat4(vec4(x_axis * sx, 0.0), vec4(y_axis * sy, 0.0), vec4(z_axis, 0.0), vec4(centre, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * world;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float shape = 0.0;
	float core = 0.0;
	float life = 1.0;
	if (spark_shape == 0) {
		// Round falloff: no square edge anywhere on the quad.
		float d = length(p);
		shape = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
		core = pow(clamp(1.0 - d * 2.5, 0.0, 1.0), 2.0);
		life = sin(age * PI);
	} else if (spark_shape == 1) {
		// A soft capsule, brighter at its head (the end nearer the gather point).
		float along = max(abs(p.y) - 0.15, 0.0) / 0.85;
		float d = length(vec2(p.x, along));
		shape = pow(clamp(1.0 - d, 0.0, 1.0), 1.6) * mix(0.35, 1.0, smoothstep(1.0, -0.6, p.y));
		core = pow(clamp(1.0 - length(vec2(p.x * 2.5, along)), 0.0, 1.0), 2.0);
		life = smoothstep(0.0, 0.25, age) * (1.0 - smoothstep(0.7, 1.0, age));
	} else if (spark_shape == 2) {
		// Glow orb: a white core in a soft halo that breathes.
		float pulse = 0.85 + 0.15 * sin(TIME * TAU * pulse_rate);
		float d = length(p) / pulse;
		shape = pow(clamp(1.0 - d, 0.0, 1.0), 2.4);
		float ripple = 0.5 + 0.5 * sin(atan(p.y, p.x) * 5.0 + TIME * 7.0);
		shape *= 0.85 + 0.15 * ripple;
		core = pow(clamp(1.0 - d * 2.6, 0.0, 1.0), 1.5);
		life = strength;
	} else {
		// Floor: two shock rings running outward plus a soft breathing glow pool under the feet.
		float r = length(p);
		float ang = atan(p.y, p.x);
		float crackle = floor(TIME * 12.0);
		float rings = floor_ring(r, fract(TIME * pulse_rate), vfx_noise1(ang * 6.0 + crackle))
			+ floor_ring(r, fract(TIME * pulse_rate + 0.5), vfx_noise1(ang * 6.0 + 9.0 + crackle));
		float pool = pow(clamp(1.0 - r / 0.55, 0.0, 1.0), 2.0) * (0.75 + 0.25 * sin(TIME * TAU * pulse_rate * 2.0));
		shape = rings + 0.45 * pool;
		core = rings * 0.4;
		life = strength;
	}
	vec3 hot = mix(tint.rgb * COLOR.rgb, vec3(1.0), clamp(core * core_whiteness, 0.0, 1.0));
	ALBEDO = max(min(hot * shape * life * intensity, vec3(max_hdr)), vec3(0.0));
}
