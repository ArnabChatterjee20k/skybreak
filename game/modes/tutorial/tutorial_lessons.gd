class_name TutorialLessons
extends RefCounted
## The tutorial's lessons, in order. Each step's check reads the sim's events
## and state through the TutorialSession, so a lesson passes only by doing it.

const Event := CombatSim.EventType
const State := FighterState.State
const Mode := TrainingDummy.Mode
const P := TutorialSession.PLAYER
const D := TutorialSession.DUMMY


static func all() -> Array[TutorialLesson]:
	return [
		_move_fly_lock_on(), _light_string(), _heavies(), _air_combo(), _defense(),
		_grab_and_tech(), _dash_and_vanish(), _ki_and_burst(), _weapons(),
	]


static func _move_fly_lock_on() -> TutorialLesson:
	var lesson := TutorialLesson.new(&"move", "Move, fly and lock on",
		"The sky is your arena. Let's get moving!")
	lesson.setup = func(s: TutorialSession) -> void:
		s.place_dummy(14.0)
		s.player().lock_on_target = -1
	lesson.step("Walk around with [W] [A] [S] [D].", func(s: TutorialSession) -> bool:
		var moved := s.player().position - s.step_start_position
		return Vector2(moved.x, moved.z).length() >= 5.0)
	lesson.step("Hold [Space] to fly up high.", func(s: TutorialSession) -> bool:
		return s.height_of(s.player()) >= 6.0)
	lesson.step("Hold [C] to fly down and land (double-tap [C] to dive).", func(s: TutorialSession) -> bool:
		return s.player().state in [State.IDLE, State.MOVING])
	lesson.step("Press [Tab] to lock on to the dummy.", func(s: TutorialSession) -> bool:
		return s.player().lock_on_target == D)
	return lesson


static func _light_string() -> TutorialLesson:
	var lesson := TutorialLesson.new(&"light", "Light string",
		"Lights are fast. Timing turns them into a combo.")
	lesson.step("Tap [LMB] to jab the dummy.", func(s: TutorialSession) -> bool:
		return s.count(Event.HIT, P, D) + s.count(Event.COUNTER, P, D) > 0)
	lesson.step("Press [LMB] again in rhythm for the full string. Mashing drops it!",
		func(s: TutorialSession) -> bool:
			var last: StringName = s.player_move_ids(&"light_string").back()
			return s.count(Event.HIT, P, D, [last]) > 0)
	return lesson


static func _heavies() -> TutorialLesson:
	var lesson := TutorialLesson.new(&"heavy", "Heavy and charge",
		"Heavies are slow but hit hard.")
	lesson.step("Press [RMB] for a smash.", func(s: TutorialSession) -> bool:
		return s.count(Event.HIT, P, D, s.player_move_ids(&"smash")) > 0)
	lesson.step("Hold [RMB] to charge, then let go to swing.", func(s: TutorialSession) -> bool:
		return s.count(Event.HIT, P, D, s.player_move_ids(&"charged_smash")) > 0)
	return lesson


static func _air_combo() -> TutorialLesson:
	var lesson := TutorialLesson.new(&"air", "Launcher, air combo, spike",
		"Take the fight up, then bring it crashing down.")
	lesson.step("Hold [S] and press [RMB] to launch the dummy.", func(s: TutorialSession) -> bool:
		return s.count(Event.HIT, P, D, s.player_move_ids(&"launcher")) > 0)
	lesson.step("Chase it! Fly up with [Space] and hit it in the air.", func(s: TutorialSession) -> bool:
		return s.count(Event.HIT, P, D) > 0 and s.height_of(s.dummy()) >= 2.0, "", Mode.FLY)
	lesson.step("Hold [C] and press [RMB] to spike it down.", func(s: TutorialSession) -> bool:
		return s.count(Event.HIT, P, D, s.player_move_ids(&"spike")) > 0, "", Mode.FLY)
	return lesson


