class_name MatchVfx
extends Node3D
## The T-D27 effects layer: reads CombatSim.events and fighter state (read-only) and
## plays pooled effects: heavy-hit bursts, guard-break shatter, KO contact burst, zone
## extras, swing smears, dash/vanish afterimages, speed lines, sonic rings, landing
## dust, aura flares and the power-up aura while charging ki. CombatFeedback forwards
## each tick's events to react().

const E := CombatSim.EventType
const S := FighterState.State
## Hits with at least this much hitstop (ticks) read as heavy, as in CombatFeedback.
const HEAVY_HITSTOP := 7
## A dash leaves an afterimage every this many ticks.
const GHOST_EVERY := 4
## Speed (m/s) that fires the sonic ring, and ticks before it can fire again.
const SONIC_SPEED := 50.0
const SONIC_COOLDOWN := 45
## Trails (afterimages, sonic rings) that would start this close to the lens (m) are skipped:
## a body-sized shell right in front of the camera covers the fight (#127).
const NEAR_LENS := 3.5
## A sonic ring is 2.8 m wide, so it keeps further from the lens.
const NEAR_LENS_RING := 5.0
## Pose ghosts kept per fighter; the oldest is reused when all are fading.
const GHOSTS_PER_FIGHTER := 4
## Flying at this share of fly_speed or faster counts as top speed (speed lines).
const TOP_SPEED_SHARE := 0.95
## Falling faster than this (m/s) onto the ground kicks up dust.
const LANDING_SPEED := 7.0
## Fighter position is the capsule centre; feet are this far below.
const FEET := 1.0
## Per zone: dust colour, debris colour, extra effect on landing.
const ZONE_GROUND := {
	&"skyhold_ruins": [Color(0.78, 0.74, 0.66), Color(0.55, 0.52, 0.48), &""],
	&"verdant_falls": [Color(0.7, 0.78, 0.6), Color(0.32, 0.5, 0.22), &""],
	&"ember_rift": [Color(0.42, 0.34, 0.32), Color(0.2, 0.15, 0.14), &"sparkles"],
	&"frozen_peaks": [Color(0.92, 0.96, 1.0), Color(0.7, 0.82, 0.95), &""],
	&"shattered_mesa": [Color(0.9, 0.66, 0.42), Color(0.62, 0.38, 0.22), &""],
	&"stormfall_city": [Color(0.6, 0.64, 0.7), Color(0.36, 0.38, 0.44), &""],
	&"heartbloom_gardens": [Color(1.0, 0.86, 0.9), Color(0.95, 0.55, 0.7), &"petals"],
}
const EMBER := Color(1.0, 0.45, 0.1)
## Weapon kinds to smear styles; ranged weapons have none.
const SMEAR_BY_WEAPON := {
	Weapon.Kind.NONE: &"smear_fist", Weapon.Kind.KI_GAUNTLETS: &"smear_gauntlets",
	Weapon.Kind.STORM_BLADE: &"smear_blade", Weapon.Kind.SKY_LANCE: &"smear_lance",
	Weapon.Kind.TITAN_HAMMER: &"smear_hammer", Weapon.Kind.ORBIT_CHAKRAM: &"smear_chakram",
	Weapon.Kind.EMBER_SCYTHE: &"smear_scythe",
}

## Metres a hit effect sits out from the target's body axis past the contact, so it
## flares beside the torso instead of on it.
const SPARK_STANDOFF := 0.4
## Effect scale when more than two fighters share the screen (FFA).
const CROWD_SCALE := 0.8
## Rendered frames the KO impact frame holds (ART_BIBLE §7: the 1-frame KO impact frame).
const KO_IMPACT_FRAMES := 1
## Ticks of continuous ki charging before the aura reaches power level 2 and 3.
const AURA_LEVEL_TICKS: Array[int] = [60, 150]

