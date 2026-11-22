class_name DevParams
extends RefCounted
## Dev-only switches for the net tools: URL query parameters in a web build
## (`?appwrite=http://127.0.0.1:8787/v1&duo_test=host`), `--name=value` user args
## after `--` on desktop. Always empty in release builds.

static var _cache: Dictionary = {}
static var _loaded := false


## The value of name, or fallback when unset or in a release build.
static func get_value(name: String, fallback: String = "") -> String:
	if not OS.is_debug_build():
		return fallback
	if not _loaded:
		_loaded = true
		_cache = _read()
	return String(_cache.get(name, fallback))


## Replaces the parameters (tests).
static func override(values: Dictionary) -> void:
	_loaded = true
	_cache = values.duplicate()


static func _read() -> Dictionary:
	var out := {}
	if OS.has_feature("web") and ClassDB.class_exists(&"JavaScriptBridge"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		if search is String:
			for pair in (search as String).trim_prefix("?").split("&", false):
				out[pair.get_slice("=", 0).uri_decode()] = pair.get_slice("=", 1).uri_decode() if pair.contains("=") else "1"
		return out
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var pair := arg.trim_prefix("--")
			out[pair.get_slice("=", 0)] = pair.get_slice("=", 1) if pair.contains("=") else "1"
	return out
