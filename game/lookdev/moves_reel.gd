extends SceneTree
## Moves reel of a character on the look-dev stage, against a grey target
## dummy so the hits read (.claude/skills/voxel-character-lookdev/SKILL.md).
##   godot --path . --disable-vsync -s res://game/lookdev/moves_reel.gd -- <out dir> [full|poses|combat]
##       --scene=<character scene> --moves=res://game/combat/moves/<name>/
##       [--dummy=<scene>] [--stats=<FighterStats .tres>] [--energy=#ff9e40]
## Writes numbered JPG frames (f_00000.jpg...) for ffmpeg at 60 fps; "poses"
## writes one still per procedural pose, "combat" only the melee segments.
## Needs a GPU. --stats sets the pushbox spacing (default FighterStats').
##
## Everything here is look-dev only: the sim is faked (positions, states and
## move ticks are scripted per segment and fed to CharacterView.apply_state,
## one sim tick per frame), and the poses the game has no clip for yet (combat
## hover, crossed guard, ki shot, kick, jump crouch, a big flinch) are layered
## over the clips by LookdevPoseOverride. Neither the sim nor the clips change.

const USAGE := "moves_reel.gd -- <out dir> [full|poses|combat] --scene=<character scene> --moves=<move dir/> [--dummy=<scene>] [--stats=<.tres>] [--energy=#rrggbb] [--hide-stowed]"
## Any humanoid CharacterView on the shared skeleton; it's rendered flat grey.
const DEFAULT_DUMMY := "res://game/characters/kael_chunky/kael_chunky.tscn"
const DT := 1.0 / 60.0
## Camera target follow rate per frame.
const CAM_FOLLOW := 0.12
const STAND := 1.0  # FighterState.stand_height: the body's height when standing
const GRAVITY := 22.0
const S := FighterState.State
## Body capsule (hips to head) the strikes stop at, from the measured voxel
## silhouette (waist radius ~0.2-0.3 m); plus the striking fist or boot's own radius.
const BODY_RADIUS := 0.24
const STRIKER_RADIUS := 0.07

# ---------------------------------------------------------------- poses
# Skeleton space: +Z his front, +X his left, +Y up. See LookdevPoseOverride.

const HOVER_AIMS := {
	&"LeftUpperLeg": Vector3(0.1, -0.72, 0.68), &"LeftLowerLeg": Vector3(0.04, -0.82, -0.56),
	&"RightUpperLeg": Vector3(-0.08, -0.95, 0.22), &"RightLowerLeg": Vector3(-0.03, -0.78, -0.62),
	&"LeftUpperArm": Vector3(0.45, -0.72, 0.5), &"LeftLowerArm": Vector3(-0.18, 0.55, 0.82),
	&"RightUpperArm": Vector3(-0.45, -0.72, 0.5), &"RightLowerArm": Vector3(0.18, 0.55, 0.82),
}
const HOVER_TURNS := {&"Spine": Vector3(8, 0, 0), &"Head": Vector3(-6, 0, 0)}

const GUARD_AIMS := {
	&"LeftUpperArm": Vector3(0.32, -0.3, 0.9), &"LeftLowerArm": Vector3(-0.72, 0.64, 0.27),
	&"LeftHand": Vector3(-0.6, 0.75, 0.3),
	&"RightUpperArm": Vector3(-0.3, -0.26, 0.92), &"RightLowerArm": Vector3(0.7, 0.68, 0.22),
	&"RightHand": Vector3(0.6, 0.76, 0.28),
}
const GUARD_TURNS := {&"Spine": Vector3(10, 0, 0), &"Head": Vector3(12, 0, 0)}

## Right arm thrust straight out, palm-heel forward; left fist held at the chest.
const SHOT_AIMS := {
	&"RightUpperArm": Vector3(-0.06, 0.06, 1.0), &"RightLowerArm": Vector3(-0.02, 0.06, 1.0),
	&"RightHand": Vector3(0.0, 0.45, 0.9),
	&"LeftUpperArm": Vector3(0.38, -0.62, 0.45), &"LeftLowerArm": Vector3(-0.42, 0.48, 0.76),
}
const SHOT_TURNS := {&"Spine": Vector3(4, 12, 0), &"UpperChest": Vector3(0, 14, 0)}
## The same arm a moment after firing: elbow kicked back and up by the recoil.
const RECOIL_AIMS := {
	&"RightUpperArm": Vector3(-0.25, 0.0, 0.97), &"RightLowerArm": Vector3(-0.1, 0.55, 0.83),
	&"RightHand": Vector3(0.0, 0.8, 0.6),
	&"LeftUpperArm": Vector3(0.38, -0.62, 0.45), &"LeftLowerArm": Vector3(-0.42, 0.48, 0.76),
}

## Both palms driven forward together for the beam.
const BEAM_AIMS := {
	&"RightUpperArm": Vector3(0.12, 0.0, 1.0), &"RightLowerArm": Vector3(0.1, 0.02, 1.0),
	&"RightHand": Vector3(0.0, 0.5, 0.86),
	&"LeftUpperArm": Vector3(-0.12, 0.0, 1.0), &"LeftLowerArm": Vector3(-0.1, 0.02, 1.0),
	&"LeftHand": Vector3(0.0, 0.5, 0.86),
	&"LeftUpperLeg": Vector3(0.18, -0.85, 0.5), &"LeftLowerLeg": Vector3(0.05, -0.95, -0.3),
	&"RightUpperLeg": Vector3(-0.2, -0.95, -0.2), &"RightLowerLeg": Vector3(-0.05, -0.98, -0.2),
}
const BEAM_TURNS := {&"Spine": Vector3(6, 0, 0)}

## Kick, right leg: chamber (knee up, shin hanging) then snap out, leaning back.
const KICK_CHAMBER := {
	&"RightUpperLeg": Vector3(-0.12, 0.2, 1.0), &"RightLowerLeg": Vector3(-0.05, -0.95, 0.15),
	&"RightFoot": Vector3(0.0, -0.5, 0.86),
	&"LeftUpperArm": Vector3(0.38, -0.55, 0.55), &"LeftLowerArm": Vector3(-0.35, 0.55, 0.75),
	&"RightUpperArm": Vector3(-0.5, -0.6, 0.2), &"RightLowerArm": Vector3(0.2, 0.6, 0.75),
}
const KICK_EXTEND := {
	&"RightUpperLeg": Vector3(-0.22, 0.42, 0.88), &"RightLowerLeg": Vector3(-0.2, 0.45, 0.87),
	&"RightFoot": Vector3(-0.1, 0.25, 0.96),
	&"LeftUpperArm": Vector3(0.38, -0.55, 0.55), &"LeftLowerArm": Vector3(-0.35, 0.55, 0.75),
	&"RightUpperArm": Vector3(-0.55, -0.75, -0.3), &"RightLowerArm": Vector3(-0.2, -0.6, 0.75),
}
const KICK_TURNS := {&"Spine": Vector3(-16, 18, 0), &"Hips": Vector3(0, 12, 0)}

