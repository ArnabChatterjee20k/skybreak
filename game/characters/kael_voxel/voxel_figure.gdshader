shader_type spatial;
// Voxel look-dev material: baked per-voxel colour (variation + cavity) from
// COLOR, smooth corner AO from CUSTOM0, and a bevel highlight on convex voxel
// edges from CUSTOM1 (the edge brightens and its normal tilts outward, so
// every block reads as a tactile, slightly rounded cube).
render_mode diffuse_burley, specular_schlick_ggx;

uniform float roughness_value : hint_range(0.0, 1.0) = 0.8;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float specular_value : hint_range(0.0, 1.0) = 0.4;
uniform float bevel_width : hint_range(0.0, 0.5) = 0.16;
uniform float bevel_tilt : hint_range(0.0, 2.0) = 0.7;
uniform float edge_lift : hint_range(0.0, 1.0) = 0.12;
uniform float corner_ao : hint_range(0.0, 1.0) = 0.85;
uniform float emission_value = 0.0;

// Set per instance by CharacterView (energy-coloured rim); kept subtle here.
instance uniform vec4 rim_energy_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
instance uniform float rim_energy_mix = 0.0;

varying vec4 corner_ao_values;
varying vec4 edge_flags;

void vertex() {
	corner_ao_values = CUSTOM0;
	edge_flags = CUSTOM1;
}

float ramp(float t) {
	return 1.0 - smoothstep(0.0, bevel_width, t);
}

void fragment() {
	// Clamped: on sliver faces (and MSAA samples past an edge) the
	// interpolated UV can land far outside the face and extrapolate the AO.
	vec2 f = clamp(UV, vec2(0.0), vec2(1.0));
	float ao = clamp(mix(mix(corner_ao_values.x, corner_ao_values.y, f.x),
		mix(corner_ao_values.w, corner_ao_values.z, f.x), f.y), 0.0, 1.0);
	vec4 flags = clamp(edge_flags, vec4(0.0), vec4(1.0));
	float u0 = flags.x * ramp(f.x);
	float u1 = flags.y * ramp(1.0 - f.x);
	float v0 = flags.z * ramp(f.y);
	float v1 = flags.w * ramp(1.0 - f.y);
	float edge = max(max(u0, u1), max(v0, v1));
	// Skinning can shrink or collapse the tangent frame where a vertex blends
	// strongly rotated bones; never normalize a degenerate vector (NaN shading
	// becomes a white firefly that bloom spreads into a blob).
	vec3 base_n = dot(NORMAL, NORMAL) > 1e-8 && !any(isnan(NORMAL)) ? normalize(NORMAL) : VIEW;
	vec3 tilt = TANGENT * (u1 - u0) + BINORMAL * (v1 - v0);
	if (any(isnan(tilt)) || dot(tilt, tilt) > 4.0) {
		tilt = vec3(0.0);
	}
	vec3 n = base_n + tilt * bevel_tilt;
	n = dot(n, n) > 1e-6 ? normalize(n) : base_n;
	// Keep the tilted normal facing the viewer: a back-facing shading normal
	// makes the specular term blow up into single-pixel fireflies.
	n = normalize(n + VIEW * max(0.0, 0.08 - dot(n, VIEW)));
	NORMAL = n;
	// Vertex colours are authored in sRGB.
	// Clamped: with MSAA, varyings are evaluated at the pixel centre, which can
	// lie far outside a nearly edge-on voxel face, and the extrapolated colour
	// then blows up into an HDR firefly that bloom spreads into a blob.
	vec3 c = clamp(COLOR.rgb, vec3(0.0), vec3(1.0));
	vec3 base = mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
	vec3 albedo = base * (1.0 + edge * edge_lift);
	ALBEDO = albedo * mix(1.0, ao, corner_ao * 0.5);
	AO = mix(1.0, ao, corner_ao);
	AO_LIGHT_AFFECT = 0.25;
	ROUGHNESS = clamp(roughness_value + edge * 0.08, 0.05, 1.0);
	METALLIC = metallic_value;
	SPECULAR = specular_value;
	EMISSION = base * emission_value;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION += rim_energy_color.rgb * fres * rim_energy_mix * 0.6;
}
