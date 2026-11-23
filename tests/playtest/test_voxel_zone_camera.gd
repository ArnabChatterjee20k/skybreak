extends GutTest
## T-135: the fight camera on every voxel zone, from its current HIGH bake, in
## scripted fights (VoxelCameraFight): an all-AI Kael vs Vexa fight that frames
## both locked fighters at near and far range, and the player pinned with their
## back to a tall voxel prop (where a zone has one on level ground). The camera
## never comes within CameraClearance.MIN_CLEARANCE of solid voxel geometry,
## under the ground or inside a prop.

const FIGHT_TICKS := 1200
const FIGHT_SEED := 7
const WALL_TICKS := 420
## Both locked fighters on screen: share of locked fight frames (QA's view soak uses 95%).
const BOTH_ON := 0.95
const NEAR_ON := 0.90
const FAR_ON := 0.95
## Pinned 2 m from the target with the back to a wall, the camera squeezes in front
## of the player; 14 m apart it frames both like the open fight. See TODO T-135-a.
const WALL_NEAR_ON := 0.85
const WALL_FAR_ON := 0.95

var _missing: Array[String] = []
var _walls := 0


func _has_bake(id: StringName) -> bool:
	var why := []
	var zone := VoxelZoneBake.instantiate(id, GraphicsSettings.Quality.HIGH, VoxelZoneView.BUILDERS[id], why)
	if zone == null:
		_missing.append("%s (%s)" % [id, ", ".join(why)])
		return false
	zone.free()
	return true


func _pend_missing() -> void:
	if _missing.is_empty():
		return
	# Bakes are generated locally (VOXEL-BAKES); a live build takes minutes per zone.
	if not QaKnownIssues.bakes_required():
		pending("%s — %d zones without a current HIGH bake (SKYBREAK_REQUIRE_BAKES=1 fails): %s" % [QaKnownIssues.describe(&"VOXEL-BAKES"),
			_missing.size(), _missing[0]])
		return
	assert_eq(_missing, [] as Array[String], "rebake: tools/voxel_zone_bake.gd --tier=high")


func test_every_voxel_zone_fight_frames_both_fighters_near_and_far_without_clipping() -> void:
	var near_seen := 0
	var far_seen := 0
	for id: StringName in VoxelZoneView.BUILDERS:
		if not _has_bake(id):
			continue
		var r := VoxelCameraFight.run(self, id, FIGHT_SEED, FIGHT_TICKS)
		var c := CameraClearance.sweep(r.zone_node, r.points)
		assert_eq((c.samples as Array).size(), 0, "%s: camera clips voxel geometry in %d frames, first %s"
			% [id, (c.samples as Array).size(), c.samples.slice(0, 1)])
		assert_gt(r.locked, FIGHT_TICKS / 2, "%s: the fight ran locked on" % id)
		assert_gte(float(r.both_on) / maxi(r.locked, 1), BOTH_ON, "%s: both on screen %d/%d" % [id, r.both_on, r.locked])
		if r.near >= 60:
			assert_gte(float(r.near_on) / r.near, NEAR_ON, "%s: near (< %.1f m) both on %d/%d"
				% [id, VoxelCameraFight.NEAR, r.near_on, r.near])
		if r.far >= 30:
			assert_gte(float(r.far_on) / r.far, FAR_ON, "%s: far (> %.0f m) both on %d/%d"
				% [id, VoxelCameraFight.FAR, r.far_on, r.far])
		near_seen += r.near
		far_seen += r.far
		(r.match as Node).free()
	if _missing.size() < VoxelZoneView.BUILDERS.size():
		assert_gt(near_seen, 300, "the fights covered near range")
		assert_gt(far_seen, 100, "the fights covered far range")
	_pend_missing()


func test_a_player_backed_against_a_tall_voxel_prop_keeps_the_camera_out_of_it() -> void:
	for id: StringName in VoxelZoneView.BUILDERS:
		if not _has_bake(id):
			continue
		for gap: float in [2.0, 14.0]:
			for side in 5:
				var w := VoxelCameraFight.backed_against(self, id, gap, WALL_TICKS, side)
				if (w.wall as AABB).has_volume():
					_walls += 1
					var c := CameraClearance.sweep(w.zone_node, w.points)
					assert_eq((c.samples as Array).size(), 0, "%s gap %.0f side %d: clips in %d frames, first %s"
						% [id, gap, side, (c.samples as Array).size(), c.samples.slice(0, 1)])
					var share := float(w.both_on) / maxi(w.locked, 1)
					assert_gte(share, WALL_NEAR_ON if gap < 5.0 else WALL_FAR_ON, "%s gap %.0f side %d: both on %d/%d"
						% [id, gap, side, w.both_on, w.locked])
				(w.match as Node).free()
	if _missing.size() < VoxelZoneView.BUILDERS.size():
		assert_gt(_walls, 10, "some zones have a tall prop on level ground to stand against")
	_pend_missing()
