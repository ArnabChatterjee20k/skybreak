// Soft dark disc under a fighter, with a team-colour rim when airborne; pulled toward the camera.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;

uniform vec4 shadow_color : source_color = vec4(0.08, 0.05, 0.14, 1.0);
// 0..1 darkness at the centre; the shadow node lowers it with height.
uniform float strength = 0.6;
uniform float lift = 0.25;
uniform vec4 ring_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
// 0..1 rim opacity; zero on the ground.
uniform float ring_strength = 0.0;

void vertex() {
	VERTEX = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX += normalize(-VERTEX) * lift;
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	// Solid core with a short soft edge, the toon way.
	float core = (1.0 - smoothstep(0.62, 1.0, r)) * strength;
	// Crisp rim just inside the edge.
	float ring = (smoothstep(0.80, 0.84, r) - smoothstep(0.95, 0.99, r)) * ring_strength;
	float a = max(core, ring);
	ALBEDO = mix(shadow_color.rgb, ring_color.rgb, ring / max(a, 0.0001));
	ALPHA = a;
}