## Read-only. Found among the ancestors (the arena's `sim`) when not set.
var sim: CombatSim
## Rations the screen-wide impact moments (shared with CombatFeedback).
var impact_gate := ImpactFrameGate.new()
## Energy colour per fighter: yours warm, the opponent cool (GAME_DESIGN §11).
var energy_colors: Array[Color] = [Color(1.0, 0.55, 0.2), Color(0.35, 0.8, 1.0)]

var _pools: Dictionary = {}
var _screen: VfxScreen
var _trails: Array[FlightTrail] = []
var _prev_state := PackedInt32Array()
var _prev_phase := PackedInt32Array()
## Special tells, trails and Vexa's decoy ghost (T-SP1).
var specials := SpecialVfx.new()
var _prev_position := PackedVector3Array()
var _prev_velocity := PackedVector3Array()
var _sonic_ready := PackedInt32Array()
var _was_fast := PackedByteArray()
## Ki blasts, beams and clash prompts (T-KI1).
var ki_layer := KiLayer.new()
## Particle share for the graphics tier (GraphicsSettings vfx_density); set before the first tick.
var particle_quality := 1.0
var _auras: Array[FighterAura] = []
## Each aura eases between the fighter's last two tick positions.
var _aura_from := PackedVector3Array()
var _aura_to := PackedVector3Array()
var _aura_level := PackedInt32Array()
## Per fighter: PoseGhost silhouettes for dash afterimages (#127), built on first use.
var _ghosts: Array = []
var _ghost_sources: Array = []
var _views_searched := false


func _ready() -> void:
	particle_quality = float(GraphicsSettings.load_saved().quality_value("vfx_density"))
	for kind in VfxCatalog.kinds():
		var pool := VfxPool.new(kind, VfxCatalog.CAPACITY[kind])
		add_child(pool)
		pool.fill(VfxCatalog.PREFILL)
		_pools[kind] = pool
	_screen = VfxScreen.new()
	add_child(_screen)
	ki_layer.vfx = self
	add_child(ki_layer)


## Plays this tick's effects. Call once per sim tick, after sim.tick().
func react(events: Array[Dictionary]) -> void:
	if sim == null:
		sim = _find_sim()
	impact_gate.tick()
	var zone: StringName = sim.zone if sim != null else &""
	for event in events:
		_play_event(event, zone)
		if event.get("type", -1) == CombatSim.EventType.PERFECT_DODGE:
			_play_perfect_dodge(event)
	specials.react(self, sim, events)
	if sim != null:
		ki_layer.sim = sim
		_watch_fighters()
		ki_layer.react(events)


## Perfect dodge (T-DEF2): a bright white-blue afterimage where the dodger was, crisp speed lines
## and a short cool colour pop; no full-screen flash, so the counter-attack stays readable.
func _play_perfect_dodge(event: Dictionary) -> void:
	if sim == null or event.get("target", -1) < 0:
		return
	var dodger := sim.fighters[event.target as int]
	var ghost := Color(0.75, 0.9, 1.0)
	if not pose_ghost(event.target as int, ghost):
		spawn(&"afterimage", dodger.position, ghost, 1.2)
	var center := _screen_point(dodger.position)
	_screen.burst_lines(center, ghost, 0.22)
	_screen.color_pop(ghost, 0.3, 0.12)


func _process(delta: float) -> void:
	follow_fighters(delta)
	for list: Variant in _ghosts:
		if list != null:
			for ghost: PoseGhost in list:
				ghost.advance(delta)


## Moves the speed-line emitters onto the fighters (each drawn frame).
func follow_fighters(delta: float = 1.0 / 60.0) -> void:
	if sim == null:
		return
	var blend := Engine.get_physics_interpolation_fraction()
	for i in mini(_auras.size(), _aura_to.size()):
		_auras[i].global_position = _aura_from[i].lerp(_aura_to[i], blend)
	for i in mini(_trails.size(), sim.fighters.size()):
		var fighter := sim.fighters[i]
		var lines := wants_speed_lines(fighter, sim.tuning) and not sim.round_over
		_trails[i].follow(fighter.position, fighter.velocity if lines else Vector3.ZERO, color_of(i), delta)


