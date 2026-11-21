class_name WebTierBudget
extends RefCounted
## What a built scene asks of the Compatibility renderer (the web build, WebGL2),
## measured against its fixed limits. Read by the Web-tier tests and
## game/debug/web_tier_probe.gd.
##   var report := WebTierBudget.measure(zone)   # then WebTierBudget.problems(report)

## Each geometry instance whose material has an `instance uniform` takes a
## block of 16 vec4 slots (ShaderLanguage::MAX_INSTANCE_UNIFORM_INDICES) in the
## global uniform buffer, visible or not. Compatibility clamps that buffer to
## the max uniform block size: 64 KiB / 16 B = 4096 slots, so 256 instances.
const SLOTS_PER_INSTANCE := 16
const COMPAT_UNIFORM_SLOTS := 4096
## Instances one zone may spend; the rest is for fighters, weapons and VFX pools.
const ZONE_INSTANCE_UNIFORM_INSTANCES := 0
## A whole match on the web build (fighters, weapons, VFX pools, zone).
const MATCH_INSTANCE_UNIFORM_INSTANCES := COMPAT_UNIFORM_SLOTS / SLOTS_PER_INSTANCE
## Compatibility's per-object light caps (rendering/limits/opengl/*, defaults)
## and its 8 directional lights; a zone keeps under both with room for VFX.
const ZONE_OMNI_SPOT_LIGHTS := 8
const ZONE_DIRECTIONAL_LIGHTS := 4
const ZONE_SHADOWED_LIGHTS := 1
## WebGL2 guarantees 2048 px textures, and every WebGL2 GPU in practice 4096:
## the merged props' face textures stay within that.
const MAX_TEXTURE_SIDE := 4096
## Vertices in one surface: 16-bit-friendly is not required (WebGL2 has 32-bit
## indices), but one draw stays well under a browser's buffer allocation.
const MAX_SURFACE_VERTICES := 1 << 20


## Counts what the subtree at root uses (see problems()).
static func measure(root: Node) -> Dictionary:
	var r := {
		"instance_uniform_instances": 0, "instance_uniform_nodes": [] as Array[String],
		"omni_spot_lights": 0, "directional_lights": 0, "shadowed_lights": 0,
		"max_surface_vertices": 0, "max_texture_side": 0, "geometry_instances": 0,
		"directional_nodes": [] as Array[String],
	}
	var seen_textures := {}
	for node in root.find_children("*", "", true, false):
		# Hidden lights (the classic world's under a voxel zone) cost nothing.
		if node is Light3D and (node as Light3D).visible \
				and (not node.is_inside_tree() or (node as Light3D).is_visible_in_tree()):
			var light := node as Light3D
			if light is DirectionalLight3D:
				r.directional_lights += 1
				(r.directional_nodes as Array).append(str(root.get_path_to(light)))
			else:
				r.omni_spot_lights += 1
			if light.shadow_enabled:
				r.shadowed_lights += 1
		if not node is GeometryInstance3D:
			continue
		r.geometry_instances += 1
		var materials := _materials(node as GeometryInstance3D)
		for m in materials:
			if has_instance_uniforms(m):
				r.instance_uniform_instances += 1
				if (r.instance_uniform_nodes as Array).size() < 8:
					(r.instance_uniform_nodes as Array).append(str(root.get_path_to(node)))
				break
		for m in materials:
			for tex in _textures(m):
				if not seen_textures.has(tex):
					seen_textures[tex] = true
					r.max_texture_side = maxi(r.max_texture_side, maxi(tex.get_width(), tex.get_height()))
		var mesh := _mesh(node as GeometryInstance3D) as ArrayMesh
		if mesh != null:
			for s in mesh.get_surface_count():
				r.max_surface_vertices = maxi(r.max_surface_vertices, mesh.surface_get_array_len(s))
	return r


