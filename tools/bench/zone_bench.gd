extends SceneTree
## Voxel zone render benchmark: builds each zone at each quality tier, flies
## the zone's fly-through path and prints visible and shadow triangles, draw
## calls and CPU/GPU render ms per tier (avg, p95, max over the path).
##   godot --path . --resolution 1920x1080 --disable-vsync -s res://tools/bench/zone_bench.gd -- \
##       [--zones=all|heartbloom,frozen_peaks,...] [--tiers=high,medium,low,web] [--samples=48]
##       [--frames=3] [--time=dusk] [--fighters=4] [--json=<file>] [--breakdown]
## --breakdown estimates, at the worst sample, which node groups draw (frustum
## and visibility range tested per instance node, surfaces counted as draws).
## Counts don't depend on resolution, so a small window under lavapipe gives
## the real counts; only the owner's GPU gives meaningful ms.
## Exits 1 if any zone misses the medium budget (MEDIUM_TRIS, MEDIUM_DRAWS at p95).

const ZONES := {
	"heartbloom": "res://game/world/voxel_zones/heartbloom/heartbloom_voxel.gd",
	"frozen_peaks": "res://game/world/zones_voxel/frozen_peaks/frozen_peaks_voxel.gd",
	"verdant_falls": "res://game/world/zones_voxel/verdant_falls/verdant_falls_voxel.gd",
	"shattered_mesa": "res://game/world/zones_voxel/shattered_mesa/shattered_mesa_voxel.gd",
	"ember_rift": "res://game/world/zones_voxel/ember_rift/ember_rift_voxel.gd",
	"skyhold_ruins": "res://game/world/zones_voxel/skyhold_ruins/skyhold_ruins_voxel.gd",
	"stormfall_city": "res://game/world/zones_voxel/stormfall_city/stormfall_city_voxel.gd",
}
const TIERS := {
	"low": GraphicsSettings.Quality.LOW,
	"medium": GraphicsSettings.Quality.MEDIUM,
	"high": GraphicsSettings.Quality.HIGH,
	"web": GraphicsSettings.Quality.WEB,
}
const KAEL := "res://game/characters/kael_voxel/kael_voxel.tscn"
## Medium budget per frame (95th percentile over the path).
const MEDIUM_TRIS := 300000
const MEDIUM_DRAWS := 250

var _args := {}
var _results := []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_run.call_deferred()


func _run() -> void:
	var zones: Array = ZONES.keys() if _args.get("zones", "all") == "all" else _args.zones.split(",")
	var tiers: PackedStringArray = _args.get("tiers", "high,medium,low,web").split(",")
	print("Zone benchmark: %s, %s, %dx%d" % [RenderingServer.get_video_adapter_name(),
		RenderingServer.get_current_rendering_driver_name(), root.size.x, root.size.y])
	var pass_all := true
	for zone_name: String in zones:
		for tier_name in tiers:
			var r := await _measure(zone_name, tier_name)
			_results.append(r)
			print("%-15s %-6s tris avg %8d p95 %8d max %8d | draws avg %4d p95 %4d max %4d | shadow tris p95 %8d draws p95 %4d | GPU avg %6.2f p95 %6.2f | CPU avg %6.2f p95 %6.2f ms"
				% [zone_name, tier_name, r.tris.avg, r.tris.p95, r.tris.max, r.draws.avg, r.draws.p95, r.draws.max,
				r.shadow_tris.p95, r.shadow_draws.p95, r.gpu.avg, r.gpu.p95, r.cpu.avg, r.cpu.p95])
			if tier_name == "medium" and (r.tris.p95 > MEDIUM_TRIS or r.draws.p95 > MEDIUM_DRAWS):
				pass_all = false
	if _args.has("json"):
		var f := FileAccess.open(_args.json, FileAccess.WRITE)
		f.store_string(JSON.stringify(_results, "  "))
	if tiers.has("medium"):
		print("Medium budget (p95 <= %d tris, <= %d draws): %s" % [MEDIUM_TRIS, MEDIUM_DRAWS, "PASS" if pass_all else "FAIL"])
	quit(0 if pass_all else 1)


