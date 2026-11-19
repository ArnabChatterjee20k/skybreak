// Camera-facing aura particle: a soft rising mote, or a brief lightning streak along its velocity.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://game/view/shaders/vfx_noise.gdshaderinc"

// Per fighter, set on the GPUParticles3D node.
instance uniform vec4 tint : source_color = vec4(1.0, 0.62, 0.22, 1.0);

uniform float intensity : hint_range(0.0, 8.0) = 1.5;
// 0 = round mote, 1 = jagged streak stretched along the particle's Y axis (align_y = velocity).
uniform int spark_shape : hint_range(0, 1) = 0;
uniform float core_whiteness : hint_range(0.0, 1.0) = 0.5;
// Sideways zig-zag of a streak, as a fraction of the quad width.
uniform float streak_jitter : hint_range(0.0, 0.5) = 0.25;
// Fraction of a streak's lifetime it is visible, so streaks read as sudden flashes.
uniform float streak_flash : hint_range(0.05, 1.0) = 0.15;

varying float age;
varying float seed;

void vertex() {
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
	mat4 world = mat4(vec4(x_axis * sx, 0.0), vec4(y_axis * sy, 0.0), vec4(z_axis, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	age = INSTANCE_CUSTOM.y;
	seed = vfx_hash11(float(INSTANCE_ID) * 7.31);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float shape;
	float core;
	float life;
	if (spark_shape == 1) {
		float zig = (vfx_noise1(p.y * 5.0 + seed * 40.0 + floor(TIME * 30.0)) - 0.5) * 2.0 * streak_jitter;
		float dx = abs(p.x - zig);
		shape = (1.0 - smoothstep(0.0, 0.3, dx)) * (1.0 - smoothstep(0.55, 1.0, abs(p.y)));
		core = 1.0 - smoothstep(0.0, 0.08, dx);
		life = 1.0 - smoothstep(0.0, streak_flash, age);
	} else {
		float d = length(p);
		shape = 1.0 - smoothstep(0.0, 1.0, d);
		shape *= shape;
		core = 1.0 - smoothstep(0.0, 0.3, d);
		life = sin(clamp(age, 0.0, 1.0) * PI);
	}
	vec3 hot = mix(tint.rgb * COLOR.rgb, vec3(1.0), core * core_whiteness);
	ALBEDO = hot * shape * life * intensity;
}
