// Radial anime speed lines for rush dashes, drawn over the screen without reading it.
shader_type canvas_item;

#include "res://game/view/shaders/vfx_noise.gdshaderinc"

uniform float amount : hint_range(0.0, 1.0) = 0.0;
// Screen UV the lines converge on.
uniform vec2 center = vec2(0.5, 0.5);
// Line slots around the full circle.
uniform float line_density : hint_range(16.0, 360.0) = 120.0;
uniform vec4 color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
// Clear zone around the centre, in screen heights.
uniform float inner_radius : hint_range(0.0, 1.0) = 0.28;
// Line thickness as a fraction of its slot.
uniform float line_width : hint_range(0.05, 1.0) = 0.3;
// Lines re-roll this many times a second, like hand-drawn frames.
uniform float redraw_fps : hint_range(1.0, 60.0) = 24.0;

void fragment() {
	vec2 p = UV - center;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(p);
	float slots = floor(line_density);
	float a = (atan(p.y, p.x) / TAU + 0.5) * slots;
	float slot = floor(a);
	float frame = floor(TIME * redraw_fps);
	float pick = vfx_hash21(vec2(slot, frame));
	float shape_roll = vfx_hash21(vec2(slot + 71.0, frame));
	float on = step(pick, amount * 0.75);
	float width = line_width * (0.3 + 0.7 * shape_roll) * 0.5;
	float start = inner_radius + shape_roll * 0.3 * (1.0 - amount);
	float taper = smoothstep(start, start + 0.25, r);
	// Lines narrow to a point toward the centre.
	float tip_width = width * taper;
	float line = 1.0 - smoothstep(tip_width, tip_width + 0.12, abs(fract(a) - 0.5));
	COLOR = vec4(color.rgb, color.a * on * line * taper * amount);
}
