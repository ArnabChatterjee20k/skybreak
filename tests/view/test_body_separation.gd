extends GutTest
## #73: attack clips lunged drawn bodies into their victims (Frozen Peaks: 410 of 1679 close
## frames overlapped, worst 0.76 m). BodySeparation eases the drawn bodies apart.

var _qa: VisualQa


func before_all() -> void:
	_qa = VisualQa.new()
	_qa.zone = &"frozen_peaks"
	_qa.ticks = 1200
	_qa.seed_value = 2
	add_child(_qa)
	await _qa.run()
	gut.p(_qa.summary())


func after_all() -> void:
	_qa.queue_free()


func test_drawn_bodies_rarely_touch_and_never_sink_deep() -> void:
	var samples: int = _qa.samples[&"fighter_vs_fighter"]
	assert_gt(samples, 300, "close frames measured")
	var share := float(_qa.violations[&"fighter_vs_fighter"]) / samples
	assert_lt(share, 0.05, "overlapping share of close frames")
	assert_lt(float(_qa.worst[&"fighter_vs_fighter"]), 0.30, "deepest core overlap (m)")


func test_the_striker_gives_way_to_the_body_it_hits() -> void:
	var striker := FighterState.new()
	striker.state = FighterState.State.ATTACKING
	var victim := FighterState.new()
	victim.state = FighterState.State.HITSTUN
	assert_eq(BodySeparation.striking(victim), false)
	assert_gt(BodySeparation.STRIKER_SHARE, 0.5)


func test_a_grab_pair_and_a_vanish_are_left_alone() -> void:
	var one := FighterState.new()
	var two := FighterState.new()
	assert_false(BodySeparation.pair_exempt(one, two, 0, 1))
	one.state = FighterState.State.VANISHING
	assert_true(BodySeparation.pair_exempt(one, two, 0, 1))
	one.state = FighterState.State.THROWING
	one.grab_partner = 1
	assert_true(BodySeparation.pair_exempt(one, two, 0, 1))


func test_a_flier_over_a_head_is_stacked_and_one_beside_is_not() -> void:
	# Verdant seed 7: Brann hovered 1.39 m above and 0.89 m beside Lyra, inside her silhouette.
	var brann := FighterState.new()
	brann.stats = Roster.character(&"brann").stats
	var lyra := FighterState.new()
	lyra.stats = Roster.character(&"lyra").stats
	assert_gt(BodySeparation.stack_gap(brann, lyra, 0.89, 1.39), 0.4)
	assert_eq(BodySeparation.stack_gap(brann, lyra, 2.0, 1.39), 0.0, "beside")
	assert_eq(BodySeparation.stack_gap(brann, lyra, 0.5, 3.0), 0.0, "well above")
	assert_eq(BodySeparation.stack_gap(brann, lyra, 0.5, 0.2), 0.0, "level: the core check's job")
