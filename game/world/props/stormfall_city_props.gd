class_name StormfallCityProps
extends RefCounted
## Stormfall City grey-block: ruined blocks on a 48 m street grid, landmark towers,
## water towers, cars and neon strips.

## Matches the street grid painted by the terrain shader.
const BLOCK := 48.0
const STREET := 12.0
## Sign colours: magenta, cyan, gold, violet.
const NEON: Array[Color] = [Color(1.0, 0.18, 0.7), Color(0.15, 0.95, 1.0), Color(1.0, 0.78, 0.25), Color(0.62, 0.35, 1.0)]
## Skyline ring: tall towers along the city's edge hide the neighbouring zones' cliffs (#137).
const SKYLINE_WEIGHTS := Vector2(0.45, 0.8)
const SKYLINE_HEIGHTS := Vector2(70.0, 150.0)
const FACADES: Array[Color] = [Color(1, 1, 1), Color(1.15, 1.0, 0.82), Color(1.2, 0.72, 0.6), Color(0.75, 1.0, 1.0), Color(0.8, 0.8, 0.85)]


static func build(parent: Node3D, kit: PropKit, zone: ZoneData, layout: ZoneLayout) -> void:
	var zi := layout.index_of(zone.id)
	var c := zone.centre
	var concrete := kit.material("city_concrete", Color(0.5, 0.5, 0.55), {"windows": 1.0, "window_color": Color(0.72, 0.58, 0.36), "shadow_tint": Color(0.5, 0.52, 0.62)})
	var tower_mat := kit.material("city_tower", Color(0.5, 0.54, 0.62), {"windows": 1.0, "window_color": Color(0.32, 0.6, 0.75)})
	var metal := kit.material("city_metal", Color(0.45, 0.47, 0.5))
	# Instance colour tints the glow (night_emission > 0), so signs mix magenta, cyan and gold.
	var neon := kit.material("city_neon", Color(0.2, 0.2, 0.25), {"emission_color": Color(1, 1, 1), "emission_strength": 1.6, "night_emission": 0.01})
	# A neon night city whatever the clock: windows and signs always lit (#120).
	for m in [concrete, tower_mat, neon]:
		m.set_shader_parameter("night", 1.0)
		kit.night_materials.erase(m)
	var sign_tint := PackedColorArray()
	var buildings: Array[Transform3D] = []
	var tint := PackedColorArray()
	var rubble: Array[Transform3D] = []
	var tanks: Array[Transform3D] = []
	var signs: Array[Transform3D] = []
	var towers: Array[Vector2] = []
	for i in zone.landmark_names.size():
		if zone.landmark_names[i].contains("Tower"):
			towers.append(Vector2(zone.landmark_positions[i].x, zone.landmark_positions[i].z))
	var block_min := floori((c.x - 340.0) / BLOCK)
	var block_max := ceili((c.x + 340.0) / BLOCK)
	var row_min := floori((c.y - 460.0) / BLOCK)
	var row_max := ceili((c.y + 460.0) / BLOCK)
	for bz in range(row_min, row_max + 1):
		for bx in range(block_min, block_max + 1):
			var cx := bx * BLOCK - 6.0
			var cz := bz * BLOCK - 6.0
			var half := (BLOCK - STREET) * 0.5
			if layout.weights_at(cx, cz)[zi] < 0.8 or kit.roughness(cx, cz, half) > 2.5:
				continue
			if not kit.is_clear(cx, cz, half):
				continue
			var g := kit.ground(cx, cz)
			var is_tower := false
			for t in towers:
				if t.distance_to(Vector2(cx, cz)) < BLOCK * 0.5:
					is_tower = true
			if is_tower:
				buildings.append(PropKit.placed(Vector3(cx, g - 1.0, cz), Vector3(26, kit.rng.randf_range(130.0, 170.0), 26), 0.0))
				tint.append(Color(0.8, 0.85, 0.95))
				signs.append(PropKit.placed(Vector3(cx + 13.2, g + 40.0, cz), Vector3(0.6, 50.0, 3.0), 0.0))
				sign_tint.append(NEON[kit.rng.randi() % NEON.size()])
				continue
			var roll := kit.rng.randf()
			if roll < 0.12:
				# Collapsed block: rubble heaps.
				for k in 5:
					var s := kit.rng.randf_range(4.0, 10.0)
					rubble.append(PropKit.placed(Vector3(cx + kit.rng.randf_range(-14, 14), g - 1.0, cz + kit.rng.randf_range(-14, 14)),
						Vector3(s * 1.5, s * 0.7, s), kit.rng.randf() * TAU, Vector3(kit.rng.randf_range(-0.3, 0.3), 0, kit.rng.randf_range(-0.3, 0.3))))
				continue
			var parts := 1 if roll < 0.45 else 4
			for k in parts:
				var size := Vector2(half * 2.0 - 2.0, half * 2.0 - 2.0) if parts == 1 else Vector2(half - 2.0, half - 2.0)
				var off := Vector2.ZERO if parts == 1 else Vector2((k % 2) * 2 - 1, (k / 2) * 2 - 1) * half * 0.5
				var h := kit.rng.randf_range(14.0, 42.0) if parts == 4 else kit.rng.randf_range(24.0, 64.0)
				# Ruined: some buildings lean.
				var lean := Vector3.ZERO
				if kit.rng.randf() < 0.15:
					lean = Vector3(kit.rng.randf_range(-0.12, 0.12), 0, kit.rng.randf_range(-0.12, 0.12))
				buildings.append(PropKit.placed(Vector3(cx + off.x, g - 1.0, cz + off.y), Vector3(size.x, h, size.y), 0.0, lean))
				tint.append(kit.jitter(FACADES[kit.rng.randi() % FACADES.size()], 0.1))
				if kit.rng.randf() < 0.12:
					tanks.append(PropKit.placed(Vector3(cx + off.x, g - 1.0 + h, cz + off.y), Vector3(7, 9, 7), 0.0))
				if kit.rng.randf() < 0.3:
					signs.append(PropKit.placed(Vector3(cx + off.x + size.x * 0.5 + 0.3, g + h * 0.5, cz + off.y), Vector3(0.6, h * 0.4, 2.0), 0.0))
					sign_tint.append(NEON[kit.rng.randi() % NEON.size()])
				# Shop-front light bands at street level, on two faces.
				if kit.rng.randf() < 0.6 and lean == Vector3.ZERO:
					var band := Vector3(size.x * kit.rng.randf_range(0.5, 0.85), 1.2, 0.5)
					signs.append(PropKit.placed(Vector3(cx + off.x, g + 4.5, cz + off.y + size.y * 0.5 + 0.3), band, 0.0))
					sign_tint.append(NEON[kit.rng.randi() % NEON.size()])
					signs.append(PropKit.placed(Vector3(cx + off.x - size.x * 0.5 - 0.3, g + 4.5, cz + off.y), band, PI * 0.5))
					sign_tint.append(NEON[kit.rng.randi() % NEON.size()])
	_skyline(kit, zone, layout, buildings, tint)
	kit.multimesh(parent, "Buildings", PropKit.box(), concrete, buildings, tint, "building_corner")
	kit.multimesh(parent, "Rubble", PropKit.box(), concrete, rubble, PackedColorArray(), "", false)
	kit.multimesh(parent, "WaterTowers", PropKit.cylinder(0.5, 0.5, 8), metal, tanks, PackedColorArray(), "water_tower")
	kit.multimesh(parent, "NeonSigns", PropKit.box(), neon, signs, sign_tint, "", false)
	# Wrecked cars along the streets.
	var cars: Array[Transform3D] = []
	var car_tint := PackedColorArray()
	var tries := 0
	while cars.size() < 140 and tries < 3000:
		tries += 1
		var along := kit.rng.randf_range(-440.0, 440.0)
		var horizontal := kit.rng.randf() < 0.5
		var across := c.y if horizontal else c.x
		var line := float(roundi(across / BLOCK) + kit.rng.randi_range(-9, 9)) * BLOCK + 18.0
		var x := c.x + along if horizontal else line + kit.rng.randf_range(-3.0, 3.0)
		var z := line + kit.rng.randf_range(-3.0, 3.0) if horizontal else c.y + along
		if layout.weights_at(x, z)[zi] < 0.85 or not kit.is_clear(x, z, 3.0):
			continue
		var yaw := (0.0 if horizontal else PI * 0.5) + kit.rng.randf_range(-0.4, 0.4)
		cars.append(PropKit.placed(Vector3(x, kit.ground(x, z), z), Vector3(4.6, 1.6, 2.0), yaw))
		car_tint.append(Color.from_hsv(kit.rng.randf(), 0.5, 0.8))
	kit.multimesh(parent, "Cars", PropKit.box(), metal, cars, car_tint, "car", false)


