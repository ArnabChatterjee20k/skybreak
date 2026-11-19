extends SceneTree
## Render-cost benchmark: flies both fighters through the test arena on a fixed
## route with the camera locked, and reports GPU and CPU frame times for each
## graphics preset. Measures render cost, not fps, so a throttled or hidden
## window doesn't skew it.
##
## godot --path . --resolution 1920x1080 --disable-vsync -s res://game/debug/render_benchmark.gd
##
## Add `-- --fighters 4` to draw two extra Kaels beside the sim fighters
## (render cost of a 4-character scene; they copy the sim fighters' state).
##
## Exits 1 if the medium preset misses the budget.

const WARMUP_FRAMES := 120
const MEASURED_FRAMES := 600
## Pass budget at medium (ms, 95th percentile), leaving headroom under 16.6 ms.
const GPU_BUDGET_P95 := 12.0
const CPU_BUDGET_P95 := 8.0

const DASH := FighterInput.Action.DASH

var _previous: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
var _fighter_count := 2


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--fighters")
	if at >= 0 and at + 1 < args.size():
		_fighter_count = maxi(2, int(args[at + 1]))
	print("Render benchmark: %s, %s, %dx%d, %d fighters" % [
		RenderingServer.get_video_adapter_name(),
		RenderingServer.get_current_rendering_driver_name(),
		root.size.x, root.size.y, _fighter_count])
	var medium_passed := true
	for quality in GraphicsSettings.Quality.values():
		var result := await _measure(quality)
		var quality_name: String = GraphicsSettings.Quality.keys()[quality]
		print("%-6s GPU avg %5.2f  p95 %5.2f  max %5.2f | CPU avg %5.2f  p95 %5.2f  max %5.2f | setup avg %5.2f ms" % [
			quality_name,
			result.gpu.avg, result.gpu.p95, result.gpu.max,
			result.cpu.avg, result.cpu.p95, result.cpu.max,
			result.setup.avg])
		if quality == GraphicsSettings.Quality.MEDIUM:
			medium_passed = result.gpu.p95 < GPU_BUDGET_P95 and result.cpu.p95 < CPU_BUDGET_P95
	print("Medium budget (GPU p95 < %.0f ms, CPU p95 < %.0f ms): %s" % [
		GPU_BUDGET_P95, CPU_BUDGET_P95, "PASS" if medium_passed else "FAIL"])
	quit(0 if medium_passed else 1)


func _measure(quality: GraphicsSettings.Quality) -> Dictionary:
	var arena: Node = load("res://game/levels/test_arena.tscn").instantiate()
	_previous = [FighterInput.new(), FighterInput.new()]
	arena.input_override = _route_input
	arena.match_flow.enabled = false  # same route as before; the HUD still draws
	root.add_child(arena)
	_add_extra_fighters(arena)
	await process_frame
	if not arena.vfx_prewarm.is_finished:
		await arena.vfx_prewarm.finished
	# The arena's graphics menu applies saved settings on ready; override them.
	var settings := GraphicsSettings.new()
	settings.quality = quality
	settings.vsync_enabled = false
	settings.apply_to(root)
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)

	for _frame in WARMUP_FRAMES:
		await process_frame
	var gpu: Array[float] = []
	var cpu: Array[float] = []
	var setup: Array[float] = []
	for _frame in MEASURED_FRAMES:
		await process_frame
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		setup.append(RenderingServer.get_frame_setup_time_cpu())
	arena.queue_free()
	await process_frame
	return {"gpu": _stats(gpu), "cpu": _stats(cpu), "setup": _stats(setup)}


## Extra fighter views that mirror the sim fighters 3 m to the side.
func _add_extra_fighters(arena: Node) -> void:
	for i in _fighter_count - 2:
		var source: FighterView = arena.get_node("Fighter%d" % (i % 2 + 1))
		var mirror := _Mirror.new()
		mirror.position = Vector3(3.0 * (i + 1), 0, 0)
		mirror.view = FighterView.new()
		mirror.view.character_scene = source.character_scene
		mirror.view.energy_color = source.energy_color
		mirror.view.fighter = source.fighter
		arena.add_child(mirror)
		mirror.add_child(mirror.view)


## Draws a FighterView every frame at the sim's latest state; freed with the arena.
class _Mirror extends Node3D:
	var view: FighterView

	func _process(delta: float) -> void:
		view.remember_previous_tick()
		view.present(1.0, delta)


## Fixed route: both take off, then circle-strafe in opposite directions while
## bobbing up and down, with a dash every two seconds.
func _route_input(index: int, tick: int) -> FighterInput:
	var held := 0
	if tick > 60 and tick % 120 < 6:
		held |= DASH
	var input := FighterInput.from_held(held, _previous[index])
	if tick < 60:
		input.vertical = 1
	else:
		input.move = Vector2(1.0 if index == 0 else -1.0, 0.0)
		input.vertical = 1 if (tick / 90) % 2 == 0 else -1
	_previous[index] = input
	return input


static func _stats(samples: Array[float]) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	return {
		"avg": total / sorted.size(),
		"p95": sorted[int(sorted.size() * 0.95)],
		"max": sorted[-1],
	}
