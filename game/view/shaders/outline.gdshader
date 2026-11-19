// Inverted-hull ink outline, used as the next_pass of a toon material.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.06, 0.04, 0.1, 1.0);
// Width in pixels at 1080p; scales with the render height so resolution scale keeps the look.
uniform float outline_width : hint_range(0.0, 8.0) = 2.0;
// Beyond this camera distance (metres) the width shrinks, so far fighters aren't swamped in ink.
uniform float outline_fade_distance : hint_range(1.0, 200.0) = 25.0;
uniform float outline_min_width : hint_range(0.0, 4.0) = 0.75;
// Red vertex colour scales the width (0 = no outline, 1 = full). Off by default.
uniform bool use_vertex_color_mask = false;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	// Direction in pixel space, so the width is even on wide screens.
	vec2 dir_px = (PROJECTION_MATRIX * vec4(view_normal, 0.0)).xy * VIEWPORT_SIZE;
	dir_px /= max(length(dir_px), 1e-5);

	float depth = max(clip.w, 1e-3);
	float width_px = max(outline_width * min(1.0, outline_fade_distance / depth), outline_min_width);
	width_px = min(width_px, outline_width);
	if (use_vertex_color_mask) {
		width_px *= COLOR.r;
	}

	// Pixels -> NDC, then times w so the offset survives the perspective divide (constant on screen).
	float px_scale = VIEWPORT_SIZE.y / 1080.0;
	vec2 ndc_per_px = 2.0 / VIEWPORT_SIZE;
	clip.xy += dir_px * width_px * px_scale * ndc_per_px * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
