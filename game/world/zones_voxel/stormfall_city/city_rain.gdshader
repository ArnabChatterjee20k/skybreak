shader_type spatial;
// Rain streaks: thin camera-facing quads stretched along their fall, faint,
// thinning out close to the camera.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

void vertex() {
	// Billboard around the particle's own vertical axis.
	vec3 up = normalize(MODEL_MATRIX[1].xyz);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz);
	vec3 side = normalize(cross(up, to_cam));
	vec3 world = MODEL_MATRIX[3].xyz + side * VERTEX.x + vec3(0.18, -1.0, 0.1) * -VERTEX.y;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float d = length(VERTEX);
	float near_fade = smoothstep(2.0, 6.0, d);
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = vec3(0.55, 0.6, 0.7) * 0.08 * near_fade * edge * (1.0 - UV.y * 0.5);
}
