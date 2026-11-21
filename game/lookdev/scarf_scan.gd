extends SceneTree
## Move-frame check for a cloth chain (Kael's scarf tail): runs the real view
## with the body actually travelling (run circle, take-off, banking flight, a
## flight dash), so ScarfLag swings the chain, and measures every face skinned
## only to the chain bones each frame. A strand or gap shows up as a face whose
## edges grow or shrink against rest. Edge-on joint continuity: wherever two
## rows of the chain meet on its side faces, their shared depth (the overlap the
## edge-on silhouette passes through) must stay at least --min-overlap cells
## under the real bends, or a notch shows. Headless is fine.
##   godot --headless --path . -s res://game/lookdev/scarf_scan.gd -- --scene=<character scene>
##       [--bones=Scarf1,Scarf2,Scarf3,Scarf4,Scarf5] [--limit=1.6]
##       [--moves=res://game/combat/moves/kael/] [--cell=0.011] [--min-overlap=1.0]
## Prints the worst face, the largest bend at each chain joint and the thinnest
## joint overlap per segment; exits 1 if any face edge grows past limit x rest
## or any overlap drops below min-overlap cells.

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
var _moves := ""
var _cell := 0.011
var _min_overlap := 1.0
var _chain_ids := PackedInt32Array()
## Row junctions on the chain's side faces: (surface, vertex at one end of the
## shared depth, vertex at the other end, rest length) per junction.
var _junctions := []
var _thinnest := INF
var _thinnest_label := ""
var _bend_max := PackedFloat32Array()


func _initialize():
	_go.call_deferred()


func _go():
	var args := LookdevArgs.parse()
	var scene := args.need("scene", "scarf_scan.gd -- --scene=<character scene> [--bones=A,B] [--limit=1.6]")
	if scene == "":
		return
	_limit = float(args.get_option("limit", "1.6"))
	_moves = args.get_option("moves", "res://game/combat/moves/kael/")
	_cell = float(args.get_option("cell", "0.011"))
	_min_overlap = float(args.get_option("min-overlap", "1.0"))
	_body = Node3D.new()
	_body.position = Vector3(3.4, 0, 0)  # on the run circle, so nothing teleports
	root.add_child(_body)
	_view = load(scene).instantiate()
	_body.add_child(_view)
	_skeleton = _view.model.get_node("%GeneralSkeleton") as Skeleton3D
	_mesh = _skeleton.find_children("*", "MeshInstance3D", false, false)[0]
	for b in args.get_option("bones", "Scarf1,Scarf2,Scarf3,Scarf4,Scarf5").split(","):
		_chain[_skeleton.find_bone(b)] = true
		_chain_ids.append(_skeleton.find_bone(b))
	_bend_max.resize(_chain_ids.size() - 1)
	_bend_max.fill(0.0)
	_collect_faces()
	_collect_junctions()
	print("chain faces %d, side-face row junctions %d" % [_faces.size() / 2, _junctions.size()])
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
	# The 3-hit combo twice, as the reel plays it (side-on, stepping in).
	_fighter.velocity = Vector3.ZERO
	_fighter.position = Vector3(3.4, 1, 0)
	_fighter.facing_yaw = -PI * 0.5
	_fighter.enter_state(S.IDLE)
	await _steps("combo settle", 30, func(_i): pass)
	var ids := ["light_1", "light_2", "light_3"]
	for loop in 2:
		for k in ids.size():
			var move: MoveData = load(_moves + ids[k] + ".tres")
			if move == null:
				break
			_fighter.begin_move(move)
			var last := move.total_ticks() if k == ids.size() - 1 else move.recovery_start_tick() + 4
			await _steps("combo %s" % ids[k], last - 1, func(_i):
				_fighter.move_tick += 1
				if _fighter.move_tick < move.startup_ticks + move.active_ticks:
					var fwd := Basis(Vector3.UP, _fighter.facing_yaw) * Vector3.FORWARD
					_fighter.position += fwd * move.step_distance / maxf(move.startup_ticks + move.active_ticks, 1))
		_fighter.enter_state(S.IDLE)
		await _steps("combo rest", 24, func(_i): pass)
	var bends := []
	for b in _bend_max:
		bends.append("%.0f" % rad_to_deg(b))
	print("largest bend per chain joint (deg): %s" % ", ".join(bends))
	print("worst chain face edge %.2fx rest (%s), limit %.2fx" % [_worst, _worst_label, _limit])
	print("thinnest edge-on joint overlap %.2f cells (%s), minimum %.2f" % [_thinnest, _thinnest_label, _min_overlap])
	quit(0 if _worst <= _limit and _thinnest >= _min_overlap else 1)


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
	var seg_thin := INF
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
		seg_thin = minf(seg_thin, _overlap(mats))
		if label != "settle":
			_track_bends(mats)
	if label == "settle":
		return  # warm-up: the chain starts from its rest shape
	if seg_worst > _worst:
		_worst = seg_worst
		_worst_label = label
	if seg_thin < _thinnest:
		_thinnest = seg_thin
		_thinnest_label = label
	print("%s: longest chain face edge %.2fx rest, shortest %.2fx, thinnest joint overlap %.2f cells" % [label, seg_worst, seg_low, seg_thin])


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


