class_name GoldenReplay
extends RefCounted
## A recorded AI match (seed, setup, every tick's inputs and state hash) that a
## fresh CombatSim must replay bit for bit. Drift names its first tick and the
## field that differs, from per-field digests stored next to the hashes.

const FORMAT := 1
## Ticks a decided round stays on screen before the recorder starts the next one.
const DEFAULT_ROUND_RESTART_TICKS := 90
## Digest row parts after the fighters: one byte each.
const LIST_PARTS: Array[StringName] = [&"pickups", &"projectiles", &"gadgets"]
const _COMPRESSION := FileAccess.COMPRESSION_ZSTD

static var _sim_paths: Array[String] = []

var name: String = ""
var description: String = ""
var seed_value: int = 0
var zone: StringName = &"skyhold_ruins"
var pickups: bool = false
## Sky drop interval [min, max] in ticks; empty keeps PickupTuning's default.
var pickup_interval: Array = []
## [{character, team, ai_level, start: Vector3, health_percent}] in slot order.
var fighters: Array = []
var ticks: int = 0
## start_round() runs before these ticks (0-based tick indices).
var round_starts: Array[int] = []
## Per tick, one FighterInput per fighter.
var inputs: Array = []
## state_hash() before the first tick (index 0) and after every tick.
var hashes: Array[int] = []
## One digest row per entry in hashes: a byte per sim field, per fighter field, per list part.
var digests: Array[PackedByteArray] = []
## Field names of the digest rows: {"sim": [...], "fighter": [...]}.
var fields: Dictionary = {}
## Event name -> count over the whole replay, what this replay covers.
var coverage: Dictionary = {}


## Records spec ({name, description, seed, zone, pickups, pickup_interval,
## fighters: [{character, team, ai_level, start}], ticks, round_restart_ticks})
## by letting AIDriver play every slot.
static func record(spec: Dictionary) -> GoldenReplay:
	var replay := GoldenReplay.new()
	replay.name = String(spec.get("name", ""))
	replay.description = String(spec.get("description", ""))
	replay.seed_value = int(spec.get("seed", 0))
	replay.zone = StringName(spec.get("zone", &"skyhold_ruins"))
	replay.pickups = bool(spec.get("pickups", false))
	replay.pickup_interval = spec.get("pickup_interval", [])
	replay.fighters = spec.get("fighters", [])
	replay.ticks = int(spec.get("ticks", 0))
	var restart_ticks := int(spec.get("round_restart_ticks", DEFAULT_ROUND_RESTART_TICKS))
	var sim := replay.build_sim()
	var entries: Array = []
	for slot in replay.fighters.size():
		var entry: Dictionary = replay.fighters[slot]
		entries.append({"character": entry.character, "team": entry.team, "is_ai": true,
			"ai_level": entry.ai_level})
	var driver := AIDriver.for_sim(sim, entries)
	replay.fields = field_names(sim)
	replay._note(sim)
	var decided_for := 0
	for tick_index in replay.ticks:
		if sim.round_over:
			decided_for += 1
			if decided_for > restart_ticks:
				sim.start_round()
				replay.round_starts.append(tick_index)
				decided_for = 0
		var tick_inputs := driver.inputs_for(sim)
		var copies: Array[FighterInput] = []
		for input in tick_inputs:
			copies.append(copy_input(input))
		replay.inputs.append(copies)
		sim.tick(tick_inputs)
		replay._note(sim)
	return replay


## A fresh sim set up like the recorded one: flat floor, no world.
func build_sim() -> CombatSim:
	var sim := CombatSim.new(seed_value)
	sim.zone = zone
	sim.pickups_enabled = pickups
	if pickup_interval.size() == 2:
		sim.pickup_tuning.spawn_interval_min_ticks = int(pickup_interval[0])
		sim.pickup_tuning.spawn_interval_max_ticks = int(pickup_interval[1])
	for slot in fighters.size():
		var entry: Dictionary = fighters[slot]
		var character := Roster.character(StringName(entry.character))
		assert(character != null, "unknown character %s" % entry.character)
		var fighter := sim.add_fighter(entry.start, character.stats)
		fighter.team = int(entry.team)
		# A fixture shortcut to reach a KO sooner; start_round() restores full health.
		fighter.health = fighter.stats.max_health * FighterState.METER_UNIT * int(entry.get("health_percent", 100)) / 100
	sim.lock_everyone_onto_nearest()
	return sim


