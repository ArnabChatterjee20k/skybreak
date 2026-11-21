class_name VoxelZoneBake
extends RefCounted
## A zone's built static voxel look, saved by tools/voxel_zone_bake.gd per
## quality tier, so a match loads it instead of building for minutes. The bake
## is the built VoxelZone itself as a PackedScene (its builder script, every
## node it made, meshes, materials, occluders) plus its script state, which
## restore() puts back so animate(), presets() and cloud_sea() work as after a
## build. A bake is used only while its source hash matches the zone's sources.

## Bump when the saved layout changes.
const VERSION := 1
const DIR := "res://game/world/voxel_zone_kit/baked/"
## Meta on the baked zone root that carries the bake's header and script state.
const META := &"voxel_zone_bake"
## Tiers that get a bake, as VoxelQuality/GraphicsSettings name them.
const TIERS: Array[GraphicsSettings.Quality] = [
	GraphicsSettings.Quality.HIGH, GraphicsSettings.Quality.MEDIUM,
	GraphicsSettings.Quality.LOW, GraphicsSettings.Quality.WEB,
]
## Sources every zone's look depends on besides its own folder.
const SHARED_DIRS: Array[String] = [
	"res://game/world/voxel_zone_kit",
	"res://game/world/props",
	"res://game/world/islands",
	"res://game/world/terrain",
	"res://game/world/zones",
]
const SHARED_FILES: Array[String] = [
	"res://game/world/world_map.gd",
	"res://game/characters/voxel_kit/voxel_sdf.gd",
	"res://game/characters/voxel_kit/voxel_grid.gd",
	"res://game/characters/voxel_kit/voxel_mesher.gd",
	"res://game/characters/voxel_kit/voxel_figure.gdshader",
]
const SOURCE_EXTENSIONS: Array[String] = ["gd", "gdshader", "gdshaderinc", "tres", "res"]

## Bakes a loading screen already fetched, by path (taken once by load_scene).
static var preloaded := {}


## Where the bake of a zone at a tier lives.
static func path_for(zone_id: StringName, tier: GraphicsSettings.Quality) -> String:
	return DIR + "%s_%s.scn" % [zone_id, String(GraphicsSettings.Quality.keys()[tier]).to_lower()]


## Files that change a zone's look: its builder's folder plus the shared kit,
## the sim data it draws over, and the voxel mesher. Sorted.
static func sources_for(builder_path: String) -> Array[String]:
	var out: Array[String] = []
	for d: String in [builder_path.get_base_dir()] + SHARED_DIRS:
		_collect(d, out)
	for f in SHARED_FILES:
		if not f in out:
			out.append(f)
	out.sort()
	return out