## Finds where two rows of the chain meet on its side faces (normal +-x): the
## depth both rows share at that height is what the edge-on silhouette passes
## through, so it must not pinch below a cell when the chain bends.
func _collect_junctions() -> void:
	for si in _mesh.mesh.get_surface_count():
		var arr: Array = _mesh.mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		# side -> {"x|y" boundary -> {"above": [[z0, z1]...], "below": [...], "at": {z key: vertex}}}
		var sides := {}
		for n in range(0, _faces.size(), 2):
			if _faces[n] != si:
				continue
			var v0 := _faces[n + 1]
			var lo := verts[v0]
			var hi := verts[v0]
			for k in 4:
				lo = lo.min(verts[v0 + k])
				hi = hi.max(verts[v0 + k])
			if hi.x - lo.x > 0.0001:
				continue  # not a side face
			for edge: Array in [["above", lo.y], ["below", hi.y]]:
				var key := "%d|%d" % [roundi(lo.x / 0.0005), roundi(float(edge[1]) / 0.0005)]
				if not sides.has(key):
					sides[key] = {"above": [], "below": [], "at": {}}
				sides[key][edge[0]].append([lo.z, hi.z])
				for k in 4:
					if absf(verts[v0 + k].y - float(edge[1])) < 0.0001:
						sides[key]["at"][roundi(verts[v0 + k].z / 0.0005)] = v0 + k
		for key: String in sides:
			var j: Dictionary = sides[key]
			if j["above"].is_empty() or j["below"].is_empty():
				continue
			var a := _merged(j["above"])
			var b := _merged(j["below"])
			for ia: Vector2 in a:
				for ib: Vector2 in b:
					var z0 := maxf(ia.x, ib.x)
					var z1 := minf(ia.y, ib.y)
					if z1 - z0 < 0.0001:
						continue
					var e0: int = j["at"].get(roundi(z0 / 0.0005), -1)
					var e1: int = j["at"].get(roundi(z1 / 0.0005), -1)
					if e0 >= 0 and e1 >= 0:
						_junctions.append([si, e0, e1, z1 - z0])


## Sorted z intervals merged where they touch.
static func _merged(list: Array) -> Array:
	list.sort_custom(func(p: Array, q: Array): return p[0] < q[0])
	var out := []
	for iv: Array in list:
		if not out.is_empty() and iv[0] <= (out[-1] as Vector2).y + 0.0001:
			out[-1] = Vector2((out[-1] as Vector2).x, maxf((out[-1] as Vector2).y, iv[1]))
		else:
			out.append(Vector2(iv[0], iv[1]))
	return out


## Thinnest posed joint overlap this frame, in cells.
func _overlap(mats: Array) -> float:
	var thin := INF
	var cache := {}
	for jn: Array in _junctions:
		var si: int = jn[0]
		if not cache.has(si):
			cache[si] = _mesh.mesh.surface_get_arrays(si)
		var arr: Array = cache[si]
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var ends := []
		for v: int in [jn[1], jn[2]]:
			var p := Vector3.ZERO
			for k in 4:
				p += (mats[bones[v * 4 + k]] * verts[v]) * ws[v * 4 + k]
			ends.append(p)
		thin = minf(thin, (ends[0] as Vector3).distance_to(ends[1]) / _cell)
	return thin


## Records the largest bend at each chain joint: the child bone's skin rotation against its parent's.
func _track_bends(mats: Array) -> void:
	for i in _chain_ids.size() - 1:
		var parent: Quaternion = (mats[_chain_ids[i]] as Transform3D).basis.get_rotation_quaternion()
		var child: Quaternion = (mats[_chain_ids[i + 1]] as Transform3D).basis.get_rotation_quaternion()
		_bend_max[i] = maxf(_bend_max[i], parent.angle_to(child))
