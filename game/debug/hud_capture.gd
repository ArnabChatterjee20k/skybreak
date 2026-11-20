extends SceneTree
## Renders the menus next to staged match-HUD states for UI review (T-UI1):
## 1v1 plates, FFA-4, round/count/FIGHT!/K.O.! banners, combo, READ! and the
## beam-clash prompt. The sim is frozen after the intro and its meters staged.
## xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##   --rendering-method gl_compatibility --resolution 1920x1080 -s res://game/debug/hud_capture.gd -- <out dir>

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://hud_capture"
	DirAccess.make_dir_recursive_absolute(_out)
	await _menus()
	await _duel()
	await _ffa()
	quit()


func _wait(frames: int) -> void:
	for f in frames:
		await process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join(shot_name + ".png"))
	print("[hud] ", shot_name, " ", image.get_size())


func _menus() -> void:
	var front: Node = load("res://game/ui/menus/front_end.tscn").instantiate()
	front.skip_splash = true
	root.add_child(front)
	await _wait(90)
	await _shot("menu_main")
	front._on_mode_chosen(&"vs_ai")
	front.go(&"character_select")
	await _wait(60)
	await _shot("menu_character_select")
	front.queue_free()
	await _wait(2)


func _start(characters: Array) -> ZoneMatch:
	var fighters := []
	for i in characters.size():
		fighters.append({"character": characters[i], "team": i, "is_ai": i > 0, "ai_level": 1})
	var zone_match: ZoneMatch = load("res://game/levels/zone_match.tscn").instantiate()
	zone_match.configure({"zone": &"heartbloom_gardens", "fighters": fighters})
	zone_match.sim.rng.seed = 7
	root.add_child(zone_match)
	zone_match.control_hints.strip_visible = true
	return zone_match


func _flow_at(zone_match: ZoneMatch, phase: MatchFlow.Phase, ticks: int) -> void:
	zone_match.match_flow.phase = phase
	zone_match.match_flow.phase_ticks = ticks


func _duel() -> void:
	var zone_match := _start([&"lyra", &"vexa"])
	var flow := zone_match.match_flow
	await _wait(8)
	_flow_at(zone_match, MatchFlow.Phase.INTRO, 10)
	zone_match.set_physics_process(false)
	await _wait(6)
	await _shot("banner_round")
	_flow_at(zone_match, MatchFlow.Phase.INTRO, MatchFlow.INTRO_ROUND_TICKS + 2)
	await _wait(6)
	await _shot("banner_count")
	_flow_at(zone_match, MatchFlow.Phase.FIGHT, 4)
	await _wait(6)
	await _shot("banner_fight")
	# Staged mid-round: P1 hurt with grey health and a weapon, P2 low and just hit.
	_flow_at(zone_match, MatchFlow.Phase.FIGHT, 400)
	flow.timer_ticks = 47 * MatchFlow.TICKS_PER_SECOND
	flow.wins = [1, 0]
	var a := zone_match.sim.fighters[0]
	var b := zone_match.sim.fighters[1]
	a.health = int(a.stats.max_health * FighterState.METER_UNIT * 0.62)
	a.grey_health = int(a.stats.max_health * FighterState.METER_UNIT * 0.12)
	a.ki = int(zone_match.sim.meter_tuning.ki_max * FighterState.METER_UNIT * 0.6)
	a.burst = int(zone_match.sim.meter_tuning.burst_stock_size * FighterState.METER_UNIT * 1.2)
	a.weapons[0] = Weapon.Kind.ARC_REVOLVER
	a.active_slot = 0
	a.ammo[0] = 9
	b.ki = int(zone_match.sim.meter_tuning.ki_max * FighterState.METER_UNIT * 0.3)
	await _wait(4)
	b.health = int(b.stats.max_health * FighterState.METER_UNIT * 0.22)
	for hits in range(1, 8):
		a.combo_hits = hits
		await _wait(1)
	await _wait(4)
	await _shot("hud_1v1")
	await _shot_720(zone_match)
	_read_pop(zone_match)
	await _wait(5)
	await _shot("read_pop")
	await _clash(zone_match)
	_flow_at(zone_match, MatchFlow.Phase.KO, 20)
	flow.last_winner = 0
	b.health = 0
	await _wait(8)
	await _shot("banner_ko")
	zone_match.queue_free()
	await _wait(3)


func _shot_720(zone_match: ZoneMatch) -> void:
	var window := root
	window.size = Vector2i(1280, 720)
	window.content_scale_size = Vector2i.ZERO
	await _wait(6)
	await _shot("hud_1v1_720")
	window.size = Vector2i(1920, 1080)
	await _wait(6)


func _read_pop(zone_match: ZoneMatch) -> void:
	var pop: Node3D = preload("res://game/view/shaders/vfx/read_pop.tscn").instantiate()
	zone_match.add_child(pop)
	pop.global_position = zone_match.fighter_views[0].global_position + Vector3(0, 0.6, 0)
	pop.call("play")


func _clash(zone_match: ZoneMatch) -> void:
	var clash := BeamClash.new()
	clash.owners = PackedInt32Array([0, 1])
	clash.push = 34
	var now := zone_match.sim.current_tick
	var buttons := [FighterInput.Action.KI_BLAST, FighterInput.Action.BLOCK,
		FighterInput.Action.GRAB, FighterInput.Action.CHARGE, FighterInput.Action.KI_BLAST]
	for k in buttons.size():
		clash.beat_ticks.append(now + 4 + k * 16)
		clash.beat_buttons.append(buttons[k])
	var layer := CanvasLayer.new()
	layer.layer = 5
	var prompt := BeamClashPrompt.new()
	layer.add_child(prompt)
	zone_match.add_child(layer)
	await _wait(1)
	prompt.show_clash(zone_match.sim, clash)
	await _wait(3)
	await _shot("clash_prompt")
	layer.queue_free()


func _ffa() -> void:
	var zone_match := _start([&"kael", &"vexa", &"lyra", &"brann"])
	await _wait(8)
	_flow_at(zone_match, MatchFlow.Phase.FIGHT, 400)
	zone_match.set_physics_process(false)
	zone_match.match_flow.timer_ticks = 63 * MatchFlow.TICKS_PER_SECOND
	zone_match.match_flow.wins = [0, 1, 0, 0]
	var fractions := [0.8, 0.45, 0.15, 0.0]
	for i in 4:
		var fighter := zone_match.sim.fighters[i]
		fighter.health = int(fighter.stats.max_health * FighterState.METER_UNIT * fractions[i])
		fighter.ki = int(zone_match.sim.meter_tuning.ki_max * FighterState.METER_UNIT * (0.25 * i + 0.1))
	# Past the chip trail, so the bars show the staged health.
	await _wait(90)
	await _shot("hud_ffa4")
	zone_match.queue_free()
	await _wait(3)