## Crouch: anticipation before the jump, and the landing squash.
const CROUCH_AIMS := {
	&"LeftUpperLeg": Vector3(0.14, -0.55, 0.82), &"LeftLowerLeg": Vector3(0.05, -0.85, -0.52),
	&"RightUpperLeg": Vector3(-0.14, -0.55, 0.82), &"RightLowerLeg": Vector3(-0.05, -0.85, -0.52),
	&"LeftUpperArm": Vector3(0.3, -0.8, -0.5), &"LeftLowerArm": Vector3(0.2, -0.85, -0.3),
	&"RightUpperArm": Vector3(-0.3, -0.8, -0.5), &"RightLowerArm": Vector3(-0.2, -0.85, -0.3),
}
const CROUCH_TURNS := {&"Spine": Vector3(22, 0, 0), &"Head": Vector3(-12, 0, 0)}
## In the air: knees tucked, arms flung up.
const TUCK_AIMS := {
	&"LeftUpperLeg": Vector3(0.12, -0.35, 0.93), &"LeftLowerLeg": Vector3(0.05, -0.95, 0.1),
	&"RightUpperLeg": Vector3(-0.12, -0.6, 0.8), &"RightLowerLeg": Vector3(-0.05, -0.9, -0.4),
	&"LeftUpperArm": Vector3(0.55, 0.55, 0.3), &"LeftLowerArm": Vector3(0.2, 0.9, 0.3),
	&"RightUpperArm": Vector3(-0.55, 0.55, 0.3), &"RightLowerArm": Vector3(-0.2, 0.9, 0.3),
}

## Dummy flinch: snapped back at the waist and neck, arms thrown.
const FLINCH_TURNS := {&"Spine": Vector3(-20, 8, 0), &"Chest": Vector3(-12, 0, 6), &"Head": Vector3(-24, 0, 0)}
const FLINCH_AIMS := {
	&"LeftUpperArm": Vector3(0.55, -0.75, -0.35), &"RightUpperArm": Vector3(-0.55, -0.75, -0.35),
}

# ---------------------------------------------------------------- actors

class Actor:
	var f := FighterState.new()
	var body: Node3D
	var view: CharacterView
	var pose: LookdevPoseOverride
	var pose_target := 0.0
	var pose_rate := 0.15
	var flash := 0.0
	var material: StandardMaterial3D  # the dummy's grey, for the hit flash
	## In a strike window (a move's late startup and active ticks, or the
	## procedural kick); landed once the strike has connected.
	var striking := false
	var landed := false

	func skeleton() -> Skeleton3D:
		return view.model.get_node("%GeneralSkeleton") as Skeleton3D

	func bone(name: StringName) -> Vector3:
		var sk := skeleton()
		return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(name)).origin

	func forward() -> Vector3:
		return Basis(Vector3.UP, f.facing_yaw) * Vector3.FORWARD


var _out := ""
var _scene := ""
var _dummy_scene := DEFAULT_DUMMY
var _hide_stowed := false
var MOVES := ""
## FighterStats.pushbox_radius: fighters' centres never come closer than twice this.
var PUSHBOX_RADIUS := 0.5
## Ki / energy colour of the character's shots and beam.
var KI_COLOR := Color(1.0, 0.62, 0.25)
var _frame := 0
var _viewport: SubViewport
var _stage: LookdevStage
var _caption: Label
var _hero := Actor.new()
var _dummy := Actor.new()
var _hitstop := 0
var _record := true
# Camera: mode, smoothed target, height (framed span) and yaw.
var _cam_mode := "follow"
var _cam_target := Vector3(0, 0.95, 0)
var _cam_height := 2.1
var _cam_yaw := 30.0
var _cam_snap := true
var _cam_side := -1.0
var _fx: Array[Node3D] = []
var _shots: Array[Dictionary] = []
var _kicking := false


func _initialize() -> void:
	var args := LookdevArgs.parse()
	_out = args.pos(0)
	var what := args.pos(1, "full")
	_scene = args.need("scene", USAGE)
	MOVES = args.need("moves", USAGE)
	if _scene == "" or MOVES == "" or _out == "":
		return
	if not MOVES.ends_with("/"):
		MOVES += "/"
	_dummy_scene = args.get_option("dummy", DEFAULT_DUMMY)
	_hide_stowed = args.options.has("hide-stowed")
	if args.options.has("stats"):
		PUSHBOX_RADIUS = (load(args.get_option("stats")) as FighterStats).pushbox_radius
	else:
		PUSHBOX_RADIUS = FighterStats.new().pushbox_radius
	if args.options.has("energy"):
		KI_COLOR = Color.html(args.get_option("energy"))
	DirAccess.make_dir_recursive_absolute(_out)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_stage = LookdevStage.new()
	_stage.large = true
	_viewport.add_child(_stage)
	var layer := CanvasLayer.new()
	_viewport.add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(64, 980)
	_caption.add_theme_font_size_override(&"font_size", 40)
	_caption.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.92))
	_caption.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.55))
	_caption.add_theme_constant_override(&"shadow_offset_x", 2)
	_caption.add_theme_constant_override(&"shadow_offset_y", 2)
	layer.add_child(_caption)
	_run.call_deferred(what)


func _spawn(actor: Actor, scene: String) -> void:
	actor.body = Node3D.new()
	_stage.add_child(actor.body)
	actor.view = (load(scene) as PackedScene).instantiate() as CharacterView
	actor.body.add_child(actor.view)
	_hide_weapons(actor.view)
	actor.pose = LookdevPoseOverride.new()
	actor.skeleton().add_child(actor.pose)
	actor.f.position = Vector3(0, STAND, 0)
	actor.f.facing_yaw = PI
	actor.f.enter_state(S.IDLE)


