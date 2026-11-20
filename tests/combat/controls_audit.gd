extends SceneTree
## T-UX2 controls audit: for each legend, goes through the real front end to a
## vs-AI zone_match, then drives every GAME_DESIGN §3 control with real
## InputEvents (keys, mouse buttons, wheel) through KeyboardMouseInput and
## reports the sim effect, the player's character clips and the audio cues.
## godot --headless --path . -s res://tests/combat/controls_audit.gd [-- legend ...]

const UNIT := FighterState.METER_UNIT
const LMB := -MOUSE_BUTTON_LEFT
const RMB := -MOUSE_BUTTON_RIGHT
const MMB := -MOUSE_BUTTON_MIDDLE
const WHEEL_DOWN := -MOUSE_BUTTON_WHEEL_DOWN
const WHEEL_UP := -MOUSE_BUTTON_WHEEL_UP


## Records the cues the match asks the AudioDirector for.
class CueLog:
	extends Node
	var cues: Array[StringName] = []

	func play(cue: StringName, _at: Vector3, _params: Dictionary = {}) -> void:
		cues.append(cue)

	func set_loop(key: StringName, cue: StringName, _i: float, _at: Vector3) -> void:
		if not cues.has(cue):
			cues.append(cue)

	func stop_loop(_key: StringName) -> void:
		pass

	func set_zone(_zone: StringName) -> void:
		pass


## Opponent input: presses held_bits on chosen ticks (relative to the scenario start).
class Scripted:
	extends RefCounted
	var start := 0
	var plan: Dictionary = {} # tick -> held bits
	var previous := FighterInput.new()

	func next_input(sim: CombatSim) -> FighterInput:
		var held: int = plan.get(sim.current_tick - start, 0)
		var input := FighterInput.from_held(held, previous)
		previous = input
		return input


var _legends: Array = []
var _front: Node
var _level: ZoneMatch
var _cues: CueLog
var _frame := 0
var _phase := "boot"
var _results: Dictionary = {} # action -> legend -> verdict
var _order: Array[String] = []


func _initialize() -> void:
	_legends = Array(OS.get_cmdline_user_args())
	if _legends.is_empty():
		_legends = ["kael", "vexa", "brann", "lyra"]
	_boot_menu()


func _boot_menu() -> void:
	_front = (load("res://game/ui/menus/front_end.tscn") as PackedScene).instantiate()
	_front.set("skip_splash", true)
	root.add_child(_front)
	current_scene = _front
	_frame = 0
	_phase = "menu"


func _process(_delta: float) -> bool:
	_frame += 1
	match _phase:
		"menu":
			if _frame == 3:
				_front.screens[&"main"].buttons[&"vs_ai"].pressed.emit()
				var select = _front.screens[&"character_select"]
				select.slots[0].character = StringName(_legends[0])
				select.confirm()
				_front.screens[&"zone_select"]._fight()
				_phase = "loading"
		"loading":
			if current_scene is ZoneMatch:
				_level = current_scene
				_frame = 0
				_phase = "ready"
		"ready":
			if _frame == 3:
				_run_legend(String(_legends[0]))
				_legends.pop_front()
				if _legends.is_empty():
					_print_table()
					quit(0)
				else:
					current_scene.queue_free()
					_boot_menu()
	return false


func _send(code: int, down: bool) -> void:
	var event: InputEvent
	if code < 0:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = -code as MouseButton
		mouse.pressed = down
		event = mouse
	else:
		var key := InputEventKey.new()
		key.physical_keycode = code as Key
		key.keycode = code as Key
		key.pressed = down
		event = key
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _run_legend(legend: String) -> void:
	var view := _level.fighter_views[_level.player]
	print("== %s (zone %s, player %d, character %s)" % [legend, _level.zone_id, _level.player, view.character_id])
	_level.set_physics_process(false)
	_level.set_process(false)
	_level.match_flow.enabled = false
	_cues = CueLog.new()
	root.add_child(_cues)
	_level.match_audio.director = _cues
	for scenario in _scenarios():
		var verdict := _run(scenario)
		if not _order.has(scenario.name):
			_order.append(scenario.name)
		if not _results.has(scenario.name):
			_results[scenario.name] = {}
		_results[scenario.name][legend] = verdict
		print("  %-26s %s" % [scenario.name, verdict])
	_cues.queue_free()


