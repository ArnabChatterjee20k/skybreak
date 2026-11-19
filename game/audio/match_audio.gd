class_name MatchAudio
extends Node
## Thin hook from a match to the AudioDirector: after each sim tick it passes the
## CombatAudioMapper's requests and loops on; each frame it keeps the zone
## ambience on the listener's zone (or default_zone without a world map).

var sim: CombatSim
var mapper := CombatAudioMapper.new()
## The AudioDirector; the autoload unless a test sets another.
var director: Node
## Optional world map; the ambience follows the listener's zone on it.
var world: WorldMap
## Usually the camera; ambience zone is taken at its position.
var listener: Node3D
var default_zone: StringName = &"shattered_mesa"
var zone_tracker := AmbienceZoneTracker.new()


func _ready() -> void:
	if director == null:
		director = get_node_or_null(^"/root/AudioDirector")
	if director and world == null:
		director.set_zone(default_zone)


## Call right after sim.tick().
func after_tick() -> void:
	if director == null or sim == null:
		return
	for request in mapper.observe(sim):
		director.play(request.cue, request.position, request.params)
	for loop in mapper.loops_for(sim):
		if loop.active:
			director.set_loop(loop.key, loop.cue, loop.intensity, loop.position)
		else:
			director.stop_loop(loop.key)


func _process(_delta: float) -> void:
	if director and world and listener and world.layout:
		director.set_zone(zone_tracker.update_at(world, listener.global_position))