func _run(what: String) -> void:
	_spawn(_hero, _scene)
	_spawn(_dummy, _dummy_scene)
	_dummy.material = StandardMaterial3D.new()
	_dummy.material.albedo_color = Color(0.56, 0.57, 0.6)
	_dummy.material.roughness = 0.75
	_dummy.material.emission_enabled = true
	_dummy.material.emission = Color(1.0, 0.9, 0.75)
	_dummy.material.emission_energy_multiplier = 0.0
	for node in _dummy.view.model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = _dummy.material
	_dummy.body.visible = false
	for i in 30:  # settle the pose and scarf without recording
		await _tick(false)
	if what == "poses":
		await _pose_stills()
		quit()
		return
	if what == "combat":
		await _strikes("3-hit combo", ["light_1", "light_2", "light_3"], 1)
		await _heavy_launcher()
		await _kick()
		await _guard()
		print("frames: %d" % _frame)
		quit()
		return
	await _idle("Idle", 2.0)
	await _locomotion("Walk", 3.0, 4.0)
	await _locomotion("Run", 9.0, 4.5)
	await _jump()
	await _takeoff_and_hover()
	await _flight()
	await _flight_dash()
	await _descend()
	await _ki_volley()
	await _beam()
	await _strikes("Jab", ["light_1"], 2)
	await _strikes("3-hit combo", ["light_1", "light_2", "light_3"], 2)
	await _heavy_launcher()
	await _kick()
	await _dodge()
	await _guard()
	await _knockdown()
	await _outro()
	print("frames: %d" % _frame)
	quit()


# ---------------------------------------------------------------- segments

func _reset_hero(at := Vector3.ZERO, yaw := PI) -> void:
	_hero.f.position = Vector3(at.x, STAND, at.z)
	_hero.f.velocity = Vector3.ZERO
	_hero.f.facing_yaw = yaw
	_hero.f.blocking = false
	_hero.f.enter_state(S.IDLE)
	_hero.pose.weight = 0.0
	_hero.pose_target = 0.0
	_cam_snap = true


## Dummy facing Kael, distance in front of him.
func _place_dummy(distance: float) -> void:
	_dummy.body.visible = true
	_dummy.f.position = _hero.f.position + _hero.forward() * distance
	_dummy.f.facing_yaw = _hero.f.facing_yaw + PI
	_dummy.f.velocity = Vector3.ZERO
	_dummy.f.enter_state(S.IDLE)
	_dummy.pose.weight = 0.0
	_dummy.pose_target = 0.0


func _hide_dummy() -> void:
	_dummy.body.visible = false
	_dummy.f.enter_state(S.IDLE)


func _wait(ticks: int) -> void:
	for i in ticks:
		await _tick()


func _idle(caption: String, seconds: float) -> void:
	_caption.text = caption
	_cam_mode = "follow"
	if _hero.f.state != S.IDLE:
		_hero.f.enter_state(S.IDLE)
	_hero.f.velocity = Vector3.ZERO
	await _wait(int(seconds * 60))


## Walks or runs round a circle (the stage is only so deep), easing up to speed;
## the camera follows at three-quarters, then swings to a side view.
func _locomotion(caption: String, speed: float, seconds: float) -> void:
	_caption.text = caption
	_cam_mode = "follow"
	var centre := Vector3(0, 0, 2.2)
	var radius := 3.4
	var angle := atan2(_hero.f.position.z - centre.z, _hero.f.position.x - centre.x)
	if absf(Vector2(_hero.f.position.x - centre.x, _hero.f.position.z - centre.z).length() - radius) > 0.2:
		_reset_hero(centre + Vector3(0, 0, -radius), PI * 0.5)
		angle = -PI * 0.5
	if _hero.f.state != S.MOVING:
		_hero.f.enter_state(S.MOVING)
	var v0 := Vector2(_hero.f.velocity.x, _hero.f.velocity.z).length()
	var ticks := int(seconds * 60)
	for i in ticks:
		if i == ticks / 2:
			_cam_mode = "side"
		var v := lerpf(v0, speed, minf(i / 30.0, 1.0))
		angle -= v * DT / radius
		var pos := centre + Vector3(cos(angle), 0, sin(angle)) * radius
		var tangent := Vector3(sin(angle), 0, -cos(angle))
		_hero.f.velocity = tangent * v
		_hero.f.position = Vector3(pos.x, STAND, pos.z)
		_hero.f.facing_yaw = atan2(-tangent.x, -tangent.z)
		await _tick()


func _jump() -> void:
	_caption.text = "Jump & land"
	_cam_mode = "follow"
	_reset_hero(Vector3.ZERO, PI)
	await _wait(10)
	for k in 2:
		# Anticipation: sink into a crouch.
		_set_pose(_hero, CROUCH_AIMS, CROUCH_TURNS, true, 1.0, 0.2)
		await _wait(12)
		# Launch: tuck in the air.
		_hero.f.enter_state(S.FALLING)
		_hero.f.velocity = Vector3(0, 9.5, 0.6)
		_set_pose(_hero, TUCK_AIMS, {}, false, 0.85, 0.12)
		while true:
			_hero.f.velocity.y -= GRAVITY * DT
			_hero.f.position += _hero.f.velocity * DT
			if _hero.f.velocity.y < -3.0:
				_hero.pose_target = 0.0
			if _hero.f.position.y <= STAND:
				_hero.f.position.y = STAND
				break
			await _tick()
		# Landing squash, then up.
		_hero.f.velocity = Vector3.ZERO
		_hero.f.enter_state(S.IDLE)
		_set_pose(_hero, CROUCH_AIMS, CROUCH_TURNS, true, 1.0, 0.45)
		await _wait(8)
		_hero.pose_target = 0.0
		_hero.pose_rate = 0.06
		await _wait(22)


func _takeoff_and_hover() -> void:
	_caption.text = "Take off  /  hover"
	_cam_mode = "follow"
	_set_pose(_hero, CROUCH_AIMS, CROUCH_TURNS, true, 0.8, 0.2)
	await _wait(10)
	_hero.f.enter_state(S.FLYING)
	_set_pose(_hero, HOVER_AIMS, HOVER_TURNS, false, 1.0, 0.07)
	var base := _hero.f.position.y
	for i in 210:
		var t := i * DT
		var rise := minf(t / 0.8, 1.0)
		var y := base + 1.4 * (1.0 - pow(1.0 - rise, 3.0)) + sin(t * 2.6) * 0.06
		_hero.f.velocity = Vector3(0, (y - _hero.f.position.y) / DT, 0)
		_hero.f.position.y = y
		await _tick()


