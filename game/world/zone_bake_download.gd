class_name ZoneBakeDownload
extends Node
## Fetches and mounts one zone bake's pack for the web build (ZoneBakePacks):
## reads zones/manifest.json next to the page, reuses a whole cached pack or
## downloads it, checks size and SHA-256, keeps it in user:// and mounts it. Emits
## finished(ok, why) once; on failure the zone builds live, as without a bake.

signal finished(ok: bool, why: String)

## The bake to make loadable (VoxelZoneBake.path_for).
var bake := ""
## URL of the folder holding index.html, ending in "/"; "" = the page's folder.
var base_url := ""
## Overall progress, 0..1 (the manifest counts as 5%).
var progress := 0.0

var _http: HTTPRequest
var _entry := {}
var _done := false


func _init(bake_path := "") -> void:
	bake = bake_path


func _ready() -> void:
	if base_url == "":
		base_url = page_folder()
	if ResourceLoader.exists(bake):
		_finish(true, "")
		return
	_http = HTTPRequest.new()
	_http.accept_gzip = false
	# Packs are 15-57 MB: read up to 4 MiB a frame, not the 64 KiB default.
	_http.download_chunk_size = 4 << 20
	add_child(_http)
	_http.request_completed.connect(_on_manifest, CONNECT_ONE_SHOT)
	_request(base_url + ZoneBakePacks.DIR + "/" + ZoneBakePacks.MANIFEST)


func _process(_delta: float) -> void:
	if _done or _entry.is_empty() or _http == null:
		return
	var total := maxi(1, int(_entry.size))
	progress = 0.05 + 0.95 * clampf(float(_http.get_downloaded_bytes()) / total, 0.0, 1.0)


## The folder of the page the web build runs in, ending in "/" ("" off the web).
static func page_folder() -> String:
	if not OS.has_feature("web"):
		return ""
	var href := str(JavaScriptBridge.eval("window.location.href", true))
	href = href.get_slice("#", 0).get_slice("?", 0)
	return href.substr(0, href.rfind("/") + 1)


func _request(url: String) -> void:
	var err := _http.request(url)
	if err != OK:
		_finish(false, "can't request %s (%s)" % [url, error_string(err)])


func _on_manifest(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_finish(false, "no zone manifest (result %d, HTTP %d)" % [result, code])
		return
	_entry = ZoneBakePacks.entry_in(body.get_string_from_utf8(), bake)
	if _entry.is_empty():
		_finish(false, "the manifest has no pack for %s" % bake)
		return
	progress = 0.05
	DirAccess.make_dir_recursive_absolute(ZoneBakePacks.CACHE_DIR)
	var path := _cache_path()
	if ZoneBakePacks.cached_ok(path, _entry):
		_mount(path)
		return
	_http.request_completed.connect(_on_pack, CONNECT_ONE_SHOT)
	_request(base_url + ZoneBakePacks.DIR + "/" + String(_entry.file).uri_encode())


func _on_pack(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_finish(false, "downloading %s failed (result %d, HTTP %d)" % [_entry.file, result, code])
		return
	if not ZoneBakePacks.whole(body, _entry):
		_finish(false, "%s arrived damaged (%d bytes, expected %d, or SHA-256 differs)" % [_entry.file, body.size(),
			int(_entry.size)])
		return
	# Written here, not via HTTPRequest.download_file: on the web that leaves an empty file.
	var f := FileAccess.open(_cache_path(), FileAccess.WRITE)
	if f == null:
		_finish(false, "can't keep %s (%s)" % [_entry.file, error_string(FileAccess.get_open_error())])
		return
	f.store_buffer(body)
	f.close()
	_mount(_cache_path())


func _mount(path: String) -> void:
	ZoneBakePacks.prune_cache(path.get_file())
	if not ZoneBakePacks.mount(path) or not ResourceLoader.exists(bake):
		_finish(false, "mounting %s failed" % path.get_file())
		return
	_finish(true, "")


func _cache_path() -> String:
	return ZoneBakePacks.CACHE_DIR.path_join(String(_entry.file))


func _finish(ok: bool, why: String) -> void:
	if _done:
		return
	_done = true
	progress = 1.0
	if not ok:
		push_warning("ZoneBakeDownload: %s; the zone builds live" % why)
	finished.emit(ok, why)
