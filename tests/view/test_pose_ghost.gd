extends GutTest
## #127: a dash afterimage is the fighter's own silhouette (PoseGhost), not a capsule shell.

const SCENE := preload("res://game/levels/zone_match.tscn")


func _match() -> ZoneMatch:
	var zone_match: ZoneMatch = SCENE.instantiate()
	zone_match.configure({"voxel_zone": false, "fighters": [
		{"character": &"kael", "team": 0, "is_ai": true}, {"character": &"vexa", "team": 1, "is_ai": true}]})
	add_child_autofree(zone_match)
	zone_match.set_physics_process(false)
	zone_match.set_process(false)
	return zone_match


func test_a_dash_leaves_a_pose_ghost_instead_of_a_capsule() -> void:
	var zone_match := _match()
	await get_tree().process_frame
	var vfx := zone_match.combat_feedback.vfx
	var fighter := zone_match.sim.fighters[0]
	fighter.state = FighterState.State.DASHING
	fighter.velocity = Vector3(0, 0, -30)
	var none: Array[Dictionary] = []
	vfx.react(none)
	var ghosts := vfx.find_children("*", "PoseGhost", true, false)
	assert_eq(ghosts.size(), 1, "one silhouette ghost")
	assert_true((ghosts[0] as PoseGhost).is_playing())
	assert_eq(vfx.pool(&"afterimage").playing_count(), 0, "no capsule shell")
	var ghost := ghosts[0] as PoseGhost
	ghost.advance(PoseGhost.LIFETIME)
	assert_false(ghost.is_playing(), "gone within its lifetime")
	assert_false(ghost.visible)


func test_a_ghost_freezes_the_pose_it_was_given() -> void:
	var source := Skeleton3D.new()
	add_child_autofree(source)
	source.add_bone(&"Hips")
	source.add_bone(&"Head")
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.skin = Skin.new()
	source.add_child(mesh)
	var ghost := PoseGhost.new()
	add_child_autofree(ghost)
	ghost.setup(source, mesh)
	var poses: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))]
	ghost.play(Transform3D(Basis.IDENTITY, Vector3(5, 0, 0)), poses, Color.ORANGE)
	var skeleton := ghost.get_child(0) as Skeleton3D
	assert_eq(skeleton.get_bone_count(), 2)
	assert_eq(skeleton.get_bone_pose(1).origin, Vector3(0, 1.6, 0))
	assert_eq(ghost.global_position, Vector3(5, 0, 0))
	assert_lte(PoseGhost.START_ALPHA, 0.45, "mostly see-through")


func test_a_ghost_left_elsewhere_keeps_the_pose_and_moves_there() -> void:
	# Vexa's afterimage decoy and the special trails also drew capsules (#127).
	var zone_match := _match()
	await get_tree().process_frame
	var vfx := zone_match.combat_feedback.vfx
	var fighter := zone_match.sim.fighters[1]
	var decoy := fighter.position + Vector3(3, 0, 0)
	var none: Array[Dictionary] = []
	vfx.react(none)
	assert_true(vfx.pose_ghost(1, Color.VIOLET, decoy))
	var ghost := vfx.find_children("*", "PoseGhost", true, false)[0] as PoseGhost
	var skeleton := BodySeparation._skeleton_of(zone_match.fighter_views[1])
	assert_almost_eq(ghost.global_position.distance_to(skeleton.global_position + Vector3(3, 0, 0)), 0.0, 0.001)
