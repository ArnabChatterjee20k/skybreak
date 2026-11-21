extends GutTest
## VOXEL-WEB size: the web build ships no zone bake in index.pck; each zone's
## WEB bake is a pack fetched over HTTP behind the loading screen. Packing
## refuses stale bakes, a pack holds the bake byte for byte, and the download
## checks, caches and mounts it.

const STUB := "res://tests/world/stub_baked_zone.gd"
const PRESETS_PATH := "res://export_presets.cfg"
const TMP := "user://test_zone_bake_packs/"
const WEB := GraphicsSettings.Quality.WEB

var _saved_remote: bool


class StaticServer extends Node:
	## A tiny HTTP/1.0 file server on 127.0.0.1 for download tests.
	var files := {}
	var requests: Array[String] = []
	var port := 0
	var _tcp := TCPServer.new()
	var _peers: Array[StreamPeerTCP] = []
	var _bufs: Array[PackedByteArray] = []
	var _sending: Array = []

	func _ready() -> void:
		for p in range(18450, 18550):
			if _tcp.listen(p, "127.0.0.1") == OK:
				port = p
				return

	func _process(_delta: float) -> void:
		while _tcp.is_connection_available():
			_peers.append(_tcp.take_connection())
			_bufs.append(PackedByteArray())
		for i in range(_peers.size() - 1, -1, -1):
			var peer := _peers[i]
			peer.poll()
			var n := peer.get_available_bytes()
			if n > 0:
				_bufs[i].append_array(peer.get_data(n)[1])
			var text := _bufs[i].get_string_from_ascii()
			if not text.contains("\r\n\r\n"):
				continue
			var path := text.get_slice(" ", 1).uri_decode()
			requests.append(path)
			var body: PackedByteArray = files.get(path, PackedByteArray())
			var head := "HTTP/1.0 %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [
				"200 OK" if files.has(path) else "404 Not Found", body.size()]
			var reply := head.to_ascii_buffer()
			reply.append_array(body)
			_sending.append([peer, reply])
			_peers.remove_at(i)
			_bufs.remove_at(i)
		for i in range(_sending.size() - 1, -1, -1):
			var peer: StreamPeerTCP = _sending[i][0]
			var reply: PackedByteArray = _sending[i][1]
			peer.poll()
			var sent: Array = peer.put_partial_data(reply)
			reply = reply.slice(int(sent[1]))
			_sending[i][1] = reply
			if reply.is_empty() or sent[0] != OK:
				peer.disconnect_from_host()
				_sending.remove_at(i)

	func _exit_tree() -> void:
		_tcp.stop()


func before_all() -> void:
	_saved_remote = ZoneBakePacks.remote


func after_all() -> void:
	ZoneBakePacks.remote = _saved_remote
	_remove_tree(TMP)
	_remove_tree(ZoneBakePacks.CACHE_DIR)


func _remove_tree(dir: String) -> void:
	for d in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _filter(platform: String) -> PackedStringArray:
	var config := ConfigFile.new()
	assert_eq(config.load(PRESETS_PATH), OK, "export_presets.cfg loads")
	for section in config.get_sections():
		if config.get_value(section, "platform", "") == platform:
			var out := PackedStringArray()
			for f in String(config.get_value(section, "exclude_filter", "")).split(","):
				if f.strip_edges() != "":
					out.append(f.strip_edges())
			return out
	return PackedStringArray()


## Whether the export's exclude filter drops res:// path (Godot matches it with and without res://).
static func _excluded(filters: PackedStringArray, path: String) -> bool:
	for f in filters:
		if path.matchn(f) or path.trim_prefix("res://").matchn(f):
			return true
	return false