## Each scenario: name, keys [[tick, code, down]], ticks, check (Callable(log) -> String or ""),
## optional setup (Callable), opponent plan, distance.
func _scenarios() -> Array[Dictionary]:
	var A := FighterInput.Action
	var list: Array[Dictionary] = []
	list.append({"name": "move (W)", "keys": [[0, KEY_W, true], [20, KEY_W, false]], "ticks": 24,
		"check": func(l): return "" if l.moved > 1.0 and l.states.has("MOVING") else "no movement"})
	list.append({"name": "ascend (Space)", "keys": [[0, KEY_SPACE, true], [30, KEY_SPACE, false]], "ticks": 32,
		"check": func(l): return "" if l.rise > 1.0 else "did not rise"})
	list.append({"name": "descend (Left Ctrl)", "keys": [[0, KEY_SPACE, true], [30, KEY_SPACE, false], [32, KEY_CTRL, true], [60, KEY_CTRL, false]], "ticks": 62,
		"check": func(l): return "" if l.drop > 0.5 else "did not descend"})
	list.append({"name": "light (LMB)", "keys": [[0, LMB, true], [2, LMB, false]], "ticks": 25,
		"check": func(l): return _has_move(l, "light_1")})
	for heavy in [["smash (RMB)", [], "smash"], ["breaker (W+RMB)", [KEY_W], "breaker"],
			["launcher (S+RMB)", [KEY_S], "launcher"], ["rising (Space+RMB)", [KEY_SPACE], "rising"],
			["spike (Ctrl+RMB)", [KEY_CTRL], "spike"], ["sweep (A+RMB)", [KEY_A], "sweep"]]:
		var keys: Array = []
		for k in heavy[1]:
			keys.append([0, k, true])
			keys.append([4, k, false])
		keys.append([1, RMB, true])
		keys.append([3, RMB, false])
		var slot: String = heavy[2]
		list.append({"name": heavy[0], "keys": keys, "ticks": 45,
			"check": func(l): return _has_move(l, slot)})
	list.append({"name": "hold heavy (RMB)", "keys": [[0, RMB, true], [70, RMB, false]], "ticks": 110,
		"check": func(l): return _has_move(l, "charged_smash")})
	list.append({"name": "block (E)", "keys": [[0, KEY_E, true], [20, KEY_E, false]], "ticks": 22,
		"check": func(l): return "" if l.states.has("BLOCKING") else "no BLOCKING"})
	list.append({"name": "perfect block (tap E)", "keys": [[8, KEY_E, true], [9, KEY_E, false]], "ticks": 40,
		"distance": 1.6, "opponent": {5: A.LIGHT},
		"check": func(l): return "" if l.events.has("PERFECT_BLOCK") else "no PERFECT_BLOCK (events %s)" % [l.events]})
	list.append({"name": "dash (Shift+D)", "keys": [[0, KEY_D, true], [1, KEY_SHIFT, true], [3, KEY_SHIFT, false], [10, KEY_D, false]], "ticks": 30,
		"check": func(l): return "" if l.states.has("DASHING") else "no DASHING"})
	list.append({"name": "rush dash (Shift+W, locked)", "keys": [[0, KEY_W, true], [1, KEY_SHIFT, true], [3, KEY_SHIFT, false], [10, KEY_W, false]], "ticks": 40,
		"check": func(l): return "" if l.dash_kinds.has("RUSH") else "no RUSH (kinds %s)" % [l.dash_kinds]})
	list.append({"name": "grab (F)", "keys": [[0, KEY_F, true], [2, KEY_F, false]], "ticks": 80, "distance": 1.4,
		"check": func(l): return "" if l.events.has("GRAB") else "no GRAB (moves %s)" % [l.moves]})
	list.append({"name": "pick up (G)", "keys": [[0, KEY_G, true], [2, KEY_G, false]], "ticks": 15, "pickup": [Weapon.Kind.STORM_BLADE],
		"check": func(l): return "" if l.events.has("PICKUP") else "no PICKUP"})
	list.append({"name": "throw (G/V armed)", "keys": [[0, KEY_G, true], [2, KEY_G, false], [20, KEY_V, true], [22, KEY_V, false]], "ticks": 40, "pickup": [Weapon.Kind.STORM_BLADE],
		"check": func(l): return "" if l.events.has("WEAPON_THROW") else "no WEAPON_THROW"})
	list.append({"name": "cycle weapons (B/Z)", "keys": [[0, KEY_G, true], [2, KEY_G, false], [12, KEY_B, true], [14, KEY_B, false], [40, KEY_Z, true], [42, KEY_Z, false]], "ticks": 60, "pickup": [Weapon.Kind.STORM_BLADE],
		"check": func(l): return "" if l.events.count("WEAPON_SWITCH") >= 2 else "WEAPON_SWITCH x%d" % l.events.count("WEAPON_SWITCH")})
	list.append({"name": "quick swap (C)", "keys": [[0, KEY_G, true], [2, KEY_G, false], [12, KEY_B, true], [14, KEY_B, false], [40, KEY_C, true], [42, KEY_C, false]], "ticks": 60, "pickup": [Weapon.Kind.STORM_BLADE],
		"check": func(l): return "" if l.events.count("WEAPON_SWITCH") >= 2 or l.events.has("SWAP_CANCEL") else "WEAPON_SWITCH x%d" % l.events.count("WEAPON_SWITCH")})
	list.append({"name": "mouse wheel (target switch)", "keys": [[0, WHEEL_DOWN, true], [0, WHEEL_DOWN, false]], "ticks": 5,
		"check": func(l): return "" if l.wheel_seen else "wheel never reached FighterInput.target_switch"})
	list.append({"name": "ki blast tap (Q)", "keys": [[0, KEY_Q, true], [2, KEY_Q, false]], "ticks": 30,
		"check": func(l): return "" if l.events.has("KI_BLAST") and l.blast_nodes > 0 else "no KI_BLAST/visual"})
	list.append({"name": "ki blast hold (Q)", "keys": [[0, KEY_Q, true], [30, KEY_Q, false]], "ticks": 40,
		"check": func(l): return "" if _has_move(l, "charged_blast") == "" and l.blast_nodes > 0 else "no charged blast"})
	list.append({"name": "charge ki (R)", "keys": [[0, KEY_R, true], [40, KEY_R, false]], "ticks": 42, "ki": 50,
		"check": func(l): return "" if l.states.has("CHARGING") and l.ki_gain > 0 else "no CHARGING"})
	for unbuilt in [["special 1 (1)", KEY_1], ["special 2 (2)", KEY_2], ["special 3 (3)", KEY_3],
			["ultimate (4)", KEY_4], ["transform (T)", KEY_T]]:
		var bit: int = {KEY_1: A.SPECIAL_1, KEY_2: A.SPECIAL_2, KEY_3: A.SPECIAL_3, KEY_4: A.ULTIMATE, KEY_T: A.TRANSFORM}[unbuilt[1]]
		list.append({"name": unbuilt[0], "keys": [[0, unbuilt[1], true], [3, unbuilt[1], false]], "ticks": 40, "bit": bit,
			"check": func(l): return "" if l.moves.size() > 0 or l.states.size() > 1 else "NOT IMPLEMENTED: bit reaches FighterInput (%s), the sim never reads it" % l.bit_seen})
	list.append({"name": "vanish (Shift+E)", "keys": [[0, KEY_SHIFT, true], [0, KEY_E, true], [3, KEY_SHIFT, false], [3, KEY_E, false]], "ticks": 30,
		"check": func(l): return "" if l.states.has("VANISHING") else "no VANISHING"})
	list.append({"name": "combo breaker (X)", "keys": [[10, KEY_X, true], [12, KEY_X, false]], "ticks": 40, "distance": 1.6,
		"opponent": {2: A.LIGHT}, "bit": A.BREAKER,
		"check": func(l): return "" if l.events.has("BREAKER") else "NOT IMPLEMENTED: pressed in hitstun (%s), bit reaches FighterInput (%s), the sim never reads it" % [l.states.has("HITSTUN"), l.bit_seen]})
	list.append({"name": "lock-on toggle (MMB)", "keys": [[0, MMB, true], [2, MMB, false], [10, MMB, true], [12, MMB, false]], "ticks": 14,
		"check": func(l): return "" if l.locks.has(-1) and l.locks.has(1) else "locks %s" % [l.locks]})
	list.append({"name": "lock-on toggle (Tab)", "keys": [[0, KEY_TAB, true], [2, KEY_TAB, false]], "ticks": 4,
		"check": func(l): return "" if l.locks.has(-1) else "locks %s" % [l.locks]})
	return list