## Speed lines only for a long dash (past the tapped step), a flight boost or top speed.
static func wants_speed_lines(fighter: FighterState, tuning: MovementTuning) -> bool:
	match fighter.state:
		S.DASHING:
			return fighter.dash_kind == FighterState.DashKind.SUSTAINED \
				or (fighter.dash_kind == FighterState.DashKind.RUSH and fighter.state_ticks >= tuning.dash_step_ticks)
		S.FLYING, S.FALLING:
			return fighter.velocity.length() >= tuning.fly_speed * TOP_SPEED_SHARE
	return false


## Advances every effect and overlay; tests and fast-forward scripts call this.
func advance(delta: float) -> void:
	for kind: StringName in _pools:
		(_pools[kind] as VfxPool).advance(delta)
	_screen.advance(delta)


func pool(kind: StringName) -> VfxPool:
	return _pools.get(kind)


func pools() -> Array[VfxPool]:
	var found: Array[VfxPool] = []
	for kind: StringName in _pools:
		found.append(_pools[kind])
	return found


func screen() -> VfxScreen:
	return _screen


func color_of(fighter_index: int) -> Color:
	if fighter_index < 0 or energy_colors.is_empty():
		return VfxCatalog.WARM
	return energy_colors[fighter_index % energy_colors.size()]


func spawn(kind: StringName, where: Vector3, color: Color = Color.TRANSPARENT, effect_scale: float = 1.0,
		orientation: Basis = Basis.IDENTITY) -> VfxEffect:
	var effect := (_pools[kind] as VfxPool).spawn()
	effect.play_at(where, color, effect_scale, orientation)
	return effect


## A ki blast from `from` toward `to`, ending in an impact burst there.
func play_ki_blast(from: Vector3, to: Vector3, color: Color, speed: float = 45.0) -> KiBlastEffect:
	var blast := (_pools[&"ki_blast"] as VfxPool).spawn() as KiBlastEffect
	blast.launch(from, to - from, color, from.distance_to(to) / speed, speed)
	return blast


## A ki blast held in flight at `at`; the caller moves it (KiLayer follows the sim).
func hold_ki_blast(at: Vector3, color: Color) -> KiBlastEffect:
	var blast := (_pools[&"ki_blast"] as VfxPool).spawn() as KiBlastEffect
	blast.launch(at, Vector3.ZERO, color, 10.0, 0.0)
	return blast


## A beam charging at `from` and firing to `to`; clash flares the tip.
func play_beam(from: Vector3, to: Vector3, color: Color, charge: float = 0.6, sustain: float = 1.2,
		clash: bool = false) -> KiBeamEffect:
	var beam := (_pools[&"ki_beam"] as VfxPool).spawn() as KiBeamEffect
	beam.fire(from, to, color, charge, sustain, clash)
	return beam


