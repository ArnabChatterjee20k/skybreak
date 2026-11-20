// Look prototype: additive soft light shaft card; turns to face the camera around its long axis.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://prototypes/look/shaders/look_noise.gdshaderinc"

uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.6, 0.25);
instance uniform float seed = 0.0;

void fragment() {
	float across = 1.0 - pow(abs(UV.x - 0.5) * 2.0, 1.5);
	float along = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.55, UV.y);
	float n = lk_noise(vec2(UV.x * 6.0 + seed, UV.y * 1.5));
	float fade = clamp(1.0 - abs(dot(NORMAL, VIEW)) * 0.0, 0.0, 1.0);
	ALBEDO = tint.rgb * across * along * (0.5 + 0.5 * n) * tint.a * fade;
}