## Every limit a zone report breaks, as readable lines (empty = fits the Web tier).
static func problems(r: Dictionary, uniform_instances := ZONE_INSTANCE_UNIFORM_INSTANCES) -> Array[String]:
	var out: Array[String] = []
	if r.instance_uniform_instances > uniform_instances:
		out.append("%d instances use instance uniforms (max %d), e.g. %s" % [r.instance_uniform_instances,
			uniform_instances, r.instance_uniform_nodes])
	if r.omni_spot_lights > ZONE_OMNI_SPOT_LIGHTS:
		out.append("%d omni/spot lights (max %d)" % [r.omni_spot_lights, ZONE_OMNI_SPOT_LIGHTS])
	if r.directional_lights > ZONE_DIRECTIONAL_LIGHTS:
		out.append("%d directional lights (max %d)" % [r.directional_lights, ZONE_DIRECTIONAL_LIGHTS])
	if r.shadowed_lights > ZONE_SHADOWED_LIGHTS:
		out.append("%d shadowed lights (max %d)" % [r.shadowed_lights, ZONE_SHADOWED_LIGHTS])
	if r.max_texture_side > MAX_TEXTURE_SIDE:
		out.append("a %d px texture (max %d)" % [r.max_texture_side, MAX_TEXTURE_SIDE])
	if r.max_surface_vertices > MAX_SURFACE_VERTICES:
		out.append("a surface with %d vertices (max %d)" % [r.max_surface_vertices, MAX_SURFACE_VERTICES])
	return out


## True when the material (or a next pass) declares an `instance uniform`.
static func has_instance_uniforms(m: Material) -> bool:
	while m != null:
		var sm := m as ShaderMaterial
		if sm != null and sm.shader != null and _declares_instance_uniform(sm.shader.code):
			return true
		m = m.next_pass
	return false


static func _declares_instance_uniform(code: String) -> bool:
	return _scan(code, {})


## Walks the code (and its includes) with #define / #ifdef / #ifndef / #else /
## #endif, so an instance uniform behind an unset define does not count.
static func _scan(code: String, defines: Dictionary) -> bool:
	var active: Array[bool] = []
	var include := RegEx.create_from_string("^#include\\s+\"([^\"]+)\"")
	var uniform := RegEx.create_from_string("^instance\\s+uniform\\b")
	for raw in code.split("\n"):
		var line := raw.strip_edges()
		var on := not active.has(false)
		if line.begins_with("#ifdef ") or line.begins_with("#ifndef "):
			var defined := defines.has(line.get_slice(" ", 1).strip_edges())
			active.append(defined if line.begins_with("#ifdef ") else not defined)
		elif line.begins_with("#else") and not active.is_empty():
			active[-1] = not active[-1]
		elif line.begins_with("#endif") and not active.is_empty():
			active.pop_back()
		elif not on:
			continue
		elif line.begins_with("#define "):
			defines[line.get_slice(" ", 1).strip_edges()] = true
		elif include.search(line) != null:
			var sub := load(include.search(line).get_string(1)) as ShaderInclude
			if sub != null and _scan(sub.code, defines):
				return true
		elif uniform.search(line) != null:
			return true
	return false


static func _mesh(g: GeometryInstance3D) -> Mesh:
	if g is MeshInstance3D:
		return (g as MeshInstance3D).mesh
	if g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh != null:
		return (g as MultiMeshInstance3D).multimesh.mesh
	return null


static func _materials(g: GeometryInstance3D) -> Array[Material]:
	var out: Array[Material] = []
	if g.material_override != null:
		out.append(g.material_override)
	if g.material_overlay != null:
		out.append(g.material_overlay)
	var mesh := _mesh(g)
	if mesh != null:
		for s in mesh.get_surface_count():
			var m: Material = mesh.surface_get_material(s)
			if g is MeshInstance3D and (g as MeshInstance3D).get_surface_override_material(s) != null:
				m = (g as MeshInstance3D).get_surface_override_material(s)
			if m != null:
				out.append(m)
	return out


static func _textures(m: Material) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var sm := m as ShaderMaterial
	if sm == null or sm.shader == null:
		return out
	for u in sm.shader.get_shader_uniform_list():
		var v: Variant = sm.get_shader_parameter(u.name)
		if v is Texture2D:
			out.append(v)
	return out
