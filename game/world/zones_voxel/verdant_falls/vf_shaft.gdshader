// God-ray card: a see-through stepped shaft of warm light, fading at both ends
// and toward the camera (the web fallback for screen-space light shafts).
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform vec3 light_color : source_color = vec3(1.0, 0.95, 0.82);
uniform float strength = 0.07;

void fragment() {
	float along = UV.y;
	float steps = floor(UV.x * 6.0) / 6.0;
	float across = 1.0 - abs(steps * 2.0 - 1.0 + 1.0 / 6.0);
	float ends = smoothstep(0.0, 0.25, along) * smoothstep(1.0, 0.6, along);
	float near = smoothstep(15.0, 45.0, -VERTEX.z);
	float facing = abs(dot(NORMAL, VIEW));
	ALBEDO = light_color * strength * across * ends * near * facing;
}
