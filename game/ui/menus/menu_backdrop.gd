class_name MenuBackdrop
extends Node3D
## The live 3D scene behind the menus: the world flythrough when it exists
## and a window is open, otherwise a stylised sky of floating islands.

const FLYTHROUGH_SCENE := "res://game/world/preview/world_flythrough.tscn"

## &"flythrough" or &"stylised".
var kind: StringName = &""
var flythrough: Node3D
var _camera: Camera3D
var _islands: Node3D
var _time := 0.0


## `prefer_flythrough` false always builds the light stylised scene.
func build(prefer_flythrough := true) -> void:
	if prefer_flythrough and DisplayServer.get_name() != "headless" and ResourceLoader.exists(FLYTHROUGH_SCENE):
		flythrough = (load(FLYTHROUGH_SCENE) as PackedScene).instantiate() as Node3D
		add_child(flythrough)
		var hud := flythrough.get_node_or_null(^"Hud") as CanvasLayer
		if hud != null:
			hud.visible = false
		flythrough.set_process_unhandled_input(false)
		kind = &"flythrough"
		return
	_build_stylised()
	kind = &"stylised"


func _process(delta: float) -> void:
	_time += delta
	if kind == &"stylised":
		_camera.position = Vector3(sin(_time * 0.05) * 60.0, 30.0 + sin(_time * 0.21) * 4.0, cos(_time * 0.05) * 60.0)
		_camera.look_at(Vector3(0, 22, 0))
		for i in _islands.get_child_count():
			var island := _islands.get_child(i) as Node3D
			island.position.y = island.get_meta(&"base_y") + sin(_time * 0.5 + i) * 1.2


func _build_stylised() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.25, 0.62)
	sky_material.sky_horizon_color = Color(1.0, 0.62, 0.48)
	sky_material.ground_horizon_color = Color(0.95, 0.6, 0.55)
	sky_material.ground_bottom_color = Color(0.25, 0.18, 0.4)
	sky_material.sun_angle_max = 20.0
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.95, 0.65, 0.6)
	environment.fog_density = 0.004
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.5, 0.8, 0)
	sun.light_color = Color(1.0, 0.82, 0.65)
	sun.light_energy = 1.2
	add_child(sun)
	_islands = Node3D.new()
	add_child(_islands)
	var rng := RandomNumberGenerator.new()
	rng.seed = 128
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.48, 0.78, 0.42)
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.62, 0.45, 0.5)
	var blossom := StandardMaterial3D.new()
	blossom.albedo_color = Color(1.0, 0.68, 0.8)
	for i in 14:
		var island := Node3D.new()
		var radius := rng.randf_range(4.0, 12.0)
		var top := MeshInstance3D.new()
		var top_mesh := CylinderMesh.new()
		top_mesh.top_radius = radius
		top_mesh.bottom_radius = radius * 0.9
		top_mesh.height = 1.6
		top.mesh = top_mesh
		top.material_override = grass
		island.add_child(top)
		var base := MeshInstance3D.new()
		var base_mesh := CylinderMesh.new()
		base_mesh.top_radius = radius * 0.9
		base_mesh.bottom_radius = 0.4
		base_mesh.height = radius * 1.6
		base.mesh = base_mesh
		base.position.y = -radius * 0.8 - 0.8
		base.material_override = rock
		island.add_child(base)
		if rng.randf() < 0.6:
			var tree := MeshInstance3D.new()
			var crown := SphereMesh.new()
			crown.radius = radius * 0.35
			crown.height = radius * 0.6
			tree.mesh = crown
			tree.position = Vector3(rng.randf_range(-0.4, 0.4) * radius, radius * 0.35, rng.randf_range(-0.4, 0.4) * radius)
			tree.material_override = blossom
			island.add_child(tree)
		var angle := TAU * i / 14.0 + rng.randf_range(-0.2, 0.2)
		var dist := rng.randf_range(25.0, 110.0)
		island.position = Vector3(cos(angle) * dist, rng.randf_range(-5.0, 45.0), sin(angle) * dist)
		island.set_meta(&"base_y", island.position.y)
		_islands.add_child(island)
	_camera = Camera3D.new()
	_camera.fov = 60.0
	_camera.far = 800.0
	add_child(_camera)
	_camera.current = true
	_process(0.0)