## Feeds the recorded inputs to a fresh sim and compares every tick's hash.
## Returns {ok, tick, message}; tick is the first divergent hash index (0 = setup).
func play() -> Dictionary:
	var sim := build_sim()
	var current_fields := field_names(sim)
	if current_fields != fields:
		var setup_ok := sim.state_hash() == hashes[0]
		return {"ok": false, "tick": 0, "message": "%s: the hashed fields changed (%s)%s" % [
			name, _field_change(current_fields), "" if setup_ok else ", so every hash differs"]}
	var verdict := _compare(sim, 0)
	if not verdict.ok:
		return verdict
	for tick_index in inputs.size():
		if round_starts.has(tick_index):
			sim.start_round()
		var tick_inputs: Array[FighterInput] = []
		tick_inputs.assign(inputs[tick_index])
		sim.tick(tick_inputs)
		verdict = _compare(sim, tick_index + 1)
		if not verdict.ok:
			return verdict
	return {"ok": true, "tick": -1, "message": "%s: %d ticks, no drift" % [name, inputs.size()]}


func _compare(sim: CombatSim, index: int) -> Dictionary:
	var current := sim.state_hash()
	if current == hashes[index]:
		return {"ok": true, "tick": index, "message": ""}
	var row := digest_row(sim)
	var differences: Array[String] = []
	var golden: PackedByteArray = digests[index]
	for i in mini(row.size(), golden.size()):
		if row[i] != golden[i]:
			differences.append(_describe(sim, i))
	if row.size() != golden.size():
		differences.append("digest row length %d, golden %d" % [row.size(), golden.size()])
	if differences.is_empty():
		differences.append("a value no per-field digest covers (hash %d, golden %d)" % [current, hashes[index]])
	var when := "at setup (before tick 0)" if index == 0 else "after tick %d" % (index - 1)
	return {"ok": false, "tick": index, "message": "%s: first drift %s of %d: %s" % [
		name, when, inputs.size(), "; ".join(differences)]}


## Names digest byte i and gives its current value.
func _describe(sim: CombatSim, i: int) -> String:
	var sim_fields: Array = fields.sim
	var fighter_fields: Array = fields.fighter
	if i < sim_fields.size():
		return "sim.%s (now %s)" % [sim_fields[i], _short(_sim_values(sim)[i])]
	i -= sim_fields.size()
	var per_fighter := fighter_fields.size()
	if i < per_fighter * sim.fighters.size():
		var slot := i / per_fighter
		var field := i % per_fighter
		return "fighter %d (%s) %s (now %s)" % [slot, fighters[slot].character, fighter_fields[field],
			_short(sim.fighters[slot].state_values()[field])]
	i -= per_fighter * sim.fighters.size()
	var part := LIST_PARTS[i] if i < LIST_PARTS.size() else &"?"
	return "%s (now %d)" % [part, (sim.get(part) as Array).size()]


func _field_change(current: Dictionary) -> String:
	var notes: Array[String] = []
	for part: String in ["sim", "fighter"]:
		var before: Array = fields.get(part, [])
		var after: Array = current.get(part, [])
		var added := after.filter(func(f: String) -> bool: return not before.has(f))
		var removed := before.filter(func(f: String) -> bool: return not after.has(f))
		if not added.is_empty():
			notes.append("%s added %s" % [part, added])
		if not removed.is_empty():
			notes.append("%s removed %s" % [part, removed])
		if added.is_empty() and removed.is_empty() and before != after:
			notes.append("%s fields reordered" % part)
	return ", ".join(notes)


static func _short(value: Variant) -> String:
	var text := var_to_str(value).replace("\n", " ")
	return text if text.length() <= 120 else text.left(117) + "..."


func _note(sim: CombatSim) -> void:
	hashes.append(sim.state_hash())
	digests.append(digest_row(sim))
	for event in sim.events:
		var event_name: String = CombatSim.EventType.keys()[int(event.type)]
		coverage[event_name] = int(coverage.get(event_name, 0)) + 1


## One byte per hashed value: sim fields, then each fighter's state_values(), then list parts.
static func digest_row(sim: CombatSim) -> PackedByteArray:
	var row := PackedByteArray()
	for value in _sim_values(sim):
		row.append(_byte(value))
	for fighter in sim.fighters:
		for value in fighter.state_values():
			row.append(_byte(value))
	for part in LIST_PARTS:
		var values: Array = []
		for item: Object in sim.get(part):
			values.append_array(item.call(&"state_values"))
		row.append(_byte(values))
	return row


static func _byte(value: Variant) -> int:
	return hash(var_to_bytes(value)) & 0xff


## The sim-level values state_hash() covers, named by field_names().sim.
static func _sim_values(sim: CombatSim) -> Array:
	if _sim_paths.is_empty():
		_sim_paths.assign(_parse_list((sim.get_script() as GDScript).source_code, "func state_hash"))
	var values: Array = []
	for field: String in _sim_paths:
		values.append(sim.get_indexed(NodePath(field.replace(".", ":"))))
	return values


