// Look prototype: soft painted smoke / cloud card, camera-facing, for depth layers.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://prototypes/look/shaders/look_noise.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.6);
instance uniform float seed = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 c = UV - 0.5;
	float n = lk_fbm(UV * vec2(3.0, 2.0) + seed);
	float shape = 1.0 - smoothstep(0.15, 0.5, length(c * vec2(1.0, 1.4)) + (n - 0.5) * 0.45);
	float top = smoothstep(0.9, 0.2, UV.y);
	ALBEDO = tint.rgb * mix(0.8, 1.1, top);
	ALPHA = shape * tint.a * (0.6 + 0.4 * n);
}
