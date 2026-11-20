extends SceneTree
## Rig check over a character's moves: steps every move in a moves folder (plus
## guard, flight, hit, grab and throw) and samples posed frames. Reports faces
## stretched more than 3x from rest, and clipping: vertices that pierce a rigid
## part the design names in clearance_parts() ({bone: sdf in rest space}, or
## {bone: [sdf, probe bone names]} to test only those bones' vertices),
## counting only vertices that were clear of it at rest. Headless is fine.
##   godot --headless --path . -s res://game/lookdev/move_scan.gd -- --scene=<character scene>
##       --moves=res://game/combat/moves/<name>/ [--every=2] [--clip-tolerance=0.015]
## Exits 1 on any stretch or a clip deeper than the tolerance.

const USAGE := "move_scan.gd -- --scene=<character scene> --moves=<moves folder> [--every=2] [--clip-tolerance=0.015]"
const S := FighterState.State

var _view: CharacterView
var _skeleton: Skeleton3D
var _f := FighterState.new()
## Per face corner 0 and 2 (rest), their bones and weights, flattened.
var _rest := PackedVector3Array()
var _bones := PackedInt32Array()
var _weights := PackedFloat32Array()
## Vertices sampled for clipping: rest position, dominant bone, bones and weights.
var _probe_rest := PackedVector3Array()
var _probe_main := PackedInt32Array()
var _probe_bones := PackedInt32Array()
var _probe_weights := PackedFloat32Array()
## Clearance parts: bone index -> sdf, and each probe's rest clearance per part.
var _parts := {}
var _probe_clear := {}
## Clearance part -> the probe bones it tests (absent: all).
var _only := {}
var _tolerance := 0.015
var _worst := {}
var _stretched := 0


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := LookdevArgs.parse()
	var scene := args.need("scene", USAGE)
	var moves_dir := args.need("moves", USAGE)
	if scene == "" or moves_dir == "":
		quit(2)
		return
	var every := int(args.get_option("every", "2"))
	_tolerance = float(args.get_option("clip-tolerance", "0.015"))
	_view = load(scene).instantiate()
	root.add_child(_view)
	_skeleton = _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	_f.enter_state(S.IDLE)
	await _advance(20)
	_collect()
	var states := {"guard": S.BLOCKING, "flight": S.FLYING, "hitstun": S.HITSTUN, "grabbed": S.GRABBED,
		"throwing": S.THROWING, "knockdown": S.KNOCKDOWN, "charging": S.CHARGING}
	for label: String in states:
		_f = FighterState.new()
		_f.enter_state(states[label])
		for t in 40:
			await _advance(1)
			if t % every == 0:
				_scan(label, t)
	var dir := moves_dir if moves_dir.ends_with("/") else moves_dir + "/"
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for file: String in files:
		var move := load(dir + file.trim_suffix(".remap")) as MoveData
		if move == null:
			continue
		_f = FighterState.new()
		_f.enter_state(S.IDLE)
		await _advance(4)
		_f.begin_move(move)
		while _f.move_tick < move.total_ticks():
			_f.state_ticks += 1
			_f.move_tick += 1
			await _advance(0)
			if _f.move_tick % every == 0:
				_scan(String(move.id), _f.move_tick)
	print("--- move scan: %d probes, %d clearance parts" % [_probe_rest.size(), _parts.size()])
	var bad := 0
	var labels := {}
	for key: String in _worst:
		var w: Dictionary = _worst[key]
		var flag := "CLIP" if w.depth > _tolerance else "ok  "
		if w.depth > _tolerance:
			labels[key.get_slice(" / ", 0)] = true
		print("%s %-30s deepest %.3f m at tick %d (%s into %s), %d vertices past tolerance" % [flag, key, w.depth, w.tick,
			w.probe, w.part, w.count])
	bad = labels.size()
	print("stretched faces %d, clipping moves %d" % [_stretched, bad])
	quit(0 if _stretched == 0 and bad == 0 else 1)


func _advance(ticks: int) -> void:
	for t in ticks:
		_f.state_ticks += 1
	_view.apply_state(_f, 1.0 / 60.0)
	await process_frame
	await process_frame