## Flies a banking loop in front of the back wall, the camera close.
func _flight() -> void:
	_caption.text = "Flight"
	_cam_mode = "close"
	_hero.pose_target = 0.0
	_hero.pose_rate = 0.05
	var centre := Vector3(0, 0, 2.6)
	var radius := 3.6
	var angle := atan2(_hero.f.position.z - centre.z, _hero.f.position.x - centre.x)
	var start := centre + Vector3(cos(angle), 0, sin(angle)) * radius
	var from := _hero.f.position
	var y0 := _hero.f.position.y
	for i in 210:
		var v := lerpf(2.0, 11.0, minf(i / 50.0, 1.0))
		angle -= v * DT / radius
		var pos := centre + Vector3(cos(angle), 0, sin(angle)) * radius
		var tangent := Vector3(sin(angle), 0, -cos(angle))
		var y := y0 + 0.5 * sin(i * DT * 1.8)
		var next := Vector3(pos.x, y, pos.z)
		if i < 20:
			next = from.lerp(next, i / 20.0)
		_hero.f.velocity = (next - _hero.f.position) / DT
		_hero.f.position = next
		_hero.f.facing_yaw = atan2(-tangent.x, -tangent.z)
		await _tick()


## A straight flight dash across the stage, the camera tracking alongside.
func _flight_dash() -> void:
	_caption.text = "Flight dash"
	_cam_mode = "dash"
	var y := _hero.f.position.y
	_hero.f.position = Vector3(-14.0, y, 2.0)
	_hero.f.facing_yaw = -PI * 0.5  # heading +X
	_cam_snap = true
	_hero.f.enter_state(S.DASHING)
	_hero.f.dash_kind = FighterState.DashKind.SUSTAINED
	_hero.f.dash_direction = Vector3.RIGHT
	for i in 100:
		var v := lerpf(8.0, 26.0, minf(i / 15.0, 1.0)) if i < 80 else lerpf(26.0, 4.0, (i - 80) / 20.0)
		_hero.f.velocity = Vector3(v, 0, 0)
		_hero.f.position += _hero.f.velocity * DT
		if i % 5 == 0 and i < 80:
			_afterimage(Color(KI_COLOR, 0.18))
		await _tick()
	_hero.f.dash_kind = FighterState.DashKind.NONE
	_hero.f.enter_state(S.FLYING)
	await _wait(20)


func _descend() -> void:
	_caption.text = "Descend & land"
	_cam_mode = "follow"
	_hero.f.enter_state(S.FALLING)
	_hero.f.velocity = Vector3(1.5, 0, 0)
	while _hero.f.position.y > STAND:
		_hero.f.velocity.y -= GRAVITY * 0.6 * DT
		_hero.f.position += _hero.f.velocity * DT
		await _tick()
	_hero.f.position.y = STAND
	_hero.f.velocity = Vector3.ZERO
	_hero.f.enter_state(S.IDLE)
	_set_pose(_hero, CROUCH_AIMS, CROUCH_TURNS, true, 1.0, 0.4)
	await _wait(9)
	_hero.pose_target = 0.0
	_hero.pose_rate = 0.05
	await _wait(40)


## Four ki shots, alternating hands; each orb flies ~1.4 s to the dummy and pops.
func _ki_volley() -> void:
	_caption.text = "Ki blast volley"
	_reset_hero(Vector3(-2.75, 0, 2.0), -PI * 0.5)  # side-on, facing +X: the camera sees her front
	_place_dummy(5.5)
	_cam_mode = "range"
	_cam_snap = true
	await _wait(25)
	for k in 4:
		var right := k % 2 == 0
		var aims := SHOT_AIMS if right else _mirror(SHOT_AIMS)
		var turns := SHOT_TURNS if right else _mirror(SHOT_TURNS, true)
		_set_pose(_hero, aims, turns, false, 1.0, 0.25)
		await _wait(6)
		var hand := _hero.bone(&"RightHand" if right else &"LeftHand")
		var orb := _glow_orb(0.09)
		orb.global_position = hand + _hero.forward() * 0.12
		_flash_at(orb.global_position, 0.12, 6)
		_shots.append({"node": orb, "speed": 3.9})
		# Recoil, then back to the shot pose.
		_set_pose(_hero, RECOIL_AIMS if right else _mirror(RECOIL_AIMS), turns, false, 1.0, 0.5)
		await _wait(7)
		_set_pose(_hero, aims, turns, false, 1.0, 0.2)
		await _wait(15)
	_hero.pose_target = 0.0
	_hero.pose_rate = 0.08
	while not _shots.is_empty():
		await _tick()
	await _wait(30)
	_clear_fx()


func _beam() -> void:
	_caption.text = "Beam charge"
	_reset_hero(Vector3(-2.5, 0, 2.0), -PI * 0.5)  # side-on, facing +X: the charge faces the camera
	_place_dummy(5.0)
	_cam_mode = "close"
	_hero.f.enter_state(S.CHARGING)
	var orb := _glow_orb(0.04)
	for t in 150:
		orb.global_position = _hands_point()
		orb.scale = Vector3.ONE * (1.0 + t / 150.0 * 2.4 + 0.2 * sin(t * 0.7))
		await _tick()
	_caption.text = "Beam fire"
	_cam_mode = "range"
	_cam_snap = true
	_hero.f.enter_state(S.IDLE)
	_set_pose(_hero, BEAM_AIMS, BEAM_TURNS, false, 1.0, 0.3)
	var forward := _hero.forward()
	var beam := _beam_mesh()
	var impact := _glow_orb(0.18)
	for t in 200:
		var start := _hands_point()
		orb.global_position = start
		var reach := _dummy.bone(&"Chest").distance_to(start) - 0.1
		var on := t < 180
		var length := minf((t + 1) * 0.9, reach) if on else 0.0
		beam.visible = on and length > 0.05
		impact.visible = on and length >= reach
		orb.visible = on
		if beam.visible:
			beam.global_position = start + forward * length * 0.5
			beam.look_at(start + forward * length + Vector3(0, 0.0001, 0), Vector3.UP)
			beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
			var w := 1.0 + 0.15 * sin(t * 1.3)
			beam.scale = Vector3(w, maxf(length, 0.001), w)
		if impact.visible:
			impact.global_position = start + forward * length
			impact.scale = Vector3.ONE * (1.0 + 0.3 * sin(t * 2.1))
			if t % 12 == 0:
				_hit(_dummy, 0.35, 2, false)
		if t == 180:
			_hero.pose_target = 0.0
			_caption.text = ""
		await _tick()
	_clear_fx()
	await _wait(20)


