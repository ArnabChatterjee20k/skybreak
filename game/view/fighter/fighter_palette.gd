class_name FighterPalette
extends RefCounted
## Recolours a character for its team: each material whose name ends in a
## palette key ("..._coat" -> "coat") gets a copy with that albedo colour.
## Shared materials are never edited, so other fighters keep their colours.

const ALBEDO := &"albedo_color"


## Applies palette (part name -> Color) to every mesh under root.
static func apply(root: Node, palette: Dictionary) -> void:
	if palette.is_empty():
		return
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			var part := part_name(material)
			if material is ShaderMaterial and palette.has(part):
				var copy := material.duplicate() as ShaderMaterial
				copy.set_shader_parameter(ALBEDO, palette[part])
				mesh.set_surface_override_material(surface, copy)


## "kael_chunky_coat" -> "coat"; "" for unnamed materials.
static func part_name(material: Material) -> String:
	if material == null or material.resource_name.is_empty():
		return ""
	return material.resource_name.rsplit("_", true, 1)[-1]
