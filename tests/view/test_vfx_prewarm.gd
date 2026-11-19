extends GutTest


func test_headless_prewarm_finishes_without_drawing() -> void:
	var prewarm: VfxPrewarm = add_child_autofree(VfxPrewarm.new())
	watch_signals(prewarm)
	prewarm.start(null)
	await wait_process_frames(2)
	assert_true(prewarm.is_finished)
	assert_signal_emitted(prewarm, "finished")


func test_prewarm_covers_every_world_effect_scene() -> void:
	var dir := DirAccess.open("res://game/view/shaders/vfx")
	var listed := VfxPrewarm.WORLD_EFFECTS.map(func(scene): return scene.resource_path)
	listed.append(VfxPrewarm.AURA.resource_path)
	for file in dir.get_files():
		if file.ends_with(".tscn"):
			assert_has(listed, "res://game/view/shaders/vfx/" + file, "%s is prewarmed" % file)


func test_arena_starts_the_prewarm() -> void:
	var arena: Node = add_child_autofree(load("res://game/levels/test_arena.tscn").instantiate())
	await wait_process_frames(3)
	assert_true(arena.vfx_prewarm.is_finished)
