extends SceneTree
## Writes Kael's imported %GeneralSkeleton (rests, parents), his move frame data and the old
## clips' finger poses to JSON for the Python motion pipeline.
##   godot --headless --path . -s res://game/characters/motion/tools/export_rig.gd -- <out.json>

const SCENE := "res://game/characters/kael_chunky/kael_chunky.tscn"
const MOVE_DIR := "res://game/combat/moves/kael/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://kael_rig.json"
	var view := (load(SCENE) as PackedScene).instantiate() as CharacterView
	var skeleton := view.get_node("Model/KaelChunkyBody").get_node("%GeneralSkeleton") as Skeleton3D
	var bones := []
	for i in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(i)
		var q := rest.basis.get_rotation_quaternion()
		bones.append({
			"name": skeleton.get_bone_name(i),
			"parent": skeleton.get_bone_parent(i),
			"position": [rest.origin.x, rest.origin.y, rest.origin.z],
			"rotation": [q.x, q.y, q.z, q.w],
		})
	var moves := {}
	for file in DirAccess.get_files_at(MOVE_DIR):
		var move := load(MOVE_DIR + file) as MoveData
		if move == null:
			continue
		var boxes := []
		for offset in move.hitbox_offsets:
			boxes.append([offset.x, offset.y, offset.z])
		moves[String(move.id)] = {"startup": move.startup_ticks, "active": move.active_ticks,
			"recovery": move.recovery_ticks, "hitbox_offsets": boxes}
	var fingers := {}
	var idle := view.clips.library.get_animation(&"idle")
	for track in idle.get_track_count():
		var bone := String(idle.track_get_path(track)).get_slice(":", 1)
		if idle.track_get_type(track) == Animation.TYPE_ROTATION_3D and ("Proximal" in bone \
				or "Intermediate" in bone or "Distal" in bone or "Metacarpal" in bone):
			var q: Quaternion = idle.track_get_key_value(track, 0)
			fingers[bone] = [q.x, q.y, q.z, q.w]
	var model_to_view := Transform3D(Basis(Vector3.UP, PI), Vector3(0, -1, 0))
	var data := {"bones": bones, "moves": moves, "fingers": fingers,
		"skeleton_to_view": _transform_list(model_to_view * view.get_node("Model/KaelChunkyBody").transform
			* _path_transform(view.get_node("Model/KaelChunkyBody"), skeleton))}
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	print("wrote %d bones, %d moves to %s" % [bones.size(), moves.size(), out_path])
	view.free()
	quit(0)


func _path_transform(from: Node, to: Node3D) -> Transform3D:
	var chain: Array[Node3D] = []
	var node: Node = to
	while node != from:
		chain.push_front(node as Node3D)
		node = node.get_parent()
	var result := Transform3D.IDENTITY
	for item in chain:
		result = result * item.transform
	return result


func _transform_list(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
		t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]
