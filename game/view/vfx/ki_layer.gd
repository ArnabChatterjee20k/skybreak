class_name KiLayer
extends Node3D
## Draws the sim's ki attacks (T-KI1): travelling blasts with a glow and trail,
## the charge orb that swells while a blast or beam charges, muzzle flashes,
## impact bursts, reflect flashes, beams at their sim thickness and the beam
## clash prompts. View only: reads CombatSim, never writes it. MatchVfx owns it
## and forwards each tick's events to react().

const E := CombatSim.EventType
const REFLECT_COLOR := Color(0.75, 0.9, 1.0)
## Clash start/end burst and ring scales: the ring stays about 3 m, the star about 1.5 m.
const CLASH_BURST_SCALE := 1.4
const CLASH_RING_SCALE := 0.6
## The charge orb: size at the start and at the end of the charge.
const CHARGE_START_SCALE := 0.35
const CHARGE_END_SCALE := 1.6
## Visible blast size per metre of sim radius.
const BLAST_SCALE_PER_RADIUS := 1.9

var sim: CombatSim
var vfx: MatchVfx

var _shots: Dictionary = {} # projectile id -> KiBlastEffect
var _previous: Dictionary = {} # projectile id -> position last tick
var _beams: Dictionary = {} # beam id -> Array[KiBeamEffect] (main, side rays)
var _tells: Dictionary = {} # fighter index -> KiBeamEffect charging before its beam fires
var _charge_orbs: Dictionary = {} # fighter index -> KiBlastEffect held at the hands
var _prompt: BeamClashPrompt


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_prompt = BeamClashPrompt.new()
	layer.add_child(_prompt)


## This tick's ki events; call once per sim tick, after sim.tick().
func react(events: Array[Dictionary]) -> void:
	if sim == null:
		return
	for event in events:
		_play(event)
	_sync_shots()
	_sync_charge_orbs()
	_sync_beams()
	_prompt.show_clash(sim, _local_clash())


func _process(_delta: float) -> void:
	if sim == null:
		return
	var blend := Engine.get_physics_interpolation_fraction()
	for projectile in sim.projectiles:
		var shot: KiBlastEffect = _shots.get(projectile.id)
		if shot == null:
			continue
		var from: Vector3 = _previous.get(projectile.id, projectile.position)
		shot.global_position = from.lerp(projectile.position, blend)


func color_of(fighter_index: int) -> Color:
	if sim == null or fighter_index < 0 or fighter_index >= sim.fighters.size():
		return VfxCatalog.WARM
	return KiRules.kit_of(sim.fighters[fighter_index]).color


## Live blast effects, for tests.
func shot_count() -> int:
	return _shots.size()


func beam_effect_count() -> int:
	var count := 0
	for effects: Array in _beams.values():
		count += effects.size()
	return count


func prompt() -> BeamClashPrompt:
	return _prompt


func _play(event: Dictionary) -> void:
	var where: Vector3 = event.get("position", Vector3.ZERO)
	match event.type:
		E.KI_FIRE:
			var charged: bool = event.get("shot", 0) == KiRules.Shot.CHARGED
			vfx.spawn(&"blast_impact", where, color_of(event.fighter).lerp(Color.WHITE, 0.3), 0.9 if charged else 0.45)
		E.KI_CHARGE:
			vfx.spawn(&"aura_flare", sim.fighters[event.fighter].position, color_of(event.fighter), 0.7)
		E.KI_ABSORB:
			vfx.spawn(&"sonic_ring", where, Color(1, 1, 1, 0.8), 0.5)
		E.PROJECTILE_HIT:
			if event.get("weapon", -1) == Weapon.Kind.NONE and event.get("reflected", false):
				vfx.spawn(&"sonic_ring", where, REFLECT_COLOR, 1.1)
				vfx.spawn(&"vanish_burst", where, REFLECT_COLOR, 0.8)
		E.BEAM_START:
			_start_tell(event.fighter, event.move_id)
		E.BEAM_CLASH, E.CLASH_END:
			# One compact beat at the clash point, about a fighter tall (ART_BIBLE §7).
			vfx.spawn(&"anime_burst", where, Color.WHITE, CLASH_BURST_SCALE)
			vfx.spawn(&"sonic_ring", where, Color.WHITE, CLASH_RING_SCALE)
		E.CLASH_BEAT:
			if event.get("gain", 0) > 0:
				vfx.spawn(&"sonic_ring", where, color_of(event.fighter), 0.8)


