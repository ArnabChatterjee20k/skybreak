// Shared by the zone surface planes (lake, lava, cloud sea): terrain height and zone weight lookups.
uniform sampler2D heightmap : filter_nearest, repeat_disable;
uniform sampler2D zone_weights_a : filter_linear, repeat_disable;
uniform sampler2D zone_weights_b : filter_linear, repeat_disable;
uniform vec2 map_origin = vec2(-1024.0);
uniform float cell_size = 2.0;
uniform int map_samples = 1025;
uniform int weight_samples = 257;
// Index of the zone this plane belongs to; it fades out where that zone's weight drops.
uniform int zone_index = 0;
// Optional clip circle (x, z, radius) in world metres, e.g. lava only inside the crater.
uniform vec3 clip_circle = vec3(0.0, 0.0, 1.0e6);

bool outside_clip(vec2 xz) {
	return distance(xz, clip_circle.xy) > clip_circle.z;
}

float terrain_height(vec2 xz) {
	vec2 f = clamp((xz - map_origin) / cell_size, vec2(0.0), vec2(float(map_samples - 1)));
	ivec2 i = ivec2(floor(f));
	vec2 t = fract(f);
	float a = texelFetch(heightmap, i, 0).r;
	float b = texelFetch(heightmap, min(i + ivec2(1, 0), ivec2(map_samples - 1)), 0).r;
	float c = texelFetch(heightmap, min(i + ivec2(0, 1), ivec2(map_samples - 1)), 0).r;
	float d = texelFetch(heightmap, min(i + ivec2(1, 1), ivec2(map_samples - 1)), 0).r;
	return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
}

float zone_weight(vec2 xz) {
	vec2 uv = ((xz - map_origin) / (cell_size * float(map_samples - 1)) * float(weight_samples - 1) + 0.5) / float(weight_samples);
	vec4 a = texture(zone_weights_a, uv);
	vec4 b = texture(zone_weights_b, uv);
	float w[6] = float[6](a.r, a.g, a.b, a.a, b.r, b.g);
	return w[zone_index];
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}
