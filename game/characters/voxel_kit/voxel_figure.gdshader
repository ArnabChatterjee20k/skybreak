shader_type spatial;
// Voxel figures (characters, weapons): voxel_surface.gdshaderinc with the
// per-instance energy rim.
render_mode diffuse_burley, specular_schlick_ggx;

#define VOXEL_RIM
#include "res://game/characters/voxel_kit/voxel_surface.gdshaderinc"