static func _collect(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		# The bake's own layout is versioned by VERSION, not hashed.
		if f.get_extension() in SOURCE_EXTENSIONS and f != "voxel_zone_bake.gd":
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if d != "baked":
			_collect(dir.path_join(d), out)


## SHA-256 of a zone's sources, or "" when they can't be read (exported builds
## ship tokenised scripts and remapped resources; their bakes are trusted).
static func source_hash_for(builder_path: String) -> String:
	var paths := sources_for(builder_path)
	if paths.is_empty():
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for p in paths:
		if not FileAccess.file_exists(p):
			return ""
		var bytes := FileAccess.get_file_as_bytes(p)
		if bytes.is_empty():
			return ""
		if p.get_extension() != "res":
			bytes = bytes.get_string_from_utf8().replace("\r", "").to_utf8_buffer()
		ctx.update((p + "\n").to_utf8_buffer())
		ctx.update(bytes)
	return ctx.finish().hex_encode()


## Packs a built zone (in the tree, build() done) into a PackedScene with its
## state. The zone is left as it was.
static func pack(zone: VoxelZone, zone_id: StringName, tier: GraphicsSettings.Quality, builder_path: String,
		build_ms: int) -> PackedScene:
	var metas := {}
	for m in zone.get_meta_list():
		metas[m] = zone.get_meta(m)
		zone.remove_meta(m)
	var state := {
		"vars": snapshot(zone, zone),
		"metas": encode(metas, zone, {}),
		"prop_materials": VoxelProp.materials(),
	}
	zone.set_meta(META, {
		"version": VERSION, "zone": zone_id, "tier": int(tier), "source_hash": source_hash_for(builder_path),
		"build_ms": build_ms, "state": state,
	})
	# The cached-mesh face images duplicate the face textures; loaded bakes never need them.
	var stripped: Array[ArrayMesh] = []
	for n in zone.find_children("*", "Node", true, false):
		n.owner = zone
		for m in _meshes_of(n):
			if m.has_meta("faces") and not m in stripped:
				stripped.append(m)
	var faces := {}
	for m in stripped:
		faces[m] = m.get_meta("faces")
		m.remove_meta("faces")
	var scene := PackedScene.new()
	var err := scene.pack(zone)
	for m in stripped:
		m.set_meta("faces", faces[m])
	zone.remove_meta(META)
	for m: StringName in metas:
		zone.set_meta(m, metas[m])
	return scene if err == OK else null


static func _meshes_of(n: Node) -> Array[ArrayMesh]:
	var out: Array[ArrayMesh] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
		out.append((n as MeshInstance3D).mesh)
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null \
			and (n as MultiMeshInstance3D).multimesh.mesh is ArrayMesh:
		out.append((n as MultiMeshInstance3D).multimesh.mesh)
	return out


## Saves a packed zone with a path-derived uid, so a fresh bake matches too.
static func save(scene: PackedScene, path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		return err
	return ResourceSaver.set_uid(path, ResourceUID.create_id_for_path(path))


## The bake's header (version, zone, tier, source_hash, build_ms), or {}.
static func header_of(scene: PackedScene) -> Dictionary:
	if scene == null:
		return {}
	var s := scene.get_state()
	if s.get_node_count() == 0:
		return {}
	for i in s.get_node_property_count(0):
		if s.get_node_property_name(0, i) == "metadata/" + String(META):
			return s.get_node_property_value(0, i)
	return {}


## Why a bake can't be used ("" when it can): missing, old layout, other zone or
## tier, or stale sources.
static func check(zone_id: StringName, tier: GraphicsSettings.Quality, builder_path: String) -> String:
	var path := path_for(zone_id, tier)
	if not ResourceLoader.exists(path):
		return "no bake at %s" % path
	var scene := preloaded.get(path, null) as PackedScene
	if scene == null:
		scene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	return why_unusable(scene, zone_id, tier, builder_path)


static func why_unusable(scene: PackedScene, zone_id: StringName, tier: GraphicsSettings.Quality,
		builder_path: String) -> String:
	var h := header_of(scene)
	if h.is_empty() or int(h.get("version", 0)) != VERSION:
		return "unreadable or old bake"
	if StringName(h.zone) != zone_id or int(h.tier) != int(tier):
		return "bake is for %s/%d" % [h.zone, h.tier]
	var current := source_hash_for(builder_path)
	if current != "" and current != String(h.source_hash):
		return "stale bake (sources changed since it was baked)"
	return ""


## The zone's bake as a built VoxelZone (not in the tree, state restored), or
## null with the reason in why[0].
static func instantiate(zone_id: StringName, tier: GraphicsSettings.Quality, builder_path: String,
		why: Array = []) -> VoxelZone:
	var path := path_for(zone_id, tier)
	var scene := preloaded.get(path, null) as PackedScene
	preloaded.erase(path)
	if scene == null:
		if not ResourceLoader.exists(path):
			why.append("no bake at %s" % path)
			return null
		scene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	var reason := why_unusable(scene, zone_id, tier, builder_path)
	if reason != "":
		why.append(reason)
		return null
	var zone := scene.instantiate() as VoxelZone
	if zone == null:
		why.append("bake root is not a VoxelZone")
		return null
	restore(zone)
	return zone


## Puts a baked zone's script state, metas and shared prop materials back.
static func restore(zone: VoxelZone) -> void:
	var h: Dictionary = zone.get_meta(META)
	zone.remove_meta(META)
	var state: Dictionary = h.state
	apply_snapshot(zone, zone, state.vars)
	var metas: Dictionary = decode(state.metas, zone)
	for m: StringName in metas:
		zone.set_meta(m, metas[m])
	# The stage drives the shared materials (lanterns) and syncs merged ones from them.
	VoxelProp.adopt(state.prop_materials, _merged_materials(zone))
	zone.restored()


static func _merged_materials(zone: Node) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	var seen := {}
	for n in zone.find_children("*", "Node", true, false):
		for m in _meshes_of(n):
			var mat := m.surface_get_material(0) as ShaderMaterial if m.get_surface_count() > 0 else null
			if mat != null and mat.shader == VoxelProp.MERGED_SHADER and not seen.has(mat):
				seen[mat] = true
				out.append(mat)
	return out


# ---------------------------------------------------------------- state

## Script variables of obj (a zone or a helper it owns), encoded.
static func snapshot(obj: Object, zone: Node, seen := {}) -> Dictionary:
	var out := {}
	for p in obj.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var v: Variant = obj.get(p.name)
		var enc: Variant = encode(v, zone, seen)
		if enc != null or v == null:
			out[p.name] = enc
	return out


## Sets obj's script variables from a snapshot.
static func apply_snapshot(obj: Object, zone: Node, snap: Dictionary) -> void:
	for name: String in snap:
		var cur: Variant = obj.get(name)
		var enc: Variant = snap[name]
		if enc is Dictionary and (enc as Dictionary).has("$obj"):
			var e: Dictionary = enc
			var helper: Object = cur if cur is Object and cur != null and cur.get_script() == e["$obj"] \
				else (zone as VoxelZone).make_restored(e["$obj"])
			if helper == null:
				continue
			apply_snapshot(helper, zone, e.vars)
			obj.set(name, helper)
			continue
		obj.set(name, decode(enc, zone))


## A value with nodes as paths from the zone and helper objects as snapshots;
## null for what can't be kept (callables, nodes outside the zone).
static func encode(v: Variant, zone: Node, seen: Dictionary) -> Variant:
	match typeof(v):
		TYPE_OBJECT:
			if v == null:
				return null
			if v is Node:
				var n := v as Node
				if n == zone or zone.is_ancestor_of(n):
					return {"$node": String(zone.get_path_to(n))}
				return null
			if v is Resource:
				return v
			var o := v as Object
			if o.get_script() == null or (o.get_script() as Script).resource_path.get_file().contains("::") \
					or (o.get_script() as Script).resource_path == "" or seen.has(o.get_instance_id()):
				return null
			seen[o.get_instance_id()] = true
			return {"$obj": o.get_script(), "vars": snapshot(o, zone, seen)}
		TYPE_ARRAY:
			var a := v as Array
			var items := []
			for x: Variant in a:
				items.append(encode(x, zone, seen))
			return {"$arr": items, "t": a.get_typed_builtin(), "c": a.get_typed_class_name(),
				"s": a.get_typed_script()}
		TYPE_DICTIONARY:
			var d := v as Dictionary
			var pairs := []
			for k: Variant in d:
				pairs.append([encode(k, zone, seen), encode(d[k], zone, seen)])
			return {"$dict": pairs, "kt": d.get_typed_key_builtin(), "kc": d.get_typed_key_class_name(),
				"ks": d.get_typed_key_script(), "vt": d.get_typed_value_builtin(),
				"vc": d.get_typed_value_class_name(), "vs": d.get_typed_value_script()}
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			return null
	return v


static func decode(v: Variant, zone: Node) -> Variant:
	if not v is Dictionary:
		return v
	var d := v as Dictionary
	if d.has("$node"):
		return zone.get_node_or_null(NodePath(d["$node"]))
	if d.has("$obj"):
		var helper := (zone as VoxelZone).make_restored(d["$obj"])
		if helper != null:
			apply_snapshot(helper, zone, d.vars)
		return helper
	if d.has("$arr"):
		var items := []
		for x: Variant in d["$arr"]:
			items.append(decode(x, zone))
		if int(d.t) == TYPE_NIL:
			return items
		return Array(items, int(d.t), StringName(d.c), d.s)
	if d.has("$dict"):
		var out := {}
		if int(d.kt) != TYPE_NIL or int(d.vt) != TYPE_NIL:
			out = Dictionary({}, int(d.kt), StringName(d.kc), d.ks, int(d.vt), StringName(d.vc), d.vs)
		for pair: Array in d["$dict"]:
			out[decode(pair[0], zone)] = decode(pair[1], zone)
		return out
	return d