func _measure(zone_name: String, tier_name: String) -> Dictionary:
	var tier: GraphicsSettings.Quality = TIERS[tier_name]
	var settings := GraphicsSettings.new(false)
	settings.quality = tier
	settings.vsync_enabled = false
	settings.fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	settings.apply_to(root)
	var world := Node3D.new()
	root.add_child(world)
	var t0 := Time.get_ticks_msec()
	VoxelQuality.tier = tier
	var zone := (load(ZONES[zone_name]) as GDScript).new() as VoxelZone
	world.add_child(zone)
	zone.build()
	var build_ms := Time.get_ticks_msec() - t0
	var stage := VoxelStage.new()
	world.add_child(stage)
	stage.setup(zone.presets(), zone.cloud_sea())
	stage.lantern_materials = zone.lantern_materials
	stage.apply_quality(tier)
	stage.apply(_args.get("time", "dusk"))
	_add_fighters(world, zone, int(_args.get("fighters", "4")))
	var cam := Camera3D.new()
	cam.near = 0.1
	cam.far = 4000.0
	world.add_child(cam)
	cam.make_current()
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var pts := zone.flight()
	var samples := int(_args.get("samples", "48"))
	var frames := int(_args.get("frames", "3"))
	var series := {"tris": [], "draws": [], "shadow_tris": [], "shadow_draws": [], "gpu": [], "cpu": []}
	for i in 30:
		await process_frame
	for s in samples:
		var u := float(s) / float(samples - 1) * float(pts.size() - 1)
		cam.fov = float(pts[floori(u)].get("fov", 55.0))
		cam.global_position = _spline(pts, "from", u)
		cam.look_at(_spline(pts, "at", u), Vector3.UP)
		zone.animate(u)
		for f in frames:
			await process_frame
		await RenderingServer.frame_post_draw
		var vis := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
		var shd := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW
		var prims := RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME
		var calls := RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
		series.tris.append(RenderingServer.viewport_get_render_info(rid, vis, prims))
		series.draws.append(RenderingServer.viewport_get_render_info(rid, vis, calls))
		series.shadow_tris.append(RenderingServer.viewport_get_render_info(rid, shd, prims))
		series.shadow_draws.append(RenderingServer.viewport_get_render_info(rid, shd, calls))
		series.gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		series.cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid)
			+ RenderingServer.get_frame_setup_time_cpu())
		if _args.has("verbose"):
			print("  %s %s sample %d: %d tris %d draws, shadow %d tris %d draws" % [zone_name, tier_name, s,
				series.tris[-1], series.draws[-1], series.shadow_tris[-1], series.shadow_draws[-1]])
	if _args.has("breakdown"):
		var worst: int = series.tris.find(series.tris.max())
		var u := float(worst) / float(samples - 1) * float(pts.size() - 1)
		cam.global_position = _spline(pts, "from", u)
		cam.look_at(_spline(pts, "at", u), Vector3.UP)
		_breakdown(zone, cam)
	var out := {"zone": zone_name, "tier": tier_name, "build_ms": build_ms}
	for k: String in series:
		out[k] = _summary(series[k])
	world.queue_free()
	await process_frame
	await process_frame
	return out


## Prints the node groups that draw from cam (tile and tier suffixes folded).
func _breakdown(zone: Node, cam: Camera3D) -> void:
	var groups := {}
	var planes := cam.get_frustum()
	var stack: Array[Node] = [zone]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var gi := n as GeometryInstance3D
		if gi == null or not gi.is_visible_in_tree():
			continue
		var aabb := gi.global_transform * gi.get_aabb()
		var d := cam.global_position.distance_to(aabb.get_center())
		if d < gi.visibility_range_begin or (gi.visibility_range_end > 0.0 and d >= gi.visibility_range_end):
			continue
		var inside := true
		for pl in planes:
			var c := aabb.get_center()
			var e := aabb.size * 0.5
			if pl.distance_to(c) > absf(pl.normal.x) * e.x + absf(pl.normal.y) * e.y + absf(pl.normal.z) * e.z:
				inside = false
				break
		if not inside:
			continue
		var mesh: Mesh = null
		var count := 1
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D:
			mesh = (gi as MultiMeshInstance3D).multimesh.mesh
			count = (gi as MultiMeshInstance3D).multimesh.instance_count
		if mesh == null:
			continue
		var tris := 0
		for s in mesh.get_surface_count():
			var il: int = mesh.surface_get_array_index_len(s)
			tris += (il if il > 0 else mesh.surface_get_array_len(s)) / 3
		var own := String(n.name)
		var up := String(n.get_parent().name)
		if own.begins_with("@"):
			own = up
			up = String(n.get_parent().get_parent().name)
		var key := own.get_slice("_", 0) + "/" + up.get_slice("_", 0)
		var shadow := gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var g: Array = groups.get(key, [0, 0, 0, 0])
		groups[key] = [g[0] + mesh.get_surface_count(), g[1] + tris * count, g[2] + (tris * count if shadow else 0), g[3] + 1]
	var keys := groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return groups[a][0] > groups[b][0])
	print("  breakdown at the worst sample (group: draws, tris, shadow-casting tris, nodes):")
	for k: String in keys.slice(0, 25):
		print("    %-40s %4d %9d %9d %4d" % [k, groups[k][0], groups[k][1], groups[k][2], groups[k][3]])


## Stand-ins for the fighters (voxel Kael) round the first shot's subject, so
## the frame carries the 4-character cost.
func _add_fighters(world: Node3D, zone: VoxelZone, count: int) -> void:
	if count <= 0 or not ResourceLoader.exists(KAEL):
		return
	var shots := zone.shots()
	var at := Vector2.ZERO
	for s: Dictionary in shots:
		if s.has("kael"):
			at = s.kael[0]
			break
	for i in count:
		var p := at + Vector2(cos(i * TAU / count), sin(i * TAU / count)) * 3.0
		var view := (load(KAEL) as PackedScene).instantiate() as Node3D
		var body := Node3D.new()
		world.add_child(body)
		body.add_child(view)
		var y := zone.ground_at(p.x, p.y)
		body.position = Vector3(p.x, (y if is_finite(y) else 0.0) + 1.0, p.y)


static func _summary(values: Array) -> Dictionary:
	var v := values.duplicate()
	v.sort()
	var total := 0.0
	for x: float in v:
		total += x
	return {"avg": total / maxf(1.0, v.size()), "p95": v[clampi(int(ceil(v.size() * 0.95)) - 1, 0, v.size() - 1)],
		"max": v[-1]}


static func _spline(pts: Array[Dictionary], key: String, u: float) -> Vector3:
	var i := clampi(floori(u), 0, pts.size() - 2)
	var t := u - i
	var p0: Vector3 = pts[maxi(i - 1, 0)][key]
	var p1: Vector3 = pts[i][key]
	var p2: Vector3 = pts[i + 1][key]
	var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)][key]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