## A stub zone baked for a zone id and tier, saved under TMP; returns its file.
func _stub_bake(zone_id: StringName, tier: GraphicsSettings.Quality, hashed_as := STUB) -> String:
	var saved := VoxelQuality.tier
	VoxelQuality.tier = tier
	var zone := (load(STUB) as GDScript).new() as VoxelZone
	add_child(zone)
	zone.build()
	var scene := VoxelZoneBake.pack(zone, zone_id, tier, hashed_as, 1)
	zone.free()
	VoxelQuality.tier = saved
	DirAccess.make_dir_recursive_absolute(TMP)
	var path := TMP + "%s_%d.scn" % [zone_id, tier]
	assert_eq(ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS), OK)
	return path


func test_the_web_pck_leaves_out_every_zone_bake_and_the_desktop_keeps_its_tiers() -> void:
	var web := _filter("Web")
	var desktop := _filter("Windows Desktop")
	assert_false(web.is_empty())
	for id: StringName in VoxelZoneView.BUILDERS:
		for tier in VoxelZoneBake.TIERS:
			var bake := VoxelZoneBake.path_for(id, tier)
			assert_true(_excluded(web, bake), "web index.pck leaves out %s (it ships as a zone pack)" % bake)
			assert_eq(_excluded(desktop, bake), tier == WEB, "desktop ships %s: %s" % [bake, tier != WEB])


func test_the_web_pck_leaves_out_look_dev_reports_tools_and_renders() -> void:
	var web := _filter("Web")
	for path in ["res://game/lookdev/moves_reel.gd", "res://reports/qa/x/clip.mp4", "res://tools/web/pack_zone_bakes.gd",
			"res://game/characters/motion/renders/pass2/kael_sheet.png", "res://docs/GAME_DESIGN.md",
			"res://tests/web/test_zone_bake_packs.gd", "res://game/audio/music/preview/preview_menu.ogg"]:
		assert_true(_excluded(web, path), "web leaves out %s" % path)
	for path in ["res://game/world/zone_bake_packs.gd", "res://game/world/zone_bake_download.gd",
			"res://game/ui/menus/zone_cards/ember_rift.png", "res://game/characters/voxel_kit/baked/kael_voxel_design.res",
			"res://game/world/voxel_zone_kit/voxel_zone_bake.gd", "res://game/audio/music/tracks/menu.ogg"]:
		assert_false(_excluded(web, path), "web keeps %s" % path)


func test_packing_refuses_a_missing_stale_or_other_tier_bake() -> void:
	var out := TMP + "refuse"
	assert_string_contains(String(ZoneBakePacks.pack_zone(out, &"gut_none", WEB, STUB, TMP + "nope.scn").error), "no bake")
	var stale := _stub_bake(&"gut_stale", WEB, VoxelZoneView.BUILDERS[&"ember_rift"])
	assert_string_contains(String(ZoneBakePacks.pack_zone(out, &"gut_stale", WEB, STUB, stale).error), "stale")
	var high := _stub_bake(&"gut_high", GraphicsSettings.Quality.HIGH)
	assert_true(ZoneBakePacks.pack_zone(out, &"gut_high", WEB, STUB, high).has("error"), "a HIGH bake isn't a WEB pack")
	assert_false(DirAccess.dir_exists_absolute(out.path_join(ZoneBakePacks.DIR)) \
		and not DirAccess.get_files_at(out.path_join(ZoneBakePacks.DIR)).is_empty(), "nothing packed")


func test_a_mounted_pack_loads_the_same_bake_at_its_res_path() -> void:
	var src := _stub_bake(&"gut_mount", WEB)
	var out := TMP + "mount"
	var e := ZoneBakePacks.pack_zone(out, &"gut_mount", WEB, STUB, src)
	assert_false(e.has("error"), str(e))
	var bake := VoxelZoneBake.path_for(&"gut_mount", WEB)
	assert_eq(e.bake, bake)
	assert_string_starts_with(String(e.file), "gut_mount_web.")
	assert_false(ResourceLoader.exists(bake))
	assert_true(ZoneBakePacks.mount(out.path_join(ZoneBakePacks.DIR).path_join(e.file)))
	assert_true(ResourceLoader.exists(bake))
	assert_eq(FileAccess.get_file_as_bytes(bake), FileAccess.get_file_as_bytes(src), "byte for byte")
	assert_eq(VoxelZoneBake.check(&"gut_mount", WEB, STUB), "", "the mounted bake passes the stale check")
	var zone := VoxelZoneBake.instantiate(&"gut_mount", WEB, STUB)
	assert_not_null(zone)
	if zone != null:
		assert_eq(zone.get("lamps").size(), 3)
		zone.free()


