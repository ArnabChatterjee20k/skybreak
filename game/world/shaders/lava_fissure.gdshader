// Lava fissure on the crater floor: a molten seam along the strip's length with ragged
// crust edges, a slow travelling flow and shimmer. Unshaded so it reads as a light source.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform vec4 core_color : source_color = vec4(0.95, 0.36, 0.06, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.72, 0.28, 1.0);
uniform vec4 crust_color : source_color = vec4(0.16, 0.06, 0.05, 1.0);
// 0 day .. 1 night: the seam glows brighter in the dark.
uniform float night = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float t = TIME;
	// 0 on the seam's centre line, 1 at the strip's long edges.
	float across = abs(UV.y - 0.5) * 2.0;
	float ragged = noise(world_pos.xz * 0.9) * 0.6 + noise(world_pos.xz * 3.1) * 0.4;
	float taper = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float width = (0.45 + 0.5 * ragged) * taper;
	if (across > width) {
		discard;
	}
	float core = 1.0 - across / max(width, 0.001);
	float flow = noise(vec2(world_pos.x + world_pos.z, t * 0.7) * 0.8 - vec2(t * 0.9, 0.0));
	float shimmer = 0.85 + 0.15 * sin(t * 2.3 + flow * 8.0);
	vec3 molten = mix(core_color.rgb, hot_color.rgb, core * core * (0.6 + 0.4 * flow)) * shimmer;
	ALBEDO = mix(crust_color.rgb, molten * (1.0 + night * 0.25), smoothstep(0.12, 0.42, core));
}
