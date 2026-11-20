extends SceneTree
## Look-direction mockups (T-LOOK): renders one fight moment in one style.
## godot --path . --resolution 1920x1080 --fixed-fps 60 -s res://prototypes/look/look_capture.gd -- <style a|b|c|d> <zone> <moment melee|beam|wide|ffa|strip> <out.png|out dir>
## Uses the real ZoneMatch (sim, fighters, animation, HUD); the style only overrides the view.

const STYLES := {
	"a": "res://prototypes/look/styles/look_style.gd",
	"b": "res://prototypes/look/styles/style_anime.gd",
	"c": "res://prototypes/look/styles/style_painterly.gd",
	"d": "res://prototypes/look/styles/style_side.gd",
}
const E := CombatSim.EventType
const MELEE_HITS := [E.HIT, E.COUNTER, E.KO]

var style_id := "a"
var zone: StringName = &"ember_rift"
var moment := "melee"
var out := ""
var match_node: ZoneMatch
var style: LookStyle
var bot: ShowcaseBot


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	style_id = args[0]
	zone = StringName(args[1])
	moment = args[2]
	out = args[3]
	var seed_value := int(args[4]) if args.size() > 4 else 7
	var skip := int(args[5]) if args.size() > 5 else 0
	var w := int(OS.get_environment("LOOK_W")) if OS.get_environment("LOOK_W") != "" else 1920
	root.size = Vector2i(w, w * 9 / 16)
	var legends: Array = [&"kael", &"vexa"]
	if moment == "ffa":
		legends = [&"kael", &"vexa", &"lyra", &"brann"]
	_build(legends, seed_value)
	match moment:
		"melee":
			await _wait_for_melee(skip)
		"beam":
			await _wait_for_beam()
		"wide":
			await _wait_for_wide()
		"ffa":
			await _wait_for_ffa(skip)
		"strip":
			await _strip(skip)
	quit()


func _build(legends: Array, seed_value: int) -> void:
	var scripted := moment == "beam"
	var fighters := []
	for i in legends.size():
		fighters.append({"character": legends[i], "team": i, "is_ai": not scripted, "ai_level": 4})
	match_node = load("res://game/levels/zone_match.tscn").instantiate()
	match_node.configure({"zone": zone, "fighters": fighters})
	match_node.sim.rng.seed = seed_value
	style = (load(STYLES[style_id]) as GDScript).new()
	style.moment = moment
	root.add_child(match_node)
	if scripted:
		bot = ShowcaseBot.new(match_node.sim, 4)
		match_node.input_override = func(i: int, tick: int) -> FighterInput: return bot.input_for(i, tick)
	# Runs after the match's own present_frame, so it can move the camera and views.
	root.add_child(style)
	style.setup(match_node)


## Steps one rendered frame; returns this tick's sim events (empty when no tick ran).
func _frame() -> Array[Dictionary]:
	var tick := match_node.sim.current_tick
	await process_frame
	if bot and match_node.sim.current_tick != tick:
		bot.observe()
	if match_node.sim.current_tick != tick:
		return match_node.sim.events
	return [] as Array[Dictionary]


func _render(on: bool) -> void:
	RenderingServer.render_loop_enabled = on


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if path.ends_with(".jpg"):
		image.save_jpg(path, 0.88)
	else:
		image.save_png(path)
	print("saved ", path, " tick ", match_node.sim.current_tick)


func _gap() -> float:
	var f := match_node.sim.fighters
	return f[0].position.distance_to(f[1].position)


## Captures the (skip+1)-th close melee hit. With LOOK_TICK set, rendering stays off
## until shortly before that tick (found by a headless scout run, which prints it).
func _wait_for_melee(skip: int) -> void:
	var known := int(OS.get_environment("LOOK_TICK")) if OS.get_environment("LOOK_TICK") != "" else -1
	var scout := DisplayServer.get_name() == "headless"
	_render(false)
	var seen := 0
	var f := 0
	while f < 60 * 90:
		f += 1
		if known > 0 and match_node.sim.current_tick >= known - 10:
			_render(true)
		var events := await _frame()
		for e in events:
			if OS.get_environment("LOOK_DEBUG") != "" and e.type <= E.THROW:
				print("ev ", f, " ", E.find_key(e.type), " gap ", _gap(), " ", e.keys())
			if e.type in MELEE_HITS and e.has("move_id") and int(e.get("hitstop", 0)) >= 6 and _gap() < 4.5 and f > 240:
				seen += 1
				if seen > skip:
					print("LOOK hit tick ", match_node.sim.current_tick)
					if scout:
						return
					if OS.get_environment("LOOK_PRE") != "":
						await _save(out.get_basename() + "_pre.png")
					style.on_hit(e)
					await _frame()
					await _save(out)
					return
	push_error("no melee hit found")


func _wait_for_beam() -> void:
	_render(false)
	var f := 0
	var fired := -1
	while f < 60 * 40:
		f += 1
		var events := await _frame()
		for e in events:
			if e.type == E.BEAM_CLASH and fired < 0:
				fired = f
				_render(true)
		if fired > 0 and f >= fired + int(OS.get_environment("LOOK_BEAM_AT") if OS.get_environment("LOOK_BEAM_AT") != "" else "10"):
			if OS.get_environment("LOOK_DEBUG") != "":
				print("beams ", match_node.sim.beams.size(), " clashes ", match_node.sim.beam_clashes.size(), " fx ", match_node.combat_feedback.vfx.ki_layer.beam_effect_count())
				for b in match_node.sim.beams:
					print(" beam ", b.owner, " ", b.origin if "origin" in b else "")
				if DisplayServer.get_name() == "headless":
					return
			await _save(out)
			return
	push_error("no beam clash")


func _wait_for_wide() -> void:
	style.wide = true
	_render(false)
	for f in 260:
		if f == 250:
			_render(true)
		await _frame()
	await _save(out)


func _wait_for_ffa(skip: int) -> void:
	_render(false)
	var f := 0
	while f < 60 * 60:
		f += 1
		if f == 300 + skip - 10:
			_render(true)
		await _frame()
		if f >= 300 + skip:
			break
	await _save(out)


## Every 4th frame of 7 s, from `skip` frames in. Only those frames are drawn (lavapipe
## is slow); the sim, animation and camera still step every frame.
func _strip(skip: int) -> void:
	_render(false)
	DirAccess.make_dir_recursive_absolute(out)
	var start := 360 + skip
	for f in start + 420:
		_render(f >= start and (f - start) % 4 == 0)
		await _frame()
		if f >= start and (f - start) % 4 == 0:
			await _save(out.path_join("f%03d.jpg" % ((f - start) / 4)))
