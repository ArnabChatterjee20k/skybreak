class_name TerrainShape
extends RefCounted
## The terrain generator: seeded noise plus hand-placed shaping per zone, blended
## by ZoneLayout weights. Only the bake script calls this; the game reads the baked
## TerrainHeightmap.

const SEED := 7031
## Map half-size (m) covered by the heightmap; the dome wall stands at 1000 m.
const HALF_SIZE := 1024.0

# Hand-placed free-standing mesas: local offset (x, z), radius, height.
const MESAS := [
	[Vector2(-150, -120), 55.0, 88.0], [Vector2(-60, -260), 38.0, 70.0],
	[Vector2(-250, 40), 70.0, 96.0], [Vector2(-110, 90), 30.0, 62.0],
	[Vector2(40, -40), 46.0, 104.0], [Vector2(-230, -230), 42.0, 78.0],
	[Vector2(-20, 170), 36.0, 66.0],
]
# Rock fangs piercing the Skyhold cloud sea: local offset, radius, height.
const SKY_FANGS := [
	[Vector2(-160, -40), 26.0, 120.0], [Vector2(170, 90), 30.0, 135.0],
	[Vector2(20, 230), 22.0, 100.0], [Vector2(-60, -250), 28.0, 125.0],
]

var layout: ZoneLayout
var _low := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _canyon := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _river := FastNoiseLite.new()
var _centres: Dictionary = {}


func _init(zone_layout: ZoneLayout) -> void:
	layout = zone_layout
	for zone in layout.zones:
		_centres[zone.id] = zone.centre
	_low.seed = SEED
	_low.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_low.frequency = 0.0035
	_low.fractal_octaves = 4
	_detail.seed = SEED + 1
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail.frequency = 0.035
	_detail.fractal_octaves = 2
	_canyon.seed = SEED + 2
	_canyon.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_canyon.frequency = 0.0055
	_canyon.fractal_octaves = 2
	_ridge.seed = SEED + 3
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.frequency = 0.0045
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 4
	_river.seed = SEED + 4
	_river.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_river.frequency = 0.006
	_river.fractal_octaves = 2


## Height (m) at world (x, z).
func height_at(x: float, z: float) -> float:
	var w := layout.weights_at(x, z)
	var h := 0.0
	for i in w.size():
		if w[i] <= 0.0:
			continue
		var zone_id: StringName = ZoneLayout.ZONE_IDS[i]
		var c: Vector2 = _centres[zone_id]
		h += w[i] * _zone_height(zone_id, x, z, x - c.x, z - c.y)
	# Ring of mountains under the dome wall frames the horizon.
	var edge := maxf(absf(x), absf(z))
	var ring := 120.0 + 40.0 * _low.get_noise_2d(x * 3.0, z * 3.0)
	h = lerpf(h, maxf(h, ring), _smooth(930.0, 1015.0, edge))
	return h


func _zone_height(zone_id: StringName, x: float, z: float, lx: float, lz: float) -> float:
	match zone_id:
		&"shattered_mesa":
			return _mesa(x, z, lx, lz)
		&"skyhold_ruins":
			return _skyhold(x, z, lx, lz)
		&"stormfall_city":
			return _city(x, z, lx, lz)
		&"frozen_peaks":
			return _peaks(x, z, lx, lz)
		&"verdant_falls":
			return _verdant(x, z, lx, lz)
		&"ember_rift":
			return _ember(x, z, lx, lz)
	return 0.0


# Red desert floor, a terraced plateau cut by canyons on the outer side, free mesas inside.
func _mesa(x: float, z: float, lx: float, lz: float) -> float:
	var floor_h := 16.0 + 5.0 * _low.get_noise_2d(x, z) + 1.2 * _detail.get_noise_2d(x, z)
	var plateau_mask := _smooth(20.0, 90.0, lx + 0.6 * lz - 40.0 + 30.0 * _low.get_noise_2d(z, x))
	var canyon := absf(_canyon.get_noise_2d(x, z))
	var open := _smooth(0.05, 0.13, canyon)
	var plateau := _terrace(floor_h + (78.0 - floor_h) * plateau_mask * open, 13.0)
	var h := maxf(floor_h, plateau)
	for mesa in MESAS:
		var d := Vector2(lx, lz).distance_to(mesa[0])
		var r: float = mesa[1] * (1.0 + 0.12 * _detail.get_noise_2d(x * 0.4, z * 0.4))
		var top: float = mesa[2] + 2.0 * _detail.get_noise_2d(x, z)
		h = maxf(h, _terrace(lerpf(floor_h, top, _smooth(r + 14.0, r - 2.0, d)), 11.0))
	return h


