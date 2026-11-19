extends GutTest
## QA-6: a grabbed or thrown fighter stays inside the arena box and above the ground.

const GRAB := FighterInput.Action.GRAB
const LIGHT := FighterInput.Action.LIGHT
const State := FighterState.State
const Event := CombatSim.EventType
## The QA soak's bounds slack (QaSimChecks.BOUNDS_SLACK).
const SLACK := 0.05
const HALF := 6.0

var _sim: CombatSim
var _previous: Array[FighterInput] = []


## Ground rising 1 m per metre toward -Z, as on a steep zone slope.
static func _ramp(_x: float, z: float, _y: float) -> float:
	return maxf(-z, 0.0)


func _start(positions: Array[Vector3], terrain: bool) -> void:
	var tuning := (load("res://game/combat/default_movement_tuning.tres") as MovementTuning).duplicate() as MovementTuning
	tuning.arena_half_size = HALF
	_sim = CombatSim.new(7, tuning)
	if terrain:
		_sim.ground_height = _ramp
	for at in positions:
		_sim.add_fighter(at)
	_sim.lock_everyone_onto_nearest()
	_previous = []
	for _i in positions.size():
		_previous.append(FighterInput.new())


## Ticks with held actions per fighter; returns this run's events.
func _tick(held: Array) -> Array[Dictionary]:
	var inputs: Array[FighterInput] = []
	for f in _sim.fighters.size():
		inputs.append(FighterInput.from_held(held[f] if f < held.size() else 0, _previous[f]))
	_sim.tick(inputs)
	_previous = inputs
	return _sim.events


## Every fighter inside the arena box and not below its stand height (stored and live).
func _check_bounds(where: String) -> bool:
	for i in _sim.fighters.size():
		var f := _sim.fighters[i]
		var out := absf(f.position.x) > HALF + SLACK or absf(f.position.z) > HALF + SLACK \
			or f.position.y > _sim.tuning.arena_ceiling + SLACK
		var ground := _sim.tuning.ground_height + (_ramp(f.position.x, f.position.z, f.position.y)
			if _sim.ground_height.is_valid() else 0.0)
		var under := not f.is_ko_state() and (f.position.y < f.stand_height - SLACK or f.position.y < ground - SLACK)
		if out or under:
			fail_test("%s: fighter %d %s at %s (stand %.2f, ground %.2f)" % [where, i,
				FighterState.State.keys()[f.state], f.position, f.stand_height, ground])
			return false
	return true


func test_a_grab_at_the_wall_holds_the_target_inside_the_arena() -> void:
	_start([Vector3(0, 0, -HALF + 0.9), Vector3(0, 0, -HALF + 0.05)], false)
	var grabbed := false
	for t in 120:
		var events := _tick([GRAB if t == 0 else 0])
		grabbed = grabbed or events.any(func(e: Dictionary) -> bool: return e.type == Event.GRAB)
		if not _check_bounds("tick %d" % t):
			return
	assert_true(grabbed, "the grab lands")


func test_a_grab_up_a_steep_slope_holds_the_target_above_the_ground() -> void:
	_start([Vector3(0, 0, 0), Vector3(0, 0, -1.4)], true)
	var grabbed := false
	for t in 120:
		var events := _tick([GRAB if t == 0 else 0])
		grabbed = grabbed or events.any(func(e: Dictionary) -> bool: return e.type == Event.GRAB)
		if not _check_bounds("tick %d" % t):
			return
	assert_true(grabbed, "the grab lands")


func test_no_fighter_leaves_the_arena_across_a_grab_and_throw_soak() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var grabs := 0
	var throws := 0
	for run in 40:
		var angle := rng.randf() * TAU
		var wall := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(HALF - 1.5, HALF)
		var side := Vector3(cos(angle + rng.randf_range(-1.0, 1.0)), 0, sin(angle)) * 1.3
		_start([wall - side, wall], run % 2 == 0)
		for t in 300:
			var held: Array = [0, 0]
			if t % 50 == 0:
				held[0] = GRAB
			elif t % 50 == 25:
				held[1] = GRAB if rng.randf() < 0.5 else LIGHT
			for e in _tick(held):
				grabs += 1 if e.type == Event.GRAB else 0
				throws += 1 if e.type == Event.THROW else 0
			if not _check_bounds("run %d tick %d" % [run, t]):
				return
	gut.p("grab soak: %d grabs, %d throws" % [grabs, throws])
	assert_gt(grabs, 20, "plenty of grabs")
	assert_gt(throws, 20, "plenty of throws")
