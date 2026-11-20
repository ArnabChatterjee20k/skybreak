// Soft dark disc on the ground under a fighter; pulled toward the camera so it never sinks.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform vec4 shadow_color : source_color = vec4(0.08, 0.05, 0.14, 1.0);
// 0..1 darkness at the centre; the shadow node lowers it with height.
uniform float strength = 0.6;
uniform float lift = 0.25;

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += normalize(-VERTEX) * lift;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	// Solid core with a short soft edge, the toon way.
	float a = 1.0 - smoothstep(0.62, 1.0, r);
	ALBEDO = shadow_color.rgb;
	ALPHA = a * strength;
}
