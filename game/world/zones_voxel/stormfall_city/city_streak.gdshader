shader_type spatial;
// Neon reflection streaks on the wet street (CityBlocks quads under each sign):
// additive, broken into rain-shivered bars, brightest near the facade.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

varying vec2 local_uv;
varying vec4 face;
varying vec4 base_col;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local_uv = UV2;
	face = CUSTOM0;
	base_col = COLOR;
}

void fragment() {
	vec2 q = clamp(local_uv / max(face.xy, vec2(0.001)), 0.0, 1.0);
	float across = clamp(1.0 - abs(q.x * 2.0 - 1.0), 0.0, 1.0);
	float along = q.y;
	float bars = step(0.35, hash(vec2(floor(local_uv.y / 0.088), face.w * 91.0)));
	float k = pow(across, 2.5) * (1.0 - along) * (1.0 - along) * (0.35 + 0.65 * bars);
	vec3 c = base_col.rgb;
	c = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
	ALBEDO = c * k * 0.22;
}
