class_name LookdevStage
extends Node3D
## Neutral look-dev stage (docs/lookdev/kael.md, "Lighting stack"): a mid-grey
## cyclorama (floor curving up into a back wall), a soft key with a soft
## contact shadow, a cool fill, a warm bounce from below, a subtle rim from
## behind, SSAO, filmic tone mapping. The subject stands at the origin, facing +Z.

var camera: Camera3D
var key: DirectionalLight3D
## A much bigger cyclorama, for moving shots that travel and look along the
## stage (set before adding the stage to the tree).
var large := false
## The soft ellipse under the feet; a moving subject can carry it along.
var contact_shadow: MeshInstance3D

## Key light softness. PCSS dithers its penumbra per pixel: a wide angular
## size and blur made that dither read as dot grain in close shots and around
## the feet, so the key is a little tighter, and captures add TAA, which
## jitters the dither every frame and accumulates it into a smooth penumbra.
## The soft contact shadow comes from the ellipse under the feet and SSAO.
const KEY_ANGULAR_DISTANCE := 2.2
const KEY_SHADOW_BLUR := 0.8
## Frames a still waits for TAA to converge before it's saved.
const TAA_SETTLE_FRAMES := 12


## Capture viewport settings shared by stills and reels: 4x MSAA on the voxel
## edges plus TAA for the shadow penumbra.
static func configure_viewport(viewport: SubViewport) -> void:
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.use_taa = true
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED


func _ready() -> void:
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	_environment()
	_cyclorama()
	_lights()
	_contact_shadow()
	camera = Camera3D.new()
	camera.fov = 30.0
	camera.near = 0.05
	add_child(camera)
	camera.make_current()


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.43, 0.45)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.35
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.8
	env.ssao_light_affect = 0.15
	env.ssil_enabled = true
	env.ssil_radius = 1.0
	env.ssil_intensity = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_hdr_threshold = 1.4
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.0
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


## Floor + quarter-cylinder bend + back wall, one continuous grey surface.
func _cyclorama() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := 400.0 if large else 14.0
	var back := -3.5
	var radius := 2.5
	var profile := PackedVector2Array()  # (z, y) from the front of the floor to the top of the wall
	profile.append(Vector2(300.0 if large else 8.0, 0.0))
	for k in range(0, 17):
		var a := PI * 0.5 * k / 16.0
		profile.append(Vector2(back + radius - sin(a) * radius, radius - cos(a) * radius))
	profile.append(Vector2(back, 200.0 if large else 9.0))
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		var n := Vector3(0, -(b.x - a.x), b.y - a.y).normalized()  # up on the floor, +Z on the wall
		var v := [Vector3(-width, a.y, a.x), Vector3(width, a.y, a.x), Vector3(width, b.y, b.x), Vector3(-width, b.y, b.x)]
		for idx: int in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.add_vertex(v[idx])
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.505, 0.515)
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cyc := MeshInstance3D.new()
	cyc.mesh = mesh
	cyc.material_override = mat
	add_child(cyc)


func _lights() -> void:
	# Key: warm, high front-left, soft (wide angular size) shadow.
	key = _directional(Vector3(-38, 35, 0), Color(1.0, 0.95, 0.87), 2.1, true)
	key.light_angular_distance = KEY_ANGULAR_DISTANCE
	key.shadow_blur = KEY_SHADOW_BLUR
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 12.0
	key.shadow_bias = 0.02
	key.shadow_normal_bias = 0.6
	# Fill: cool, front-right, lower.
	_directional(Vector3(-12, -50, 0), Color(0.78, 0.85, 1.0), 0.45, false)
	# Bounce: warm grey from below.
	_directional(Vector3(70, 15, 0), Color(0.95, 0.88, 0.8), 0.22, false)
	# Rim: from behind, above; subtle.
	_directional(Vector3(-28, 165, 0), Color(1.0, 0.94, 0.85), 1.1, false)


func _directional(rotation_deg: Vector3, color: Color, energy: float, shadow: bool) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = rotation_deg
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = shadow
	add_child(light)
	return light


## A soft dark ellipse under the feet, on top of the key's shadow and SSAO.
func _contact_shadow() -> void:
	var quad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.1, 0.8)
	quad.mesh = plane
	quad.position = Vector3(0, 0.002, 0.02)
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled;
void fragment() {
	float d = length((UV - 0.5) * vec2(2.0, 2.0));
	float a = (1.0 - smoothstep(0.15, 1.0, d)) * 0.55;
	ALBEDO = vec3(1.0 - a);
}
"""
	mat.shader = shader
	quad.material_override = mat
	add_child(quad)
	contact_shadow = quad


## Frames a vertical span [bottom, top] at the given vertical fill, looking
## horizontally from yaw 0 (front, +Z), with optional pitch-down.
func frame(target: Vector3, height: float, fill := 0.86, pitch_deg := -4.0, yaw_deg := 0.0) -> void:
	var half := height * 0.5 / fill
	var distance := half / tan(deg_to_rad(camera.fov) * 0.5)
	var up := deg_to_rad(-pitch_deg)  # camera elevation: looking down = raised camera
	var yaw := deg_to_rad(yaw_deg)
	var dir := Vector3(sin(yaw) * cos(up), sin(up), cos(yaw) * cos(up))
	camera.global_position = target + dir * distance
	camera.look_at(target, Vector3.UP)
