// Soft halo billboards around paper lanterns: invisible by day, warm at dusk and night.
// Stands in for real lights (the world has none besides the sun).
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.62, 0.32, 1.0);
uniform float strength = 1.1;
// 0 day, 1 night; driven by WorldAtmosphere.
uniform float night = 0.0;

void vertex() {
	// Face the camera, keeping the instance scale.
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
}

void fragment() {
	if (night < 0.01) {
		discard;
	}
	float r = length(UV - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.0, 1.0, r);
	vec3 tint = mix(glow_color.rgb, COLOR.rgb, 0.4);
	ALBEDO = tint * core * core * strength * night;
}
