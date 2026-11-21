class_name ZoneBakePacks
extends RefCounted
## The web build's zone bakes, one resource pack per zone next to index.html
## (zones/<zone>_web.<sha>.pck plus zones/manifest.json), so the first load
## fetches only the game and a match fetches its zone's bake behind the
## LoadingScreen (ZoneBakeDownload). Each pack holds the bake file byte for byte
## at its res:// path, so a mounted bake is the same bake a desktop build loads.

## Folder of the packs and the manifest, relative to the exported index.html.
const DIR := "zones"
const MANIFEST := "manifest.json"
## Downloaded packs, kept between visits (the web build syncs user:// to IndexedDB).
const CACHE_DIR := "user://zone_bakes/"
## The tier the web build loads (GraphicsSettings defaults to it there).
const TIER := GraphicsSettings.Quality.WEB

## Whether bakes come from packs over HTTP (the web build); tests switch it on.
static var remote := OS.has_feature("web")
## Packs already mounted this session, by file name.
static var mounted := {}


## Whether a bake not in the build can be fetched as a pack.
static func downloadable(bake_path: String) -> bool:
	return remote and bake_path.begins_with(VoxelZoneBake.DIR) and bake_path.ends_with("_web.scn")


## The pack file name for a bake: zone, tier and the start of the bake's SHA-256.
static func file_name(bake_path: String, sha256: String) -> String:
	return "%s.%s.pck" % [bake_path.get_file().get_basename(), sha256.substr(0, 12)]


## Packs one zone's bake into out_dir/zones/; returns its manifest entry
## {bake, file, size, sha256 (of the pack)} or {error}. The bake must be current for the zone,
## tier and builder (VoxelZoneBake.why_unusable), so a stale bake never ships.
## source is where the bake file is read from (default: its res:// path).
static func pack_zone(out_dir: String, zone_id: StringName, tier: GraphicsSettings.Quality,
		builder_path: String, source := "") -> Dictionary:
	var bake := VoxelZoneBake.path_for(zone_id, tier)
	if source == "":
		source = bake
	if not FileAccess.file_exists(source):
		return {"error": "no bake at %s" % source}
	var scene := ResourceLoader.load(source, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var why := VoxelZoneBake.why_unusable(scene, zone_id, tier, builder_path)
	if why != "":
		return {"error": "%s: %s" % [source, why]}
	var bytes := FileAccess.get_file_as_bytes(source)
	var sha := _sha256(bytes)
	var dir := out_dir.path_join(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var file := file_name(bake, sha)
	var packer := PCKPacker.new()
	var err := packer.pck_start(dir.path_join(file))
	if err == OK:
		err = packer.add_file(bake, ProjectSettings.globalize_path(source))
	if err == OK:
		err = packer.flush()
	packer = null  # closes the file
	if err != OK:
		return {"error": "packing %s failed (%s)" % [file, error_string(err)]}
	var packed := FileAccess.get_file_as_bytes(dir.path_join(file))
	return {"bake": bake, "file": file, "size": packed.size(), "sha256": _sha256(packed)}


## Writes out_dir/zones/manifest.json: {"version", "packs": {bake path: entry}}.
static func write_manifest(out_dir: String, entries: Array[Dictionary]) -> Error:
	var packs := {}
	for e in entries:
		packs[e.bake] = {"file": e.file, "size": e.size, "sha256": e.sha256}
	var f := FileAccess.open(out_dir.path_join(DIR).path_join(MANIFEST), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"version": VoxelZoneBake.VERSION, "packs": packs}, "\t", true))
	return OK


## The manifest entry {file, size, sha256} for a bake, or {} (bad manifest,
## other bake layout, or no pack for it).
static func entry_in(manifest_text: String, bake_path: String) -> Dictionary:
	var m: Variant = JSON.parse_string(manifest_text)
	if not m is Dictionary or int((m as Dictionary).get("version", 0)) != VoxelZoneBake.VERSION:
		return {}
	var packs: Variant = (m as Dictionary).get("packs")
	if not packs is Dictionary or not (packs as Dictionary).get(bake_path) is Dictionary:
		return {}
	var e: Dictionary = packs[bake_path]
	if not (e.get("file") is String and e.get("size") is float and e.get("sha256") is String) \
			or String(e.file).get_file() != e.file or not String(e.file).ends_with(".pck"):
		return {}
	return {"file": e.file, "size": int(e.size), "sha256": e.sha256}


## Mounts a pack so its bake loads from its res:// path; true once mounted.
static func mount(pck_path: String) -> bool:
	var key := pck_path.get_file()
	if mounted.has(key):
		return true
	if not ProjectSettings.load_resource_pack(pck_path, false):
		return false
	mounted[key] = true
	return true


## Whether a cached pack is whole: its size and SHA-256 match the manifest.
static func cached_ok(path: String, entry: Dictionary) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var bytes := FileAccess.get_file_as_bytes(path)
	return bytes.size() == int(entry.size) and _sha256(bytes) == String(entry.sha256)


## Removes cached packs other than keep (older bakes of any zone at this tier).
static func prune_cache(keep: String) -> void:
	var stem := keep.get_slice(".", 0)
	for f in DirAccess.get_files_at(CACHE_DIR):
		if f != keep and f.get_slice(".", 0) == stem:
			DirAccess.remove_absolute(CACHE_DIR.path_join(f))


static func _sha256(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()