## Kael's own moves against the dummy, played `loops` times.
func _strikes(caption: String, ids: Array, loops: int) -> void:
	_caption.text = caption
	_reset_hero(Vector3.ZERO, -PI * 0.5)  # fighting along X: side-on to the camera
	_place_dummy(PUSHBOX_RADIUS * 2.0)
	_cam_mode = "pair"
	await _wait(15)
	for loop in loops:
		for k in ids.size():
			var move: MoveData = load(MOVES + ids[k] + ".tres")
			await _perform(_hero, move, k == ids.size() - 1)
		_hero.f.enter_state(S.IDLE)
		await _wait(24)
		_dummy.f.position = _hero.f.position + _hero.forward() * PUSHBOX_RADIUS * 2.0
		_dummy.f.enter_state(S.IDLE)


func _heavy_launcher() -> void:
	_caption.text = "Heavy  /  launcher"
	_reset_hero(Vector3.ZERO, -PI * 0.5)  # fighting along X: side-on to the camera
	_place_dummy(PUSHBOX_RADIUS * 2.0)
	_cam_mode = "pair"
	await _wait(15)
	await _perform(_hero, load(MOVES + "smash.tres"), false)
	await _perform(_hero, load(MOVES + "launcher.tres"), true)
	_hero.f.enter_state(S.IDLE)
	# The dummy is airborne from the launcher: let it come down and get up.
	while _dummy.f.state in [S.HITSTUN, S.FALLING]:
		await _tick()
	await _wait(40)


## A standing front kick: chamber, snap out, retract (procedural, no clip).
func _kick() -> void:
	_caption.text = "Front kick"
	_reset_hero(Vector3.ZERO, -PI * 0.5)  # fighting along X: side-on to the camera
	_place_dummy(PUSHBOX_RADIUS * 2.0 + 0.1)
	_cam_mode = "pair"
	await _wait(15)
	for k in 2:
		_set_pose(_hero, KICK_CHAMBER, KICK_TURNS, false, 1.0, 0.18)
		await _wait(9)
		_hero.pose.set_pose(KICK_EXTEND, KICK_TURNS, false)
		_hero.pose.weight = 1.0
		_kicking = true
		_hero.striking = true
		_hero.landed = false
		_hero.f.position += _hero.forward() * 0.1
		await _wait(5)
		if not _hero.landed:
			_hero.landed = true
			_hit(_dummy, 1.0, 6, false)
		await _wait(7)
		_kicking = false
		_hero.striking = false
		_hero.pose.set_pose(KICK_CHAMBER, KICK_TURNS, false)
		await _wait(6)
		_hero.pose_target = 0.0
		_hero.pose_rate = 0.12
		await _wait(26)
		_dummy.f.position = _hero.f.position + _hero.forward() * (PUSHBOX_RADIUS * 2.0 + 0.1)
		_dummy.f.enter_state(S.IDLE)


## The dummy swings; Kael dodges aside (afterimage) and comes back.
func _dodge() -> void:
	_caption.text = "Dodge"
	_reset_hero(Vector3.ZERO, -PI * 0.5)  # fighting along X: side-on to the camera
	_place_dummy(1.5)
	_cam_mode = "pair"
	await _wait(15)
	for k in 2:
		var side := 1.0 if k == 0 else -1.0
		_dummy.f.begin_move(load(MOVES + "smash.tres"))
		await _wait(5)
		var dir := Basis(Vector3.UP, _hero.f.facing_yaw) * Vector3.RIGHT * side
		_hero.f.enter_state(S.DASHING)
		_hero.f.dash_kind = FighterState.DashKind.DODGE
		_hero.f.dash_direction = dir
		for i in 20:
			_hero.f.velocity = dir * 8.0 * (1.0 - i / 20.0)
			_hero.f.position += _hero.f.velocity * DT
			if i % 3 == 0:
				_afterimage(Color(0.45, 0.75, 1.0, 0.22))
			await _tick()
		_hero.f.velocity = Vector3.ZERO
		_hero.f.dash_kind = FighterState.DashKind.NONE
		_hero.f.enter_state(S.IDLE)
		while _dummy.f.state == S.ATTACKING:
			await _tick()
		await _wait(10)
		# Step back in.
		_hero.f.enter_state(S.MOVING)
		var back := _dummy.f.position + _dummy.forward() * 1.5
		var from := _hero.f.position
		for i in 24:
			var next := from.lerp(back, smoothstep(0.0, 1.0, i / 23.0))
			_hero.f.velocity = (next - _hero.f.position) / DT
			_hero.f.position = next
			await _tick()
		_hero.f.velocity = Vector3.ZERO
		_hero.f.enter_state(S.IDLE)
		await _wait(10)


## Kael holds a crossed-forearm guard through the dummy's 3-hit string.
func _guard() -> void:
	_caption.text = "Guard"
	_reset_hero(Vector3.ZERO, -PI * 0.5)  # fighting along X: side-on to the camera
	_place_dummy(PUSHBOX_RADIUS * 2.0)
	_cam_mode = "pair"
	await _wait(10)
	_hero.f.enter_state(S.BLOCKING)
	_hero.f.blocking = true
	_set_pose(_hero, GUARD_AIMS, GUARD_TURNS, false, 1.0, 0.2)
	await _wait(16)
	for id: String in ["light_1", "light_2", "light_3", "smash"]:
		await _perform(_dummy, load(MOVES + id + ".tres"), id == "smash")
	_dummy.f.enter_state(S.IDLE)
	await _wait(20)
	_hero.f.blocking = false
	_hero.f.enter_state(S.IDLE)
	_hero.pose_target = 0.0
	_hero.pose_rate = 0.08
	await _wait(20)


## The dummy lands a heavy; Kael is knocked down and gets back up.
func _knockdown() -> void:
	_caption.text = "Hit react  /  knockdown"
	_reset_hero(Vector3.ZERO, -PI * 0.5)  # fighting along X: side-on to the camera
	_place_dummy(PUSHBOX_RADIUS * 2.0)
	_cam_mode = "pair"
	await _wait(15)
	await _perform(_dummy, load(MOVES + "light_2.tres"), true)
	await _wait(10)
	await _perform(_dummy, load(MOVES + "smash.tres"), true)
	while _hero.f.state != S.IDLE:
		await _tick()
	await _wait(20)


func _outro() -> void:
	_caption.text = "Idle"
	_hide_dummy()
	_reset_hero(Vector3.ZERO, PI)
	_cam_mode = "orbit"
	_cam_yaw = -70.0
	await _wait(270)


