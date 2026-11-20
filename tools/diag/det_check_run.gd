class_name DetCheck
extends RefCounted
## Determinism self-check (T-D32): a SHA-256 hash chain over the full sim state of
## the flat-floor golden scenarios and a ki AI duel (T-KI1), plus DetMath probes. The lines must be
## byte-identical on every platform (Linux, Windows, web). Printed by
## tools/diag/det_check.gd (desktop) and tools/web/det_check_main.gd (browser).

const FREE_FOR_ALL_EVERY := 2_000
const BOT_MATCH_EVERY := 600
const KI_MATCH_EVERY := 600
## Kael vs Vexa AI duel at level 5: specials, Momentum and the afterimage (T-SP1).
const SPECIALS_SEED := 4242
const SPECIALS_TICKS := 3_600
const SPECIALS_EVERY := 600

var _chain := PackedByteArray()
var _lines := PackedStringArray()


## Runs both scenarios; the last line is the total over all the others.
func run() -> PackedStringArray:
	_lines = PackedStringArray(["det_check v1", "det_math %s" % _det_math_probe()])
	_chain = "chain".to_utf8_buffer()
	var combat := load("res://tests/combat/test_combat_sim.gd").new() as Node
	combat._run_match(FlatFloorSequences.FREE_FOR_ALL_SEED, FlatFloorSequences.FREE_FOR_ALL_TICKS, {}, 4,
		func(sim: CombatSim) -> void: _link("ffa", sim, FREE_FOR_ALL_EVERY))
	combat.free()
	_chain = "chain".to_utf8_buffer()
	var weapons := load("res://tests/combat/test_weapons.gd").new() as Node
	weapons._bot_match(FlatFloorSequences.BOT_MATCH_SEED, FlatFloorSequences.BOT_MATCH_TICKS, &"skyhold_ruins",
		func(sim: CombatSim) -> void: _link("bot", sim, BOT_MATCH_EVERY))
	weapons.free()
	_chain = "chain".to_utf8_buffer()
	var ki := load("res://tests/combat/test_ki_blasts.gd").new() as Node
	ki._ki_match(ki.KI_MATCH_SEED, ki.KI_MATCH_TICKS, func(sim: CombatSim) -> void: _link("ki", sim, KI_MATCH_EVERY))
	ki.free()
	_chain = "chain".to_utf8_buffer()
	_specials_duel()
	_lines.append("det_check total %s" % _sha("\n".join(_lines).to_utf8_buffer()))
	return _lines


## Two level-5 AIs, Kael and Vexa, on the flat floor; their specials fire often.
func _specials_duel() -> void:
	var sim := CombatSim.new(SPECIALS_SEED)
	sim.add_fighter(Vector3(0, 1, 6), EngagementBand.stats_for(&"kael"))
	sim.add_fighter(Vector3(0, 1, -6), EngagementBand.stats_for(&"vexa"))
	sim.lock_everyone_onto_nearest()
	var driver := AIDriver.for_sim(sim, [
		{"character": &"kael", "team": 0, "is_ai": true, "ai_level": 5},
		{"character": &"vexa", "team": 1, "is_ai": true, "ai_level": 5},
	])
	var specials := 0
	for _i in SPECIALS_TICKS:
		if sim.round_over:
			sim.start_round()
		sim.tick(driver.inputs_for(sim))
		for event in sim.events:
			if event.type == CombatSim.EventType.SPECIAL_START:
				specials += 1
		_link("specials", sim, SPECIALS_EVERY)
	_lines.append("specials started %d" % specials)


# Chains this tick's full state into the running hash; prints it every `every` ticks.
func _link(name: String, sim: CombatSim, every: int) -> void:
	var parts: Array = [sim.current_tick, sim.rng.state, sim.round_over, sim.round_winner]
	for fighter in sim.fighters:
		parts.append_array(fighter.state_values())
	for projectile in sim.projectiles:
		parts.append_array(projectile.state_values())
	for pickup in sim.pickups:
		parts.append_array(pickup.state_values())
	for gadget in sim.gadgets:
		parts.append_array(gadget.state_values())
	parts.append_array(KiRules.state_values(sim))
	parts.append_array(SpecialRules.state_values(sim))
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(_chain)
	context.update(var_to_bytes(parts))
	_chain = context.finish()
	if sim.current_tick % every == 0:
		_lines.append("%s t%d %s %s" % [name, sim.current_tick, _chain.hex_encode().substr(0, 16),
			FlatFloorSequences.fingerprint(sim)])


# Bit patterns of DetMath over a spread of arguments, hashed.
func _det_math_probe() -> String:
	var values := PackedFloat64Array()
	for i in 2_000:
		var x := (i - 1_000) * 0.0137
		values.append_array([DetMath.sin(x), DetMath.cos(x), DetMath.atan(x), DetMath.atan2(x, 0.7 - x),
			DetMath.acos(x / 14.0), DetMath.asin(x / 14.0), DetMath.exp(x), DetMath.log(absf(x) + 0.001),
			DetMath.pow(absf(x), 1.37), DetMath.wrap_angle(x * 3.0)])
	return _sha(values.to_byte_array())


func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode().substr(0, 16)