func test_the_manifest_names_each_pack_with_its_size_and_hash() -> void:
	var src := _stub_bake(&"gut_manifest", WEB)
	var out := TMP + "manifest"
	var e := ZoneBakePacks.pack_zone(out, &"gut_manifest", WEB, STUB, src)
	var entries: Array[Dictionary] = [e]
	assert_eq(ZoneBakePacks.write_manifest(out, entries), OK)
	var text := FileAccess.get_file_as_string(out.path_join(ZoneBakePacks.DIR).path_join(ZoneBakePacks.MANIFEST))
	var got := ZoneBakePacks.entry_in(text, e.bake)
	assert_eq(got, {"file": e.file, "size": e.size, "sha256": e.sha256})
	assert_eq(ZoneBakePacks.entry_in(text, VoxelZoneBake.path_for(&"other", WEB)), {})
	assert_eq(ZoneBakePacks.entry_in(text.replace("\"version\": %d" % VoxelZoneBake.VERSION, "\"version\": 0"), e.bake), {},
		"another bake layout is refused")
	assert_eq(ZoneBakePacks.entry_in(text.replace(String(e.file), "../evil.pck"), e.bake), {}, "no paths in file names")


func _serve(out: String) -> StaticServer:
	var server := StaticServer.new()
	var dir := out.path_join(ZoneBakePacks.DIR)
	for f in DirAccess.get_files_at(dir):
		server.files["/%s/%s" % [ZoneBakePacks.DIR, f]] = FileAccess.get_file_as_bytes(dir.path_join(f))
	add_child_autofree(server)
	return server


func _download(bake: String, port: int) -> Array:
	var dl := ZoneBakeDownload.new(bake)
	dl.base_url = "http://127.0.0.1:%d/" % port
	var result := []
	dl.finished.connect(func(ok: bool, why: String) -> void: result.append_array([ok, why]))
	add_child_autofree(dl)
	var frames := 0
	while result.is_empty() and frames < 1200:
		await get_tree().process_frame
		frames += 1
	assert_eq(dl.progress, 1.0)
	return result


func _packed(zone_id: StringName, out: String) -> Dictionary:
	var e := ZoneBakePacks.pack_zone(out, zone_id, WEB, STUB, _stub_bake(zone_id, WEB))
	var entries: Array[Dictionary] = [e]
	ZoneBakePacks.write_manifest(out, entries)
	return e


func test_a_download_fetches_checks_caches_and_mounts_the_pack() -> void:
	var out := TMP + "download"
	var e := _packed(&"gut_download", out)
	var server := _serve(out)
	assert_ne(server.port, 0, "test server listens")
	var result: Array = await _download(e.bake, server.port)
	assert_eq(result, [true, ""])
	assert_true(ResourceLoader.exists(e.bake))
	assert_true(FileAccess.file_exists(ZoneBakePacks.CACHE_DIR.path_join(e.file)), "kept for the next visit")
	assert_eq(server.requests, ["/zones/manifest.json", "/zones/" + String(e.file)])
	assert_not_null(VoxelZoneBake.instantiate(&"gut_download", WEB, STUB), "its bake loads")


