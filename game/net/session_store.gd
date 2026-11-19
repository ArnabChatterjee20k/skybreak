class_name SessionStore
extends RefCounted
## "Remember me" for Duo sign-in: keeps the Appwrite session (never the password)
## in the OS user data dir, encrypted with a random per-install key.

const DEFAULT_PATH := "user://skybreak_session.cfg"
const DEFAULT_KEY_PATH := "user://skybreak_install.key"
const SECTION := "session"

var path: String
var key_path: String


func _init(session_path: String = DEFAULT_PATH, install_key_path: String = DEFAULT_KEY_PATH) -> void:
	path = session_path
	key_path = install_key_path


## Saves the output of AppwriteClient.export_session().
func save(session: Dictionary) -> Error:
	var config := ConfigFile.new()
	for key: String in ["cookies", "fallback_cookies", "user_id", "user_name"]:
		config.set_value(SECTION, key, session.get(key, ""))
	return config.save_encrypted_pass(path, _install_key())


## The saved session, or {} when there is none or it cannot be read.
func load_session() -> Dictionary:
	if not FileAccess.file_exists(path) or not FileAccess.file_exists(key_path):
		return {}
	var config := ConfigFile.new()
	if config.load_encrypted_pass(path, _install_key()) != OK:
		return {}
	var session := {}
	if config.has_section(SECTION):
		for key in config.get_section_keys(SECTION):
			session[key] = config.get_value(SECTION, key)
	return session


func has_session() -> bool:
	return FileAccess.file_exists(path)


func clear() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _install_key() -> String:
	if FileAccess.file_exists(key_path):
		var existing := FileAccess.get_file_as_string(key_path).strip_edges()
		if existing.length() == 64:
			return existing
	var key := Crypto.new().generate_random_bytes(32).hex_encode()
	var file := FileAccess.open(key_path, FileAccess.WRITE)
	if file:
		file.store_string(key)
	return key
