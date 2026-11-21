class_name VoxelZone
extends Node3D
## Base class of a voxel zone's look (the kit's README has the recipe). A zone
## builds its terrain and props under itself in build(), and tells the stage
## and the capture script what it needs: presets, the cloud sea, hero shots,
## the fly-through path and where the visible ground is.

## Cell ladder (the characters' relationship): T0 hand-scale props, T1 the
## walkable lawn and most props, T2 cliffs and cores, T3 far rock and clouds.
const T0 := 0.022
const T1 := 0.088
const T2 := 0.35
const T3 := 1.4

## Numbers for the perf report (quads, instances, build times).
var stats := {}
## Emissive (lantern) materials the stage should drive per preset.
var lantern_materials: Array[ShaderMaterial] = []


## Builds everything. Override.
func build() -> void:
	pass


## Lighting presets by name (VoxelStage.PRESETS keys). Override to tune.
func presets() -> Dictionary:
	return VoxelStage.PRESETS


## The cloud sea: {rect: Rect2 (x, z), height, puffs, seed}, or {} for none.
func cloud_sea() -> Dictionary:
	return {}


## Visible ground height at (x, z) (where feet go), or -INF.
func ground_at(_x: float, _z: float) -> float:
	return -INF


## Hero stills: [{name, from, at, fov, kael: [Vector2 at, float yaw] (optional),
## kael_y: float (optional, overrides the ground), times: ["dusk", ...] (optional)}].
func shots() -> Array[Dictionary]:
	return []


## The fly-through: [{from, at, fov (optional)}] control points, evenly spaced
## in time, and an optional kael: [Vector2, yaw] for a stand-in on the way.
func flight() -> Array[Dictionary]:
	return []


## Where Kael stands during the fly-through: [Vector2 at, float yaw], or [].
func flight_kael() -> Array:
	return []


## A fresh helper object of this script for a loaded bake to fill in
## (VoxelZoneBake.restore). Override for helpers whose constructor takes args.
func make_restored(script: Script) -> Object:
	for m in script.get_script_method_list():
		if m.name == "_init" and (m.args as Array).size() > (m.default_args as Array).size():
			return null
	return script.new()


## Called after a bake was loaded and its state put back, instead of build().
## Override to redo anything build() set up outside the saved nodes and state.
func restored() -> void:
	pass


## Updates moving parts (lantern sway, cloud drift) to time t in seconds.
## Override if the zone animates; the capture calls it every frame.
func animate(_t: float) -> void:
	pass
