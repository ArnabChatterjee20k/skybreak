extends SceneTree
## Move-frame check for a cloth chain (Kael's scarf tail): runs the real view
## with the body actually travelling (run circle, take-off, banking flight, a
## flight dash), so ScarfLag swings the chain, and measures every face skinned
## only to the chain bones each frame. A strand or gap shows up as a face whose
## edges grow or shrink against rest. Headless is fine.
##   godot --headless --path . -s res://game/lookdev/scarf_scan.gd -- --scene=<character scene>
##       [--bones=Scarf1,Scarf2,Scarf3,Scarf4,Scarf5] [--limit=1.6]
## Prints the worst face per segment; exits 1 if any face edge grows past limit x rest.

const S := FighterState.State
const DT := 1.0 / 60.0

var _view: CharacterView
var _body: Node3D
var _skeleton: Skeleton3D
var _mesh: MeshInstance3D
var _fighter := FighterState.new()
var _chain := {}
var _faces := PackedInt32Array()  # (surface, first vertex) pairs
var _limit := 1.6
var _worst := 0.0
var _worst_label := ""


func _initialize():
	_go.call_deferred()


func _go():
	var args := LookdevArgs.parse()
	var scene := args.need("scene", "scarf_scan.gd -- --scene=<character scene> [--bones=A,B] [--limit=1.6]")
	if scene == "":
		return
	_limit = float(args.get_option("limit", "1.6"))
	_body = Node3D.new()
	_body.position = Vector3(3.4, 0, 0)  # on the run circle, so nothing teleports
	root.add_child(_body)
	_view = load(scene).instantiate()
	_body.add_child(_view)
	_skeleton = _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	_mesh = _skeleton.find_children("*", "MeshInstance3D", false, false)[0]
	for b in args.get_option("bones", "Scarf1,Scarf2,Scarf3,Scarf4,Scarf5").split(","):
		_chain[_skeleton.find_bone(b)] = true
	_collect_faces()
	print("chain faces ", _faces.size() / 2)
	_fighter.position = Vector3(3.4, 1, 0)
	_fighter.enter_state(S.IDLE)
	await _steps("settle", 40, func(_i): pass)
	# Run a circle at full speed.
	_fighter.enter_state(S.MOVING)
	var angle := 0.0
	await _steps("run", 150, func(i):
		var v := lerpf(3.0, 9.0, minf(i / 30.0, 1.0))
		angle -= v * DT / 3.4
		var next := Vector3(cos(angle) * 3.4, 1.0, sin(angle) * 3.4)
		var tangent := Vector3(sin(angle), 0, -cos(angle))
		_fighter.velocity = (next - _fighter.position) / DT
		_fighter.position = next
		_fighter.facing_yaw = atan2(-tangent.x, -tangent.z))
	# Take off and hover.
	_fighter.enter_state(S.FLYING)
	var base := _fighter.position.y
	await _steps("takeoff", 90, func(i):
		var y := base + 1.4 * (1.0 - pow(1.0 - minf(i * DT / 0.8, 1.0), 3.0))
		_fighter.velocity = Vector3(0, (y - _fighter.position.y) / DT, 0)
		_fighter.position.y = y)
	# Banking flight loop.
	await _steps("flight", 210, func(i):
		var v := lerpf(2.0, 11.0, minf(i / 50.0, 1.0))
		angle -= v * DT / 3.6
		var next := Vector3(cos(angle) * 3.6, base + 1.4 + 0.5 * sin(i * DT * 1.8), sin(angle) * 3.6)
		var tangent := Vector3(sin(angle), 0, -cos(angle))
		_fighter.velocity = (next - _fighter.position) / DT
		_fighter.position = next
		_fighter.facing_yaw = atan2(-tangent.x, -tangent.z))
	# Flight dash: snapped to a start line as the reel does, then 26 m/s.
	_fighter.position = Vector3(-14.0, _fighter.position.y, 2.0)
	_fighter.facing_yaw = -PI * 0.5
	_fighter.enter_state(S.DASHING)
	_fighter.dash_kind = FighterState.DashKind.SUSTAINED
	_fighter.dash_direction = Vector3.RIGHT
	await _steps("dash", 100, func(i):
		var v := lerpf(8.0, 26.0, minf(i / 15.0, 1.0)) if i < 80 else lerpf(26.0, 4.0, (i - 80) / 20.0)
		_fighter.velocity = Vector3(v, 0, 0)
		_fighter.position += _fighter.velocity * DT)
	# A hard reversal mid-flight: the chain whips round.
	_fighter.dash_kind = FighterState.DashKind.NONE
	_fighter.enter_state(S.FLYING)
	await _steps("reverse", 60, func(i):
		_fighter.facing_yaw += PI / 20.0 if i < 20 else 0.0
		_fighter.velocity = Basis(Vector3.UP, _fighter.facing_yaw) * Vector3.FORWARD * 8.0
		_fighter.position += _fighter.velocity * DT)
	print("worst chain face edge %.2fx rest (%s), limit %.2fx" % [_worst, _worst_label, _limit])
	quit(0 if _worst <= _limit else 1)


