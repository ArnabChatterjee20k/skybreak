class_name TutorialAutopilot
extends RefCounted
## Scripted player for the tutorial: for each lesson step, the inputs that
## complete it, chosen from sim state (taps when free, presses in the string
## window, perfect-block taps). The tests pass every lesson with it, and the
## capture script uses it to stage screens.

const A := FighterInput.Action
const State := FighterState.State
## Ticks before a strike's first active tick that a perfect-block tap comes.
const PERFECT_BLOCK_LEAD := 3
## Strikes and grabs start from this far from the dummy (min, max), metres.
const STRIKE_BAND := Vector2(1.0, 2.0)
const CHARGE_BAND := Vector2(2.6, 3.2)

var _previous := FighterInput.new()


## The player's input for the coming tick.
func input_for(s: TutorialSession) -> FighterInput:
	var plan := _plan(s)
	var held: int = plan.get("held", 0)
	var tap: int = plan.get("tap", 0)
	# A tap is a press on one tick; held last tick means let go first.
	if tap and not _previous.is_held(tap):
		held |= tap
	var input := FighterInput.from_held(held, _previous)
	input.move = plan.get("move", Vector2.ZERO)
	input.vertical = plan.get("vertical", 0)
	_previous = input
	return input


func _plan(s: TutorialSession) -> Dictionary:
	if s.lesson_complete:
		return {}
	var me := s.player()
	var free := me.state in [State.IDLE, State.MOVING, State.FLYING, State.FALLING]
	var close_in := [&"light", &"heavy", &"grab"].has(s.lesson().id) \
		or (s.lesson().id == &"air" and s.step_index == 0)
	if close_in and free and s.height_of(s.dummy()) > 0.05:
		# Let the dummy settle on the floor before the next strike.
		return {}
	var gap := me.position.distance_to(s.dummy().position)
	# The charged smash steps far forward, so it starts from further out.
	var band := CHARGE_BAND if s.lesson().id == &"heavy" and s.step_index == 1 else STRIKE_BAND
	if close_in and free and (gap > band.y or gap < band.x):
		# Knocked away or on top of it: get back to striking range first
		# (locked on, forward is toward the dummy).
		var rise := s.dummy().position.y - me.position.y
		return {"move": Vector2(0, 1 if gap > band.y else -1), "vertical": signi(roundi(rise))}
	match [s.lesson().id, s.step_index]:
		[&"move", 0]:
			return {"move": Vector2(0, 1)}
		[&"move", 1]:
			return {"vertical": 1}
		[&"move", 2]:
			return {"vertical": -1}
		[&"move", 3]:
			return {"tap": A.LOCK_TOGGLE}
		[&"light", 0]:
			return {"tap": A.LIGHT if free else 0}
		[&"light", 1]:
			return {"tap": A.LIGHT if free or _in_string_window(me) else 0}
		[&"heavy", 0]:
			return {"tap": A.HEAVY if free else 0}
		[&"heavy", 1]:
			# Hold the heavy through a charge level, then let go.
			if me.state == State.ATTACKING and (me.holding_charge or me.charge_ticks > 0):
				return {"held": A.HEAVY if me.charge_level < 2 else 0}
			return {"held": A.HEAVY if free else 0}
		[&"air", 0]:
			return {"tap": A.HEAVY if free else 0, "move": Vector2(0, -1)}
		[&"air", 1]:
			return _chase_in_air(s, A.LIGHT, 0)
		[&"air", 2]:
			return _chase_in_air(s, A.HEAVY, -1)
		[&"defense", 0]:
			return {"held": A.BLOCK}
		[&"defense", 1], [&"meters", 1]:
			return {"held": A.BLOCK if _perfect_block_moment(s.dummy()) else 0}
		[&"defense", 2]:
			var guarding := me.state == State.BLOCKING and s.dummy().state == State.ATTACKING
			return {"held": A.BLOCK | (A.HEAVY if guarding else 0)}
		[&"grab", 0]:
			return {"tap": A.GRAB if free else 0}
		[&"grab", 1]:
			return {"tap": A.GRAB if me.state == State.GRABBED else 0}
		[&"dash", 0]:
			return {"tap": A.DASH if free else 0, "move": Vector2(1, 0)}
		[&"dash", 1]:
			return {"tap": A.DASH if free else 0, "move": Vector2(0, 1)}
		[&"dash", 2]:
			return {"tap": (A.DASH | A.BLOCK) if free else 0}
		[&"meters", 0]:
			return {"held": A.CHARGE}
		[&"weapons", 0], [&"weapons", 1]:
			return _walk_to_pickup(s)
		[&"weapons", 2]:
			return {"tap": A.WEAPON_NEXT if free and me.switch_lockout == 0 else 0}
		[&"weapons", 3]:
			if me.held_weapon() == Weapon.Kind.NONE:
				return {"tap": A.WEAPON_NEXT if free and me.switch_lockout == 0 else 0}
			return {"tap": A.THROW if free and me.switch_lockout == 0 else 0}
	return {}


## One tick into the timing window of the current light: queue the next hit.
func _in_string_window(me: FighterState) -> bool:
	return me.state == State.ATTACKING and me.string_index > 0 and not me.string_queued \
		and me.hitstop_ticks == 0 and me.move_tick == me.move.string_window_start_tick + 1


## True on the tick to tap block so the attacker's strike lands inside the perfect-block window.
func _perfect_block_moment(attacker: FighterState) -> bool:
	if attacker.state != State.ATTACKING or attacker.move == null \
			or attacker.move.kind != MoveData.Kind.STRIKE:
		return false
	return attacker.move.startup_ticks - attacker.move_tick == PERFECT_BLOCK_LEAD


## Flies level with the airborne dummy, closes in (locked on, forward is toward it), then attacks.
func _chase_in_air(s: TutorialSession, attack: int, vertical_on_attack: int) -> Dictionary:
	var me := s.player()
	var target := s.dummy()
	var rise := target.position.y - me.position.y
	var planar := Vector2(target.position.x - me.position.x, target.position.z - me.position.z).length()
	var plan := {}
	if absf(rise) > 0.4:
		plan.vertical = 1 if rise > 0.0 else -1
	if planar > 1.6:
		plan.move = Vector2(0, 1)
	var free := me.state in [State.IDLE, State.MOVING, State.FLYING, State.FALLING]
	if free and absf(rise) <= 0.8 and planar <= 2.0 and s.height_of(target) >= 2.0:
		plan.tap = attack
		plan.vertical = vertical_on_attack
	return plan


## Walks (unlocked, view yaw 0) to the nearest pickup and presses G in reach.
func _walk_to_pickup(s: TutorialSession) -> Dictionary:
	var me := s.player()
	if s.sim.pickup_in_reach(TutorialSession.PLAYER) >= 0:
		var free := me.state in [State.IDLE, State.MOVING]
		return {"tap": A.PICKUP if free else 0}
	var nearest: WeaponPickup
	for pickup in s.sim.pickups:
		if nearest == null or me.position.distance_to(pickup.position) < me.position.distance_to(nearest.position):
			nearest = pickup
	if nearest == null:
		return {}
	var to := nearest.position - me.position
	# With view yaw 0, move.y forward is world -Z and move.x right is world +X.
	return {"move": Vector2(to.x, -to.z).normalized()}