func test_a_cached_pack_is_not_downloaded_again() -> void:
	var out := TMP + "cached"
	var e := _packed(&"gut_cached", out)
	DirAccess.make_dir_recursive_absolute(ZoneBakePacks.CACHE_DIR)
	DirAccess.copy_absolute(out.path_join(ZoneBakePacks.DIR).path_join(e.file), ZoneBakePacks.CACHE_DIR.path_join(e.file))
	var older := ZoneBakePacks.CACHE_DIR.path_join("gut_cached_web.000000000000.pck")
	FileAccess.open(older, FileAccess.WRITE).store_string("old")
	var server := _serve(out)
	var result: Array = await _download(e.bake, server.port)
	assert_eq(result, [true, ""])
	assert_eq(server.requests, ["/zones/manifest.json"], "only the manifest")
	assert_false(FileAccess.file_exists(older), "older packs of the zone are pruned")


func test_a_damaged_or_missing_pack_fails_and_leaves_nothing_behind() -> void:
	var out := TMP + "damaged"
	var e := _packed(&"gut_damaged", out)
	var server := _serve(out)
	var key := "/zones/" + String(e.file)
	var bytes: PackedByteArray = server.files[key]
	bytes[bytes.size() - 1] ^= 0xff
	server.files[key] = bytes
	var result: Array = await _download(e.bake, server.port)
	assert_eq(result[0], false)
	assert_string_contains(String(result[1]), "damaged")
	assert_false(ResourceLoader.exists(e.bake))
	assert_false(FileAccess.file_exists(ZoneBakePacks.CACHE_DIR.path_join(e.file)))
	assert_false(FileAccess.file_exists(ZoneBakePacks.CACHE_DIR.path_join(String(e.file) + ".part")))
	server.files.clear()
	result = await _download(VoxelZoneBake.path_for(&"gut_nothing", WEB), server.port)
	assert_eq(result[0], false, "no manifest: the zone builds live")


func test_the_loading_screen_downloads_the_bake_before_loading_it() -> void:
	var out := TMP + "screen"
	var e := _packed(&"gut_screen", out)
	var server := _serve(out)
	var dl := ZoneBakeDownload.new(e.bake)
	dl.base_url = "http://127.0.0.1:%d/" % server.port
	var screen := LoadingScreen.new()
	screen.paths.assign(["res://game/world/zones/ember_rift.tres", e.bake])
	screen.download = dl
	var got := {}
	screen.done = func(loaded: Dictionary) -> void: got.merge(loaded)
	add_child_autofree(screen)
	var frames := 0
	while got.is_empty() and frames < 1200:
		await get_tree().process_frame
		frames += 1
	assert_eq(got.size(), 2)
	assert_true(got.get(e.bake) is PackedScene, "the downloaded bake loaded")
	assert_almost_eq(screen.progress, 1.0, 0.0001)


func test_on_the_web_a_match_asks_for_the_web_bake_it_will_download() -> void:
	var config := get_node(^"/root/MatchConfig")
	var saved_zone: StringName = config.zone
	var saved_style := ArtStyle.current()
	ArtStyle.set_current(ArtStyle.Kind.VOXEL)
	config.zone = &"ember_rift"
	ZoneBakePacks.remote = true
	var bake := VoxelZoneBake.path_for(&"ember_rift", GraphicsSettings.load_saved().quality)
	assert_eq(config.zone_bake_path(), bake if bake.ends_with("_web.scn") or ResourceLoader.exists(bake) else "")
	assert_true(ZoneBakePacks.downloadable(VoxelZoneBake.path_for(&"ember_rift", WEB)))
	assert_false(ZoneBakePacks.downloadable(VoxelZoneBake.path_for(&"ember_rift", GraphicsSettings.Quality.HIGH)))
	ZoneBakePacks.remote = false
	assert_false(ZoneBakePacks.downloadable(VoxelZoneBake.path_for(&"ember_rift", WEB)), "desktop never downloads")
	ZoneBakePacks.remote = _saved_remote
	config.zone = saved_zone
	ArtStyle.set_current(saved_style)