func _collect_faces() -> void:
	for si in _mesh.mesh.get_surface_count():
		var arr: Array = _mesh.mesh.surface_get_arrays(si)
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for fi in verts.size() / 4:
			var only := true
			for k in 16:
				var v := fi * 16 + k
				if ws[v] > 0.0001 and not _chain.has(bones[v]):
					only = false
					break
			if only:
				_faces.append_array([si, fi * 4])


## Steps ticks frames, calling move(i) before each, and scans every frame.
func _steps(label: String, ticks: int, move: Callable) -> void:
	var seg_worst := 0.0
	var seg_low := INF
	for i in ticks:
		move.call(i)
		_fighter.state_ticks += 1
		_body.position = _fighter.position - Vector3(0, 1, 0)
		_body.rotation.y = _fighter.facing_yaw
		var mats := []
		var grab := func():
			if mats.is_empty():
				for b in _skeleton.get_bone_count():
					mats.append(_skeleton.get_bone_global_pose(b) * _skeleton.get_bone_global_rest(b).affine_inverse())
		_skeleton.skeleton_updated.connect(grab)
		_view.apply_state(_fighter, DT)
		await process_frame
		_skeleton.skeleton_updated.disconnect(grab)
		if mats.is_empty():
			continue
		var r := _measure(mats)
		seg_worst = maxf(seg_worst, r.x)
		seg_low = minf(seg_low, r.y)
	if label == "settle":
		return  # warm-up: the chain starts from its rest shape
	if seg_worst > _worst:
		_worst = seg_worst
		_worst_label = label
	print("%s: longest chain face edge %.2fx rest, shortest %.2fx" % [label, seg_worst, seg_low])


## (longest, shortest) posed/rest edge ratio over the chain's faces.
func _measure(mats: Array) -> Vector2:
	var hi := 0.0
	var lo := INF
	var cache := {}
	for n in range(0, _faces.size(), 2):
		var si := _faces[n]
		if not cache.has(si):
			cache[si] = _mesh.mesh.surface_get_arrays(si)
		var arr: Array = cache[si]
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var v0 := _faces[n + 1]
		var posed := []
		for k in 4:
			var p := Vector3.ZERO
			for j in 4:
				p += (mats[bones[(v0 + k) * 4 + j]] * verts[v0 + k]) * ws[(v0 + k) * 4 + j]
			posed.append(p)
		for k in 4:
			var rest_len := verts[v0 + k].distance_to(verts[v0 + (k + 1) % 4])
			var ratio: float = (posed[k] as Vector3).distance_to(posed[(k + 1) % 4]) / rest_len
			hi = maxf(hi, ratio)
			lo = minf(lo, ratio)
	return Vector2(hi, lo)