# Tall towers on the outer blocks, where the city fades into its neighbours, so the
# horizon is skyline instead of another zone's terrain.
static func _skyline(kit: PropKit, zone: ZoneData, layout: ZoneLayout, buildings: Array[Transform3D], tint: PackedColorArray) -> void:
	var zi := layout.index_of(zone.id)
	var c := zone.centre
	for bz in range(floori((c.y - 560.0) / BLOCK), ceili((c.y + 560.0) / BLOCK) + 1):
		for bx in range(floori((c.x - 440.0) / BLOCK), ceili((c.x + 440.0) / BLOCK) + 1):
			var cx := bx * BLOCK - 6.0
			var cz := bz * BLOCK - 6.0
			var w := layout.weights_at(cx, cz)[zi]
			if w < SKYLINE_WEIGHTS.x or w >= SKYLINE_WEIGHTS.y or not kit.is_clear(cx, cz, 24.0):
				continue
			var low := minf(minf(kit.ground(cx - 12.0, cz - 12.0), kit.ground(cx + 12.0, cz + 12.0)),
				minf(kit.ground(cx + 12.0, cz - 12.0), kit.ground(cx - 12.0, cz + 12.0)))
			var size := Vector2(kit.rng.randf_range(16.0, 30.0), kit.rng.randf_range(16.0, 30.0))
			var h := kit.rng.randf_range(SKYLINE_HEIGHTS.x, SKYLINE_HEIGHTS.y)
			buildings.append(PropKit.placed(Vector3(cx, low - 4.0, cz), Vector3(size.x, h, size.y), 0.0))
			tint.append(kit.jitter(Color(0.62, 0.66, 0.82), 0.1))
