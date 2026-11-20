extends GutTest
## T-UX2 regression: the owner's "ki blast not working". A real Q key event in a
## vs-AI zone_match must reach the sim, spawn a ki blast, draw it and sound it.

const SCENE := preload("res://game/levels/zone_match.tscn")


## Records the cues the match asks the AudioDirector for.
class CueLog:
	extends Node
	var cues: Array[StringName] = []

	func play(cue: StringName, _at: Vector3, _params: Dictionary = {}) -> void:
		cues.append(cue)

	func set_loop(_key: StringName, _cue: StringName, _intensity: float, _at: Vector3) -> void:
		pass

	func stop_loop(_key: StringName) -> void:
		pass

	func set_zone(_zone: StringName) -> void:
		pass


var _match: ZoneMatch
var _cues: CueLog


func before_each() -> void:
	_match = SCENE.instantiate()
	_match.configure({"fighters": [
		{"character": &"kael", "team": 0, "is_ai": false, "ai_level": 0},
		{"character": &"vexa", "team": 1, "is_ai": true, "ai_level": 3},
	]})
	add_child_autofree(_match)
	_match.set_physics_process(false)
	_match.set_process(false)
	# Rounds off so input counts at once; the rival stands still so nothing absorbs the shot.
	_match.match_flow.enabled = false
	_match.drivers[1] = null
	_cues = CueLog.new()
	add_child_autofree(_cues)
	_match.match_audio.director = _cues


func after_each() -> void:
	_key(KEY_Q, false)


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _step(ticks: int) -> void:
	for _i in ticks:
		_match.step_tick()
		_match.present_frame(1.0, 1.0 / 60.0)


func _blast_node(id: int) -> Node3D:
	return _match.weapon_layer.find_child("KiBlast%d" % id, false, false) as Node3D


func test_tapping_q_fires_a_visible_audible_ki_blast() -> void:
	var me := _match.sim.fighters[_match.player]
	var ki := me.ki
	_key(KEY_Q, true)
	_step(1)
	assert_eq(me.move_id(), &"ki/blast", "Q reached the sim as KI_BLAST")
	_key(KEY_Q, false)
	_step(KiBlasts.tap_move().startup_ticks)
	assert_eq(_match.sim.projectiles.size(), 1, "a ki blast is in flight")
	var blast := _match.sim.projectiles[0]
	assert_eq(blast.level, KiBlasts.TAP)
	assert_lt(me.ki, ki, "it cost ki")
	var node := _blast_node(blast.id)
	assert_not_null(node, "the view draws the blast")
	if node:
		assert_true(node.is_visible_in_tree())
		var at := node.global_position
		_step(2)
		assert_gt(node.global_position.distance_to(at), 0.5, "the visual flies every frame")
	assert_has(_cues.cues, &"ki_blast_fire", "the shot is heard")


func test_holding_q_fires_a_bigger_charged_blast() -> void:
	_key(KEY_Q, true)
	_step(KiBlasts.charged_move().startup_ticks + 1)
	_key(KEY_Q, false)
	assert_eq(_match.sim.projectiles.size(), 1)
	var blast := _match.sim.projectiles[0]
	assert_eq(blast.level, KiBlasts.CHARGED)
	var node := _blast_node(blast.id)
	assert_not_null(node)
	if node:
		assert_true(node.is_visible_in_tree())


func test_the_blast_lands_on_the_rival_with_its_impact_cue() -> void:
	_key(KEY_Q, true)
	_step(1)
	_key(KEY_Q, false)
	var health := _match.sim.fighters[1].health
	for _i in 90:
		_step(1)
		if _match.sim.fighters[1].health < health:
			break
	assert_lt(_match.sim.fighters[1].health, health, "the rival took the blast")
	assert_has(_cues.cues, &"ki_blast_impact")
