extends SceneTree
## Writes the legend special kits (kits/*.tres) from the numbers below. The .tres
## files are the data the game loads; rerun after changing a number:
## godot --headless --path . -s res://game/combat/specials/make_special_kits.gd

const OUT := "res://game/combat/specials/kits/"
const _KB := MoveData.KnockbackType
const _FX := SpecialMove.Effect
const _AI := SpecialMove.AiRole
const KAEL_COLOR := Color(1.0, 0.62, 0.22)
const VEXA_COLOR := Color(0.72, 0.38, 1.0)


func _init() -> void:
	_save(_kael(), "kael_special_kit.tres")
	_save(_vexa(), "vexa_special_kit.tres")
	quit()


func _kael() -> SpecialKit:
	var kit := SpecialKit.new()
	kit.legend = &"kael"
	kit.mechanic = SpecialKit.Mechanic.MOMENTUM
	kit.color = KAEL_COLOR
	# 1: Comet Drive. A committed shoulder-first rush; Space/C send it up (launch) or down (spike).
	var comet := SpecialMove.new()
	comet.slot = 1
	comet.display_name = "Comet Drive"
	comet.beats = "Backdashes, whiffed pokes and mid-range ki; ends combos far away"
	comet.effect = _FX.RUSH
	comet.travel_distance = 6.0
	comet.travel_start_tick = 12
	comet.travel_end_tick = 22
	comet.variant_pitch = 0.7
	comet.move = _move("kael_comet_drive", "Comet Drive", 12, 10, 22, Vector3(0, 0.1, -0.9), 0.75,
		900, 34, 14, 9, _KB.BLOWBACK, Vector3(0, 5, -26), 20, 25, 12, 34)
	comet.rise_move = _move("kael_comet_drive_rise", "Comet Drive (rising)", 12, 10, 24,
		Vector3(0, 0.4, -0.9), 0.75, 800, 36, 14, 9, _KB.LAUNCH, Vector3(0, 14, -5), 20, 25, 12, 34)
	comet.dive_move = _move("kael_comet_drive_dive", "Comet Drive (diving)", 12, 10, 24,
		Vector3(0, -0.3, -0.9), 0.75, 850, 30, 14, 9, _KB.SPIKE, Vector3(0, -18, -4), 20, 25, 12, 34)
	comet.tell_cue = &"rush_whoosh"
	comet.color = KAEL_COLOR
	comet.ai_role = _AI.APPROACH
	comet.ai_min_range = 4.5
	comet.ai_max_range = 8.0
	comet.ai_min_level = 2
	# 2: Gale Counter. A guard-stance read: a strike in the window is caught and answered.
	var counter := SpecialMove.new()
	counter.slot = 2
	counter.display_name = "Gale Counter"
	counter.beats = "Strikes, strings and rushes (not grabs or shots)"
	counter.effect = _FX.COUNTER
	counter.move = _move("kael_gale_counter", "Gale Counter", 3, 20, 24, Vector3.ZERO, 0.0,
		0, 0, 0, 0, _KB.NONE, Vector3.ZERO, 0, 25, 0, 0)
	counter.counter_start_tick = 3
	counter.counter_end_tick = 23
	counter.counter_freeze_ticks = 12
	counter.counter_move = _move("kael_gale_riposte", "Gale Riposte", 4, 3, 20, Vector3(0, 0.2, -1.1), 1.0,
		1000, 40, 16, 10, _KB.BLOWBACK, Vector3(0, 6, -28), 24, 0, 4, 24)
	counter.tell_cue = &"perfect_block"
	counter.color = Color(0.85, 0.95, 1.0)
	counter.ai_role = _AI.COUNTER
	counter.ai_min_range = 0.0
	counter.ai_max_range = 3.5
	counter.ai_min_level = 3
	# 3: Skyfall. A telegraphed leap that crashes down on a guard.
	var skyfall := SpecialMove.new()
	skyfall.slot = 3
	skyfall.display_name = "Skyfall"
	skyfall.beats = "Blocking (40 guard, breaks a guard under 40); loses to anti-airs and dodges"
	skyfall.effect = _FX.LEAP
	skyfall.travel_distance = 5.0
	skyfall.travel_start_tick = 2
	skyfall.travel_end_tick = 22
	skyfall.leap_height = 2.2
	skyfall.move = _move("kael_skyfall", "Skyfall", 22, 4, 22, Vector3(0, -0.4, -0.8), 1.1,
		850, 30, 16, 10, _KB.SPIKE, Vector3(0, -14, -4), 40, 35, 22, 36)
	skyfall.move.guard_break_below = 40
	skyfall.tell_cue = &"power_up_burst"
	skyfall.color = KAEL_COLOR
	skyfall.ai_role = _AI.ANTI_GUARD
	skyfall.ai_min_range = 2.0
	skyfall.ai_max_range = 5.5
	skyfall.ai_min_level = 2
	kit.specials = [comet, counter, skyfall]
	return kit


