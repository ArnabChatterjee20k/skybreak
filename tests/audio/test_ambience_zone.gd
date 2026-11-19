extends GutTest

var _layout: ZoneLayout


func before_all() -> void:
	_layout = ZoneLayout.load_default()


func _zone_at(at: Vector3) -> StringName:
	var tracker := AmbienceZoneTracker.new()
	return tracker.update(_layout.weights_at(at.x, at.z, at.y), ZoneLayout.ZONE_IDS)


func test_each_ground_zone_centre_plays_its_own_ambience() -> void:
	for zone in _layout.ground_zones():
		assert_eq(_zone_at(Vector3(zone.centre.x, 0.0, zone.centre.y)), zone.id)


func test_up_in_heartbloom_the_ground_zone_below_does_not_leak_in() -> void:
	var heartbloom: ZoneData = _layout.zones[_layout.index_of(&"heartbloom_gardens")]
	var centre := heartbloom.centre
	var below := _zone_at(Vector3(centre.x, 0.0, centre.y))
	assert_ne(below, &"heartbloom_gardens", "on the ground it is the ground zone")
	var high := heartbloom.altitude_band.y + 10.0
	assert_eq(_zone_at(Vector3(centre.x, high, centre.y)), &"heartbloom_gardens")


func test_hysteresis_holds_the_zone_across_a_border_wobble() -> void:
	var tracker := AmbienceZoneTracker.new()
	var ids: Array[StringName] = [&"a", &"b"]
	assert_eq(tracker.update(PackedFloat32Array([0.6, 0.4]), ids), &"a")
	assert_eq(tracker.update(PackedFloat32Array([0.48, 0.52]), ids), &"a", "a small lead does not switch")
	assert_eq(tracker.update(PackedFloat32Array([0.3, 0.7]), ids), &"b")


func test_flying_from_stormfall_up_into_heartbloom_switches_the_director_ambience() -> void:
	var director: Node = preload("res://game/audio/audio_director.gd").new()
	director.settings = AudioSettings.new()
	add_child_autofree(director)
	director.set_process(false)
	var tracker := AmbienceZoneTracker.new()
	var heartbloom: ZoneData = _layout.zones[_layout.index_of(&"heartbloom_gardens")]
	var c := heartbloom.centre
	var seen: Array[StringName] = []
	for step in 21:
		var y := lerpf(0.0, heartbloom.altitude_band.y + 20.0, step / 20.0)
		director.set_zone(tracker.update(_layout.weights_at(c.x, c.y, y), ZoneLayout.ZONE_IDS))
		if not seen.has(director.current_zone):
			seen.append(director.current_zone)
	assert_eq(seen.size(), 2, "one switch on the way up: %s" % [seen])
	assert_eq(director.loop_cue(&"ambience"), &"amb_heartbloom_gardens")
