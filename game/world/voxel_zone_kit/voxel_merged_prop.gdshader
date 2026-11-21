shader_type spatial;
// voxel_figure.gdshader for greedy-merged static props (VoxelFaceMerge): each
// pixel finds its voxel face in the merged quad and reads that face's corner
// colours, corner AO and edge flags from the face texture, then shades exactly
// like the per-face mesh (same triangle split for colour, bilinear AO, bevels).
render_mode diffuse_burley, specular_schlick_ggx;

uniform float roughness_value : hint_range(0.0, 1.0) = 0.8;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float specular_value : hint_range(0.0, 1.0) = 0.4;
uniform float bevel_width : hint_range(0.0, 0.5) = 0.16;
uniform float bevel_tilt : hint_range(0.0, 2.0) = 0.7;
uniform float edge_lift : hint_range(0.0, 1.0) = 0.12;
uniform float corner_ao : hint_range(0.0, 1.0) = 0.85;
uniform float emission_value = 0.0;
uniform sampler2D faces : filter_nearest, repeat_disable;

varying flat vec4 rect;

const float AO_LEVELS[4] = float[](0.42, 0.62, 0.82, 1.0);

void vertex() {
	rect = CUSTOM0;
}

float ramp(float t) {
	return 1.0 - smoothstep(0.0, bevel_width, t);
}

vec4 texel(int i, int width) {
	return texelFetch(faces, ivec2(i % width, i / width), 0);
}

void fragment() {
	vec2 wh = rect.yz;
	vec2 cell = clamp(floor(UV), vec2(0.0), wh - 1.0);
	vec2 f = clamp(UV - cell, vec2(0.0), vec2(1.0));
	int width = textureSize(faces, 0).x;
	int first = (int(rect.x) + int(cell.y) * int(wh.x) + int(cell.x)) * 4;
	vec4 t0 = texel(first, width);
	vec4 t1 = texel(first + 1, width);
	vec4 t2 = texel(first + 2, width);
	vec4 t3 = texel(first + 3, width);
	ivec4 code = ivec4(round(vec4(t0.a, t1.a, t2.a, t3.a) * 255.0));
	vec4 corner_ao_values = vec4(AO_LEVELS[code.x & 3], AO_LEVELS[code.y & 3], AO_LEVELS[code.z & 3],
		AO_LEVELS[code.w & 3]);
	vec4 flags = vec4((code >> ivec4(2)) & ivec4(1));
	// The face's two triangles (corners 0-2-1 and 0-3-2), interpolated as the mesh did.
	vec3 c = f.x >= f.y ? t0.rgb + f.x * (t1.rgb - t0.rgb) + f.y * (t2.rgb - t1.rgb)
		: t0.rgb + f.y * (t3.rgb - t0.rgb) + f.x * (t2.rgb - t3.rgb);
	float ao = clamp(mix(mix(corner_ao_values.x, corner_ao_values.y, f.x),
		mix(corner_ao_values.w, corner_ao_values.z, f.x), f.y), 0.0, 1.0);
	float u0 = flags.x * ramp(f.x);
	float u1 = flags.y * ramp(1.0 - f.x);
	float v0 = flags.z * ramp(f.y);
	float v1 = flags.w * ramp(1.0 - f.y);
	float edge = max(max(u0, u1), max(v0, v1));
	vec3 base_n = normalize(NORMAL);
	vec3 tilt = TANGENT * (u1 - u0) + BINORMAL * (v1 - v0);
	vec3 n = base_n + tilt * bevel_tilt;
	n = dot(n, n) > 1e-6 ? normalize(n) : base_n;
	// Keep the tilted normal facing the viewer (no specular fireflies).
	n = normalize(n + VIEW * max(0.0, 0.08 - dot(n, VIEW)));
	NORMAL = n;
	c = clamp(c, vec3(0.0), vec3(1.0));
	vec3 base = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
	vec3 albedo = base * (1.0 + edge * edge_lift);
	ALBEDO = albedo * mix(1.0, ao, corner_ao * 0.5);
	AO = mix(1.0, ao, corner_ao);
	AO_LIGHT_AFFECT = 0.25;
	ROUGHNESS = clamp(roughness_value + edge * 0.08, 0.05, 1.0);
	METALLIC = metallic_value;
	SPECULAR = specular_value;
	EMISSION = base * emission_value;
}
