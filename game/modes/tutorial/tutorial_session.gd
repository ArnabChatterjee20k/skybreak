class_name TutorialSession
extends RefCounted
## Runs the tutorial on a CombatSim with no scene: the current lesson and
## step, the dummy (standing, blocking or sparring), and goal checks fed by
## the sim's events and state after every tick. The room scene and the tests
## drive it the same way: inputs_for() before each tick, after_tick() after.

signal step_passed(step_index: int)
signal lesson_passed(lesson_index: int)

const PLAYER := TrainingSession.PLAYER
const DUMMY := TrainingSession.DUMMY
const Event := CombatSim.EventType
## The sparring dummy jabs this often, and grabs this often (ticks).
const JAB_PERIOD := 70
const GRAB_PERIOD := 90
## The sparring dummy only grabs within this distance, metres.
const GRAB_RANGE := 2.6
## The sparring dummy walks in when farther than this, metres.
const SPARRING_RANGE := 2.0

var sim: CombatSim
var training: TrainingSession
var lessons: Array[TutorialLesson] = []
var lesson_index := 0
var step_index := 0
## True once every step of the current lesson passed; next_lesson() moves on.
var lesson_complete := false
## Events since the current step began.
var step_events: Array[Dictionary] = []
## Player position and burst when the current step began.
var step_start_position := Vector3.ZERO
var step_start_burst := 0
## Ticks since the current step began.
var step_ticks := 0

var _sparring_previous := FighterInput.new()
var _sparring_ticks := 0


func _init(tutorial_sim: CombatSim, lesson_list: Array[TutorialLesson] = []) -> void:
	sim = tutorial_sim
	training = TrainingSession.new(sim)
	lessons = lesson_list if not lesson_list.is_empty() else TutorialLessons.all()
	start_lesson(0)


func lesson() -> TutorialLesson:
	return lessons[lesson_index]


## The current step, or an empty dictionary once the lesson is complete.
func current_step() -> Dictionary:
	return {} if lesson_complete else lesson().steps[step_index]


func is_last_lesson() -> bool:
	return lesson_index >= lessons.size() - 1


func start_lesson(index: int) -> void:
	lesson_index = clampi(index, 0, lessons.size() - 1)
	lesson_complete = false
	training.infinite_meters = lesson().infinite_meters
	training.infinite_health = true
	training.reset_positions()
	if lesson().setup.is_valid():
		lesson().setup.call(self)
	_start_step(0)


## Moves on to the next lesson; false after the last one.
func next_lesson() -> bool:
	if is_last_lesson():
		return false
	start_lesson(lesson_index + 1)
	return true


## Starts the current lesson over.
func retry() -> void:
	start_lesson(lesson_index)


func inputs_for(player_input: FighterInput) -> Array[FighterInput]:
	var inputs: Array[FighterInput] = [player_input, _dummy_input()]
	for _extra in range(inputs.size(), sim.fighters.size()):
		inputs.append(FighterInput.new())
	return inputs


## Records this tick's events and passes the step when its goal is met.
func after_tick() -> void:
	training.after_tick()
	step_events.append_array(sim.events)
	step_ticks += 1
	if lesson_complete:
		return
	var check: Callable = current_step().check
	if not check.call(self):
		return
	step_passed.emit(step_index)
	if step_index + 1 < lesson().steps.size():
		_start_step(step_index + 1)
	else:
		lesson_complete = true
		lesson_passed.emit(lesson_index)


func player() -> FighterState:
	return sim.fighters[PLAYER]


func dummy() -> FighterState:
	return sim.fighters[DUMMY]


## Height of fighter above the floor, metres.
func height_of(fighter: FighterState) -> float:
	return fighter.position.y - sim.tuning.ground_height


## Events of type this step, filtered by who did it (attacker, or fighter for
## weapon events), who took it, and move id; -1 / empty matches anything.
func count(type: CombatSim.EventType, by := -1, on := -1, move_ids: Array = []) -> int:
	var found := 0
	for event in step_events:
		if event.type != type:
			continue
		if by >= 0 and event.get("attacker", event.get("fighter", -1)) != by:
			continue
		if on >= 0 and event.get("target", -1) != on:
			continue
		if not move_ids.is_empty() and not move_ids.has(event.get("move_id", &"")):
			continue
		found += 1
	return found


## Move ids of the player's move set slot (a MoveData or an array of them).
func player_move_ids(slot: StringName) -> Array:
	var value: Variant = player().stats.move_set.get(slot)
	if value is MoveData:
		return [value.id]
	return (value as Array).map(func(move: MoveData) -> StringName: return move.id)


## Puts the dummy gap metres in front of the player, both on the floor, locked on.
func place_dummy(gap: float) -> void:
	var dummy_fighter := dummy()
	dummy_fighter.position = player().position + Vector3(0, 0, -gap)
	dummy_fighter.velocity = Vector3.ZERO
	sim.lock_everyone_onto_nearest()


func _start_step(index: int) -> void:
	step_index = index
	step_events = []
	step_ticks = 0
	step_start_position = player().position
	step_start_burst = player().burst
	_sparring_ticks = 0
	training.set_dummy_mode(lesson().steps[index].dummy_mode)


func _dummy_input() -> FighterInput:
	var sparring: String = "" if lesson_complete else current_step().sparring
	if sparring == "":
		return training.dummy.input_for(sim, DUMMY, PLAYER)
	_sparring_ticks += 1
	var held := 0
	var free := dummy().state in [FighterState.State.IDLE, FighterState.State.MOVING,
		FighterState.State.FLYING]
	if free and not _sparring_previous.held_actions:
		match sparring:
			"jab":
				if _sparring_ticks >= JAB_PERIOD:
					held = FighterInput.Action.LIGHT
			"grab":
				if _sparring_ticks >= GRAB_PERIOD \
						and dummy().position.distance_to(player().position) <= GRAB_RANGE:
					held = FighterInput.Action.GRAB
	if held:
		_sparring_ticks = 0
	var input := FighterInput.from_held(held, _sparring_previous)
	# Walks back into range when pushed away.
	if free and dummy().position.distance_to(player().position) > SPARRING_RANGE:
		input.move = Vector2(0, 1)
	_sparring_previous = input
	return input
