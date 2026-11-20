shader_type spatial;
// Stormfall City blocks (CityBlocks meshes): every face is cut into cells of
// CUSTOM0.z metres. Per-cell colour noise, a bevel highlight on each face's
// outer cell ring, windows snapped to cells on facades (lit, dark glass, broken,
// boarded), rain stains, a wet sheen on up-facing cells and emissive neon.
render_mode cull_back;

uniform float window_energy = 1.0;
uniform float neon_energy = 1.0;
uniform float lit_fraction = 0.28;
uniform float beacon = 1.0;
uniform float strobe = 0.0;
uniform float wet = 1.0;
uniform float edge_lift = 0.22;
uniform float bevel_tilt = 0.45;

varying vec3 world_n;
varying vec4 face;
varying vec2 facade_uv;
varying vec2 local_uv;
varying vec4 base_col;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

float hash3(ivec3 c) {
	uint h = uint(c.x) * 73856093u ^ uint(c.y) * 19349663u ^ uint(c.z) * 83492791u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h & 65535u) / 65535.0;
}

void vertex() {
	world_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	face = CUSTOM0;
	facade_uv = UV;
	local_uv = UV2;
	base_col = COLOR;
}

void fragment() {
	int code = int(base_col.a * 255.0);
	vec3 n = normalize(world_n);
	float cell = max(face.z, 0.01);
	int sd = int(round(face.w * 977.0)) + int(round(dot(n, vec3(1.0, 7.0, 13.0)) * 3.0));
	ivec2 cc = ivec2(floor(local_uv / cell));
	float noise = hash3(ivec3(cc, sd)) * 2.0 - 1.0;
	vec3 albedo = to_linear(base_col.rgb);
	vec3 emission = vec3(0.0);
	float rough = 0.85;
	float spec = 0.3;
	float metal = 0.0;
	float amount = 0.025;
	bool vertical = abs(n.y) < 0.5;
	if (code == 2 || code == 5) { amount = 0.06; }
	// Bevel: the outer ring of cells on each face catches light.
	vec2 d2 = min(local_uv, face.xy - local_uv) / cell;
	float edge_d = min(d2.x, d2.y);
	float edge = (1.0 - smoothstep(0.0, 0.9, edge_d)) * step(1.5, min(face.x, face.y) / cell);
	vec3 tilt = vec3(0.0);
	if (code == 1 || code == 2) {
		// Facades: a window grid snapped to cells.
		float storey = 3.5;
		float bay = 3.0;
		float h = facade_uv.y;
		float nb = floor((face.x - 1.0) / bay);
		if (vertical && h > 4.4 && nb >= 1.0 && face.y > 6.0) {
			float margin = (face.x - nb * bay) * 0.5;
			float bu = (local_uv.x - margin) / bay;
			int bi = int(floor(bu));
			int si = int(floor(h / storey));
			float fu = (fract(bu) * bay);
			float fv = (h - float(si) * storey);
			// Window: 4 x 5 cells at 35 cm (1.4 x 1.75 m), sill at 0.9 m.
			float wx0 = floor((bay * 0.5 - 0.7) / cell) * cell;
			float wx1 = wx0 + floor(1.4 / cell + 0.5) * cell;
			float wy0 = floor(0.9 / cell) * cell;
			float wy1 = wy0 + floor(1.75 / cell + 0.5) * cell;
			bool in_bay = bu >= 0.0 && bi < int(nb) && local_uv.y < face.y - 1.2;
			float hw = hash3(ivec3(bi, si, sd + 17));
			if (in_bay && fu >= wx0 && fu < wx1 && fv >= wy0 && fv < wy1) {
				float lit = step(hw, lit_fraction);
				float top = 1.0 - step(cell * 1.0, wy1 - fv);
				if (hw < lit_fraction) {
					// Lit: warm, never saturated, a little dimmer at the top (the lintel's shade).
					vec3 warm = mix(vec3(0.91, 0.78, 0.56), vec3(0.95, 0.86, 0.7), hash3(ivec3(bi, si, sd + 3)));
					float curtain = step(0.6, hash3(ivec3(bi, si, sd + 5))) * step(fu, (wx0 + wx1) * 0.5);
					albedo = to_linear(warm) * 0.3;
					emission = to_linear(warm) * window_energy * (1.0 - 0.45 * top) * (1.0 - 0.6 * curtain);
				} else if (hw < lit_fraction + 0.08) {
					albedo = vec3(0.008);
					rough = 0.95;
				} else if (hw < lit_fraction + 0.14) {
					// Boarded: horizontal planks.
					float plank = floor(fv / cell);
					albedo = to_linear(vec3(0.33, 0.27, 0.21)) * (0.8 + 0.3 * hash3(ivec3(bi, int(plank), sd + 9)));
				} else {
					// Dark glass: reflects the storm sky.
					albedo = vec3(0.012, 0.014, 0.02) * (1.0 + 0.4 * hash3(ivec3(cc, 2)));
					rough = 0.08;
					spec = 0.9;
					if (hash3(ivec3(bi, si, sd + 21)) > 0.82) {
						emission = to_linear(vec3(0.85, 0.6, 0.4)) * 0.05 * window_energy;
					}
				}
				albedo *= 1.0 - 0.6 * top;
				edge = 0.0;
			} else if (in_bay && fu >= wx0 - cell && fu < wx1 + cell && fv >= wy0 - cell && fv < wy1 + cell) {
				// Frame and sill: one cell, the sill lighter.
				albedo *= fv < wy0 ? 1.28 : 0.82;
				edge = 0.0;
			} else if (in_bay && fu >= wx0 && fu < wx1 && fv < wy0) {
				// Rain stain under the sill, fading down.
				float k = smoothstep(wy0 - cell, wy0 - 0.9, fv);
				albedo *= 1.0 - 0.22 * (1.0 - k) * step(0.35, hw);
			}
		}
	}
	if (vertical && code <= 5) {
		// Vertical rain streaks, cell columns; foot of the wall darker.
		float col_h = hash3(ivec3(cc.x, 0, sd + 31));
		float start = floor(col_h * face.y / cell);
		float len = 3.0 + 30.0 * hash3(ivec3(cc.x, 1, sd + 33));
		float run = clamp((start - float(cc.y)) / len, 0.0, 1.0);
		albedo *= 1.0 - 0.12 * step(0.82, col_h) * step(0.0, start - float(cc.y)) * (1.0 - run);
		albedo *= mix(0.62, 1.0, smoothstep(0.0, 1.6, facade_uv.y));
	}
	if (code == 3 && vertical) {
		// Laid stone: 70 cm courses of staggered blocks, dark joints, the odd
		// lighter replacement block, and lit slit windows up the shaft.
		float course = floor(local_uv.y / 0.7);
		float along = local_uv.x / 1.4 + 0.5 * mod(course, 2.0);
		float joint = max(step(fract(local_uv.y / 0.7), 0.1), step(fract(along), 0.05));
		float tone = hash3(ivec3(int(floor(along)), int(course), sd + 61));
		albedo *= (0.84 + 0.3 * tone) * (1.0 - 0.45 * joint);
		vec2 slit = vec2(abs(local_uv.x - face.x * 0.5), mod(local_uv.y, 14.0));
		if (face.x > 12.0 && face.y > 30.0 && slit.x < 0.35 && slit.y > 5.0 && slit.y < 8.5 && local_uv.y > 10.0) {
			albedo = vec3(0.01);
			emission = to_linear(vec3(0.91, 0.78, 0.56)) * 0.5 * window_energy * step(0.4, hash3(ivec3(int(local_uv.y / 14.0), 0, sd)));
		}
		edge *= 0.6;
	}
	if (code == 19) {
		// Roller shutter: ribs every cell.
		albedo *= 0.8 + 0.3 * step(0.5, fract(local_uv.y / cell));
		edge *= 0.5;
	}
	albedo *= 1.0 + noise * amount;
	if (n.y < -0.5) {
		albedo *= 0.55;
	}
	if (code == 6 || code == 7) {
		emission = to_linear(base_col.rgb) * neon_energy * (code == 6 ? 2.4 : 1.4);
		albedo = to_linear(base_col.rgb) * 0.2;
		edge = 0.0;
	} else if (code == 8) {
		emission = to_linear(base_col.rgb) * 1.15 * window_energy * (0.9 + 0.1 * noise);
	} else if (code == 22) {
		// Lit shop window: mullions every 1.2 m, shelves and stock as darker
		// cell blocks, brighter toward the top (the ceiling lights).
		float mull = step(fract(local_uv.x / 1.2), cell / 1.2) + step(local_uv.y, cell) + step(face.y - cell, local_uv.y);
		ivec2 sc = ivec2(floor(local_uv / (cell * 3.0)));
		float stock = step(0.55, hash3(ivec3(sc, sd + 51))) * step(local_uv.y, face.y * 0.7);
		vec3 warm = to_linear(base_col.rgb);
		albedo = warm * 0.1;
		emission = warm * window_energy * 0.55 * (0.55 + 0.45 * local_uv.y / face.y) * (1.0 - 0.75 * stock) * (1.0 - clamp(mull, 0.0, 1.0));
		edge = 0.0;
	} else if (code == 11) {
		emission = to_linear(base_col.rgb) * 1.0 * window_energy;
	} else if (code == 16) {
		emission = to_linear(base_col.rgb) * 2.5 * beacon;
	} else if (code == 17) {
		emission = vec3(0.9, 0.95, 1.0) * 3.0 * strobe;
	} else if (code == 15) {
		albedo = to_linear(base_col.rgb) * 0.5;
		rough = 0.04;
		spec = 0.9;
		edge = 0.0;
	} else if (code == 10) {
		rough = 0.08;
		spec = 0.9;
	} else if (code == 4 || code == 5) {
		metal = 0.35;
		rough = 0.5;
	}
	if (n.y > 0.5 && code != 15) {
		// Wet: up-facing cells darken a touch and turn glossy.
		albedo *= 1.0 - 0.15 * wet;
		rough = mix(rough, 0.18 + 0.2 * hash3(ivec3(cc, sd + 41)), wet);
		spec = mix(spec, 0.7, wet);
	}
	albedo *= 1.0 + edge * edge_lift;
	if (edge > 0.0) {
		vec2 dir = vec2(0.0);
		tilt = vec3(0.0);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = metal;
}