## One still per procedural pose, for checking them.
func _pose_stills() -> void:
	var poses := {
		"hover": [HOVER_AIMS, HOVER_TURNS, false], "guard": [GUARD_AIMS, GUARD_TURNS, false],
		"shot": [SHOT_AIMS, SHOT_TURNS, false], "recoil": [RECOIL_AIMS, SHOT_TURNS, false],
		"beam": [BEAM_AIMS, BEAM_TURNS, false], "kick_chamber": [KICK_CHAMBER, KICK_TURNS, false],
		"kick_extend": [KICK_EXTEND, KICK_TURNS, false], "crouch": [CROUCH_AIMS, CROUCH_TURNS, true],
		"tuck": [TUCK_AIMS, {}, false], "flinch": [FLINCH_AIMS, FLINCH_TURNS, false],
	}
	_cam_mode = "still"
	for key: String in poses:
		var p: Array = poses[key]
		_caption.text = key
		_hero.pose.set_pose(p[0], p[1], p[2])
		_hero.pose.weight = 1.0
		_hero.pose_target = 1.0
		for yaw: float in [35.0, 90.0]:
			_cam_yaw = yaw
			await _tick(false)
			await _tick(false)
			await RenderingServer.frame_post_draw
			_viewport.get_texture().get_image().save_jpg(_out.path_join("pose_%s_%03d.jpg" % [key, int(yaw)]), 0.9)


# ---------------------------------------------------------------- combat helpers

func _set_pose(actor: Actor, aims: Dictionary, turns: Dictionary, feet: bool, target: float, rate: float) -> void:
	actor.pose.set_pose(aims, turns, feet)
	actor.pose_target = target
	actor.pose_rate = rate


## Swaps left and right (bone names, and the X axis of aims) so a pose works on
## the other side. Turns are euler degrees: mirroring flips yaw and roll.
func _mirror(pose: Dictionary, turns := false) -> Dictionary:
	var out := {}
	for key: StringName in pose:
		var name := String(key)
		if name.begins_with("Left"):
			name = "Right" + name.substr(4)
		elif name.begins_with("Right"):
			name = "Left" + name.substr(5)
		var v: Vector3 = pose[key]
		out[StringName(name)] = Vector3(v.x, -v.y, -v.z) if turns else Vector3(-v.x, v.y, v.z)
	return out


## Plays a move to its end (or into the next one's cancel window) on actor.
func _perform(actor: Actor, move: MoveData, to_the_end: bool) -> void:
	actor.f.begin_move(move)
	var last := move.total_ticks() if to_the_end else move.recovery_start_tick() + 4
	while actor.f.state == S.ATTACKING and actor.f.move == move and actor.f.move_tick < last - 1:
		await _tick()


## A hit lands on target: a flinch (or block), hitstop, a flash and a pop.
## strength 1 is a normal hit; knock launches (BLOWBACK/LAUNCH) or floors it.
func _hit(target: Actor, strength: float, hitstop: int, guarded: bool, move: MoveData = null) -> void:
	var at := target.bone(&"Chest")
	var attacker := _hero if target == _dummy else _dummy
	var away := (target.f.position - attacker.f.position)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -target.forward()
	_hitstop = maxi(_hitstop, hitstop)
	if guarded:
		target.f.enter_state(S.BLOCKSTUN)
		target.f.stun_ticks = 14
		target.f.blocking = true
		target.f.position += away * 0.12
		_flash_at(at + away * -0.25, 0.22, 8, Color(0.6, 0.85, 1.0))
		return
	target.flash = 1.0 * clampf(strength, 0.4, 1.0)
	_flash_at(at - away * 0.15, 0.16 + 0.12 * strength, 9)
	var knock := move.knockback_type if move != null else MoveData.KnockbackType.NONE
	target.f.enter_state(S.HITSTUN)
	target.f.stun_ticks = move.hitstun_ticks if move != null else int(18 + 10 * strength)
	target.f.knockback_type = knock
	match knock:
		MoveData.KnockbackType.LAUNCH:
			target.f.velocity = Vector3(0, 9.0, 0) + away * 1.0
		MoveData.KnockbackType.BLOWBACK:
			target.f.velocity = away * 7.0
		MoveData.KnockbackType.SWEEP:
			target.f.velocity = away * 1.5
		_:
			target.f.velocity = away * 2.2 * strength
	# Bigger flinch on the dummy (Kael has the game's own hit clips).
	if target == _dummy:
		_set_pose(target, FLINCH_AIMS, FLINCH_TURNS, false, 0.0, 0.07)
		target.pose.weight = clampf(0.55 + 0.45 * strength, 0.0, 1.0)


## Per-tick physics for a fighter that is being hit (slide, launch arc, floor).
func _react(actor: Actor) -> void:
	var f := actor.f
	match f.state:
		S.HITSTUN, S.BLOCKSTUN:
			var airborne := f.position.y > STAND + 0.01 or f.velocity.y > 0.0
			if airborne:
				f.velocity.y -= GRAVITY * DT
			else:
				f.velocity = f.velocity.move_toward(Vector3.ZERO, 14.0 * DT)
			f.position += f.velocity * DT
			if f.position.y < STAND:
				f.position.y = STAND
				if airborne and f.velocity.y < -1.0:
					# Came down from a launch: floored.
					f.enter_state(S.KNOCKDOWN)
					f.stun_ticks = 110
					f.velocity = Vector3.ZERO
					return
				f.velocity.y = 0.0
			if f.state_ticks >= f.stun_ticks and not airborne:
				if f.knockback_type == MoveData.KnockbackType.BLOWBACK and actor == _hero:
					f.enter_state(S.KNOCKDOWN)
					f.stun_ticks = 130
					return
				var guarding := f.blocking
				f.enter_state(S.BLOCKING if guarding else S.IDLE)
				f.velocity = Vector3.ZERO
		S.KNOCKDOWN:
			if f.state_ticks >= f.stun_ticks:
				f.enter_state(S.IDLE)


# ---------------------------------------------------------------- effects

func _glow_material(energy: float, color := Color.TRANSPARENT) -> StandardMaterial3D:
	if color.a == 0.0:
		color = KI_COLOR
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.94, 0.82)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


