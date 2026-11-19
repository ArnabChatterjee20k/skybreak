class_name FrameMeter
extends RefCounted
## Frame data for the training overlay. Static maths gives a move's advantage
## from its MoveData; observe() measures the real advantage of each exchange
## in the sim (who can act first after the contact, in ticks).

## Frame advantage on block of a strike landing on its first active tick, for
## the attacker (positive = attacker acts first). The blocker acts on the
## stun + 1st tick after contact, the attacker after its active and recovery
## ticks; shared hitstop freezes both and cancels out.
static func on_block(move: MoveData) -> int:
	return move.blockstun_ticks + 1 - (move.active_ticks + move.recovery_ticks)


## Frame advantage on hit, as combo hit 1. Spikes end in a knockdown instead.
static func on_hit(move: MoveData) -> int:
	return move.hitstun_ticks + 1 - (move.active_ticks + move.recovery_ticks)


## Advantage text: "+5", "-2", "0"; "KD" for knockdowns, "—" when it does not apply.
static func on_hit_text(move: MoveData) -> String:
	if move.kind == MoveData.Kind.GRAB:
		return "throw"
	if move.kind == MoveData.Kind.PUSH_BLOCK:
		return "—"
	if move.knockback_type == MoveData.KnockbackType.SPIKE:
		return "KD"
	return signed(on_hit(move))


static func on_block_text(move: MoveData) -> String:
	if move.kind == MoveData.Kind.GRAB:
		return "unblockable"
	if move.kind == MoveData.Kind.PUSH_BLOCK:
		return "—"
	return signed(on_block(move))


static func signed(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


## The last move the attacker started, and its numbers.
var last_move: MoveData
## Damage of the last move's hit, after scaling; 0 until it lands.
var last_damage := 0
## Measured advantage of the last finished exchange; valid when has_measurement.
var measured_advantage := 0
var has_measurement := false
## "hit" or "block": what the measured exchange was.
var measured_kind := ""
## Combo on the dummy: live while it lasts, the last one stays readable afterwards.
var combo_hits := 0
var combo_damage := 0

var _measuring := false
var _attacker_free_tick := -1
var _defender_free_tick := -1
var _contact_kind := ""
var _previous_move: MoveData


## Call after every sim tick with the attacker and the defender it trains on.
func observe(sim: CombatSim, attacker_index: int, defender_index: int) -> void:
	var attacker := sim.fighters[attacker_index]
	var defender := sim.fighters[defender_index]
	if attacker.state == FighterState.State.ATTACKING and attacker.move != _previous_move \
			and attacker.move != null:
		last_move = attacker.move
		last_damage = 0
	_previous_move = attacker.move if attacker.state == FighterState.State.ATTACKING else null
	for event in sim.events:
		if event.get("attacker", -1) != attacker_index or event.get("target", -1) != defender_index:
			continue
		match event.type:
			CombatSim.EventType.HIT, CombatSim.EventType.COUNTER, CombatSim.EventType.ARMOR:
				_start_exchange("hit")
				last_damage = event.damage
			CombatSim.EventType.BLOCK, CombatSim.EventType.PERFECT_BLOCK:
				_start_exchange("block")
			CombatSim.EventType.THROW:
				last_damage = event.damage
	if defender.combo_hits > 0:
		combo_hits = defender.combo_hits
		combo_damage = defender.combo_damage
	if not _measuring:
		return
	if _attacker_free_tick < 0 and is_actionable(attacker):
		_attacker_free_tick = sim.current_tick
	if _defender_free_tick < 0 and is_actionable(defender):
		_defender_free_tick = sim.current_tick
	if _attacker_free_tick >= 0 and _defender_free_tick >= 0:
		measured_advantage = _defender_free_tick - _attacker_free_tick
		measured_kind = _contact_kind
		has_measurement = true
		_measuring = false


## Standing, moving, flying or guarding: free to act.
static func is_actionable(fighter: FighterState) -> bool:
	return fighter.state in [
		FighterState.State.IDLE, FighterState.State.MOVING, FighterState.State.FALLING,
		FighterState.State.FLYING, FighterState.State.BLOCKING,
	]


func clear() -> void:
	last_move = null
	last_damage = 0
	has_measurement = false
	measured_kind = ""
	combo_hits = 0
	combo_damage = 0
	_measuring = false
	_previous_move = null


func _start_exchange(kind: String) -> void:
	_measuring = true
	_contact_kind = kind
	_attacker_free_tick = -1
	_defender_free_tick = -1
