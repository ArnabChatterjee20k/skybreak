extends SceneTree
## Prints the fight-shape metrics (20 seeded 3600-tick matches, 1v1 and FFA-4).
## Pass "weapon_bot" after -- to measure the combat WeaponBot instead.

func _init() -> void:
	var weapon_bot := OS.get_cmdline_user_args().has("weapon_bot")
	for fighters in [2, 4]:
		var started := Time.get_ticks_msec()
		var metrics := SpacingMetrics.measure(fighters, 20, 3600, weapon_bot)
		print("%s: %s  (%d ms)" % ["1v1" if fighters == 2 else "FFA-4", metrics.summary(),
			Time.get_ticks_msec() - started])
	quit()
