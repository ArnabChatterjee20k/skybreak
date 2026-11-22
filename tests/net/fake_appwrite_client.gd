extends AppwriteClient
## AppwriteClient with the HTTP layer replaced: records every call and answers
## from canned replies, so net tests never touch the network.

const SESSION_COOKIE := "a_session_6a113777000db893b12e"

## Every request: {method, path, headers, body (parsed JSON or null)}.
var calls: Array[Dictionary] = []
## "METHOD /path-prefix" -> {code, body, headers}; the longest matching prefix wins.
var replies: Dictionary = {}


## Answers like Appwrite does for a good email/password sign-in.
func accept_sign_in(id: String, name: String) -> void:
	replies["POST /account/sessions/email"] = {"code": 201,
		"body": {"$id": "session-1", "userId": id, "secret": ""},
		"headers": ["Set-Cookie: %s=cookie-%s; path=/; httponly" % [SESSION_COOKIE, id],
			"X-Fallback-Cookies: {\"%s\":\"cookie-%s\"}" % [SESSION_COOKIE, id]]}
	replies["GET /account"] = {"code": 200, "body": {"$id": id, "name": name, "email": id + "@example.com"}}


func calls_to(method: HTTPClient.Method, path_prefix: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for call in calls:
		if call.method == method and (call.path as String).begins_with(path_prefix):
			found.append(call)
	return found


func _send(method: HTTPClient.Method, url: String, headers: PackedStringArray,
		payload: String) -> Dictionary:
	var path := url.trim_prefix(endpoint)
	calls.append({"method": method, "path": path, "headers": headers,
		"body": JSON.parse_string(payload) if payload else null})
	var reply: Dictionary = {"code": 200, "body": {}}
	var best := -1
	var key_method: String = ["GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "TRACE", "CONNECT", "PATCH"][method]
	for key: String in replies:
		var prefix := key.trim_prefix(key_method + " ")
		if key.begins_with(key_method + " ") and path.begins_with(prefix) and prefix.length() > best:
			best = prefix.length()
			reply = replies[key]
	var body: Variant = reply.get("body", {})
	return {"result": HTTPRequest.RESULT_SUCCESS, "code": reply.get("code", 200),
		"headers": PackedStringArray(reply.get("headers", [])),
		"body": JSON.stringify(body).to_utf8_buffer()}