func _glow_orb(radius: float) -> MeshInstance3D:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	orb.mesh = sphere
	orb.material_override = _glow_material(4.0)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := MeshInstance3D.new()
	var outer := SphereMesh.new()
	outer.radius = radius * 1.9
	outer.height = radius * 3.8
	halo.mesh = outer
	var mat := _glow_material(2.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(KI_COLOR, 0.35)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.material_override = mat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = KI_COLOR
	light.light_energy = 1.6
	light.omni_range = 2.5
	orb.add_child(light)
	_stage.add_child(orb)
	_fx.append(orb)
	return orb


## A short expanding, fading glow sphere (muzzle flash, hit pop, block spark).
func _flash_at(at: Vector3, radius: float, life: int, color := Color.TRANSPARENT) -> void:
	if color.a == 0.0:
		color = KI_COLOR
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	node.mesh = sphere
	var mat := _glow_material(5.0, color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.lerp(Color.WHITE, 0.5), 0.9)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.5
	light.omni_range = 2.0
	node.add_child(light)
	_stage.add_child(node)
	node.global_position = at
	node.set_meta(&"pop", life)
	node.set_meta(&"pop_total", life)
	_fx.append(node)


func _beam_mesh() -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.12
	cyl.height = 1.0
	beam.mesh = cyl
	beam.material_override = _glow_material(4.5)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shell := MeshInstance3D.new()
	var outer := CylinderMesh.new()
	outer.top_radius = 0.17
	outer.bottom_radius = 0.22
	outer.height = 1.0
	shell.mesh = outer
	var mat := _glow_material(1.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(KI_COLOR, 0.3)
	shell.material_override = mat
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(shell)
	_stage.add_child(beam)
	_fx.append(beam)
	return beam


## A fading translucent copy of Kael's current pose (dodge / dash afterimage).
func _afterimage(color: Color) -> void:
	var ghost := Node3D.new()
	_stage.add_child(ghost)
	for node in _hero.view.model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.visible or mi.skin == null:
			continue
		var baked := mi.bake_mesh_from_current_skeleton_pose()
		if baked == null:
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = baked
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = color
		copy.material_override = mat
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(copy)
		copy.global_transform = mi.global_transform
	ghost.set_meta(&"life", 18)
	ghost.set_meta(&"alpha", color.a)
	_fx.append(ghost)


func _clear_fx() -> void:
	for node in _fx:
		node.queue_free()
	_fx.clear()
	for shot in _shots:
		(shot["node"] as Node).queue_free()
	_shots.clear()


func _hands_point() -> Vector3:
	return (_hero.bone(&"LeftHand") + _hero.bone(&"RightHand")) * 0.5 + _hero.forward() * 0.14


func _update_fx() -> void:
	for node in _fx.duplicate():
		if node.has_meta(&"life"):
			var life: int = node.get_meta(&"life") - 1
			node.set_meta(&"life", life)
			var alpha: float = node.get_meta(&"alpha")
			for child in node.get_children():
				var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
				mat.albedo_color.a = alpha * life / 18.0
			if life <= 0:
				_fx.erase(node)
				node.queue_free()
		elif node.has_meta(&"pop"):
			var life: int = node.get_meta(&"pop") - 1
			node.set_meta(&"pop", life)
			var t := 1.0 - float(life) / float(node.get_meta(&"pop_total"))
			node.scale = Vector3.ONE * (0.6 + 1.6 * t)
			var mat := (node as MeshInstance3D).material_override as StandardMaterial3D
			mat.albedo_color.a = 0.9 * (1.0 - t)
			mat.emission_energy_multiplier = 5.0 * (1.0 - t)
			(node.get_child(0) as OmniLight3D).light_energy = 2.5 * (1.0 - t)
			if life <= 0:
				_fx.erase(node)
				node.queue_free()
	# Ki shots home on the dummy's chest and pop on contact.
	for shot in _shots.duplicate():
		var orb := shot["node"] as Node3D
		var target := _dummy.bone(&"Chest")
		var to := target - orb.global_position
		var step: float = shot["speed"] * DT
		orb.scale = Vector3.ONE * (1.0 + 0.15 * sin(_frame * 0.9))
		if to.length() <= step + 0.12:
			_shots.erase(shot)
			_fx.erase(orb)
			orb.queue_free()
			_hit(_dummy, 0.8, 4, false)
		else:
			orb.global_position += to.normalized() * step


# ---------------------------------------------------------------- stepping

## One sim tick: advance moves and reactions, pose both views, place the
## bodies, move the camera, save a frame. Hitstop freezes everything but the
## effects.
func _tick(record := true) -> void:
	var frozen := _hitstop > 0
	if frozen:
		_hitstop -= 1
	for actor: Actor in [_hero, _dummy]:
		var f := actor.f
		f.hitstop_ticks = 1 if frozen else 0
		if not frozen:
			f.state_ticks += 1
			if f.state == S.ATTACKING and f.move != null:
				f.move_tick += 1
				if f.move_tick == 1:
					actor.landed = false
				actor.striking = f.move_tick >= maxi(f.move.startup_ticks - 4, 1) \
					and f.move_tick < f.move.recovery_start_tick()
				_whiff_fallback(actor)
				if actor.f.move_tick < f.move.startup_ticks + f.move.active_ticks:
					f.position += actor.forward() * f.move.step_distance / maxf(f.move.startup_ticks + f.move.active_ticks, 1)
				if f.state == S.ATTACKING and f.move_tick >= f.move.total_ticks():
					f.enter_state(S.BLOCKING if f.blocking else S.IDLE)
			elif actor.striking and not _kicking:
				actor.striking = false
			_react(actor)
			actor.pose.weight = move_toward(actor.pose.weight, actor.pose_target, actor.pose_rate)
	if not frozen:
		_pushboxes()
	for actor: Actor in [_hero, _dummy]:
		var f := actor.f
		actor.body.position = f.position
		actor.body.rotation.y = f.facing_yaw
		if actor.body.visible:
			actor.view.apply_state(f, DT)
		actor.flash = move_toward(actor.flash, 0.0, 0.12)
		if actor.material != null:
			actor.material.emission_energy_multiplier = actor.flash * 1.6
	_contacts()
	var shadow := _stage.contact_shadow
	shadow.position = Vector3(_hero.f.position.x, 0.002, _hero.f.position.z + 0.02)
	shadow.visible = _hero.f.position.y < STAND + 0.35
	_update_fx()
	_camera()
	if record:
		await _save()
	else:
		await process_frame


## A strike that never touched the body (the clip's reach falls short at this
## spacing) still lands on its last active tick if the target is close, so a
## move is never silently lost; out of reach it whiffs.
func _whiff_fallback(attacker: Actor) -> void:
	var f := attacker.f
	if attacker.landed or f.move_tick != f.move.recovery_start_tick() - 1:
		return
	var target := _dummy if attacker == _hero else _hero
	var reach := target.f.position - f.position
	reach.y = 0.0
	if not target.body.visible or reach.length() > 1.5 or target.f.state in [S.DASHING, S.KNOCKDOWN]:
		return
	attacker.landed = true
	var heavy := f.move.knockback_type != MoveData.KnockbackType.NONE
	_hit(target, 1.0 if heavy else 0.7, 7 if heavy else 4, target.f.blocking, f.move)


## The sim's pushboxes: two grounded fighters' centres stay 2 x pushbox_radius
## apart; an overlap pushes both back equally (same mass).
func _pushboxes() -> void:
	if not (_hero.body.visible and _dummy.body.visible):
		return
	var a := _hero.f
	var b := _dummy.f
	if absf(a.position.y - b.position.y) > 1.2:
		return
	var d := Vector3(b.position.x - a.position.x, 0, b.position.z - a.position.z)
	var gap := d.length()
	var reach := PUSHBOX_RADIUS * 2.0
	if gap >= reach:
		return
	var dir := d / gap if gap > 0.001 else _hero.forward()
	var push := (reach - gap) * 0.5
	a.position -= dir * push
	b.position += dir * push


## Strikes stop at the target's surface: the attacker's fists, forearms and
## boots are tested against the target's body capsule (hips to head). The
## first touch lands the hit (hitstop, flash, pop) and any overlap pushes the
## target back, so a fist never sinks into the body.
func _contacts() -> void:
	if not (_hero.body.visible and _dummy.body.visible):
		return
	for pair: Array in [[_hero, _dummy], [_dummy, _hero]]:
		var att: Actor = pair[0]
		var def: Actor = pair[1]
		if not att.striking or def.f.state in [S.DASHING, S.KNOCKDOWN]:
			continue
		var a := def.bone(&"Hips")
		var b := def.bone(&"Head")
		var deepest := 0.0
		var push_dir := Vector3.ZERO
		for point in _strike_points(att):
			var on := Geometry3D.get_closest_point_to_segment(point, a, b)
			var off := on - point
			var pen := BODY_RADIUS + STRIKER_RADIUS - off.length()
			if pen > deepest:
				deepest = pen
				push_dir = Vector3(off.x, 0, off.z)
		if deepest <= 0.0:
			continue
		if push_dir.length() < 0.001:
			push_dir = def.f.position - att.f.position
			push_dir.y = 0.0
		push_dir = push_dir.normalized()
		def.f.position += push_dir * deepest
		def.body.position = def.f.position
		if not att.landed:
			att.landed = true
			var move: MoveData = att.f.move if att.f.state == S.ATTACKING else null
			var heavy := move == null or move.knockback_type != MoveData.KnockbackType.NONE
			_hit(def, 1.0 if heavy else 0.7, 7 if heavy else 4, def.f.blocking, move)


func _strike_points(actor: Actor) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for side: String in ["Left", "Right"]:
		var hand := actor.bone(StringName(side + "Hand"))
		var elbow := actor.bone(StringName(side + "LowerArm"))
		pts.append(hand)
		pts.append(hand + (hand - elbow).normalized() * 0.06)
		pts.append(hand.lerp(elbow, 0.5))
		pts.append(actor.bone(StringName(side + "Foot")))
		pts.append(actor.bone(StringName(side + "Toes")))
	return pts


func _camera() -> void:
	var k := _hero.f.position
	var target := Vector3(k.x, k.y - STAND + 0.95, k.z)
	var height := 2.1
	var yaw_goal := rad_to_deg(_hero.f.facing_yaw - PI) + 32.0
	var pitch := -6.0
	match _cam_mode:
		"still":
			target = Vector3(k.x, 0.95, k.z)
			height = 2.0
			yaw_goal = _cam_yaw
			_cam_snap = true
		"side":
			yaw_goal = rad_to_deg(_hero.f.facing_yaw - PI) + 85.0
		"close":
			height = 1.6
			yaw_goal = rad_to_deg(_hero.f.facing_yaw - PI) + 50.0
		"dash":
			height = 2.2
			yaw_goal = 10.0
		"pair", "range":
			var d := _dummy.f.position
			var mid := (k + d) * 0.5
			target = Vector3(mid.x, 0.95, mid.z)
			var span := k.distance_to(d)
			height = maxf(2.3, span * 0.62 + 1.2)
			var across := (d - k)
			yaw_goal = rad_to_deg(atan2(across.x, across.z)) + 90.0 * _cam_side - 18.0 * _cam_side
			if _cam_mode == "pair":
				height = 2.3
		"shoulder":
			# Behind and right of Kael, looking past him at the dummy.
			var fwd := _hero.forward()
			var right := Basis(Vector3.UP, _hero.f.facing_yaw) * Vector3.RIGHT
			var ground := Vector3(k.x, 0.0, k.z)
			var eye := ground + Vector3(0, 1.55, 0) - fwd * 3.6 + right * 1.5
			var look := ground + fwd * 2.4 + Vector3(0, 0.9, 0)
			_stage.camera.global_position = eye
			_stage.camera.look_at(look, Vector3.UP)
			_cam_snap = true
			return
		"orbit":
			yaw_goal = _cam_yaw + 0.18
			_cam_yaw = yaw_goal
	# Lead a moving hero by the follow lag, so fast flight and dashes stay in frame.
	if _cam_mode in ["follow", "side", "close", "dash"]:
		target += _hero.f.velocity * DT * (1.0 - CAM_FOLLOW) / CAM_FOLLOW
	if _cam_snap:
		_cam_target = target
		_cam_height = height
		_cam_yaw = yaw_goal
		_cam_snap = false
	_cam_target = _cam_target.lerp(target, CAM_FOLLOW)
	_cam_height = lerpf(_cam_height, height, 0.06)
	_cam_yaw = rad_to_deg(lerp_angle(deg_to_rad(_cam_yaw), deg_to_rad(yaw_goal), 0.06))
	# Stay on the open side of the cyclorama (the back wall is at -Z).
	_cam_yaw = clampf(wrapf(_cam_yaw, -180.0, 180.0), -58.0, 58.0)
	_stage.frame(_cam_target, _cam_height, 0.62, pitch, _cam_yaw)


func _save() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_jpg(_out.path_join("f_%05d.jpg" % _frame), 0.93)
	_frame += 1


## --hide-stowed: look-dev only, hides a view's stowed weapons (views with
## stowed_weapons(); they're still the old smooth meshes).
func _hide_weapons(view: CharacterView) -> void:
	if _hide_stowed and view.has_method(&"stowed_weapons"):
		for w: Node3D in view.call(&"stowed_weapons"):
			w.visible = false
