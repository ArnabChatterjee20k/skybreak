extends SceneTree
## Turns a VRoid Studio VRM 0.x export into a GLB for the character pipeline:
## faces it +Z like the humanoid retarget profile, merges primitives that share a
## material (VRoid hair comes as ~100 of them) and extracts the base colour
## textures for the toon materials. No addon needed.
## godot --headless --path . -s res://game/characters/tools/prepare_vroid.gd -- <in.vrm> <out.glb> <texture dir>

const GLB_MAGIC := 0x46546C67
const CHUNK_JSON := 0x4E4F534A
const CHUNK_BIN := 0x004E4942
const UNSIGNED_INT := 5125
const MAX_TEXTURE_SIZE := 2048


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("usage: -- <in.vrm> <out.glb> <texture dir>")
		quit(1)
		return
	var bytes := FileAccess.get_file_as_bytes(args[0])
	if bytes.decode_u32(0) != GLB_MAGIC:
		push_error("not a GLB/VRM: " + args[0])
		quit(1)
		return
	var json_length := bytes.decode_u32(12)
	var gltf: Dictionary = JSON.parse_string(bytes.slice(20, 20 + json_length).get_string_from_utf8())
	var bin_length := bytes.decode_u32(20 + json_length)
	var bin := bytes.slice(28 + json_length, 28 + json_length + bin_length)

	_turn_to_plus_z(gltf)
	bin = _merge_primitives(gltf, bin)
	_extract_textures(gltf, bin, args[2])
	_write_glb(args[1], gltf, bin)
	quit()


## VRM 0.x faces -Z; glTF and SkeletonProfileHumanoid expect +Z.
func _turn_to_plus_z(gltf: Dictionary) -> void:
	for node: Dictionary in gltf.nodes:
		if node.get("name") == "Root":
			node["rotation"] = [0.0, 1.0, 0.0, 0.0]
			return
	push_warning("no Root node; model left as is")


func _merge_primitives(gltf: Dictionary, bin: PackedByteArray) -> PackedByteArray:
	for mesh: Dictionary in gltf.meshes:
		var groups := {}
		var order := []
		for primitive: Dictionary in mesh.primitives:
			var key := JSON.stringify([primitive.get("material"), primitive.attributes, primitive.get("targets"), primitive.get("mode", 4)])
			if not groups.has(key):
				groups[key] = []
				order.append(key)
			groups[key].append(primitive)
		var merged := []
		for key: String in order:
			var parts: Array = groups[key]
			var primitive: Dictionary = parts[0].duplicate(true)
			if parts.size() > 1:
				var indices := PackedByteArray()
				for part: Dictionary in parts:
					indices.append_array(_read_indices_u32(gltf, bin, int(part.indices)))
				while bin.size() % 4 != 0:
					bin.append(0)
				gltf.bufferViews.append({"buffer": 0, "byteOffset": bin.size(), "byteLength": indices.size(), "target": 34963})
				bin.append_array(indices)
				gltf.accessors.append({"bufferView": gltf.bufferViews.size() - 1, "componentType": UNSIGNED_INT, "count": indices.size() / 4, "type": "SCALAR"})
				primitive["indices"] = gltf.accessors.size() - 1
			merged.append(primitive)
		print("%s: %d primitives -> %d" % [mesh.name, mesh.primitives.size(), merged.size()])
		mesh["primitives"] = merged
	gltf.buffers[0]["byteLength"] = bin.size()
	return bin


func _read_indices_u32(gltf: Dictionary, bin: PackedByteArray, accessor_index: int) -> PackedByteArray:
	var accessor: Dictionary = gltf.accessors[accessor_index]
	var view: Dictionary = gltf.bufferViews[int(accessor.bufferView)]
	var start := int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0))
	var out := PackedByteArray()
	out.resize(int(accessor.count) * 4)
	for i in int(accessor.count):
		var value := 0
		match int(accessor.componentType):
			5121: value = bin.decode_u8(start + i)
			5123: value = bin.decode_u16(start + i * 2)
			_: value = bin.decode_u32(start + i * 4)
		out.encode_u32(i * 4, value)
	return out


## Writes each material's base colour image as <material name>.png, at most 2K.
func _extract_textures(gltf: Dictionary, bin: PackedByteArray, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for material: Dictionary in gltf.materials:
		var pbr: Dictionary = material.get("pbrMetallicRoughness", {})
		if not pbr.has("baseColorTexture"):
			continue
		var image_info: Dictionary = gltf.images[int(gltf.textures[int(pbr.baseColorTexture.index)].source)]
		var view: Dictionary = gltf.bufferViews[int(image_info.bufferView)]
		var start := int(view.get("byteOffset", 0))
		var data := bin.slice(start, start + int(view.byteLength))
		var image := Image.new()
		if image_info.get("mimeType") == "image/png":
			image.load_png_from_buffer(data)
		else:
			image.load_jpg_from_buffer(data)
		if maxi(image.get_width(), image.get_height()) > MAX_TEXTURE_SIZE:
			image.resize(MAX_TEXTURE_SIZE, MAX_TEXTURE_SIZE * image.get_height() / image.get_width())
		var path := dir.path_join(String(material.name) + ".png")
		image.save_png(path)
		print("texture %s %dx%d" % [path, image.get_width(), image.get_height()])


func _write_glb(path: String, gltf: Dictionary, bin: PackedByteArray) -> void:
	var json := JSON.stringify(gltf).to_utf8_buffer()
	while json.size() % 4 != 0:
		json.append(0x20)
	while bin.size() % 4 != 0:
		bin.append(0)
	var header := PackedByteArray()
	header.resize(12)
	header.encode_u32(0, GLB_MAGIC)
	header.encode_u32(4, 2)
	header.encode_u32(8, 12 + 8 + json.size() + 8 + bin.size())
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_buffer(header)
	out.store_32(json.size())
	out.store_32(CHUNK_JSON)
	out.store_buffer(json)
	out.store_32(bin.size())
	out.store_32(CHUNK_BIN)
	out.store_buffer(bin)
	print("wrote %s (%d bytes)" % [path, out.get_length()])