func _start_tell(index: int, move_id: StringName) -> void:
	var fighter := sim.fighters[index]
	var kit := KiRules.kit_of(fighter)
	var move := kit.ultimate if move_id == kit.ultimate.id else kit.beam
	var beam := vfx.play_beam(sim._muzzle(fighter), sim._muzzle(fighter) + fighter.aim_basis() * Vector3.FORWARD,
		kit.color, move.startup_ticks * CombatSim.TICK_SECONDS, 30.0)
	beam.width_scale = kit.radius_for(move) / KiBeamEffect.BEAM_RADIUS
	beam.charge_scale = 1.6 if move == kit.ultimate else 1.0
	beam.wait_for_drive = true
	_tells[index] = beam


## One effect per ki projectile, kept in step with the sim; gone ones burst where they ended.
func _sync_shots() -> void:
	var alive := {}
	for projectile in sim.projectiles:
		if projectile.ki == KiRules.Shot.NONE:
			continue
		alive[projectile.id] = true
		var shot: KiBlastEffect = _shots.get(projectile.id)
		if shot == null:
			shot = vfx.hold_ki_blast(projectile.position, color_of(projectile.owner))
			shot.hold_flight(projectile.radius * BLAST_SCALE_PER_RADIUS)
			_shots[projectile.id] = shot
		_previous[projectile.id] = projectile.position
	for id: int in _shots.keys():
		if not alive.has(id):
			(_shots[id] as KiBlastEffect).impact_now()
			_shots.erase(id)
			_previous.erase(id)


## An orb swells at the hands while a charged blast charges.
func _sync_charge_orbs() -> void:
	for index in sim.fighters.size():
		var fighter := sim.fighters[index]
		var kit := KiRules.kit_of(fighter)
		var charging := fighter.state == FighterState.State.ATTACKING and fighter.move == kit.charged \
			and fighter.move_tick < kit.charged.startup_ticks
		var orb: KiBlastEffect = _charge_orbs.get(index)
		if not charging:
			if orb != null:
				orb.stop()
				_charge_orbs.erase(index)
			continue
		if orb == null:
			orb = vfx.hold_ki_blast(sim._muzzle(fighter), kit.color)
			_charge_orbs[index] = orb
		var progress := float(fighter.move_tick) / kit.charged.startup_ticks
		orb.hold_flight(lerpf(CHARGE_START_SCALE, CHARGE_END_SCALE, progress))
		orb.global_position = sim._muzzle(fighter)


## Beam effects follow the sim beams: origin, head, thickness, side rays, clash flare.
func _sync_beams() -> void:
	var alive := {}
	for beam in sim.beams:
		alive[beam.id] = true
		var effects: Array = _beams.get(beam.id, [])
		if effects.is_empty():
			var main: KiBeamEffect = _tells.get(beam.owner)
			_tells.erase(beam.owner)
			if main == null or not main.is_playing():
				main = vfx.play_beam(beam.origin, beam.head(), color_of(beam.owner), 0.0, 30.0)
			main.width_scale = beam.radius / KiBeamEffect.BEAM_RADIUS
			effects.append(main)
			if beam.split_angle > 0.0:
				for _side in 2:
					var ray := vfx.play_beam(beam.origin, beam.head(), color_of(beam.owner), 0.0, 30.0)
					ray.width_scale = beam.split_radius / KiBeamEffect.BEAM_RADIUS
					effects.append(ray)
			_beams[beam.id] = effects
		var rays := beam.rays()
		for i in mini(effects.size(), rays.size()):
			var effect: KiBeamEffect = effects[i]
			effect.drive(rays[i][0], rays[i][1], beam.clash_id >= 0)
	for id: int in _beams.keys():
		if not alive.has(id):
			for effect: KiBeamEffect in _beams[id]:
				effect.release()
			_beams.erase(id)
	# A tell whose fighter got hit out of the startup fades.
	for index: int in _tells.keys():
		var fighter := sim.fighters[index]
		if fighter.state != FighterState.State.ATTACKING or not KiRules.kit_of(fighter).is_beam(fighter.move):
			(_tells[index] as KiBeamEffect).release()
			_tells.erase(index)


## The clash the local player (fighter 0) is in, else any clash.
func _local_clash() -> BeamClash:
	var found: BeamClash = null
	for clash in sim.beam_clashes:
		if clash.side_of(0) >= 0:
			return clash
		found = clash
	return found