## Names of the values state_hash() covers, read from the hashing code itself.
static func field_names(sim: CombatSim) -> Dictionary:
	var sim_fields := _parse_list((sim.get_script() as GDScript).source_code, "func state_hash")
	var fighter_fields: Array[String] = []
	var fighter := sim.fighters[0] if not sim.fighters.is_empty() else FighterState.new()
	var source := (fighter.get_script() as GDScript).source_code
	fighter_fields.append_array(_parse_list(source, "func state_values"))
	# Nested "+ member.state_values()" lists, e.g. powers.
	var body := source.substr(source.find("func state_values"))
	body = body.substr(0, body.find("\nfunc ", 1))
	var nested := RegEx.create_from_string("\\+\\s*(\\w+)\\.state_values\\(\\)")
	for found in nested.search_all(body):
		var member := found.get_string(1)
		var inner := (fighter.get(member) as Object).get_script() as GDScript
		for field in _parse_list(inner.source_code, "func state_values"):
			fighter_fields.append("%s.%s" % [member, field])
	var expected := fighter.state_values().size()
	if fighter_fields.size() != expected:
		fighter_fields.clear()
		for i in expected:
			fighter_fields.append("value #%d" % i)
	return {"sim": sim_fields, "fighter": fighter_fields}


## The comma-separated names of the first [...] literal after anchor in source.
static func _parse_list(source: String, anchor: String) -> Array[String]:
	var names: Array[String] = []
	var start := source.find("[", source.find(anchor))
	var depth := 0
	var current := ""
	for i in range(start + 1, source.length()):
		var c := source[i]
		if c == "[" or c == "(":
			depth += 1
		elif c == ")":
			depth -= 1
		elif c == "]":
			if depth == 0:
				break
			depth -= 1
		if c == "," and depth == 0:
			names.append(current.strip_edges())
			current = ""
		else:
			current += c
	if not current.strip_edges().is_empty():
		names.append(current.strip_edges())
	return names


static func copy_input(input: FighterInput) -> FighterInput:
	var copy := FighterInput.new()
	copy.held_actions = input.held_actions
	copy.pressed_actions = input.pressed_actions
	copy.released_actions = input.released_actions
	copy.move = input.move
	copy.vertical = input.vertical
	copy.view_yaw = input.view_yaw
	copy.camera_offset = input.camera_offset
	copy.target_switch = input.target_switch
	return copy


## The input columns, in stored order.
const INPUT_COLUMNS: Array[String] = ["held_actions", "pressed_actions", "released_actions",
	"move.x", "move.y", "vertical", "view_yaw", "camera_offset.x", "camera_offset.y", "target_switch"]


## One fighter's inputs as 64-bit words per column: ints as is, floats as their bit patterns.
static func _input_words(input: FighterInput) -> PackedInt64Array:
	var floats := PackedFloat64Array([input.move.x, input.move.y, input.view_yaw,
		input.camera_offset.x, input.camera_offset.y]).to_byte_array().to_int64_array()
	return PackedInt64Array([input.held_actions, input.pressed_actions, input.released_actions,
		floats[0], floats[1], input.vertical, floats[2], floats[3], floats[4], input.target_switch])


static func _input_from_words(words: PackedInt64Array) -> FighterInput:
	var floats := PackedInt64Array([words[3], words[4], words[6], words[7], words[8]]) \
		.to_byte_array().to_float64_array()
	var input := FighterInput.new()
	input.held_actions = words[0]
	input.pressed_actions = words[1]
	input.released_actions = words[2]
	input.move = Vector2(floats[0], floats[1])
	input.vertical = words[5]
	input.view_yaw = floats[2]
	input.camera_offset = Vector2(floats[3], floats[4])
	input.target_switch = words[9]
	return input


## Inputs as fighter-major columns, each word XORed with the tick before, then compressed:
## exact bits (-0.0 and all), and held inputs shrink to almost nothing.
func _pack_inputs() -> PackedByteArray:
	var words := PackedInt64Array()
	for slot in fighters.size():
		var per_tick: Array[PackedInt64Array] = []
		for tick_inputs: Array in inputs:
			per_tick.append(_input_words(tick_inputs[slot]))
		for column in INPUT_COLUMNS.size():
			var previous := 0
			for row in per_tick:
				words.append(row[column] ^ previous)
				previous = row[column]
	return words.to_byte_array()


func _unpack_inputs(raw: PackedByteArray) -> void:
	var words := raw.to_int64_array()
	var columns := INPUT_COLUMNS.size()
	inputs.clear()
	for tick_index in ticks:
		inputs.append([])
	for slot in fighters.size():
		var per_tick: Array[PackedInt64Array] = []
		for tick_index in ticks:
			var row := PackedInt64Array()
			row.resize(columns)
			per_tick.append(row)
		for column in columns:
			var previous := 0
			var base := (slot * columns + column) * ticks
			for tick_index in ticks:
				previous ^= words[base + tick_index]
				per_tick[tick_index][column] = previous
		for tick_index in ticks:
			inputs[tick_index].append(_input_from_words(per_tick[tick_index]))


