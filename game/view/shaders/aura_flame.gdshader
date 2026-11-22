// One layer of the power-up aura: an upright camera-facing flame silhouette of rising, tapering tongues.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://game/view/shaders/vfx_noise.gdshaderinc"

// Per aura (each FighterAura owns a copy of this material; GLES3 caps instance uniforms).
uniform vec4 tint : source_color = vec4(1.0, 0.62, 0.22, 1.0);
// 0 off to 1 fully on; the aura eases it.
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// 1 at level 1, up to 3 at level 3: faster, taller, wilder tongues.
uniform float level : hint_range(0.0, 3.0) = 1.0;
uniform float intensity : hint_range(0.0, 4.0) = 0.6;
// Per layer, so stacked layers never flicker in step.
uniform float seed : hint_range(0.0, 100.0) = 0.0;
// Silhouette size in metres: half-width at the shoulders and height from the feet to the tip.
uniform float half_width : hint_range(0.1, 3.0) = 0.8;
uniform float height : hint_range(0.5, 6.0) = 3.0;
// Metres below the node origin where the flame starts (the feet).
uniform float feet : hint_range(0.0, 3.0) = 1.05;
// Metres the layer sits toward (+) or away from (-) the camera; back layers hide behind the body.
uniform float depth_offset : hint_range(-2.0, 2.0) = -0.3;
// Glow inside the silhouette (0 = only the tongue band at the edge, so the body shows through).
uniform float interior : hint_range(0.0, 1.0) = 0.25;
// Whiteness of the core near the body and the roots.
uniform float heat : hint_range(0.0, 1.0) = 0.5;
uniform float speed : hint_range(0.0, 8.0) = 2.2;
// Tongue cells across the silhouette; higher = more, thinner tongues.
uniform float tongues : hint_range(1.0, 12.0) = 4.5;
// HDR ceiling for this layer, so stacked layers and bloom never blow out to white blobs.
uniform float max_hdr : hint_range(0.5, 4.0) = 1.3;

varying vec2 shape_uv;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	to_cam.y = 0.0;
	to_cam = length(to_cam) > 1e-4 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	float s = length(MODEL_MATRIX[1].xyz);
	shape_uv = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	vec3 local = right * shape_uv.x * half_width * 1.25 + vec3(0.0, shape_uv.y * height - feet, 0.0)
		+ to_cam * depth_offset;
	vec3 world = origin + local * s;
	MODELVIEW_MATRIX = VIEW_MATRIX;
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX);
	VERTEX = world;
	NORMAL = to_cam;
}

void fragment() {
	float on = clamp(strength, 0.0, 1.0);
	if (on <= 0.001) {
		discard;
	}
	float wild = clamp(level - 1.0, 0.0, 2.0) * 0.5;
	float t = TIME * speed * (1.0 + 0.5 * wild);
	float y = shape_uv.y;
	// The whole flame sways a little more toward the top.
	float sway = (vfx_noise1(y * 2.3 - t * 0.6 + seed * 13.0) - 0.5) * 0.22 * y;
	float x = shape_uv.x * 1.25 - sway;
	// Body-hugging teardrop: narrow at the feet, widest at the shoulders, a pointed tip.
	float body = smoothstep(-0.08, 0.3, y) * 0.55 + 0.45;
	float taper = pow(clamp((1.0 - y) / 0.55, 0.0, 1.0), 0.75);
	float envelope = mix(body, body * taper, smoothstep(0.38, 0.62, y));
	// Rising tongues: tall noise cells scrolling up, cutting the edge deeper toward the tip.
	vec3 q = vec3(x * tongues, y * tongues * 0.42 - t, seed);
	float n = vfx_fbm3(q);
	float licks = vfx_noise3(vec3(x * tongues * 2.2, y * tongues - t * 1.7, seed + 7.0));
	float cut = mix(0.35, 1.05, y) + 0.25 * wild;
	float d = abs(x) / max(envelope, 1e-3) + (n - 0.5) * cut + (licks - 0.5) * 0.35 * y;
	float inside = 1.0 - smoothstep(0.78, 1.0, d);
	// A bright band just inside the edge reads as the drawn outline of an anime aura.
	float band = smoothstep(0.45, 0.85, d) * inside;
	// Thin streaks of energy rising through the flame.
	float flow = 0.65 + 0.35 * vfx_noise3(vec3(x * 9.0, y * 2.5 - t * 2.6, seed + 3.0));
	float base_fade = smoothstep(0.0, 0.1, y);
	float alpha = inside * mix(interior * flow, 1.0, band) * base_fade;
	float flick = 0.88 + 0.12 * vfx_noise1(TIME * 14.0 + seed * 5.0);
	float core = clamp((1.0 - d) * (1.0 - 0.7 * y), 0.0, 1.0);
	vec3 hot = mix(tint.rgb, vec3(1.0), clamp(heat * (core * 0.8 + band * 0.25), 0.0, 1.0));
	vec3 col = hot * alpha * flick * intensity * on;
	// Additive: only ever brighten, and never past the HDR ceiling.
	ALBEDO = max(min(col, vec3(max_hdr)), vec3(0.0));
}
