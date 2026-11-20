extends GutTest
## T-DEF3: the locked camera keeps both fighters on screen through a combo
## breaker's 5.5 m blow-out and a chase rush, seen from either fighter.
## Positions come from the real sim; the real FighterCamera follows them.

const DT := 1.0 / 60.0
const SCREEN := Vector2(1920, 1080)
const LIGHT := FighterInput.Action.LIGHT
const HEAVY := FighterInput.Action.HEAVY
const DASH := FighterInput.Action.DASH
const BREAKER := FighterInput.Action.BREAKER
const State := FighterState.State
const UNIT := FighterState.METER_UNIT
const ATTACKER := 0
const DEFENDER := 1
## Frames of a steady locked shot before the escape starts.
const SETTLE_FRAMES := 60
## Fighter centres stay inside this fraction of the half-screen.
const INNER := 0.9

var _sim: CombatSim
var _previous: Array[FighterInput] = []
var _held: Array[int] = [0, 0]
var _vertical: Array[int] = [0, 0]
var _track: Array = []


func _start() -> void:
	_sim = CombatSim.new()
	_sim.add_fighter(Vector3(0, 0, 0))
	_sim.add_fighter(Vector3(0, 0, -2))
	_sim.lock_everyone_onto_nearest()
	_previous = [FighterInput.new(), FighterInput.new()]
	_held = [0, 0]
	_vertical = [0, 0]
	_track = []
	for _i in SETTLE_FRAMES:
		_tick()


func _tick() -> void:
	var inputs: Array[FighterInput] = []
	for index in 2:
		var input := FighterInput.from_held(_held[index], _previous[index])
		input.vertical = _vertical[index]
		inputs.append(input)
	_sim.tick(inputs)
	_previous = inputs
	_track.append([_sim.fighters[0].position, _sim.fighters[1].position])


func _tap(index: int, action: int, vertical := 0) -> void:
	_held[index] |= action
	_vertical[index] = vertical
	_tick()
	_held[index] &= ~action
	_vertical[index] = 0


func _until(index: int, state: State, limit: int) -> void:
	for _i in limit:
		if _sim.fighters[index].state == state:
			return
		_tick()


## The worst NDC edge reach of either fighter after the settle, the camera following player.
func _worst_edge(player: int) -> float:
	var camera := FighterCamera.new()
	add_child_autofree(camera)
	var worst := 0.0
	for frame in _track.size():
		var points: Array = _track[frame]
		camera.follow(points[player], points[1 - player], true, DT)
		if frame < SETTLE_FRAMES:
			continue
		var view := camera.global_transform
		var tan_v := tan(deg_to_rad(camera.fov) / 2.0)
		for point: Vector3 in points:
			var local := view.affine_inverse() * point
			if local.z >= -0.01:
				return INF
			var ndc := Vector2(local.x / -local.z / (tan_v * SCREEN.x / SCREEN.y), local.y / -local.z / tan_v)
			worst = maxf(worst, maxf(absf(ndc.x), absf(ndc.y)))
	return worst


func _breaker_blow_out() -> void:
	_start()
	_sim.fighters[DEFENDER].burst = 2 * _sim.meter_tuning.burst_stock_size * UNIT
	_tap(ATTACKER, LIGHT)
	_until(DEFENDER, State.HITSTUN, 20)
	while _sim.fighters[DEFENDER].hitstop_ticks > 0:
		_tick()
	_tap(DEFENDER, BREAKER)
	assert_eq(_sim.fighters[ATTACKER].escapes.kind, FighterEscapes.Kind.BLOWN_AWAY, "the breaker blows out")
	for _i in 90:
		_tick()
	var gap := _sim.fighters[ATTACKER].position - _sim.fighters[DEFENDER].position
	gap.y = 0.0
	assert_gt(gap.length(), 5.0, "blown out to mid range")


func _chase_rush(way: int) -> void:
	_start()
	_sim.fighters[ATTACKER].ki = 100 * UNIT
	_tap(ATTACKER, HEAVY)
	_until(DEFENDER, State.HITSTUN, 30)
	while _sim.fighters[DEFENDER].hitstop_ticks > 0:
		_tick()
	_tap(ATTACKER, DASH, way)
	assert_eq(_sim.fighters[ATTACKER].escapes.chasing, DEFENDER, "the chase starts")
	for _i in 90:
		_tick()


func test_the_breaker_blow_out_stays_on_screen_from_the_breaker() -> void:
	_breaker_blow_out()
	var edge := _worst_edge(DEFENDER)
	assert_lte(edge, INNER, "a fighter reached %.2f of the half-screen" % edge)


func test_the_breaker_blow_out_stays_on_screen_from_the_blown_out_fighter() -> void:
	_breaker_blow_out()
	var edge := _worst_edge(ATTACKER)
	assert_lte(edge, INNER, "a fighter reached %.2f of the half-screen" % edge)


func test_every_chase_rush_stays_on_screen_from_either_fighter() -> void:
	for way in [0, 1, -1]:
		_chase_rush(way)
		for player in [ATTACKER, DEFENDER]:
			var edge := _worst_edge(player)
			assert_lte(edge, INNER, "chase way %d seen by %d: a fighter reached %.2f of the half-screen" % [way, player, edge])