func _vexa() -> SpecialKit:
	var kit := SpecialKit.new()
	kit.legend = &"vexa"
	kit.mechanic = SpecialKit.Mechanic.AFTERIMAGE
	kit.color = VEXA_COLOR
	kit.decoy_ticks = 150
	kit.decoy_blast_radius = 2.4
	kit.decoy_blast = _move("vexa_afterimage_burst", "Afterimage Burst", 1, 1, 1, Vector3.ZERO, 0.0,
		500, 30, 12, 8, _KB.BLOWBACK, Vector3(0, 6, -14), 10, 0, 0, 0)
	# 1: Shade Flicker. Sinks into smoke, reappears behind the target and strikes.
	var flicker := SpecialMove.new()
	flicker.slot = 1
	flicker.display_name = "Shade Flicker"
	flicker.beats = "An unlocked or late-turning guard, and zoning; +6 on hit links a light"
	flicker.effect = _FX.BLINK
	flicker.blink_tick = 10
	flicker.blink_range = 8.0
	flicker.blink_behind = 1.3
	flicker.move = _move("vexa_shade_flicker", "Shade Flicker", 14, 3, 18, Vector3(0, 0.1, -0.9), 0.8,
		600, 26, 12, 7, _KB.NONE, Vector3(0, 0, -3), 10, 30, 14, 30)
	flicker.move.invincible_start_tick = 6
	flicker.move.invincible_end_tick = 13
	flicker.move.ignores_pushbox = true
	flicker.tell_cue = &"vanish_out"
	flicker.color = VEXA_COLOR
	flicker.ai_role = _AI.MIXUP
	flicker.ai_min_range = 2.5
	flicker.ai_max_range = 7.5
	flicker.ai_min_level = 3
	# 2: Mirage Step. Slides away (A/D sideways, W through, else back) and leaves the afterimage.
	var mirage := SpecialMove.new()
	mirage.slot = 2
	mirage.display_name = "Mirage Step"
	mirage.beats = "Committed attacks, rushes and beams aimed at where she stood"
	mirage.effect = _FX.DECOY_STEP
	mirage.travel_distance = 4.5
	mirage.travel_start_tick = 3
	mirage.travel_end_tick = 13
	mirage.stop_on_contact = false
	mirage.move = _move("vexa_mirage_step", "Mirage Step", 3, 10, 12, Vector3.ZERO, 0.0,
		0, 0, 0, 0, _KB.NONE, Vector3.ZERO, 0, 25, 0, 0)
	mirage.tell_cue = &"dodge"
	mirage.color = VEXA_COLOR
	mirage.ai_role = _AI.EVADE
	mirage.ai_min_range = 0.0
	mirage.ai_max_range = 6.0
	mirage.ai_min_level = 2
	# 3: Razor Waltz. A spinning three-cut rush; the confirm ender.
	var waltz := SpecialMove.new()
	waltz.slot = 3
	waltz.display_name = "Razor Waltz"
	waltz.beats = "Ends confirmed strings for damage and carry; -13 when blocked"
	waltz.effect = _FX.RUSH
	waltz.travel_distance = 5.0
	waltz.travel_start_tick = 9
	waltz.travel_end_tick = 27
	waltz.rehit_ticks = PackedInt32Array([15, 21])
	waltz.stop_on_contact = false
	waltz.move = _move("vexa_razor_waltz", "Razor Waltz", 9, 18, 20, Vector3(0, 0.2, -0.9), 0.85,
		260, 30, 12, 5, _KB.NONE, Vector3(0, 1, -4), 8, 35, 9, 32)
	waltz.tell_cue = &"whoosh_heavy"
	waltz.color = VEXA_COLOR
	waltz.ai_role = _AI.ENDER
	waltz.ai_min_range = 0.0
	waltz.ai_max_range = 3.0
	waltz.ai_min_level = 3
	kit.specials = [flicker, mirage, waltz]
	return kit


## A special's MoveData: one hitbox held over every active tick (none when radius is 0).
static func _move(id: StringName, name: String, startup: int, active: int, recovery: int,
		offset: Vector3, radius: float, damage: int, hitstun: int, blockstun: int, hitstop: int,
		knockback_type: MoveData.KnockbackType, knockback: Vector3, guard: int, ki: int,
		cancel_start: int, cancel_end: int) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.display_name = name
	move.startup_ticks = startup
	move.active_ticks = active
	move.recovery_ticks = recovery
	if radius > 0.0:
		move.hitbox_offsets = PackedVector3Array([offset])
		move.hitbox_radii = PackedFloat32Array([radius])
	move.damage = damage
	move.hitstun_ticks = hitstun
	move.blockstun_ticks = blockstun
	move.hitstop_ticks = hitstop
	move.knockback_type = knockback_type
	move.knockback = knockback
	move.guard_damage = guard
	move.ki_cost = ki
	move.cancel_level = MoveData.CancelLevel.SPECIAL
	move.cancel_start_tick = cancel_start
	move.cancel_end_tick = cancel_end
	move.cancel_on_block = false
	return move


func _save(kit: SpecialKit, file: String) -> void:
	var error := ResourceSaver.save(kit, OUT + file)
	print("%s%s: %s" % [OUT, file, error_string(error)])
