// Additive energy VFX that sit in the world: trails, smears, beams, domes (depth tested).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://game/view/vfx/shaders/vfx_energy.gdshaderinc"