# Deep basin under a cloud sea; a few rock fangs pierce it.
func _skyhold(x: float, z: float, lx: float, lz: float) -> float:
	var h := -18.0 + 9.0 * _low.get_noise_2d(x, z) + 2.0 * _detail.get_noise_2d(x, z)
	for fang in SKY_FANGS:
		var d := Vector2(lx, lz).distance_to(fang[0])
		var r: float = fang[1]
		h = maxf(h, lerpf(h, fang[2], pow(_smooth(r * 2.2, 0.0, d), 1.6)))
	return h


# Flattened city ground with raised districts and a canal.
func _city(x: float, z: float, lx: float, lz: float) -> float:
	var h := 12.0 + 0.6 * _detail.get_noise_2d(x, z)
	h += 16.0 * _box_mask(lx - 170.0, lz + 160.0, 120.0, 90.0, 14.0)
	h += 8.0 * _box_mask(lx + 190.0, lz - 140.0, 100.0, 110.0, 12.0)
	h -= 7.0 * _box_mask(lx, lz - 20.0 - 25.0 * sin(lx * 0.012), 600.0, 13.0, 6.0)
	return h


# Ridged glacier mountains around a winding ice valley.
func _peaks(x: float, z: float, lx: float, lz: float) -> float:
	var ridge := _ridge.get_noise_2d(x, z) * 0.5 + 0.5
	var mountains := 95.0 + 200.0 * pow(ridge, 1.8) + 12.0 * _low.get_noise_2d(x, z)
	mountains = _terrace(mountains, 22.0) * 0.4 + mountains * 0.6
	var valley_line := 70.0 * sin(lx / 140.0) + 30.0
	var valley := _smooth(150.0, 55.0, absf(lz - valley_line))
	var floor_h := 72.0 + 6.0 * _low.get_noise_2d(x, z) + 1.5 * _detail.get_noise_2d(x, z)
	return lerpf(mountains, floor_h, valley)


# Jungle valley: a lake under a tall waterfall cliff on the north side.
func _verdant(x: float, z: float, lx: float, lz: float) -> float:
	var h := 7.0 + 6.0 * _low.get_noise_2d(x, z) + 1.5 * _detail.get_noise_2d(x, z)
	var lake := _smooth(160.0, 110.0, Vector2(lx * 0.85, (lz + 20.0) * 1.15).length())
	h = lerpf(h, -12.0, lake)
	var cliff_edge := -150.0 + 15.0 * _low.get_noise_2d(x * 2.0, 0.0)
	var cliff := _smooth(cliff_edge + 8.0, cliff_edge - 8.0, lz)
	var top := 118.0 + 8.0 * _low.get_noise_2d(x, z)
	# River groove on the plateau feeding the waterfall at local x ~ 0.
	top -= 9.0 * _smooth(22.0, 8.0, absf(lx - 20.0 * sin(lz * 0.01)))
	return lerpf(h, top, cliff)


# Volcanic crater: steep inner wall, a rim with a breach, lava channels on the floor.
func _ember(x: float, z: float, lx: float, lz: float) -> float:
	var r := Vector2(lx, lz).length()
	var angle := atan2(lz, lx)
	var rim_r := 270.0 + 20.0 * sin(angle * 3.0) + 10.0 * _low.get_noise_2d(x, z)
	var rim_h := 150.0 + 25.0 * _low.get_noise_2d(angle * 60.0, 0.0)
	# Breach in the rim towards the south-west, where the lava flows out.
	rim_h -= 90.0 * _smooth(0.6, 0.0, absf(wrapf(angle - 2.3, -PI, PI)))
	var floor_h := 36.0 + 3.0 * _low.get_noise_2d(x, z) + 1.0 * _detail.get_noise_2d(x, z)
	var outer := 34.0 + 6.0 * _low.get_noise_2d(x, z)
	var h: float
	if r < rim_r:
		h = lerpf(floor_h, rim_h, pow(_smooth(rim_r - 90.0, rim_r, r), 1.5))
	else:
		h = lerpf(rim_h, outer, _smooth(rim_r, rim_r + 170.0, r))
	var channel := _smooth(0.07, 0.03, absf(_river.get_noise_2d(x, z)))
	channel = maxf(channel, _smooth(45.0, 25.0, r))
	return h - 10.0 * channel * _smooth(rim_r - 20.0, rim_r - 80.0, r)


static func _smooth(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# Steps with steep risers, so cliffs read as layered rock.
static func _terrace(h: float, step: float) -> float:
	var k := floorf(h / step)
	var f := h / step - k
	return (k + _smooth(0.55, 0.95, f)) * step


# 1 inside a rounded box of half-size (hx, hz), falling to 0 over `soft` metres.
static func _box_mask(px: float, pz: float, hx: float, hz: float, soft: float) -> float:
	var dx := maxf(absf(px) - hx, 0.0)
	var dz := maxf(absf(pz) - hz, 0.0)
	return _smooth(soft, 0.0, sqrt(dx * dx + dz * dz))
