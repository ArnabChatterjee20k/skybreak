class_name AppwriteClient
extends Node
## Minimal Appwrite REST client (HTTPRequest), so the same code runs on Windows
## and in the web build. Public client config only: the endpoint and project
## id are not secrets, and no API key ever goes in the game.

const ENDPOINT := "https://sgp.cloud.appwrite.io/v1"
const PROJECT_ID := "6a113777000db893b12e"
## Skybreak's database in the shared project; every resource is skybreak-prefixed.
const DATABASE_ID := "skybreak"

## Id of the signed-in user, empty before sign-in.
var user_id: String = ""
## Session cookies, sent back on every request (desktop has no cookie jar).
var _cookies: Dictionary = {}
var _fallback_cookies: String = ""


## Signs in anonymously (Auth > Anonymous must be enabled). Returns "" or an error message.
func sign_in_anonymously() -> String:
	var response := await request(HTTPClient.METHOD_POST, "/account/sessions/anonymous", {})
	if response.error:
		return response.error
	user_id = response.body.get("userId", "")
	return ""


## Creates a document; id "" lets Appwrite pick one.
func create_document(collection: String, id: String, data: Dictionary,
		permissions: Array = []) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, _documents(collection),
		{"documentId": id if id else "unique()", "data": data, "permissions": permissions})


func get_document(collection: String, id: String) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, _documents(collection) + "/" + id)


func update_document(collection: String, id: String, data: Dictionary) -> Dictionary:
	return await request(HTTPClient.METHOD_PATCH, _documents(collection) + "/" + id, {"data": data})


func delete_document(collection: String, id: String) -> Dictionary:
	return await request(HTTPClient.METHOD_DELETE, _documents(collection) + "/" + id)


## Lists documents; queries are Appwrite JSON queries (see equal_query()).
func list_documents(collection: String, queries: Array[Dictionary] = []) -> Dictionary:
	var parts: PackedStringArray = []
	for query in queries:
		parts.append("queries[]=" + JSON.stringify(query).uri_encode())
	var path := _documents(collection)
	if not parts.is_empty():
		path += "?" + "&".join(parts)
	return await request(HTTPClient.METHOD_GET, path)


static func equal_query(attribute: String, value: Variant) -> Dictionary:
	return {"method": "equal", "attribute": attribute, "values": [value]}


static func order_ascending_query(attribute: String) -> Dictionary:
	return {"method": "orderAsc", "attribute": attribute}


## One REST call. Returns {code, body (Dictionary), error ("" on 2xx)}.
func request(method: HTTPClient.Method, path: String, body: Variant = null) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray([
		"X-Appwrite-Project: " + PROJECT_ID,
		"Content-Type: application/json",
		"X-Appwrite-Response-Format: 1.6.0",
	])
	if not _cookies.is_empty() and not OS.has_feature("web"):
		var pairs: PackedStringArray = []
		for name: String in _cookies:
			pairs.append("%s=%s" % [name, _cookies[name]])
		headers.append("Cookie: " + "; ".join(pairs))
	if _fallback_cookies:
		headers.append("X-Fallback-Cookies: " + _fallback_cookies)
	var payload := "" if body == null else JSON.stringify(body)
	var error := http.request(ENDPOINT + path, headers, method, payload)
	if error != OK:
		http.queue_free()
		return {"code": 0, "body": {}, "error": "request failed (%s)" % error_string(error)}
	var result: Array = await http.request_completed
	http.queue_free()
	var code: int = result[1]
	_remember_cookies(result[2])
	var text := (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if text else {}
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var message := ""
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		message = "network error %d" % result[0]
	elif code < 200 or code >= 300:
		message = "%d %s" % [code, data.get("message", "")]
	return {"code": code, "body": data, "error": message}


func _documents(collection: String) -> String:
	return "/databases/%s/collections/%s/documents" % [DATABASE_ID, collection]


func _remember_cookies(headers: PackedStringArray) -> void:
	for header in headers:
		var lower := header.to_lower()
		if lower.begins_with("set-cookie:"):
			var pair := header.substr(11).strip_edges().get_slice(";", 0)
			var name := pair.get_slice("=", 0)
			if name.begins_with("a_session_"):
				_cookies[name] = pair.substr(name.length() + 1)
		elif lower.begins_with("x-fallback-cookies:"):
			_fallback_cookies = header.substr(19).strip_edges()
