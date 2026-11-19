// Additive energy VFX drawn over bodies, for impacts that start inside a fighter.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

#include "res://game/view/vfx/shaders/vfx_energy.gdshaderinc"
