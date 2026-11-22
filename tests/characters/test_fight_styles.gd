extends GutTest
## Pure Fight animation quality: planted feet don't slide (stance, walk, every move while the
## fighter isn't moving), strikes never pass into the opponent's body, no pose is a T-pose,
## and the IK rig really puts hands and feet on their targets.

const PLANTED := FightStyle.ANKLE + 0.025
## Most a planted foot may drift in one frame (m).
const SLIDE := 0.012
## In moves a foot only counts as planted flat on the floor (a lifting kick foot doesn't).
const PLANTED_FLAT := FightStyle.ANKLE + 0.012


func _planted_drift(a: Dictionary, b: Dictionary, body_dx := 0.0, planted := PLANTED) -> float:
	var worst := 0.0
	for key in ["lf", "rf"]:
		var p: Vector3 = a.get(key, Vector3.ZERO)
		var q: Vector3 = b.get(key, Vector3.ZERO)
		if p.y < planted and q.y < planted:
			var drift := Vector2(q.x - p.x, q.z + body_dx - p.z).length()
			worst = maxf(worst, drift)
	return worst


func test_planted_feet_hold_still_in_every_stance() -> void:
	for legend in PureMoves.LEGENDS:
		var style := FightStyle.for_legend(legend)
		for f in 180:
			var drift := _planted_drift(style.stance(f / 60.0), style.stance((f + 1) / 60.0))
			assert_lt(drift, SLIDE, "%s stance frame %d drifts %.3f" % [legend, f, drift])
			if drift >= SLIDE:
				break


func test_walking_feet_stay_planted_on_the_ground() -> void:
	for legend in PureMoves.LEGENDS:
		var style := FightStyle.for_legend(legend)
		var speed := float(PureMoves.stats(legend).walk_f) * 0.06
		for f in 120:
			var drift := _planted_drift(style.walk(f / 60.0, true, speed), style.walk((f + 1) / 60.0, true, speed),
				speed / 60.0)
			assert_lt(drift, SLIDE * 1.5, "%s walk frame %d drifts %.3f" % [legend, f, drift])
			if drift >= SLIDE * 1.5:
				break


func test_no_move_slides_a_planted_foot_while_the_fighter_stands_still() -> void:
	for legend in PureMoves.LEGENDS:
		var style := FightStyle.for_legend(legend)
		for id in PureMoves.ids(legend):
			var data := PureMoves.get_move(legend, id)
			if data.stance == &"air" or not (data.vel as Array).is_empty():
				continue
			var base := PureFightPoses.base_for(style, data)
			var worst := 0.0
			for f in range(1, PureMoves.total(data)):
				var a := style.move_pose(id, f, data, base)
				var b := style.move_pose(id, f + 1, data, base)
				worst = maxf(worst, _planted_drift(a, b, 0.0, PLANTED_FLAT))
			assert_lt(worst, SLIDE * 2.0, "%s %s planted foot drift %.3f m/frame" % [legend, id, worst])


func test_strikes_stop_at_the_opponents_body() -> void:
	for legend in PureMoves.LEGENDS:
		for id in PureMoves.ids(legend):
			var data := PureMoves.get_move(legend, id)
			if (data.box as Array).is_empty() or data.grab:
				continue
			var sim := PureFightDriver.fighting([legend, &"kael"] as Array[StringName], 0)
			sim.pf[1].x = sim.pf[0].x + sim.body_gap()
			var animator := FightAnimator.new(FightStyle.for_legend(legend))
			sim._start_move(0, id)
			for f in PureMoves.total(data):
				var pose := animator.pose(sim, 0, 0.0, 0.0, 1.0 / 60.0)
				var forward := float(sim.pf[1].x - sim.pf[0].x) * sim.pf[0].facing / 1000.0
				for key in ["lh", "rh", "lf", "rf"]:
					var at: Vector3 = pose[key]
					var height := at.y - float(sim.pf[1].y - sim.pf[0].y) / 1000.0
					if height > 0.0 and height < 1.8 and absf(at.x) < 0.45:
						assert_lte(at.z, forward - FightAnimator.BODY_HALF + 0.03,
							"%s %s frame %d %s inside the opponent" % [legend, id, f, key])
				var inputs: Array[FighterInput] = [FighterInput.new(), FighterInput.new()]
				sim.tick(inputs)
				if sim.pf[0].state != PureFighter.State.ATTACK:
					break


func test_every_pose_has_arms_down_or_working_not_a_t_pose() -> void:
	for legend in PureMoves.LEGENDS:
		var style := FightStyle.for_legend(legend)
		for cell in PureFightPoses.sheet(style, "all"):
			var pose: Dictionary = cell[1]
			for key in ["lh", "rh"]:
				var hand: Vector3 = pose[key]
				var shoulder_out := absf(hand.x) > 0.7 and absf(hand.z) < 0.2 and absf(hand.y - 1.27) < 0.12
				assert_false(shoulder_out, "%s %s: %s straight out to the side" % [legend, cell[0], key])


func test_the_rig_puts_hands_and_feet_on_reachable_targets() -> void:
	var view := (Roster.character(&"kael").voxel_scene as PackedScene).instantiate() as CharacterView
	add_child_autofree(view)
	var rig := FightRig.new()
	rig.setup(view.model.get_node("%GeneralSkeleton"))
	var style := KaelStyle.new()
	for pose: Dictionary in [style.stance(0.0), style.crouch(0.0), style.block(0.0, false, 1.0),
			PureFightPoses.active_pose(style, &"5L")]:
		rig.apply(pose)
		for key in ["l", "r"]:
			var hand: Vector3 = pose[key + "h"]
			var reach := (rig.points[key + "hand"] as Vector3).distance_to(hand)
			assert_lt(reach, 0.25, "%s hand within reach of its target (%.3f)" % [key, reach])
			var foot: Vector3 = pose[key + "f"]
			assert_lt((rig.points[key + "foot"] as Vector3).distance_to(foot), 0.12, "%s foot on its target" % key)
