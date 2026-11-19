// Map boundary: a hex energy field that fades in as the camera nears it.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, fog_disabled;

uniform vec4 field_color : source_color = vec4(0.35, 0.8, 1.0, 1.0);
// Fully visible within fade_near metres of the camera, invisible past fade_far.
uniform float fade_near = 40.0;
uniform float fade_far = 260.0;
uniform float hex_size = 6.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hex_edge(vec2 p) {
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	return 0.5 - max(dot(q, normalize(vec2(1.0, 1.7320508))), q.x);
}

void fragment() {
	float d = distance(CAMERA_POSITION_WORLD, world_pos);
	float fade = smoothstep(fade_far, fade_near, d);
	vec2 plane = abs(world_pos.y) > 399.0 ? world_pos.xz : (abs(world_pos.x) > abs(world_pos.z) ? world_pos.zy : world_pos.xy);
	float edge = 1.0 - smoothstep(0.0, 0.06, hex_edge(plane / hex_size));
	float pulse = 0.6 + 0.4 * sin(TIME * 2.0 + world_pos.y * 0.05);
	ALBEDO = field_color.rgb * (0.08 + edge * pulse) * fade;
}
