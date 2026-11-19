extends RefCounted
## Test bench for the training room: a sim with two roster fighters, a
## TrainingSession around it, and a player whose held buttons tests set.

var sim: CombatSim
var session: TrainingSession
## Buttons and stick the player holds on the coming ticks.
var held := 0
var move := Vector2.ZERO
var vertical := 0
## Every event since the bench started, in order.
var log: Array[Dictionary] = []

var _previous := FighterInput.new()


func _init(player: StringName = &"kael", dummy: StringName = &"kael") -> void:
	sim = CombatSim.new(7)
	sim.add_fighter(Vector3(0, 1, 6), Roster.character(player).stats)
	sim.add_fighter(Vector3(0, 1, -6), Roster.character(dummy).stats)
	sim.lock_everyone_onto_nearest()
	session = TrainingSession.new(sim)


func player_input() -> FighterInput:
	var input := FighterInput.from_held(held, _previous)
	input.move = move
	input.vertical = vertical
	_previous = input
	return input


func tick(count := 1) -> void:
	for _i in count:
		sim.tick(session.inputs_for(player_input()))
		log.append_array(sim.events)
		session.after_tick()


## Holds action for one tick, then lets go.
func tap(action: int) -> void:
	held |= action
	tick()
	held &= ~action


func events_of(type: CombatSim.EventType) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event in log:
		if event.type == type:
			found.append(event)
	return found


func player() -> FighterState:
	return sim.fighters[TrainingSession.PLAYER]


func dummy() -> FighterState:
	return sim.fighters[TrainingSession.DUMMY]


## Plays the player's light string: each press lands in the timing window of the hit before.
func light_string(hits: int) -> void:
	tap(FighterInput.Action.LIGHT)
	var pressed := 1
	for _i in 200:
		var fighter := player()
		if pressed < hits and fighter.state == FighterState.State.ATTACKING and fighter.hitstop_ticks == 0 \
				and fighter.string_index == pressed and not fighter.string_queued \
				and fighter.move_tick == fighter.move.string_window_start_tick + 1:
			tap(FighterInput.Action.LIGHT)
			pressed += 1
		else:
			tick()
		if pressed >= hits and fighter.state != FighterState.State.ATTACKING:
			return