static func _defense() -> TutorialLesson:
	var lesson := TutorialLesson.new(&"defense", "Block, perfect block, push-block",
		"The dummy fights back now. Stay calm.")
	lesson.step("Hold [E] to block 3 hits.", func(s: TutorialSession) -> bool:
		return s.count(Event.BLOCK, D, P) + s.count(Event.PERFECT_BLOCK, D, P) >= 3, "jab")
	lesson.step("Tap [E] just before a hit lands for a perfect block.", func(s: TutorialSession) -> bool:
		return s.count(Event.PERFECT_BLOCK, D, P) > 0, "jab")
	lesson.step("While blocking, press [RMB] to push-block it away.", func(s: TutorialSession) -> bool:
		return s.count(Event.PUSH_BLOCK, P, D) > 0, "jab")
	return lesson


static func _grab_and_tech() -> TutorialLesson:
	var lesson := TutorialLesson.new(&"grab", "Grab and tech",
		"Grabs beat blocks. Strikes beat grabs.")
	lesson.step("The dummy is blocking. Grab it with [F].", func(s: TutorialSession) -> bool:
		return s.count(Event.GRAB, P, D) > 0, "", Mode.BLOCK_ALL)
	lesson.step("Now it grabs you. Press [F] the moment you're caught to tech.",
		func(s: TutorialSession) -> bool:
			return s.count(Event.GRAB_TECH, D, P) > 0, "grab")
	return lesson


static func _dash_and_vanish() -> TutorialLesson:
	var lesson := TutorialLesson.new(&"dash", "Dodge, dash and vanish",
		"Tap Shift to dodge (free, but whiffs are punishable). Rushes and vanishes cost ki.")
	lesson.setup = func(s: TutorialSession) -> void:
		s.place_dummy(12.0)
	lesson.step("Hold [A] or [D] and tap [Shift] to sidestep round the dummy.", func(s: TutorialSession) -> bool:
		return s.player().state == State.DASHING \
			and s.player().dash_kind != FighterState.DashKind.RUSH)
	lesson.step("Hold [W] and press [Shift] to rush at the dummy.", func(s: TutorialSession) -> bool:
		return s.player().dash_kind == FighterState.DashKind.RUSH)
	lesson.step("Press [Shift] + [E] together to vanish.", func(s: TutorialSession) -> bool:
		return s.player().state == State.VANISHING)
	return lesson


static func _ki_and_burst() -> TutorialLesson:
	var lesson := TutorialLesson.new(&"meters", "Ki and burst",
		"Ki fuels dashes and vanishes. Burst is your comeback meter.")
	lesson.infinite_meters = false
	lesson.setup = func(s: TutorialSession) -> void:
		s.player().ki = 10 * FighterState.METER_UNIT
		s.player().burst = 0
	lesson.step("Hold [R] to charge your ki to full.", func(s: TutorialSession) -> bool:
		return s.player().ki >= s.sim.meter_tuning.ki_max * FighterState.METER_UNIT)
	lesson.step("Burst fills when you get hit or perfect-block. Tap [E] right before a hit!",
		func(s: TutorialSession) -> bool:
			return s.player().burst - s.step_start_burst \
				>= s.sim.meter_tuning.burst_per_perfect_block * FighterState.METER_UNIT, "jab")
	return lesson


static func _weapons() -> TutorialLesson:
	var lesson := TutorialLesson.new(&"weapons", "Weapons",
		"Weapons drop from the sky. Grab them before your rival does!")
	lesson.setup = func(s: TutorialSession) -> void:
		s.place_dummy(8.0)
		s.player().lock_on_target = -1
		s.training.spawn_weapon(Weapon.Kind.STORM_BLADE)
		var revolver := s.training.spawn_weapon(Weapon.Kind.ARC_REVOLVER)
		revolver.position += Vector3(5.0, 0, 1.5)
	lesson.step("Walk to the blade and press [G] to pick it up.", func(s: TutorialSession) -> bool:
		return s.count(Event.PICKUP, P) > 0)
	lesson.step("Pick up the revolver too. You can carry two.", func(s: TutorialSession) -> bool:
		return s.player().weapon_count() >= 2)
	lesson.step("Press [C] to switch weapons.", func(s: TutorialSession) -> bool:
		return s.count(Event.WEAPON_SWITCH, P) > 0)
	lesson.step("Press [V] to throw the one in your hand.", func(s: TutorialSession) -> bool:
		return s.count(Event.WEAPON_THROW, P) > 0)
	return lesson
