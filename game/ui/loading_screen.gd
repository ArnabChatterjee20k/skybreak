class_name LoadingScreen
extends Control
## Shown between the menus and a match while the level and the zone's voxel
## bake load on background threads (ResourceLoader.load_threaded_request), with
## the zone's name and a progress bar. On the web the bake's pack downloads
## first (download). When everything is in, calls done.

## Resource paths to load, in order of the bar's weight (all equal).
var paths: Array[String] = []
## Title on the screen (the zone's name).
var title := ""
## Called once every path has loaded: done.call(resources: Dictionary path -> Resource).
var done: Callable
## Last overall progress, 0..1.
var progress := 0.0
## Optional: fetches the bake's pack first; its bake path loads once it is done
## and is left out of done's resources if it fails.
var download: ZoneBakeDownload

var _bar: ProgressBar
var _label: Label
var _finished := false
var _waiting := false
var _note := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position = Vector2(-280, -40)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var heading := Label.new()
	heading.text = title.to_upper()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 34)
	box.add_child(heading)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.custom_minimum_size = Vector2(560, 18)
	box.add_child(_bar)
	_label = Label.new()
	_label.text = "LOADING"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	for p in paths:
		if download == null or p != download.bake:
			_request(p)
	if download != null:
		_waiting = true
		download.finished.connect(_on_downloaded, CONNECT_ONE_SHOT)
		add_child(download)


func _request(p: String) -> void:
	if ResourceLoader.load_threaded_request(p, "", true) != OK:
		push_warning("LoadingScreen: can't start loading %s" % p)


func _on_downloaded(ok: bool, _why: String) -> void:
	_waiting = false
	if ok:
		_request(download.bake)
	else:
		paths.erase(download.bake)
		_note = "  (ZONE DOWNLOAD FAILED: BUILDING IT HERE)"


func _process(_delta: float) -> void:
	if _finished:
		return
	var total := 0.0
	var all_in := not _waiting
	for p in paths:
		if _waiting and p == download.bake:
			continue
		var status := _status(p)
		total += status[1]
		all_in = all_in and status[0] != ResourceLoader.THREAD_LOAD_IN_PROGRESS
	progress = total / maxf(1.0, paths.size())
	if download != null and paths.has(download.bake):
		# The download is most of the wait: it takes 80% of the bar, loading the rest.
		progress = 0.8 * download.progress + 0.2 * progress
	if _waiting:
		_bar.value = progress * 100.0
		_label.text = "DOWNLOADING ZONE  %d%%" % roundi(download.progress * 100.0)
		return
	_bar.value = progress * 100.0
	_label.text = "LOADING  %d%%" % roundi(progress * 100.0) + _note
	if all_in:
		_finished = true
		var loaded := {}
		for p in paths:
			loaded[p] = ResourceLoader.load_threaded_get(p)
		if done.is_valid():
			done.call(loaded)


## [status, fraction] of one path's load.
static func _status(p: String) -> Array:
	var progress_out := []
	var status := ResourceLoader.load_threaded_get_status(p, progress_out)
	var fraction: float = progress_out[0] if not progress_out.is_empty() else 0.0
	if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		fraction = 1.0
	return [status, fraction]
