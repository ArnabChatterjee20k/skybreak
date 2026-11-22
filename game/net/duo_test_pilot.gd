class_name DuoTestPilot
extends RefCounted
## Dev tool for tools/net/duo_browser_test.js: with the `duo_test` DevParam
## (debug builds only) it drives the Duo screen through its own buttons (sign in,
## host or join, picks, ready, start), then plays the local fighter with an AI
## (its inputs are sent like a human's) and prints `SKYBREAK_DUO {json}` lines:
## room code, connection, periodic net stats, every confirmed state hash, the end.

const PREFIX := "SKYBREAK_DUO "
const REPORT_EVERY := 300

static var _driving := false

var level: ZoneMatch
var driver: AIDriver
var burst_frame: int = -1
var burst_ms: int = 0
var _burst_done := false
var _hashes: Array = []
var _over := false
var _last_report := -1


static func enabled() -> bool:
	return DevParams.get_value("duo_test") != ""


static func report(event: String, data: Dictionary = {}) -> void:
	var line := {"event": event, "ms": Time.get_ticks_msec()}
	line.merge(data)
	print(PREFIX + JSON.stringify(line))


## Plays the Duo screen like a person would, from sign-in to start.
static func drive_lobby(screen: DuoScreen) -> void:
	if _driving:
		return
	_driving = true
	var role := DevParams.get_value("duo_test")
	var tree := screen.get_tree()
	var link := screen.link
	report("lobby", {"role": role})
	await _until(tree, func() -> bool: return not screen._restoring, 20.0)
	if not link.client.is_signed_in():
		screen.email_field.text = DevParams.get_value("email")
		screen.password_field.text = DevParams.get_value("password")
		screen.sign_in_button.pressed.emit()
		if not await _until(tree, link.client.is_signed_in, 20.0):
			report("error", {"what": "sign-in", "status": screen.status_label.text})
			return
	report("signed_in", {"user": link.client.user_id})
	if role == "host":
		screen.host_button.pressed.emit()
		if not await _until(tree, func() -> bool: return link.lobby_code != "", 20.0):
			report("error", {"what": "host", "status": screen.status_label.text})
			return
		report("code", {"code": link.lobby_code})
	else:
		screen.code_field.text = DevParams.get_value("code")
		screen.join_button.pressed.emit()
	if not await _until(tree, link.is_connected_to_partner, 90.0):
		report("error", {"what": "connect", "status": screen.status_label.text})
		return
	report("connected", {"peer": link.local_peer})
	var legend := StringName(DevParams.get_value("legend", "kael"))
	for i in LegendCatalog.ids().size():
		if link.setup["host_legend" if link.is_host() else "guest_legend"] == legend:
			break
		screen.step_legend(1)
	if link.is_host():
		for key: String in ["zone", "ai_count", "ai_level", "lives", "minutes"]:
			var wanted := DevParams.get_value(key)
			for i in 12:
				if wanted == "" or str(link.setup[key]) == wanted:
					break
				screen.step_setup(key, 1)
	report("picked", {"setup": JSON.parse_string(JSON.stringify(link.setup))})
	while screen.is_inside_tree() and screen.is_visible_in_tree() and not screen._launched:
		if not link.ready_flags[link.local_peer]:
			screen.ready_button.pressed.emit()
		if link.is_host() and link.both_ready():
			screen.start_button.pressed.emit()
			report("start_pressed")
		await tree.create_timer(0.5).timeout
	_driving = false


static func _until(tree: SceneTree, condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await tree.create_timer(0.1).timeout
	return true


func _init(zone_match: ZoneMatch) -> void:
	level = zone_match
	driver = AIDriver.new()
	driver.setup(level.player, int(DevParams.get_value("pilot_level", "4")))
	burst_frame = int(DevParams.get_value("burst_frame", "-1"))
	burst_ms = int(DevParams.get_value("burst_ms", "0"))
	level.net_session.hash_checked.connect(func(frame: int, value: int) -> void:
		_hashes.append([frame, "%016x" % value]))
	level.net_session.desynced.connect(func(frame: int, mine: int, theirs: int) -> void:
		report("desync", {"frame": frame, "mine": "%016x" % mine, "theirs": "%016x" % theirs}))
	report("match_loaded", {"player": level.player, "zone": String(level.zone_id),
		"fighters": level.sim.fighters.size(), "seed": level.sim.rng.seed})


## The local fighter's input this tick, from the pilot AI.
func local_input() -> FighterInput:
	return driver.next_input(level.sim)


func after_tick() -> void:
	var session := level.net_session
	if session == null:
		return
	if burst_frame > 0 and not _burst_done and session.frame >= burst_frame:
		_burst_done = true
		if session.transport is LaggyTransport:
			(session.transport as LaggyTransport).hold(burst_ms)
		report("burst", {"frame": session.frame, "ms": burst_ms})
	var flow := level.match_flow as DuoFlow
	var due := session.frame % REPORT_EVERY == 0 and session.frame != _last_report
	if due or (flow.phase == MatchFlow.Phase.MATCH_OVER and not _over):
		_last_report = session.frame
		report("stats", {"frame": session.frame, "rtt": roundi(session.rtt_ms), "rollbacks": session.rollbacks,
			"rollback_frames": session.rollback_frames, "max_depth": session.max_rollback_depth,
			"stalls": session.stalls, "sync_skips": session.sync_skips, "compared": session.hashes_compared,
			"matched_frame": session.matched_hash_frame, "desync": session.desync_frame,
			"lives": [flow.lives[0], flow.lives[1]], "phase": flow.phase, "fps": Engine.get_frames_per_second(),
			"hashes": _hashes})
		_hashes = []
	if flow.phase == MatchFlow.Phase.MATCH_OVER and not _over:
		_over = true
		report("over", {"frame": session.frame, "winning_team": flow.winning_team, "timed_out": flow.timed_out,
			"rollbacks": session.rollbacks, "max_depth": session.max_rollback_depth,
			"compared": session.hashes_compared, "desync": session.desync_frame})
