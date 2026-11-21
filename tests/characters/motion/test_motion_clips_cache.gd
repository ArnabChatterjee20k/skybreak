extends GutTest
## MotionClips.build caches its derived clips per library and rig, so the legend that loads
## first can't hand its rig-fitted clips to another (it made voxel Brann's fists depend on
## test order).

const KAEL := "res://game/characters/kael_chunky/kael_chunky.tscn"
const BRANN := "res://game/characters/brann_voxel/brann_voxel.tscn"


func _view(path: String) -> CharacterView:
	var view := (load(path) as PackedScene).instantiate() as CharacterView
	add_child_autofree(view)
	return view


func _skeleton(view: CharacterView) -> Skeleton3D:
	return view.model.get_node("%GeneralSkeleton") as Skeleton3D


func test_the_same_rig_gets_the_cached_library_back() -> void:
	var view := _view(BRANN)
	var first := MotionClips.build(view.clips.motion, _skeleton(view))
	assert_same(MotionClips.build(view.clips.motion, _skeleton(view)), first)


func test_a_different_rig_gets_its_own_derived_clips() -> void:
	var kael := _view(KAEL)
	var brann := _view(BRANN)
	assert_ne(MotionClips.rig_signature(_skeleton(kael)), MotionClips.rig_signature(_skeleton(brann)),
		"the two rigs differ")
	var for_kael := MotionClips.build(kael.clips.motion, _skeleton(kael))
	var for_brann := MotionClips.build(kael.clips.motion, _skeleton(brann))
	assert_not_same(for_brann, for_kael, "Brann's rig doesn't reuse Kael's fitted clips")


func test_the_rig_signature_is_stable_for_equal_rigs() -> void:
	var a := _view(BRANN)
	var b := _view(BRANN)
	assert_eq(MotionClips.rig_signature(_skeleton(a)), MotionClips.rig_signature(_skeleton(b)))
