// Additive camera-facing impact sprite: star burst, ring, flash, spark streak or shard.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

#include "res://game/view/shaders/vfx_noise.gdshaderinc"

// Per effect instance, set by ImpactEffect.play() and its animation.
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float progress : hint_range(0.0, 1.0) = 0.0;

// 0 star burst, 1 ring, 2 flash, 3 spark streak, 4 shard.
uniform int shape : hint_range(0, 4) = 0;
uniform float intensity : hint_range(0.0, 8.0) = 1.4;
uniform float core_whiteness : hint_range(0.0, 1.0) = 0.6;
// Size multiplier at the start and end of the animation (eased out).
uniform float start_scale : hint_range(0.0, 4.0) = 0.5;
uniform float end_scale : hint_range(0.0, 8.0) = 1.5;
uniform float fade_power : hint_range(0.25, 6.0) = 1.5;
// >1 finishes the sprite before the effect ends, e.g. a flash shorter than its ring.
uniform float pace : hint_range(0.25, 8.0) = 1.0;
uniform float ray_count : hint_range(3.0, 16.0) = 8.0;
uniform float ray_sharpness : hint_range(1.0, 32.0) = 8.0;
uniform float ring_width : hint_range(0.01, 0.5) = 0.12;
// Particles read their age from INSTANCE_CUSTOM.y; plain meshes use `progress`.
uniform bool use_particle_age = false;
// Stretch along the particle's Y axis (velocity with align_y) instead of facing the camera fully.
uniform bool align_to_velocity = false;

varying float age;
varying float seed;

void vertex() {
	float t = use_particle_age ? INSTANCE_CUSTOM.y : progress;
	age = clamp(t * pace, 0.0, 1.0);
	float ease = 1.0 - pow(1.0 - age, 3.0);
	float size = mix(start_scale, end_scale, ease);
	float sx = length(MODEL_MATRIX[0].xyz) * size;
	float sy = length(MODEL_MATRIX[1].xyz) * size;
	vec3 x_axis = INV_VIEW_MATRIX[0].xyz;
	vec3 y_axis = INV_VIEW_MATRIX[1].xyz;
	vec3 z_axis = INV_VIEW_MATRIX[2].xyz;
	if (align_to_velocity) {
		vec3 along = normalize(MODEL_MATRIX[1].xyz);
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
	seed = vfx_hash21(MODEL_MATRIX[3].xz * 3.7 + float(INSTANCE_ID) * 1.13);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float fade = pow(1.0 - age, fade_power);
	float alpha;
	float core;
	if (shape == 0) {
		float ang = atan(p.y, p.x) + seed * TAU;
		float rays = pow(abs(cos(ang * ray_count * 0.5)), ray_sharpness);
		float ray_index = floor(ang * ray_count / TAU + 0.5);
		float ray_len = 0.55 + 0.45 * vfx_hash11(ray_index + seed * 97.0);
		core = 1.0 - smoothstep(0.0, 0.22, r);
		alpha = max(rays * (1.0 - smoothstep(0.0, ray_len, r)), core);
	} else if (shape == 1) {
		float width = ring_width * (1.0 - 0.6 * age) + 0.005;
		float ring = 1.0 - smoothstep(0.0, width, abs(r - 0.8));
		core = ring * ring;
		alpha = ring;
	} else if (shape == 2) {
		alpha = 1.0 - smoothstep(0.0, 1.0, r);
		alpha *= alpha;
		core = 1.0 - smoothstep(0.0, 0.4, r);
	} else if (shape == 3) {
		float dx = abs(p.x);
		alpha = (1.0 - smoothstep(0.0, 0.35, dx)) * (1.0 - smoothstep(0.2, 1.0, abs(p.y)));
		core = 1.0 - smoothstep(0.0, 0.1, dx);
	} else {
		// Tumbling diamond shard: width wobbles to fake rotation, bright edges.
		float tumble = 0.25 + 0.75 * abs(sin(TIME * 14.0 + seed * TAU));
		float half_width = (1.0 - abs(p.y)) * 0.7 * tumble;
		float inside = half_width - abs(p.x);
		alpha = step(0.0, inside) * (0.35 + 0.65 * (1.0 - smoothstep(0.0, 0.12, inside)));
		core = alpha * (1.0 - smoothstep(0.0, 0.5, abs(p.y)));
	}
	vec3 hot = mix(tint.rgb * COLOR.rgb, vec3(1.0), clamp(core * core_whiteness, 0.0, 1.0));
	// Never negative: additive layers only brighten.
	ALBEDO = max(hot * alpha * fade * intensity, vec3(0.0));
}
