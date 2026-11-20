// Emissive lava: cooled-rock crust plates drifting on a warped flow, glowing cracks
// between them and a slow heat shimmer, hidden outside its zone. Kept under the
// tonemap's white so the glow never flattens into one yellow. Instances with custom.r = 1
// are floor fissures: a molten seam along the strip with ragged crust edges.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;
#include "res://game/world/shaders/zone_plane.gdshaderinc"

uniform vec4 core_color : source_color = vec4(0.95, 0.36, 0.06, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.72, 0.28, 1.0);
uniform vec4 crust_color : source_color = vec4(0.16, 0.06, 0.05, 1.0);
uniform float glow = 1.0;
uniform vec2 flow = vec2(0.6, 0.35);
// Crust plate size in metres.
uniform float plate_size = 9.0;
// 0 day .. 1 night: cracks glow brighter in the dark.
uniform float night = 0.0;

varying vec3 world_pos;
varying float fissure;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fissure = INSTANCE_CUSTOM.r;
}

// Half-width of a fissure's ragged seam at UV (UV.x along the strip), 0..1 of the strip.
float fissure_width(vec2 uv, vec2 xz) {
	float ragged = value_noise(xz * 0.9) * 0.6 + value_noise(xz * 3.1) * 0.4;
	float taper = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x);
	return (0.45 + 0.5 * ragged) * taper;
}

// A fissure's colour from the seam centre (core 1) out to its crust edge (core 0).
vec3 fissure_colour(float core, vec2 xz, float t) {
	float seam_flow = value_noise(vec2(xz.x + xz.y, 0.0) * 0.8 - vec2(t * 0.9, t * 0.5));
	float shimmer = 0.85 + 0.15 * sin(t * 2.3 + seam_flow * 8.0);
	vec3 molten = mix(core_color.rgb, hot_color.rgb, core * core * (0.6 + 0.4 * seam_flow)) * shimmer;
	return mix(crust_color.rgb, molten * glow * (1.0 + night * 0.25), smoothstep(0.12, 0.42, core));
}

// Distance to the nearest and second-nearest jittered cell centre (cheap 3x3 cellular).
vec2 cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash12(i + g), hash12(i + g + 17.0)) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d1, d2);
}

// The lava sea: drifting crust plates, glowing cracks and molten pools.
vec3 sea_colour(vec2 xz, float t) {
	// Domain-warped flow so the plates drift and stretch instead of sliding rigidly.
	vec2 drift = flow * t * 0.25;
	vec2 warp = vec2(value_noise(xz / 23.0 + t * 0.03), value_noise(xz / 23.0 + 5.2 - t * 0.025)) - 0.5;
	vec2 p = (xz + warp * 14.0) / plate_size - drift / plate_size * 4.0;
	vec2 c = cells(p);
	// Crack width: thin edge between plates, wider where the flow pulls them apart.
	float edge = c.y - c.x;
	float open = value_noise(xz / 31.0 - drift * 0.6);
	float crack = 1.0 - smoothstep(0.04, 0.12 + open * 0.16, edge);
	// Molten pools where the crust has melted through.
	float pool = smoothstep(0.62, 0.78, value_noise(xz / 41.0 + drift * 0.4) * 0.7 + open * 0.3);
	float heat = max(crack, pool);
	// Heat shimmer: slow travelling brightness ripples on the molten parts.
	float shimmer = 0.82 + 0.18 * sin(t * 2.1 + value_noise(xz / 5.0 + t * 0.4) * 9.0 + xz.x * 0.08);
	// Crust: cooled rock with darker pitting and a faint warm underglow near the cracks.
	float pit = value_noise(p * 5.3);
	vec3 crust = crust_color.rgb * (0.7 + 0.5 * pit) + core_color.rgb * 0.18 * smoothstep(0.35, 0.0, edge);
	vec3 molten = mix(core_color.rgb, hot_color.rgb, crack * crack * shimmer) * shimmer;
	vec3 col = mix(crust, molten * glow * (1.0 + night * 0.25), heat);
	return col;
}

void fragment() {
	vec2 xz = world_pos.xz;
	if (fissure > 0.5) {
		float across = abs(UV.y - 0.5) * 2.0;
		float width = fissure_width(UV, xz);
		if (across > width) {
			discard;
		}
		ALBEDO = fissure_colour(1.0 - across / max(width, 0.001), xz, TIME);
	} else {
		if (zone_weight(xz) < 0.4 || outside_clip(xz)) {
			discard;
		}
		ALBEDO = sea_colour(xz, TIME);
	}
}
