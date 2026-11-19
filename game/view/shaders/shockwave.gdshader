// Expanding soft ring for heavy hits and clashes: additive, no screen or depth texture reads.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Per instance, set by ImpactEffect.play() and its animation.
instance uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.6, 1.0);
instance uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Per instance, set by ShockwaveEffect: lie in the node's XY plane instead of facing the camera.
instance uniform bool lie_flat = false;
// Per instance: world surface plane (xyz normal, w = normal · point) the ring fades into.
instance uniform vec4 surface_plane = vec4(0.0, 1.0, 0.0, 0.0);
// Per instance: metres above surface_plane over which the ring fades in; 0 = no surface fade.
instance uniform float surface_fade = 0.0;

// true faces the camera; false keeps the quad flat (rotate the node to the clash axis).
uniform bool billboard = true;
uniform float intensity : hint_range(0.0, 8.0) = 1.2;
// Ring thickness as a fraction of the quad's radius at the start; it thins as it grows.
uniform float ring_width : hint_range(0.01, 0.5) = 0.1;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.7;
uniform float start_radius : hint_range(0.0, 0.9) = 0.05;
// Faint fill inside the ring early on.
uniform float inner_glow : hint_range(0.0, 1.0) = 0.3;

varying vec3 world_pos;

void vertex() {
	if (billboard && !lie_flat) {
		mat4 world = mat4(
			vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
			vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
			vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
			MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * world;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
		world_pos = (world * vec4(VERTEX, 1.0)).xyz;
	} else {
		world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
}

void fragment() {
	float t = clamp(progress, 0.0, 1.0);
	float ease = 1.0 - pow(1.0 - t, 3.0);
	float r = length(UV * 2.0 - 1.0);
	float radius = mix(start_radius, 0.92, ease);
	float width = ring_width * (1.0 - 0.6 * ease) + 0.004;
	float hard_edge = width * (1.0 - edge_softness);
	float ring = 1.0 - smoothstep(hard_edge, width, abs(r - radius));
	float inner = inner_glow * (1.0 - smoothstep(0.0, radius + 1e-3, r)) * (1.0 - ease);
	float fade = pow(1.0 - t, 1.5) * (1.0 - step(1.0, r));
	// Soft fade toward the surface so the ground never cuts the ring with a straight edge.
	float height = dot(world_pos, surface_plane.xyz) - surface_plane.w;
	float ground = surface_fade > 0.0 ? smoothstep(0.0, surface_fade, height) : 1.0;
	ALBEDO = max(tint.rgb * (ring + inner) * fade * ground * intensity, vec3(0.0));
}
