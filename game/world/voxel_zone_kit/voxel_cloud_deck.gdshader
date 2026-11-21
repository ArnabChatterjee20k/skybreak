shader_type spatial;
// The cloud sea's soft floor (VoxelStage): a flat deck with slow, large-scale
// billows in T3 cells, lit from above, so the islands float over white.
render_mode diffuse_burley, specular_disabled, shadows_disabled;

uniform vec3 top_color : source_color = vec3(1.0);
uniform vec3 shadow_color : source_color = vec3(0.8, 0.8, 0.88);
uniform float cell = 1.4;
uniform float drift = 0.4;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Snap to T3 cells so the deck shares the voxel grain.
	vec2 g = floor(world_pos.xz / cell) * cell + vec2(TIME * drift, 0.0);
	float n = noise(g * 0.012) * 0.6 + noise(g * 0.045) * 0.3 + noise(g * 0.16) * 0.1;
	ALBEDO = mix(shadow_color, top_color, smoothstep(0.25, 0.75, n));
	ROUGHNESS = 1.0;
}
