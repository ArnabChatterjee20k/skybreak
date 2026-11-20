extends SceneTree
## T-DEF1 defense audit: plays QA AI matches (real ZoneMatch, AIDriver on every slot,
## view checks off) and counts defensive attempts and the outcome of every attack.
##   godot --headless --path . -s res://tools/qa/defense_audit.gd -- [--shard i/n] [--ticks N] --out DIR
## Writes DIR/defense_<shard>.json; tools/qa/defense_summary.py merges the shards.

const S := FighterState.State
const E := CombatSim.EventType
## An opponent this close (m) to an attacker during its active frames counts as threatened.
const THREAT_RANGE := 4.0
const MATCH_TICKS := 2400

var _args := {}
var totals := {}
## fighter -> open attack instance {move_id, contact, near}
var _open := {}
var _prev_state := {}
var _prev_move := {}
var _prev_move_tick := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var raw := OS.get_cmdline_user_args()
	for i in raw.size():
		if raw[i].begins_with("--"):
			var has_value := i + 1 < raw.size() and not raw[i + 1].begins_with("--")
			_args[raw[i].trim_prefix("--")] = raw[i + 1] if has_value else "1"
	var out_dir: String = _args.get("out", "user://defense")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var shard := (_args.get("shard", "0/1") as String).split("/")
	var ticks := int(_args.get("ticks", str(MATCH_TICKS)))
	var specs := QaMatchSpec.quick_matrix()
	for n in specs.size():
		if n % int(shard[1]) != int(shard[0]):
			continue
		await _play(specs[n], ticks)
	var file := FileAccess.open(out_dir.path_join("defense_%s.json" % shard[0]), FileAccess.WRITE)
	file.store_string(JSON.stringify(totals, "\t"))
	file.close()
	quit()


func _bump(key: String, by := 1) -> void:
	totals[key] = int(totals.get(key, 0)) + by


func _play(spec: QaMatchSpec, ticks: int) -> void:
	var run := QaMatchRun.new(spec)
	run.check_view = false
	run.build(root)
	await process_frame
	_open.clear()
	_prev_state.clear()
	_prev_move.clear()
	_prev_move_tick.clear()
	var fight_ticks := 0
	while run.tick < ticks and not run.is_over():
		await process_frame
		run.advance()
		if run.level.match_flow.phase != MatchFlow.Phase.FIGHT:
			continue
		fight_ticks += 1
		_observe(run.level.sim)
	_bump("fighter_ticks", fight_ticks * spec.fighter_count())
	_bump("matches")
	print("[defense] %s: %d fight ticks" % [spec.id(), fight_ticks])
	run.level.queue_free()
	await process_frame


func _observe(sim: CombatSim) -> void:
	for event: Dictionary in sim.events:
		_count_event(sim, event)
	for i in sim.fighters.size():
		var f := sim.fighters[i]
		var before: int = _prev_state.get(i, -1)
		if f.state != before:
			_count_entry(sim, i, before)
		_track_attack(sim, i)
		_prev_state[i] = f.state
		_prev_move[i] = f.move
		_prev_move_tick[i] = f.move_tick


func _count_event(sim: CombatSim, event: Dictionary) -> void:
	var type: int = event.type
	var shot := String(event.get("move_id", "")).ends_with("/shot")
	match type:
		E.HIT, E.COUNTER, E.ARMOR, E.BLOCK, E.PERFECT_BLOCK, E.GRAB, E.GRAB_TECH, E.PUSH_BLOCK:
			_bump("event_%s%s" % [E.keys()[type], "_shot" if shot else ""])
			var attacker: int = event.get("attacker", -1)
			if _open.has(attacker) and not shot and _open[attacker].move_id == event.get("move_id"):
				_open[attacker].contact = E.keys()[type]
		E.PROJECTILE_HIT:
			if event.reflected:
				_bump("projectile_reflected")
			elif event.blocked:
				_bump("projectile_blocked")
			else:
				_bump("projectile_hit")
		E.BULLET_ABSORB:
			_bump("projectile_dash_absorbed")
		E.FIRE:
			_bump("projectiles_fired", int(event.get("count", 1)))
		E.GUARD_BREAK:
			_bump("event_GUARD_BREAK")


