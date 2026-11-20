class_name TrainingSession
extends RefCounted
## Training-room rules around a CombatSim, with no scene: who controls which
## fighter, the dummy, the input loop recorder, meter and health refills, the
## position reset, the weapon spawner and the frame meter. The room scene and
## the tests drive it the same way: inputs_for() before each tick, after_tick() after.

const PLAYER := 0
const DUMMY := 1
## Gap between player and dummy after a reset, metres: inside light range.
const RESET_GAP := 2.0
## Where the pair stands after a reset (midpoint), on the floor.
const RESET_CENTRE := Vector3(0, 1, 0)
## A spawned weapon lands this far in front of the player, metres.
const SPAWN_AHEAD := 1.5

var sim: CombatSim
var dummy := TrainingDummy.new()
var input_loop := InputLoop.new()
var frame_meter := FrameMeter.new()
var input_history := InputHistory.new()
## Ki, guard and burst stay full.
var infinite_meters := true
## Health refills once a combo ends; nobody is ever knocked out.
var infinite_health := true


func _init(training_sim: CombatSim) -> void:
	sim = training_sim
	sim.pickups_enabled = false
	dummy.input_loop = input_loop
	reset_positions()


## The pair back at the centre facing each other, everything calm and refilled.
func reset_positions() -> void:
	sim.projectiles = []
	var starts := [RESET_CENTRE + Vector3(0, 0, RESET_GAP * 0.5), RESET_CENTRE - Vector3(0, 0, RESET_GAP * 0.5)]
	for i in sim.fighters.size():
		var fighter := sim.fighters[i]
		fighter.position = starts[mini(i, starts.size() - 1)]
		fighter.position.y = sim.tuning.ground_height
		fighter.velocity = Vector3.ZERO
		fighter.hitstop_ticks = 0
		fighter.grab_partner = -1
		fighter.perfect_block_armed = false
		fighter.perfect_block_lockout = 0
		fighter.enter_state(FighterState.State.IDLE)
	if sim.round_over or sim.fighters.any(func(f: FighterState) -> bool: return f.is_knocked_out()):
		sim.start_round()
	sim.lock_everyone_onto_nearest()
	for i in sim.fighters.size():
		var other := sim.fighters[sim.fighters[i].lock_on_target]
		var look := other.position - sim.fighters[i].position
		sim.fighters[i].facing_yaw = atan2(-look.x, -look.z)
	_refill(true)
	dummy.reset()
	frame_meter.clear()


func set_dummy_mode(mode: TrainingDummy.Mode) -> void:
	dummy.mode = mode
	dummy.reset()


## F6: starts recording (the player drives the dummy) or stops it.
func toggle_recording() -> void:
	if input_loop.recording:
		input_loop.stop_recording()
	else:
		input_loop.start_recording()


## F7: plays the recording on the dummy, or goes back to standing.
func toggle_playback() -> void:
	if dummy.mode == TrainingDummy.Mode.PLAYBACK:
		set_dummy_mode(TrainingDummy.Mode.STAND)
	elif input_loop.has_recording():
		set_dummy_mode(TrainingDummy.Mode.PLAYBACK)


## Inputs for the coming tick. While recording, the player's controls drive the dummy.
func inputs_for(player_input: FighterInput) -> Array[FighterInput]:
	var inputs: Array[FighterInput] = []
	input_history.add(player_input)
	if input_loop.recording:
		input_loop.record(player_input)
		inputs.append(FighterInput.new())
		inputs.append(player_input)
	else:
		inputs.append(player_input)
		inputs.append(dummy.input_for(sim, DUMMY, PLAYER))
	for _extra in range(inputs.size(), sim.fighters.size()):
		inputs.append(FighterInput.new())
	return inputs


## Meter refills, KO protection and the frame meter, after each tick.
func after_tick() -> void:
	frame_meter.observe(sim, PLAYER, DUMMY)
	for event in sim.events:
		var who: int = event.get("fighter", event.get("target", -1))
		var dodge_note := InputHistory.dodge_note(event)
		if who == PLAYER and dodge_note != "":
			input_history.note(dodge_note)
	if sim.round_over:
		reset_positions()
		return
	_refill(false)


## Drops a weapon of kind on the floor just in front of the player, ready to pick up.
func spawn_weapon(kind: Weapon.Kind) -> WeaponPickup:
	var player := sim.fighters[PLAYER]
	var ahead := Basis(Vector3.UP, player.facing_yaw) * Vector3.FORWARD * SPAWN_AHEAD
	var pickup := WeaponPickup.new()
	pickup.id = sim.next_entity_id
	sim.next_entity_id += 1
	pickup.kind = kind
	pickup.ammo = int(Weapon.RANGED_STATS[kind].ammo) if Weapon.RANGED_STATS.has(kind) else 0
	pickup.position = Vector3(player.position.x + ahead.x, sim.floor_height() + sim.pickup_tuning.rest_height,
		player.position.z + ahead.z)
	pickup.phase = WeaponPickup.Phase.GROUNDED
	pickup.ticks_left = sim.pickup_tuning.spawn_lifetime_ticks
	pickup.dropped = true
	sim.pickups.append(pickup)
	return pickup


func _refill(everything: bool) -> void:
	for fighter in sim.fighters:
		if infinite_meters or everything:
			fighter.ki = sim.meter_tuning.ki_max * FighterState.METER_UNIT
			fighter.burst = sim.meter_tuning.burst_max_stocks * sim.meter_tuning.burst_stock_size \
				* FighterState.METER_UNIT
			if fighter.state != FighterState.State.GUARD_BROKEN:
				fighter.guard = fighter.stats.guard_max * FighterState.METER_UNIT
		var in_combo := fighter.state in [FighterState.State.HITSTUN, FighterState.State.KNOCKDOWN,
			FighterState.State.GRABBED]
		if (infinite_health and not in_combo) or everything:
			fighter.health = fighter.stats.max_health * FighterState.METER_UNIT
			fighter.grey_health = 0
