// Shared body of the additive energy VFX shaders (T-D27): one shader, many looks picked by `shape`.
#include "res://game/view/shaders/vfx_noise.gdshaderinc"

// Per effect layer, set by VfxEffect on its own copy of the material (GLES3 caps per-instance shader variables).
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// 0 glow orb, 1 ring, 2 anime spike burst, 3 streak, 4 smear arc, 5 fresnel shell,
// 6 beam body, 7 lightning bolt, 8 sparkle star.
uniform int shape : hint_range(0, 8) = 0;
// Faces the camera (sprites, particles); off for real meshes (arcs, shells, beams).
uniform bool billboard = true;
uniform bool use_particle_age = false;
uniform bool align_to_velocity = false;
uniform float intensity : hint_range(0.0, 8.0) = 1.5;
uniform float core_whiteness : hint_range(0.0, 1.0) = 0.6;
uniform float start_scale : hint_range(0.0, 8.0) = 1.0;
uniform float end_scale : hint_range(0.0, 16.0) = 1.0;
uniform float fade_power : hint_range(0.0, 6.0) = 1.5;
// Share of the life spent fading in.
uniform float fade_in : hint_range(0.0, 0.9) = 0.0;
// >1 finishes this layer before the effect ends.
uniform float pace : hint_range(0.25, 8.0) = 1.0;
uniform float ray_count : hint_range(3.0, 48.0) = 12.0;
uniform float scroll_speed : hint_range(-20.0, 20.0) = 3.0;
uniform float edge_width : hint_range(0.0, 1.0) = 0.15;
// Fresnel shells: rim falloff, and drawing only the far half so the shell stays behind what it surrounds.
uniform float rim_power : hint_range(1.0, 8.0) = 2.0;
uniform bool back_faces_only = false;
// Ignores the tint and uses this colour instead (sky-tinted pops, sparkles).
uniform bool fixed_color = false;
uniform vec4 own_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying float age;
varying float seed;

void vertex() {
	float t = use_particle_age ? INSTANCE_CUSTOM.y : progress;
	age = clamp(t * pace, 0.0, 1.0);
	float ease = 1.0 - pow(1.0 - age, 3.0);
	float size = mix(start_scale, end_scale, ease);
	seed = vfx_hash21(MODEL_MATRIX[3].xz * 3.7 + MODEL_MATRIX[3].y * 1.3 + float(INSTANCE_ID) * 1.13);
	if (billboard) {
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
	} else {
		VERTEX *= size;
	}
	if (shape == 6) {
		// Beam root tapers out of the hands over its first metres, so the caster stays visible.
		float metres = VERTEX.y * length(MODEL_MATRIX[1].xyz);
		VERTEX.xz *= mix(0.3, 1.0, smoothstep(0.0, 2.2, metres));
	}
}

