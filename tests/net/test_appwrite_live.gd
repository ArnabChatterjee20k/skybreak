extends GutTest
## Optional live smoke test against the real Appwrite project. Skipped unless
## SKYBREAK_TEST_EMAIL and SKYBREAK_TEST_PASSWORD are set; never prints them.

const EMAIL_VAR := "SKYBREAK_TEST_EMAIL"
const PASSWORD_VAR := "SKYBREAK_TEST_PASSWORD"


func should_skip_script():
	if OS.get_environment(EMAIL_VAR).is_empty() or OS.get_environment(PASSWORD_VAR).is_empty():
		return "live Appwrite test: set %s and %s to run it" % [EMAIL_VAR, PASSWORD_VAR]
	return false


func test_a_player_signs_in_creates_reads_and_deletes_a_lobby() -> void:
	var client: AppwriteClient = add_child_autofree(AppwriteClient.new())
	var error: String = await client.sign_in_with_email(
		OS.get_environment(EMAIL_VAR), OS.get_environment(PASSWORD_VAR))
	assert_eq(error, "", "sign-in")
	if error:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var code := AppwriteSignalling.new_code(rng)
	var created: Dictionary = await client.create_document(AppwriteSignalling.LOBBIES, code, {
		"code": code, "host": client.user_id, "guest": "", "status": "closed",
		"seed": 1, "ai_count": 1,
	}, AppwriteSignalling.lobby_permissions(client.user_id))
	assert_eq(created.error, "", "create lobby " + code)
	if created.error:
		await client.sign_out()
		return
	var read: Dictionary = await client.get_document(AppwriteSignalling.LOBBIES, code)
	assert_eq(read.error, "", "read lobby")
	assert_eq(read.body.get("host"), client.user_id)
	var deleted: Dictionary = await client.delete_document(AppwriteSignalling.LOBBIES, code)
	assert_eq(deleted.error, "", "delete lobby")
	await client.sign_out()
	assert_false(client.is_signed_in())
