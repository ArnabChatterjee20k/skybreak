shader_type spatial;
// Static voxel zone props (VoxelProp's unmerged meshes): the figure surface
// without instance uniforms, so thousands of prop instances fit the web build.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://game/characters/voxel_kit/voxel_surface.gdshaderinc"