func _has_move(l: Dictionary, part: String) -> String:
	for id in l.moves:
		if String(id).contains(part):
			return ""
	return "no %s move (moves %s)" % [part, l.moves]


func _run(scenario: Dictionary) -> String:
	var sim := _level.sim
	sim.start_round()
	sim.projectiles.clear()
	sim.pickups.clear()
	var me := sim.fighters[_level.player]
	var other := 1 - _level.player
	var distance: float = scenario.get("distance", 6.0)
	sim.fighters[other].position = me.position + DetMath.forward(me.facing_yaw) * distance
	sim.lock_everyone_onto_nearest()
	me.ki = scenario.get("ki", 100) * UNIT
	me.burst = 300 * UNIT
	var opponent := Scripted.new()
	opponent.start = sim.current_tick
	opponent.plan = scenario.get("opponent", {})
	_level.drivers[other] = opponent
	for kind in scenario.get("pickup", []):
		sim._drop_pickup(kind, Weapon.full_ammo(kind), me.position)
		for p in sim.pickups:
			p.position = me.position
			p.fall_speed = 0.0
	_cues.cues.clear()
	var character = _level.fighter_views[_level.player]._character
	var l := {"states": [], "moves": [], "events": [], "clips": [], "dash_kinds": [], "locks": [],
		"moved": 0.0, "rise": 0.0, "drop": 0.0, "ki_gain": 0, "blast_nodes": 0, "wheel_seen": false,
		"bit_seen": false}
	var start := me.position
	var top := me.position.y
	var ki_low := me.ki
	var keys: Array = scenario.keys
	var bit: int = scenario.get("bit", 0)
	for t in scenario.ticks:
		for k in keys:
			if k[0] == t:
				_send(k[1], k[2])
		_level.step_tick()
		_level.present_frame(1.0, 1.0 / 60.0)
		var input: FighterInput = _level._player_input._previous
		if input.target_switch != 0:
			l.wheel_seen = true
		if bit and (input.held_actions & bit) != 0:
			l.bit_seen = true
		var state := String(FighterState.State.find_key(me.state))
		if not l.states.has(state):
			l.states.append(state)
		if me.move_id() != &"" and not l.moves.has(me.move_id()):
			l.moves.append(me.move_id())
		var kind := String(FighterState.DashKind.find_key(me.dash_kind))
		if not l.dash_kinds.has(kind):
			l.dash_kinds.append(kind)
		var lock := me.lock_on_target if me.lock_on_target < 0 else 1
		if not l.locks.has(lock):
			l.locks.append(lock)
		for e in sim.events:
			l.events.append(String(CombatSim.EventType.find_key(e.type)))
		if character:
			var clip: StringName = character.current_clip()
			if not l.clips.has(clip):
				l.clips.append(clip)
		for child in _level.weapon_layer.get_children():
			if String(child.name).begins_with("KiBlast") and (child as Node3D).is_visible_in_tree():
				l.blast_nodes += 1
		top = maxf(top, me.position.y)
		ki_low = mini(ki_low, me.ki)
		l.drop = maxf(l.drop, top - me.position.y)
	l.moved = Vector2(me.position.x - start.x, me.position.z - start.z).length()
	l.rise = top - start.y
	l.ki_gain = me.ki - ki_low
	for k in keys:
		_send(k[1], false)
	var problem: String = scenario.check.call(l)
	var cues: Array = _cues.cues.duplicate()
	var verdict := "OK" if problem == "" else (problem if problem.begins_with("NOT") else "BROKEN: " + problem)
	return "%s | clips %s | cues %s" % [verdict, l.clips.slice(0, 4), cues.slice(0, 5)]


func _print_table() -> void:
	print("\n| Action | " + " | ".join(_results.values()[0].keys()) + " |")
	for action in _order:
		var row: Array = []
		for legend in _results[action]:
			row.append(String(_results[action][legend]).get_slice(" |", 0))
		print("| %s | %s |" % [action, " | ".join(row)])
