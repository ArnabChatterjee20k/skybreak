extends GutTest
## QA-2: every legend's spike connects out of its air light string (hitstun outlasts spike startup).

const LEGENDS: Array[StringName] = [&"kael", &"vexa", &"lyra", &"brann"]


func test_each_air_string_light_stuns_longer_than_the_spike_takes_to_start() -> void:
	for legend in LEGENDS:
		var kit := EngagementBand.stats_for(legend).move_set
		# The string's ender knocks away, so the route spikes out of the lights before it.
		for number in kit.light_string.size() - 1:
			var light := kit.light_string[number]
			assert_gt(light.hitstun_ticks, kit.spike.startup_ticks,
				"%s light_%d (%d) vs spike startup (%d)" % [legend, number + 1, light.hitstun_ticks, kit.spike.startup_ticks])