func _collect() -> void:
	var mi: MeshInstance3D = _skeleton.find_children("*", "MeshInstance3D", false, false)[0]
	var design: Object = null
	for child in _view.get_children():
		if child.get(&"design") is Script:
			design = (child.get(&"design") as Script).new(_skeleton)
	if design and design.has_method(&"clearance_parts"):
		var named: Dictionary = design.call(&"clearance_parts")
		for bone: StringName in named:
			var part := _skeleton.find_bone(bone)
			if named[bone] is Array:
				_parts[part] = named[bone][0]
				var only := {}
				for name: StringName in named[bone][1]:
					only[_skeleton.find_bone(name)] = true
				_only[part] = only
			else:
				_parts[part] = named[bone]
	var seen := {}
	for si in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		for fi in verts.size() / 4:
			for k: int in [0, 2]:
				var v := fi * 4 + k
				_rest.append(verts[v])
				_bones.append_array(bones.slice(v * 4, v * 4 + 4))
				_weights.append_array(ws.slice(v * 4, v * 4 + 4))
			# One probe per distinct corner position.
			var v0 := fi * 4
			var key := Vector3i((verts[v0] * 400.0).round())
			if _parts.is_empty() or seen.has(key):
				continue
			seen[key] = true
			var main := bones[v0 * 4]
			var best := ws[v0 * 4]
			for j in 4:
				if ws[v0 * 4 + j] > best:
					best = ws[v0 * 4 + j]
					main = bones[v0 * 4 + j]
			_probe_rest.append(verts[v0])
			_probe_main.append(main)
			_probe_bones.append_array(bones.slice(v0 * 4, v0 * 4 + 4))
			_probe_weights.append_array(ws.slice(v0 * 4, v0 * 4 + 4))
	for part: int in _parts:
		var clear := PackedFloat32Array()
		clear.resize(_probe_rest.size())
		var sdf: Callable = _parts[part]
		for i in _probe_rest.size():
			clear[i] = sdf.call(_probe_rest[i])
		_probe_clear[part] = clear


func _skin(mats: Array[Transform3D], p: Vector3, bones: PackedInt32Array, ws: PackedFloat32Array, at: int) -> Vector3:
	var out := Vector3.ZERO
	for j in 4:
		var w := ws[at + j]
		if w > 0.0:
			out += (mats[bones[at + j]] * p) * w
	return out


func _scan(label: String, tick: int) -> void:
	var mats: Array[Transform3D] = []
	for b in _skeleton.get_bone_count():
		mats.append(_skeleton.get_bone_global_pose(b) * _skeleton.get_bone_global_rest(b).affine_inverse())
	var faces := _rest.size() / 2
	for fi in faces:
		var a := _skin(mats, _rest[fi * 2], _bones, _weights, fi * 8)
		var c := _skin(mats, _rest[fi * 2 + 1], _bones, _weights, fi * 8 + 4)
		var rest_len := _rest[fi * 2].distance_to(_rest[fi * 2 + 1])
		if a.distance_to(c) > rest_len * 3.0 + 0.01:
			_stretched += 1
			if _stretched <= 10:
				print("stretch in %s tick %d at rest %s" % [label, tick, _rest[fi * 2]])
	for part: int in _parts:
		var key := "%s / %s" % [label, _skeleton.get_bone_name(part)]
		var entry: Dictionary = _worst.get(key, {"depth": 0.0, "tick": -1, "probe": "", "part": "", "count": 0})
		var sdf: Callable = _parts[part]
		var clear: PackedFloat32Array = _probe_clear[part]
		var back := mats[part].affine_inverse()
		var only: Dictionary = _only.get(part, {})
		var count := 0
		for i in _probe_rest.size():
			if clear[i] < 0.01 or _probe_main[i] == part or (not only.is_empty() and not only.has(_probe_main[i])):
				continue
			var q := back * _skin(mats, _probe_rest[i], _probe_bones, _probe_weights, i * 4)
			var d: float = sdf.call(q)
			if d < 0.0:
				if -d > _tolerance:
					count += 1
				if -d > entry.depth:
					entry.depth = -d
					entry.tick = tick
					entry.probe = String(_skeleton.get_bone_name(_probe_main[i]))
					entry.part = String(_skeleton.get_bone_name(part))
		entry.count = maxi(entry.count, count)
		_worst[key] = entry
