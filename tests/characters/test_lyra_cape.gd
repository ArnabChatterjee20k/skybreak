extends GutTest
## Voxel Lyra's cape in a real match (QA-21): her in-game clips through the real
## ZoneMatch with AI on both slots, measured with the QA pop metric. The cape chain
## once flipped ~3 rad in one frame, 155 pops in this match.

const SPEC := "109:stormfall_city:1v1:lyra,kael:43"
const TICKS := 1800
## Share of frames a limb may reach more than the clearance gap through the cape.
const MAX_REACH_SHARE := 0.05

var _run: QaMatchRun
var _slot := -1
var _cape: LyraCapeClearance
var _pops := 0
var _frames := 0
var _clips := {}
var _reaches: Array[float] = []


func before_all() -> void:
	ArtStyle.set_current(ArtStyle.Kind.VOXEL)
	var spec := QaMatchSpec.parse(SPEC)
	_slot = spec.legends.find(&"lyra")
	_run = QaMatchRun.new(spec)
	_run.check_view = false
	_run.build(self)
	await get_tree().process_frame
	_cape = _find_cape()
	var skeleton := _cape.get_skeleton()
	skeleton.skeleton_updated.connect(func() -> void: _reaches.append(_cape.reach_through(skeleton)))
	while _run.tick < TICKS and not _run.is_over():
		if _run.tick > 0:
			_frames += 1
			_clips[_run.view_checks._clip_of(_slot)] = true
			for v in _run.view_checks.check_frame():
				if v.check == "pop" and v.fighter == _slot:
					_pops += 1
		_run.advance()
		await get_tree().process_frame


func after_all() -> void:
	ArtStyle.reset()
	if _run != null and is_instance_valid(_run.level):
		_run.level.free()


func _find_cape() -> LyraCapeClearance:
	for node in _run.level.fighter_views[_slot].find_children("*", "SkeletonModifier3D", true, false):
		if node is LyraCapeClearance:
			return node
	return null


func test_the_match_plays_her_real_clips() -> void:
	assert_eq(_frames, TICKS - 1, "the match ran without ending early")
	assert_gt(_clips.size(), 10, "Lyra played many clips: %s" % [_clips.keys()])


func test_her_cape_stays_within_the_pop_budget() -> void:
	var minutes := _frames / 3600.0
	var per_minute := _pops / minutes
	assert_lte(per_minute, QaViewChecks.POP_BUDGET_PER_MINUTE,
		"%d pops in %.2f fighter-minutes (%.1f/min)" % [_pops, minutes, per_minute])


func test_her_limbs_stay_behind_the_cape() -> void:
	assert_gt(_reaches.size(), 0)
	var over := _reaches.filter(func(r: float) -> bool: return r > _cape.clearance).size()
	var share := float(over) / _reaches.size()
	assert_lt(share, MAX_REACH_SHARE, "limbs reached through the cape in %.1f%% of frames" % (share * 100.0))
