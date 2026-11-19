// Cel-shaded surface for fighters and props: banded diffuse, optional specular band, fresnel rim.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

group_uniforms surface;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;

group_uniforms bands;
// 2 = lit/shadow, 3 = lit/mid/shadow. Ignored when the ramp texture is used.
uniform int band_count : hint_range(2, 3) = 3;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.15;
uniform float highlight_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float mid_band_level : hint_range(0.0, 1.0) = 0.6;
uniform float band_softness : hint_range(0.0, 0.2) = 0.01;
// Grayscale gradient, dark on the left; the red channel is read. Off by default.
uniform bool use_ramp_texture = false;
uniform sampler2D ramp_texture : hint_default_white, filter_linear, repeat_disable;
// Colour of the unlit side under the key (directional) light, so shadows are never black.
uniform vec4 shadow_tint : source_color = vec4(0.42, 0.38, 0.58, 1.0);

group_uniforms specular;
uniform bool specular_enabled = true;
uniform vec4 specular_color : source_color = vec4(1.0);
uniform float specular_size : hint_range(0.0, 1.0) = 0.12;
uniform float specular_softness : hint_range(0.0, 0.2) = 0.01;
uniform float specular_strength : hint_range(0.0, 4.0) = 0.6;

group_uniforms rim;
uniform vec4 rim_color : source_color = vec4(1.0, 0.96, 0.9, 1.0);
uniform float rim_width : hint_range(0.0, 1.0) = 0.3;
uniform float rim_softness : hint_range(0.0, 0.5) = 0.05;
uniform float rim_strength : hint_range(0.0, 4.0) = 0.35;
// Driven by VFX (T-D09): blends the rim toward an energy colour.
uniform vec4 rim_energy_color : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform float rim_energy_mix : hint_range(0.0, 1.0) = 0.0;
group_uniforms;

float band_ramp(float x) {
	if (use_ramp_texture) {
		return texture(ramp_texture, vec2(clamp(x, 0.0, 1.0), 0.5)).r;
	}
	float to_mid = smoothstep(shadow_threshold - band_softness, shadow_threshold + band_softness, x);
	if (band_count < 3) {
		return to_mid;
	}
	float to_lit = smoothstep(highlight_threshold - band_softness, highlight_threshold + band_softness, x);
	return to_mid * mid_band_level + to_lit * (1.0 - mid_band_level);
}

void fragment() {
	vec4 albedo = albedo_color * texture(albedo_texture, UV);
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	float facing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim_edge = 1.0 - rim_width;
	float rim = smoothstep(rim_edge - rim_softness, rim_edge + rim_softness, facing);
	vec3 rim_tint = mix(rim_color.rgb, rim_energy_color.rgb, rim_energy_mix);
	EMISSION = rim_tint * rim * rim_strength;
}

void light() {
	float n_dot_l = dot(NORMAL, LIGHT);
	vec3 light_in = LIGHT_COLOR / PI;
	float lit;
	if (LIGHT_IS_DIRECTIONAL) {
		// Key light: shadow map goes into the band test so cast shadows land on the dark band.
		lit = band_ramp(n_dot_l * ATTENUATION);
		DIFFUSE_LIGHT += light_in * mix(shadow_tint.rgb, vec3(1.0), lit);
	} else {
		// Omni/spot: banded by angle, smooth range falloff, no tint so fill lights don't glow.
		lit = band_ramp(n_dot_l) * ATTENUATION;
		DIFFUSE_LIGHT += light_in * lit;
	}

	if (specular_enabled) {
		float n_dot_h = dot(NORMAL, normalize(VIEW + LIGHT));
		float spec_edge = 1.0 - specular_size * specular_size;
		float spec = smoothstep(spec_edge - specular_softness, spec_edge + specular_softness, n_dot_h);
		SPECULAR_LIGHT += light_in * specular_color.rgb * spec * specular_strength * lit;
	}
}