void fragment() {
	if (back_faces_only && FRONT_FACING) {
		discard;
	}
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float fade = pow(1.0 - age, fade_power);
	if (fade_in > 0.0) {
		fade *= smoothstep(0.0, fade_in, age);
	}
	float alpha = 0.0;
	float core = 0.0;
	if (shape == 0) {
		alpha = 1.0 - smoothstep(0.0, 1.0, r);
		alpha *= alpha;
		core = 1.0 - smoothstep(0.0, 0.45, r);
	} else if (shape == 1) {
		float width = edge_width * (1.0 - 0.6 * age) + 0.006;
		alpha = 1.0 - smoothstep(0.0, width, abs(r - 0.82));
		core = alpha * alpha;
	} else if (shape == 2) {
		// Sharp manga spikes of random length, redrawn in steps like hand-drawn frames.
		float ang = (atan(p.y, p.x) / TAU + 0.5) * ray_count;
		float slot = floor(ang);
		float spike_len = 0.45 + 0.55 * vfx_hash11(slot * 7.31 + seed * 91.0);
		float half_width = 0.5 * (1.0 - r / spike_len);
		float spike = step(abs(fract(ang) - 0.5), half_width) * step(0.12, r);
		core = 1.0 - smoothstep(0.0, 0.25, r);
		alpha = max(spike, core);
		core = max(core, spike * (1.0 - smoothstep(0.0, 0.5, r)));
	} else if (shape == 3) {
		float dx = abs(p.x);
		alpha = (1.0 - smoothstep(0.0, 0.4, dx)) * (1.0 - smoothstep(0.15, 1.0, abs(p.y)));
		core = 1.0 - smoothstep(0.0, 0.12, dx);
	} else if (shape == 4) {
		// Swing smear: UV.x runs along the arc, UV.y from the inner to the outer edge.
		float head = clamp(age * 2.2, 0.0, 1.0);
		head = 1.0 - pow(1.0 - head, 2.0);
		float behind = head - UV.x;
		float tail = clamp(1.0 - behind / 0.85, 0.0, 1.0) * step(0.0, behind);
		float crescent = pow(UV.y, 1.6) * (1.0 - smoothstep(0.88, 1.0, UV.y));
		float streaks = 0.65 + 0.35 * vfx_hash11(floor(UV.y * 14.0) + seed * 13.0);
		alpha = tail * crescent * streaks;
		core = tail * tail * smoothstep(0.55, 0.9, UV.y);
		fade = 1.0 - smoothstep(0.45, 1.0, age);
	} else if (shape == 5) {
		float facing = abs(dot(NORMAL, VIEW));
		float rim = pow(1.0 - facing, rim_power);
		alpha = mix(rim, 1.0, edge_width) * (0.85 + 0.15 * vfx_noise1(UV.y * 20.0 + TIME * 12.0 + seed * 40.0));
		core = rim * rim;
	} else if (shape == 6) {
		// Beam body: a narrow white core where the cylinder faces the camera inside a wide
		// energy-coloured rim, with scrolling energy bands.
		float facing = abs(dot(NORMAL, VIEW));
		float bands = vfx_noise3(vec3(UV.x * 6.0, UV.y * 18.0 - TIME * scroll_speed, seed * 10.0));
		float ripples = 0.5 + 0.5 * sin(UV.y * 60.0 - TIME * scroll_speed * 6.0);
		alpha = smoothstep(0.0, 0.5, facing) * (0.55 + 0.3 * bands + 0.15 * ripples);
		// Fades right at the lens: an over-shoulder camera looks down the beam's length.
		alpha *= smoothstep(1.5, 4.5, length(VERTEX));
		core = smoothstep(0.86, 0.99, facing);
	} else if (shape == 7) {
		// Lightning: UV.y along the bolt, a jagged centre line that re-rolls 20 times a second.
		float frame = floor(TIME * 20.0) + seed * 37.0;
		float offset = (vfx_noise1(UV.y * 7.0 + frame * 3.1) - 0.5) * 0.55
			+ (vfx_noise1(UV.y * 31.0 + frame * 5.7) - 0.5) * 0.18;
		float d = abs(UV.x - 0.5 - offset);
		alpha = (1.0 - smoothstep(0.0, 0.07, d)) + 0.35 * (1.0 - smoothstep(0.0, 0.25, d));
		alpha *= step(vfx_hash11(frame), 0.8);
		core = 1.0 - smoothstep(0.0, 0.03, d);
	} else {
		// Four-point sparkle that twinkles.
		float twinkle = 0.6 + 0.4 * sin(TIME * 30.0 + seed * TAU);
		float arms = max((1.0 - smoothstep(0.0, 0.09, abs(p.x))) * (1.0 - abs(p.y)),
			(1.0 - smoothstep(0.0, 0.09, abs(p.y))) * (1.0 - abs(p.x)));
		core = 1.0 - smoothstep(0.0, 0.2, r);
		alpha = max(arms, core) * twinkle;
	}
	vec3 base = fixed_color ? own_color.rgb : tint.rgb;
	vec3 hot = mix(base * COLOR.rgb, vec3(1.0), clamp(core * core_whiteness, 0.0, 1.0));
	ALBEDO = max(hot * alpha * fade * intensity, vec3(0.0));
}