## A state entry: counts dashes, vanishes (by where they started) and guards.
func _count_entry(sim: CombatSim, i: int, before: int) -> void:
	var f := sim.fighters[i]
	match f.state:
		S.VANISHING:
			var context := "neutral"
			if before in [S.BLOCKING, S.BLOCKSTUN]:
				context = "from_guard"
			elif before == S.ATTACKING:
				context = "combo_cancel"
			elif before == S.DASHING:
				context = "from_dash"
			if _threatened(sim, i):
				context += "_under_attack"
			_bump("vanish_" + context)
		S.DASHING:
			_bump("dash_%s" % FighterState.DashKind.keys()[f.dash_kind])
			if _threatened(sim, i):
				_bump("dash_under_attack")
		S.BLOCKING:
			_bump("guard_raised")
		S.CHARGING:
			_bump("ki_charge")
		S.KNOCKDOWN:
			_bump("knockdown")


## True if an opponent within THREAT_RANGE is in the startup or active part of a strike.
func _threatened(sim: CombatSim, i: int) -> bool:
	for j in sim.fighters.size():
		var o := sim.fighters[j]
		if j == i or o.team == sim.fighters[i].team or o.state != S.ATTACKING:
			continue
		if o.attack_phase() in [FighterState.AttackPhase.STARTUP, FighterState.AttackPhase.ACTIVE] \
				and o.position.distance_to(sim.fighters[i].position) <= THREAT_RANGE:
			return true
	return false


## One instance per move started; at its end it is classed by contact or by what the
## threatened opponents were doing during its active frames.
func _track_attack(sim: CombatSim, i: int) -> void:
	var f := sim.fighters[i]
	var attacking := f.state == S.ATTACKING and f.move != null and not WeaponMoves.is_shot(f.move)
	var fresh: bool = attacking and (_prev_state.get(i, -1) != S.ATTACKING or _prev_move.get(i) != f.move \
		or f.move_tick < int(_prev_move_tick.get(i, 0)))
	if _open.has(i) and (fresh or not attacking):
		_close(i)
	if fresh:
		_open[i] = {"move_id": f.move.id, "kind": f.move.kind, "contact": "", "near": {}}
	if not _open.has(i) or f.attack_phase() != FighterState.AttackPhase.ACTIVE:
		return
	for j in sim.fighters.size():
		var o := sim.fighters[j]
		if j == i or o.team == f.team or o.is_knocked_out() \
				or o.position.distance_to(f.position) > THREAT_RANGE:
			continue
		var why := "present"
		if o.state == S.VANISHING:
			why = "vanish"
		elif o.state == S.KNOCKDOWN:
			why = "knockdown"
		elif o.is_invincible_to(true):
			why = "iframes"
		elif o.state == S.DASHING:
			why = "dash"
		_open[i].near[why] = true


func _close(i: int) -> void:
	var inst: Dictionary = _open[i]
	_open.erase(i)
	var label: String = "grab" if inst.kind == MoveData.Kind.GRAB else (
		"push_block" if inst.kind == MoveData.Kind.PUSH_BLOCK else "strike")
	var outcome: String = inst.contact
	if outcome == "":
		var near: Dictionary = inst.near
		if near.is_empty():
			outcome = "whiff_nobody_near"
		else:
			for why in ["vanish", "iframes", "knockdown", "dash"]:
				if near.has(why):
					outcome = "evaded_" + why
					break
			if outcome == "":
				outcome = "whiff_close"
	_bump("attack_%s_total" % label)
	_bump("attack_%s_%s" % [label, outcome])
