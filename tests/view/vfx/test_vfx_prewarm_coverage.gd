extends GutTest
## T-D27: the match-load prewarm draws every new VFX material and overlay.


func _materials_under(root: Node) -> Dictionary:
	var found := {}
	for node in root.find_children("*", "", true, false):
		if node is GeometryInstance3D and (node as GeometryInstance3D).material_override != null:
			var material := (node as GeometryInstance3D).material_override as ShaderMaterial
			found[material.get_meta(&"look", &"")] = true
			found[material.shader] = true
		if node is CanvasItem and (node as CanvasItem).material != null:
			found[((node as CanvasItem).material as ShaderMaterial).shader] = true
	return found


func test_effect_layers_own_their_materials_instead_of_instance_uniforms() -> void:
	var a := VfxCatalog.build(&"anime_burst")
	var b := VfxCatalog.build(&"anime_burst")
	var mat_a := a.meshes()[0].material_override as ShaderMaterial
	var mat_b := b.meshes()[0].material_override as ShaderMaterial
	assert_false(mat_a == mat_b, "tints never bleed across effects")
	assert_true(mat_a.shader == mat_b.shader, "one shader, so no extra pipelines")
	for shader in [VfxKit.ENERGY, VfxKit.DEBRIS]:
		assert_false(shader.code.contains("instance uniform"), "GLES3 caps instance uniforms")
	assert_false(FileAccess.get_file_as_string("res://game/view/vfx/shaders/vfx_energy.gdshaderinc").contains("instance uniform"))
	a.free()
	b.free()


func test_prewarm_draws_every_vfx_material() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var added := VfxCatalog.build_prewarm(root, Vector3(0, 0, -6))
	assert_eq(added.size(), VfxCatalog.kinds().size() + 1, "one of every effect plus the overlays")
	var drawn := _materials_under(root)
	for look: StringName in VfxKit.LOOKS:
		assert_true(drawn.has(look), "prewarm draws the %s look" % look)
	for shader in [VfxKit.ENERGY, VfxKit.OVERLAY, VfxKit.DEBRIS]:
		assert_true(drawn.has(shader), "prewarm compiles %s" % shader.resource_path)
	assert_true(drawn.has(VfxKit.SCREEN), "and the screen overlay shader")


func test_prewarm_plays_every_effect() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	for node in VfxCatalog.build_prewarm(root, Vector3.ZERO):
		if node is VfxEffect:
			assert_true((node as VfxEffect).is_playing(), node.name)


func test_the_match_prewarm_includes_the_catalog() -> void:
	var source: String = (load("res://game/view/vfx_prewarm.gd") as GDScript).source_code
	assert_true(source.contains("VfxCatalog.build_prewarm"))


func test_every_effect_kind_has_a_pool_capacity() -> void:
	for kind in VfxCatalog.kinds():
		assert_gt(int(VfxCatalog.CAPACITY[kind]), 0, kind)
		var effect := VfxCatalog.build(kind)
		assert_not_null(effect, kind)
		effect.free()
