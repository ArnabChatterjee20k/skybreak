class_name AppwriteClient
extends Node
## Minimal Appwrite REST client (HTTPRequest), so the same code runs on Windows
## and in the web build. Public client config only: the endpoint and project
## id are not secrets, and no API key ever goes in the game. Players sign in
## with email and password; only the session is kept, never the password.

const ENDPOINT := "https://sgp.cloud.appwrite.io/v1"
const PROJECT_ID := "6a113777000db893b12e"
## Skybreak's database in the shared project; every resource is skybreak-prefixed.
const DATABASE_ID := "skybreak"
## TablesDB (rows) responses; the skybreak database is a TablesDB database.
const RESPONSE_FORMAT := "1.8.0"
## A dead network fails a request instead of hanging the lobby.
const REQUEST_TIMEOUT_SECONDS := 30.0
## Dev builds only: env var (desktop) or URL parameter `appwrite` (web) that points
## the client at a local mock (tools/net/appwrite_mock.js). Ignored in release builds.
const ENDPOINT_OVERRIDE_ENV := "SKYBREAK_APPWRITE_ENDPOINT"

## Base URL every request goes to; ENDPOINT unless a dev build overrides it.
var endpoint: String = ENDPOINT

## Id of the signed-in user, empty before sign-in.
var user_id: String = ""
## Display name of the signed-in user (falls back to the email).
var user_name: String = ""
## Session cookies, sent back on every request (desktop has no cookie jar).
var _cookies: Dictionary = {}
var _fallback_cookies: String = ""


func _init() -> void:
	endpoint = endpoint_for_build()


## ENDPOINT, or a dev override in debug builds (never in a release export).
static func endpoint_for_build(debug: bool = OS.is_debug_build()) -> String:
	if not debug:
		return ENDPOINT
	var override := OS.get_environment(ENDPOINT_OVERRIDE_ENV)
	if override.is_empty():
		override = DevParams.get_value("appwrite")
	return override.trim_suffix("/") if override.begins_with("http") else ENDPOINT


func is_signed_in() -> bool:
	return not user_id.is_empty()


## Signs in with an email/password session. Returns "" or an error message.
func sign_in_with_email(email: String, password: String) -> String:
	clear_session()
	var response := await request(HTTPClient.METHOD_POST, "/account/sessions/email",
		{"email": email.strip_edges(), "password": password})
	if response.error:
		clear_session()
		return response.error
	user_id = response.body.get("userId", "")
	var account := await request(HTTPClient.METHOD_GET, "/account")
	user_name = _display_name(account.body, email.strip_edges())
	return ""


## Restores a saved session (see export_session()) and extends it. Returns "" or an error.
func restore_session(saved: Dictionary) -> String:
	clear_session()
	_cookies = (saved.get("cookies", {}) as Dictionary).duplicate()
	_fallback_cookies = saved.get("fallback_cookies", "")
	if _cookies.is_empty() and _fallback_cookies.is_empty():
		return "no saved session"
	await request(HTTPClient.METHOD_PATCH, "/account/sessions/current", {})
	var account := await request(HTTPClient.METHOD_GET, "/account")
	if account.error:
		clear_session()
		return account.error
	user_id = account.body.get("$id", "")
	user_name = _display_name(account.body, saved.get("user_name", ""))
	return ""


## Ends the session on the server (best effort) and forgets it locally.
func sign_out() -> void:
	if is_signed_in() or not _cookies.is_empty() or _fallback_cookies:
		await request(HTTPClient.METHOD_DELETE, "/account/sessions/current")
	clear_session()


func clear_session() -> void:
	user_id = ""
	user_name = ""
	_cookies.clear()
	_fallback_cookies = ""


## What a "Remember me" store keeps: session cookies and the player name, no password.
func export_session() -> Dictionary:
	return {"cookies": _cookies.duplicate(), "fallback_cookies": _fallback_cookies,
		"user_id": user_id, "user_name": user_name}


## Creates a row; id "" lets Appwrite pick one.
func create_row(table: String, id: String, data: Dictionary,
		permissions: Array = []) -> Dictionary:
	return await request(HTTPClient.METHOD_POST, _rows(table),
		{"rowId": id if id else "unique()", "data": data, "permissions": permissions})


func get_row(table: String, id: String) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, _rows(table) + "/" + id)


func update_row(table: String, id: String, data: Dictionary) -> Dictionary:
	return await request(HTTPClient.METHOD_PATCH, _rows(table) + "/" + id, {"data": data})


func delete_row(table: String, id: String) -> Dictionary:
	return await request(HTTPClient.METHOD_DELETE, _rows(table) + "/" + id)


## Lists rows ({total, rows}); queries are Appwrite JSON queries (see equal_query()).
func list_rows(table: String, queries: Array[Dictionary] = []) -> Dictionary:
	var parts: PackedStringArray = []
	for query in queries:
		parts.append("queries[]=" + JSON.stringify(query).uri_encode())
	var path := _rows(table)
	if not parts.is_empty():
		path += "?" + "&".join(parts)
	return await request(HTTPClient.METHOD_GET, path)


static func equal_query(attribute: String, value: Variant) -> Dictionary:
	return {"method": "equal", "attribute": attribute, "values": [value]}


static func order_ascending_query(attribute: String) -> Dictionary:
	return {"method": "orderAsc", "attribute": attribute}


## One REST call. Returns {code, body (Dictionary), error ("" on 2xx)}.
func request(method: HTTPClient.Method, path: String, body: Variant = null) -> Dictionary:
	var headers := PackedStringArray([
		"X-Appwrite-Project: " + PROJECT_ID,
		"Content-Type: application/json",
		"X-Appwrite-Response-Format: " + RESPONSE_FORMAT,
	])
	if not _cookies.is_empty() and not OS.has_feature("web"):
		var pairs: PackedStringArray = []
		for name: String in _cookies:
			pairs.append("%s=%s" % [name, _cookies[name]])
		headers.append("Cookie: " + "; ".join(pairs))
	# The browser never shows Set-Cookie to the page and sends no cross-site cookies
	# from fetch, so the web build authenticates with the fallback header alone.
	if _fallback_cookies:
		headers.append("X-Fallback-Cookies: " + _fallback_cookies)
	var payload := "" if body == null else JSON.stringify(body)
	var reply: Dictionary = await _send(method, endpoint + path, headers, payload)
	var code: int = reply.code
	_remember_cookies(reply.headers)
	var text := (reply.body as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if text else {}
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var message := ""
	if reply.result != HTTPRequest.RESULT_SUCCESS:
		message = "network error %d" % reply.result
	elif code < 200 or code >= 300:
		message = "%d %s" % [code, data.get("message", "")]
	return {"code": code, "body": data, "error": message}


## The HTTP layer, replaced in tests. Returns {result, code, headers, body (bytes)}.
func _send(method: HTTPClient.Method, url: String, headers: PackedStringArray,
		payload: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(http)
	var error := http.request(url, headers, method, payload)
	if error != OK:
		http.queue_free()
		return {"result": HTTPRequest.RESULT_CANT_CONNECT, "code": 0,
			"headers": PackedStringArray(), "body": PackedByteArray()}
	var result: Array = await http.request_completed
	http.queue_free()
	return {"result": result[0], "code": result[1], "headers": result[2], "body": result[3]}


func _rows(table: String) -> String:
	return "/tablesdb/%s/tables/%s/rows" % [DATABASE_ID, table]


func _display_name(account: Dictionary, fallback: String) -> String:
	var name: String = account.get("name", "")
	if name.is_empty():
		name = account.get("email", "")
	return name if name else fallback


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