## Whole floats as ints, so the JSON stays short.
static func _number(value: float) -> Variant:
	return int(value) if value == floorf(value) and absf(value) < 1e15 else value


func to_dictionary() -> Dictionary:
	var fighter_list: Array = []
	for entry: Dictionary in fighters:
		var start: Vector3 = entry.start
		fighter_list.append({"character": String(entry.character), "team": int(entry.team),
			"ai_level": int(entry.ai_level), "start": [_number(start.x), _number(start.y), _number(start.z)],
			"health_percent": int(entry.get("health_percent", 100))})
	# Digest rows, each XORed with the row before (mostly zeros), compressed.
	var packed := PackedByteArray()
	var previous := PackedByteArray()
	for row in digests:
		for i in row.size():
			packed.append(row[i] ^ (previous[i] if i < previous.size() else 0))
		previous = row
	return {
		"format": FORMAT, "name": name, "description": description, "seed": seed_value,
		"zone": String(zone), "pickups": pickups, "pickup_interval": pickup_interval,
		"fighters": fighter_list, "ticks": ticks, "round_starts": round_starts,
		"coverage": coverage, "fields": fields,
		"digest_row_size": digests[0].size() if not digests.is_empty() else 0,
		"digest_bytes": packed.size(),
		"digests": Marshalls.raw_to_base64(packed.compress(_COMPRESSION)),
		"input_columns": INPUT_COLUMNS,
		"inputs": Marshalls.raw_to_base64(_pack_inputs().compress(_COMPRESSION)),
		"hashes": hashes,
	}


static func from_dictionary(data: Dictionary) -> GoldenReplay:
	var replay := GoldenReplay.new()
	assert(int(data.get("format", 0)) == FORMAT, "unknown golden replay format")
	replay.name = data.name
	replay.description = data.description
	replay.seed_value = int(data.seed)
	replay.zone = StringName(data.zone)
	replay.pickups = bool(data.pickups)
	replay.pickup_interval = (data.pickup_interval as Array).map(func(v: Variant) -> int: return int(v))
	for entry: Dictionary in data.fighters:
		var start: Array = entry.start
		replay.fighters.append({"character": StringName(entry.character), "team": int(entry.team),
			"ai_level": int(entry.ai_level), "start": Vector3(start[0], start[1], start[2]),
			"health_percent": int(entry.get("health_percent", 100))})
	replay.ticks = int(data.ticks)
	for tick_index: Variant in data.round_starts:
		replay.round_starts.append(int(tick_index))
	for event_name: String in data.coverage:
		replay.coverage[event_name] = int(data.coverage[event_name])
	var field_lists: Dictionary = data.fields
	replay.fields = {"sim": _strings(field_lists.sim), "fighter": _strings(field_lists.fighter)}
	for value: Variant in data.hashes:
		replay.hashes.append(int(value))
	assert(_strings(data.input_columns) == INPUT_COLUMNS, "unknown input columns")
	var input_bytes := replay.fighters.size() * INPUT_COLUMNS.size() * replay.ticks * 8
	replay._unpack_inputs(Marshalls.base64_to_raw(data.inputs).decompress(input_bytes, _COMPRESSION))
	var row_size := int(data.digest_row_size)
	var packed := Marshalls.base64_to_raw(data.digests).decompress(int(data.digest_bytes), _COMPRESSION)
	var previous := PackedByteArray()
	previous.resize(row_size)
	for start in range(0, packed.size(), row_size):
		var row := packed.slice(start, start + row_size)
		for i in row_size:
			row[i] ^= previous[i]
		replay.digests.append(row)
		previous = row
	return replay


static func _strings(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value: Variant in values:
		out.append(String(value))
	return out


## Compact JSON: one top-level key per line, hashes 20 to a line.
func to_json() -> String:
	var data := to_dictionary()
	var lines: Array[String] = []
	for key: String in data:
		var value: Variant = data[key]
		var text: String
		if key == "hashes":
			var chunks: Array[String] = []
			for start in range(0, hashes.size(), 20):
				chunks.append(JSON.stringify(hashes.slice(start, start + 20)).trim_prefix("[").trim_suffix("]"))
			text = "[\n" + ",\n".join(chunks) + "\n]"
		else:
			text = JSON.stringify(value, "", false, true)
		lines.append("%s: %s" % [JSON.stringify(key), text])
	return "{\n" + ",\n".join(lines) + "\n}\n"


static func from_json(text: String) -> GoldenReplay:
	var data: Variant = JSON.parse_string(text)
	assert(data is Dictionary, "golden replay is not a JSON object")
	return from_dictionary(data)


func save(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_json())
	return OK


static func load_file(path: String) -> GoldenReplay:
	return from_json(FileAccess.get_file_as_string(path))