## World effects for one event in a zone.
static func effects_for(event: Dictionary, zone: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	var type: int = event.get("type", -1)
	var heavy: bool = event.get("hitstop", 0) >= HEAVY_HITSTOP
	var move := String(event.get("move_id", &""))
	var hit := type == E.HIT or type == E.THROW or type == E.COUNTER or type == E.KO
	match type:
		E.COUNTER:
			# Plain heavies get the heavy spark only; the burst is kept for counters.
			found.append(&"anime_burst")
		E.GUARD_BREAK:
			found.append(&"guard_shatter")
		E.COMBO_BREAKER:
			found.append_array(EscapeVfx.BREAKER_EFFECTS)
		E.AIR_TECH, E.TECH_ROLL:
			found.append_array(EscapeVfx.tech_effects(event))
		E.KO:
			found.append(&"ko_burst")
			if zone == &"stormfall_city":
				found.append(&"lightning")
	if hit and (move.begins_with("ki_blast") or move.begins_with("charged_blast") or move.begins_with("beam")):
		found.append(&"blast_impact")
	if hit and zone == &"heartbloom_gardens":
		if heavy or type == E.COUNTER or type == E.KO:
			found.append(&"petals")
		found.append(&"sparkles")
	return found


## Screen overlay an event earns (ImpactFrameGate.earns): &"lines" (guard break), &"ko",
## &"breaker" (combo breaker) or &"".
## react() still plays at most one per ImpactFrameGate.COOLDOWN_TICKS.
static func screen_for(event: Dictionary, combo_hits: int = 0) -> StringName:
	if not ImpactFrameGate.earns(event, combo_hits):
		return &""
	match event.get("type", -1):
		E.KO:
			return &"ko"
		E.GUARD_BREAK:
			return &"lines"
		E.COMBO_BREAKER:
			return &"breaker"
	return &""


## Smear kind for a fighter's attack, or &"" (ranged weapons, unarmed lights, grabs).
static func smear_for(weapon: Weapon.Kind, move_id: StringName) -> StringName:
	var kind: StringName = SMEAR_BY_WEAPON.get(weapon, &"")
	if kind == &"smear_fist":
		var id := String(move_id).get_slice("/", String(move_id).get_slice_count("/") - 1)
		if id.begins_with("light") or id.begins_with("grab") or id.begins_with("push"):
			return &""
	return kind


## Where a hit's spark goes: pushed out from the target's body axis past the contact
## point, so the flare sits beside the torso it hit. Other events keep their position.
static func spark_point(event: Dictionary, fighters: Array[FighterState]) -> Vector3:
	var where: Vector3 = event.get("position", Vector3.ZERO)
	var target: int = event.get("target", -1)
	if not event.get("type", -1) in [E.HIT, E.THROW, E.COUNTER, E.KO, E.ARMOR, E.BLOCK, E.GUARD_BREAK] \
			or target < 0 or target >= fighters.size():
		return where
	var out := where - fighters[target].position
	out.y = 0.0
	var attacker: int = event.get("attacker", -1)
	if out.length_squared() < 0.01 and attacker >= 0 and attacker < fighters.size():
		out = fighters[attacker].position - fighters[target].position
		out.y = 0.0
	if out.length_squared() < 0.0001:
		return where
	return where + out.normalized() * SPARK_STANDOFF


## Dust colour, debris colour and extra effect for landings in a zone.
static func ground_for(zone: StringName) -> Array:
	return ZONE_GROUND.get(zone, ZONE_GROUND[&"skyhold_ruins"])


## Effect scale for the current crowd: smaller when more than two fighters fight.
func crowd_scale() -> float:
	return CROWD_SCALE if sim != null and sim.fighters.size() > 2 else 1.0


func _play_event(event: Dictionary, zone: StringName) -> void:
	var where: Vector3 = event.get("position", Vector3.ZERO)
	var color := color_of(event.get("attacker", -1))
	var size := crowd_scale()
	var spark := spark_point(event, sim.fighters) if sim != null else where
	for kind in effects_for(event, zone):
		match kind:
			&"guard_shatter", &"petals", &"sparkles":
				spawn(kind, spark, Color.TRANSPARENT, size)
			&"breaker_ring":
				spawn(&"breaker_ring", where, color.lerp(Color.WHITE, 0.5), EscapeVfx.BREAKER_RING_SCALE,
					_facing_camera(where))
			&"tech_ghost":
				var teched: int = event.get("fighter", -1)
				if teched < 0 or not pose_ghost(teched, color.lerp(Color.WHITE, 0.5), where):
					spawn(&"afterimage", where, color.lerp(Color.WHITE, 0.5), 1.1)
			&"ko_dome":
				spawn(kind, where, color.lerp(Color.WHITE, 0.5))
			&"ko_burst":
				spawn(kind, spark, color.lerp(Color.WHITE, 0.4), size)
			&"lightning":
				spawn(kind, Vector3(where.x, where.y - FEET, where.z), Color.TRANSPARENT, 1.0, _facing_camera(where))
			_:
				spawn(kind, spark, color, size)
	var combo := _combo_hits(event.get("target", -1))
	var overlay := screen_for(event, combo)
	if overlay == &"" or not impact_gate.try_fire(event, combo):
		return
	var center := _screen_point(where)
	match overlay:
		&"lines":
			_screen.burst_lines(center, Color(1.0, 0.85, 0.85), 0.3)
		&"breaker":
			# One short flash during the breaker's hitstop; the ring is the only shape.
			_screen.flash(2, 0.25)
		&"ko":
			# The one KO beat (#121): a single impact frame centred on the contact, no flash or grade.
			_screen.impact(color, center, KO_IMPACT_FRAMES)


func _combo_hits(target: int) -> int:
	if sim == null or target < 0 or target >= sim.fighters.size():
		return 0
	return sim.fighters[target].combo_hits


func _watch_fighters() -> void:
	var count := sim.fighters.size()
	if _prev_state.size() != count:
		_start_watching(count)
	for i in count:
		var fighter := sim.fighters[i]
		var state := int(fighter.state)
		var was := _prev_state[i]
		var color := color_of(i)
		var speed := fighter.velocity.length()
		# After a KO nothing adds trails or rings, so the loser's body reads.
		var calm := sim.round_over or fighter.is_ko_state()
		# Dash afterimages, stretched along the dash.
		if not calm and state == S.DASHING and fighter.dash_kind != FighterState.DashKind.DODGE \
				and (was != S.DASHING or fighter.state_ticks % GHOST_EVERY == 0):
			if not near_lens(_prev_position[i], NEAR_LENS) and not pose_ghost(i, color):
				spawn(&"afterimage", _prev_position[i], color, 1.0, stretch_along(fighter.velocity, speed))
		elif DodgeTrail.wants_ghost(fighter) and not near_lens(_prev_position[i], NEAR_LENS) \
				and not pose_ghost(i, DodgeTrail.ghost_color(fighter, color)):
			spawn(&"afterimage", _prev_position[i], DodgeTrail.ghost_color(fighter, color), 1.0,
				stretch_along(fighter.velocity, speed))
		# Vanish: a ghost and a burst where they left, a burst where they appear.
		if state == S.VANISHING and was != S.VANISHING:
			if not near_lens(_prev_position[i], NEAR_LENS) and not pose_ghost(i, color.lerp(Color.WHITE, 0.4)):
				spawn(&"afterimage", _prev_position[i], color.lerp(Color.WHITE, 0.4), 1.15)
			spawn(&"vanish_burst", _prev_position[i], Color.TRANSPARENT)
		elif was == S.VANISHING and state != S.VANISHING:
			spawn(&"vanish_burst", fighter.position, color)
		# Power-up flare, the aura while charging, and a flare at each level it climbs.
		if state == S.CHARGING and was != S.CHARGING:
			spawn(&"aura_flare", fighter.position, color)
		var level := 0 if calm else aura_level(fighter)
		if level > _aura_level[i] and _aura_level[i] > 0:
			spawn(&"aura_flare", fighter.position, color, 0.8 + 0.2 * level)
		_aura_level[i] = level
		var aura := _auras[i]
		aura.color = ki_layer.color_of(i)
		aura.power_level = level
		aura.charging = state == S.CHARGING
		_aura_from[i] = _aura_to[i]
		_aura_to[i] = fighter.position
		# Sonic ring the moment they break the speed line.
		var fast := speed >= SONIC_SPEED
		if fast and not calm and _was_fast[i] == 0 and sim.current_tick >= _sonic_ready[i] \
				and not near_lens(fighter.position, NEAR_LENS_RING):
			spawn(&"sonic_ring", fighter.position, color.lerp(Color.WHITE, 0.6), 1.0, facing_along(fighter.velocity))
			_sonic_ready[i] = sim.current_tick + SONIC_COOLDOWN
		_was_fast[i] = 1 if fast else 0
		# Landing dust.
		var grounded := fighter.is_grounded() or fighter.state == S.KNOCKDOWN
		var was_airborne := not (was == S.IDLE or was == S.MOVING or was == S.KNOCKDOWN)
		if grounded and was_airborne and -_prev_velocity[i].y >= LANDING_SPEED:
			_land(fighter.position, -_prev_velocity[i].y, fighter.state == S.KNOCKDOWN)
		# Swing smear on the first active tick.
		var phase := int(fighter.attack_phase())
		if not calm and phase == FighterState.AttackPhase.ACTIVE and _prev_phase[i] != phase:
			_smear(fighter, color)
		_prev_state[i] = state
		_prev_phase[i] = phase
		_prev_position[i] = fighter.position
		_prev_velocity[i] = fighter.velocity


func _start_watching(count: int) -> void:
	_prev_state.resize(count)
	_prev_phase.resize(count)
	_prev_position.resize(count)
	_prev_velocity.resize(count)
	_sonic_ready.resize(count)
	_was_fast.resize(count)
	for i in count:
		var fighter := sim.fighters[i]
		_prev_state[i] = fighter.state
		_prev_phase[i] = fighter.attack_phase()
		_prev_position[i] = fighter.position
		_prev_velocity[i] = fighter.velocity
		_sonic_ready[i] = 0
		_was_fast[i] = 0
	while _trails.size() < count:
		var trail := FlightTrail.new()
		add_child(trail)
		_trails.append(trail)
	_aura_from.resize(count)
	_aura_to.resize(count)
	_aura_level.resize(count)
	while _auras.size() < count:
		var aura := FighterAura.new()
		aura.particle_quality = particle_quality
		add_child(aura)
		_auras.append(aura)
	for i in count:
		_aura_from[i] = sim.fighters[i].position
		_aura_to[i] = sim.fighters[i].position
		_aura_level[i] = 0


func _land(where: Vector3, impact_speed: float, knocked_down: bool) -> void:
	var zone: StringName = sim.zone
	var ground := ground_for(zone)
	var feet := Vector3(where.x, where.y - FEET, where.z)
	var size := clampf(impact_speed / 20.0, 0.7, 1.5) * (1.4 if knocked_down else 1.0)
	var dust := spawn(&"landing_dust", feet, ground[0], size)
	dust.tint_secondary(ground[1])
	var extra: StringName = ground[2]
	if extra == &"petals":
		spawn(&"petals", feet + Vector3.UP * 0.5)
	elif extra == &"sparkles":
		spawn(&"sparkles", feet + Vector3.UP * 0.4, EMBER)


func _smear(fighter: FighterState, color: Color) -> void:
	var kind := smear_for(fighter.held_weapon(), fighter.move_id())
	if kind == &"":
		return
	var reach := 1.6
	var boxes := fighter.active_hitboxes()
	if not boxes.is_empty():
		var tip: Vector3 = boxes[0]["end"]
		var flat := Vector3(tip.x - fighter.position.x, 0.0, tip.z - fighter.position.z)
		reach = clampf(flat.length() + float(boxes[0]["radius"]), 1.0, 3.8)
	var swing := fighter.aim_basis() * swing_tilt(fighter.move_id(), fighter.string_index)
	spawn(kind, fighter.position + Vector3.UP * 0.15, color.lerp(Color.WHITE, 0.35), reach, swing)


## Tilt of the swing plane per move: launchers sweep up, spikes down, lights alternate.
static func swing_tilt(move_id: StringName, string_index: int) -> Basis:
	var id := String(move_id)
	if id.contains("launcher") or id.contains("rising"):
		return Basis(Vector3.FORWARD, PI / 2.0)
	if id.contains("spike"):
		return Basis(Vector3.FORWARD, -PI / 2.0)
	var tilt := Basis(Vector3.FORWARD, deg_to_rad(28.0))
	if string_index % 2 == 1:
		return Basis.from_scale(Vector3(-1, 1, 1)) * tilt
	return tilt


## Basis that stretches a capsule along a motion direction.
static func stretch_along(velocity: Vector3, speed: float) -> Basis:
	if speed < 0.5:
		return Basis.IDENTITY
	var stretch := 1.0 + clampf(speed / 80.0, 0.0, 0.8)
	var along := facing_along(velocity)
	return along * Basis.from_scale(Vector3(1.0, 1.0, stretch)) * along.inverse()


## Basis whose +Z points along a direction (rings and quads face +Z).
static func facing_along(direction: Vector3) -> Basis:
	if direction.length_squared() < 0.0001:
		return Basis.IDENTITY
	var z := direction.normalized()
	var side := Vector3.UP if absf(z.y) < 0.99 else Vector3.RIGHT
	var x := side.cross(z).normalized()
	return Basis(x, z.cross(x), z)


## Leaves a PoseGhost of fighter i's current pose; false (play the capsule) when its view has
## no skinned body to copy, e.g. outside a level.
func pose_ghost(i: int, color: Color, at: Variant = null) -> bool:
	var source := _ghost_source(i)
	if source.is_empty():
		return false
	if _ghosts.size() <= i:
		_ghosts.resize(i + 1)
	if _ghosts[i] == null:
		_ghosts[i] = []
	var list: Array = _ghosts[i]
	var ghost: PoseGhost = null
	for candidate: PoseGhost in list:
		if not candidate.is_playing():
			ghost = candidate
			break
	if ghost == null and list.size() < GHOSTS_PER_FIGHTER:
		ghost = PoseGhost.new()
		add_child(ghost)
		ghost.setup(source.skeleton, source.mesh)
		list.append(ghost)
	if ghost == null:
		ghost = list[0]
		list.push_back(list.pop_front())
	var skeleton: Skeleton3D = source.skeleton
	var poses: Array[Transform3D] = []
	poses.resize(skeleton.get_bone_count())
	for bone in poses.size():
		poses[bone] = skeleton.get_bone_global_pose(bone)
	var space := skeleton.global_transform
	if at is Vector3:
		# Somewhere else than the body (a decoy): the same pose, moved there.
		var body := sim.fighters[i].position if sim != null and i < sim.fighters.size() \
			else (source.view as Node3D).global_position
		space.origin += (at as Vector3) - body
	ghost.play(space, poses, color)
	return true


## {skeleton, mesh} of fighter i's skinned body, or {} without a level's fighter views.
func _ghost_source(i: int) -> Dictionary:
	if not _views_searched:
		_views_searched = true
		var node := get_parent()
		while node != null:
			var views: Variant = node.get(&"fighter_views")
			if views is Array:
				for view: Node in views:
					_ghost_sources.append(_skinned_body(view))
				break
			node = node.get_parent()
	return _ghost_sources[i] if i < _ghost_sources.size() else {}


static func _skinned_body(view: Node) -> Dictionary:
	for node in view.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and mesh.skin != null and mesh.get_node_or_null(mesh.skeleton) is Skeleton3D:
			return {"skeleton": mesh.get_node(mesh.skeleton), "mesh": mesh, "view": view}
	return {}


## True when the scene camera is within reach (m) of where.
func near_lens(where: Vector3, reach: float) -> bool:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	return camera != null and camera.global_position.distance_to(where) < reach


func _facing_camera(where: Vector3) -> Basis:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return Basis.IDENTITY
	var to_camera := camera.global_position - where
	return Basis(Vector3.UP, atan2(to_camera.x, to_camera.z))


func _screen_point(where: Vector3) -> Vector2:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null or camera.is_position_behind(where):
		return Vector2(0.5, 0.5)
	var size := get_viewport().get_visible_rect().size
	var point := camera.unproject_position(where) / size
	return point.clamp(Vector2(0.1, 0.1), Vector2(0.9, 0.9))


## Aura power level for a fighter: 0 unless charging ki, then 1, 2, 3 the longer they charge.
static func aura_level(fighter: FighterState) -> int:
	if fighter.state != S.CHARGING:
		return 0
	var level := 1
	for ticks in AURA_LEVEL_TICKS:
		if fighter.state_ticks >= ticks:
			level += 1
	return level


## The power-up aura of each fighter, for tests and captures.
func auras() -> Array[FighterAura]:
	return _auras


func _find_sim() -> CombatSim:
	var node := get_parent()
	while node != null:
		var found: Variant = node.get(&"sim")
		if found is CombatSim:
			return found
		node = node.get_parent()
	return null
