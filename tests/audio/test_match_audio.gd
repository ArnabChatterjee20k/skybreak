extends GutTest
## A 3600-tick bot match through the mapper must ask for every core sound category.

const MATCH_TICKS := 3600
const A := FighterInput.Action
const CATEGORIES := {
	"hit": [&"hit_light", &"hit_medium", &"hit_heavy"],
	"block": [&"block", &"perfect_block", &"guard_break", &"push_block"],
	"ko": [&"ko"],
	"dash": [&"dash", &"air_dash", &"rush_whoosh"],
	"flight": [&"flight_start", &"flight_stop", &"flight_wind_loop"],
}


## Seeded bot: fighter 0 presses forward with lights, heavies, dashes and climbs;
## fighter 1 guards, counters and flies. A KO starts the next round.
func _bot_match(seed_value: int) -> Dictionary:
	var sim := CombatSim.new(seed_value)
	var stats := (CombatSim.DEFAULT_FIGHTER_STATS as FighterStats).duplicate() as FighterStats
	stats.max_health = 1500
	sim.add_fighter(Vector3(0, 1, 4), stats)
	sim.add_fighter(Vector3(0, 1, -4), stats)
	sim.lock_everyone_onto_nearest()
	var mapper := CombatAudioMapper.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
	var plans: Array[Array] = [[0, 0, 0], [0, 0, 0]]  # held, vertical, ticks left
	var heard := {}
	for _tick in MATCH_TICKS:
		var inputs: Array[FighterInput] = []
		for i in 2:
			if plans[i][2] <= 0:
				plans[i] = _plan(i, rng)
			plans[i][2] -= 1
			var input := FighterInput.from_held(plans[i][0], previous[i])
			input.vertical = plans[i][1]
			if i == 0:
				# The attacker follows the defender's height.
				var dy := sim.fighters[1].position.y - sim.fighters[0].position.y
				if absf(dy) > 1.0:
					input.vertical = 1 if dy > 0.0 else -1
			input.move = Vector2(0, 1) if i == 0 or rng.randf() < 0.3 else Vector2.ZERO
			inputs.append(input)
		sim.tick(inputs)
		previous = inputs
		for request in mapper.observe(sim):
			heard[request.cue] = true
		for loop in mapper.loops_for(sim):
			if loop.active:
				heard[loop.cue] = true
		if sim.round_over:
			sim.start_round()
	return heard


func _plan(index: int, rng: RandomNumberGenerator) -> Array:
	var roll := rng.randf()
	if index == 0:
		if roll < 0.45:
			return [A.LIGHT if rng.randf() < 0.5 else 0, 0, rng.randi_range(2, 8)]
		if roll < 0.6:
			return [A.HEAVY, 0, rng.randi_range(2, 20)]
		if roll < 0.75:
			return [A.DASH, 0, rng.randi_range(3, 25)]
		if roll < 0.85:
			return [0, 1, rng.randi_range(10, 40)]
		return [0, -1, rng.randi_range(10, 40)]
	if roll < 0.35:
		return [A.BLOCK, 0, rng.randi_range(5, 30)]
	if roll < 0.6:
		return [A.LIGHT if rng.randf() < 0.5 else 0, 0, rng.randi_range(2, 6)]
	if roll < 0.7:
		return [0, 1, rng.randi_range(10, 30)]
	if roll < 0.8:
		return [A.DASH, 0, rng.randi_range(3, 20)]
	return [0, -1, rng.randi_range(5, 30)]


func test_a_bot_match_asks_for_hit_block_ko_dash_and_flight_sounds() -> void:
	var heard := _bot_match(11)
	for category: String in CATEGORIES:
		var found: Array = CATEGORIES[category].filter(func(cue: StringName) -> bool: return heard.has(cue))
		assert_gt(found.size(), 0, "%s sounds came up (heard %s)" % [category, heard.keys()])


func test_the_bot_match_sounds_are_the_same_every_run() -> void:
	assert_eq(_bot_match(3), _bot_match(3))


func test_the_arena_hook_hands_sim_sounds_to_the_director() -> void:
	var director: Node = preload("res://game/audio/audio_director.gd").new()
	director.settings = AudioSettings.new()
	add_child_autofree(director)
	director.set_process(false)
	var sim := CombatSim.new(2)
	sim.add_fighter(Vector3(0, 1, 2))
	sim.add_fighter(Vector3(0, 1, -2))
	var hook := MatchAudio.new()
	hook.director = director
	hook.sim = sim
	add_child_autofree(hook)
	assert_eq(director.loop_cue(&"ambience"), &"amb_shattered_mesa", "default zone without a world map")
	var dash := FighterInput.new()
	dash.held_actions = A.DASH
	dash.pressed_actions = A.DASH
	hook.after_tick()
	sim.tick([dash, FighterInput.new()])
	hook.after_tick()
	assert_eq(director.voices_playing(&"dash"), 1)
