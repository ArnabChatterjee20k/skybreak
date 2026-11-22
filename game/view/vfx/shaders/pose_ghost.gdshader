// Dash afterimage of a fighter's pose (PoseGhost): a faint additive fresnel rim in the energy colour.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.45;
// View depth (m) over which it fades in from the lens.
uniform vec2 near_fade = vec2(1.5, 4.5);

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float rim = pow(1.0 - facing, 2.0);
	float body = 0.12 + 0.88 * rim;
	ALBEDO = tint.rgb * body * alpha * smoothstep(near_fade.x, near_fade.y, -VERTEX.z);
}
