shader_type spatial;
// Ember Rift lava in the voxel style: the surface is flat cells (cell_m), each
// one whole crust plate or molten crack, so the crust drifts as cells along
// the flow, never as a smooth smear. Amber-yellow hue (Brann's glow is red),
// emission capped by max_emission (3 in pools, 2 in fissures). Fissure
// instances (INSTANCE_CUSTOM.r = 1) draw a molten seam <= 30% of the strip
// width between crust plates, no hairlines. Outside clip_radius it discards.
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec3 core_color : source_color = vec3(1.0, 0.69, 0.25);
uniform vec3 fall_color : source_color = vec3(0.91, 0.44, 0.11);
uniform vec3 crust_color : source_color = vec3(0.29, 0.188, 0.157);
uniform vec3 crust_dark : source_color = vec3(0.12, 0.07, 0.06);
uniform float cell_m = 0.35;
uniform float plate_m = 5.0;
uniform vec2 flow = vec2(0.22, 0.12);
uniform float max_emission = 3.0;
uniform float glow = 1.0;
uniform float day_light = 0.0;
uniform vec3 clip_centre = vec3(660.0, 31.0, -520.0);
uniform float clip_radius = 1.0e6;
uniform vec2 vent = vec2(660.0, -520.0);
uniform float time_s = 0.0;

varying vec3 world_pos;
varying float fissure;
varying vec2 strip_uv;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fissure = INSTANCE_CUSTOM.r;
	strip_uv = UV;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Edge distance of a cellular (plate) pattern at p, in plate units.
float plate_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 j = vec2(hash12(i + o), hash12(i + o + 19.0)) * 0.8 + 0.1;
			float d = length(o + j - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void fragment() {
	if (length(world_pos.xz - clip_centre.xz) > clip_radius && fissure < 0.5) {
		discard;
	}
	// Snap to the voxel cell: everything below is constant per cell.
	vec2 cellc = (floor(world_pos.xz / cell_m) + 0.5) * cell_m;
	float t = time_s;
	vec3 col;
	float emit;
	if (fissure > 0.5) {
		// Seam across the strip (v 0..1), ragged per cell, tapered at the ends.
		float v = abs(strip_uv.y - 0.5) * 2.0;
		float u = strip_uv.x;
		float taper = smoothstep(0.0, 0.15, u) * smoothstep(1.0, 0.85, u);
		float rag = vnoise(cellc * 0.9) * 0.12;
		float seam = step(v, (0.18 + rag) * taper);
		float pulse = 0.8 + 0.2 * sin(t * 1.7 + vnoise(cellc * 0.5 - t * 0.3) * 6.0);
		float plate = hash12(floor(cellc / 0.7));
		vec3 crust = mix(crust_dark, crust_color, 0.5 + 0.5 * plate);
		col = mix(crust * (0.6 + 0.4 * day_light), core_color * pulse, seam);
		emit = seam * min(2.0, 1.3 * glow);
		ALBEDO = col * mix(1.0, emit, seam);
	} else {
		// Plates drift along the flow (and away from the vent near it), as cells.
		vec2 away = normalize(cellc - vent + vec2(0.001));
		float near_vent = 1.0 - smoothstep(20.0, 45.0, length(cellc - vent));
		vec2 drift = (flow + away * 0.35 * near_vent) * t;
		vec2 p = (cellc - drift) / plate_m;
		float e = plate_edge(p + (vec2(vnoise(cellc / 17.0), vnoise(cellc / 17.0 + 4.0)) - 0.5) * 0.8);
		float open = vnoise(cellc / 26.0 + t * 0.02);
		float crack = 1.0 - step(0.06 + open * 0.14, e);
		// The central pool churns: more molten cells near the vent.
		float churn = near_vent * step(0.55, vnoise(cellc / 3.0 + vec2(t * 0.25, -t * 0.18)));
		float molten = max(crack, churn);
		float plate = hash12(floor(p) + floor(cellc * 0.0));
		float speck = hash12(cellc * 1.7);
		vec3 crust = mix(crust_dark, crust_color, 0.35 + 0.4 * speck);
		// Faint warm underglow on crust cells right beside a crack.
		float warm = 1.0 - smoothstep(0.0, 0.2 + open * 0.14, e);
		vec3 hot = mix(fall_color, core_color, 0.25 + 0.5 * vnoise(cellc * 0.4 + t * 0.5));
		float shimmer = 0.85 + 0.15 * sin(t * 2.0 + speck * 6.28);
		col = mix(crust * (0.5 + 0.5 * day_light) + fall_color * warm * 0.18 * glow, hot * shimmer, molten);
		emit = mix(1.0, min(max_emission, 1.45 * glow), molten);
		ALBEDO = col * emit;
	}
}
