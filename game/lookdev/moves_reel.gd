extends SceneTree
## Moves reel of a character on the look-dev stage, against a grey target
## dummy so the hits read (.claude/skills/voxel-character-lookdev/SKILL.md).
##   godot --path . --disable-vsync -s res://game/lookdev/moves_reel.gd -- <out dir> [full|poses|combat|shots|beam|travel|guard|knockdown]
##       --scene=<character scene> --moves=res://game/combat/moves/<name>/
##       [--dummy=<scene>] [--stats=<FighterStats .tres>] [--energy=#ff9e40] [--fps=60]
## Writes numbered JPG frames (f_00000.jpg...) for ffmpeg at --fps (60, or 30
## to record every second tick at the same speed); "poses" writes one still
## per procedural pose, "combat" only the melee segments, "shots" the ki volley
## and beam, "travel" run, take-off, flight and dash, "guard" only the guard.
## Needs a GPU. --stats sets the pushbox spacing (default FighterStats').
##
## Everything here is look-dev only: the sim is faked (positions, states and
## move ticks are scripted per segment and fed to CharacterView.apply_state,
## one sim tick per frame), and the poses the game has no clip for yet (combat
## hover, crossed guard, ki shot, kick, jump crouch, a big flinch) are layered
## over the clips by LookdevPoseOverride. Neither the sim nor the clips change.

const USAGE := "moves_reel.gd -- <out dir> [full|poses|combat|shots|beam|travel|guard|knockdown] --scene=<character scene> --moves=<move dir/> [--dummy=<scene>] [--stats=<.tres>] [--energy=#rrggbb] [--hide-stowed] [--fps=60]"
## Any humanoid CharacterView on the shared skeleton; it's rendered flat grey.
const DEFAULT_DUMMY := "res://game/characters/kael_chunky/kael_chunky.tscn"
const DT := 1.0 / 60.0
const STAND := 1.0  # FighterState.stand_height: the body's height when standing
const GRAVITY := 22.0
const S := FighterState.State
## Body capsule (hips to head) the strikes stop at, from the measured voxel
## silhouette (waist radius ~0.2-0.3 m); plus the striking fist or boot's own radius.
const BODY_RADIUS := 0.24
const STRIKER_RADIUS := 0.07
## Emission per unit of the effects' nominal energy: about 1.2 keeps the
## energy colour's hue through the filmic tonemap (higher washes to peach).
const GLOW_GAIN := 0.27
## Molten core of beams and shots, a thin hot line inside the energy colour.
const CORE_COLOR := Color("ffd9a0")
## Body contact: the fighters' surfaces are sampled on a rest-space grid of
## this cell (every triangle, so a thin brim or a low-poly head leaves no hole
## wider than the gap), and kept BODY_GAP apart, both pushed back equally.
const SURFACE_CELL := 0.015
const BODY_GAP := 0.04
## Head check: head, hair and hat vertices on a finer grid, which must stay
## HEAD_SKIN clear of the other fighter's surface (look-dev check).
const HEAD_CELL := 0.006
const HEAD_SKIN := 0.02
## Flight dash: the hero's projected bounds stay inside this margin of the
## frame on every side, and the camera leads by this fraction of the width.
const SAFE_PAD := 0.1
const DASH_LEAD := 0.12
const FOV_ASPECT := 16.0 / 9.0
## A guarding target's forearms (elbow to past the fist, gauntlets ~1.4x) as
## capsules of this radius: blocked strikes stop at the crossed arms.
const FOREARM_RADIUS := 0.075
const FIST_PAST_WRIST := 0.4
## Strikes whose hit volume is at most this far from the target step in to it
## (a lunge); further away they whiff.
const MAX_STEP_IN := 0.8
## A limb this close to the target's surface (beyond BODY_GAP) counts as touching.
const TOUCH := 0.012
## Body overlap the contact pass resolves in one tick, at most.
const MAX_OVERLAP := 0.35
## Beam-charge orb core radius at its largest (it grows from 0.04 m).
const ORB_RADIUS := 0.04
## Over-the-shoulder camera: the most it lifts (m) and how far its sight lines
## to the dummy stay from the hero's idle surface (measured at the cut; the
## shot and beam poses turn the chest and swing the boulders in by ~0.3 m).
const SHOULDER_LIFT := 1.0
const SHOULDER_MARGIN := 0.35

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

## Beam charge: a square stance; the cupped hands are placed per character
## (_cup_pose) from the measured hands, forearms and belly.
const CHARGE_AIMS := {
	&"LeftUpperLeg": Vector3(0.16, -0.9, 0.35), &"LeftLowerLeg": Vector3(0.05, -0.95, -0.25),
	&"RightUpperLeg": Vector3(-0.16, -0.9, 0.35), &"RightLowerLeg": Vector3(-0.05, -0.95, -0.25),
}
const CHARGE_TURNS := {&"Spine": Vector3(8, 0, 0), &"Head": Vector3(8, 0, 0)}
## Cupped left hand's finger direction (fingers forward, in and a little up);
## the right hand mirrors it. Elbows bend out and back.
const CUP_HAND := Vector3(-0.5, 0.2, 0.84)
const CUP_POLE := Vector3(1.0, -0.4, -0.5)

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
	## Sampled surface points for body contact: skeleton-space rest positions,
	## their skin binds and weights (4 each), and each bind's bone.
	var probe_rest := PackedVector3Array()
	var probe_binds := PackedInt32Array()
	var probe_weights := PackedFloat32Array()
	var probe_skins: Array[Skin] = []
	var probe_skin_of := PackedInt32Array()
	## Strongest skeleton bone of each probe, and the probes on hands,
	## forearms, shins and feet (what strikes).
	var probe_bone := PackedInt32Array()
	var probe_limb := PackedInt32Array()
	## Posed surface cache: the tick it was taken and the body's position then.
	var surface := PackedVector3Array()
	var surface_tick := -1
	var surface_at := Vector3.ZERO
	## Look-dev check: the strike's measured gap and the step taken toward it.
	var stepped := 0.0
	## Head, hair and hat vertices (finer than the contact probes), same layout.
	var head_rest := PackedVector3Array()
	var head_binds := PackedInt32Array()
	var head_weights := PackedFloat32Array()
	var head_skin_of := PackedInt32Array()

	func skeleton() -> Skeleton3D:
		return view.model.get_node("%GeneralSkeleton") as Skeleton3D

	func bone(name: StringName) -> Vector3:
		var sk := skeleton()
		return sk.global_transform * pose.bone_pose(sk, sk.find_bone(name)).origin

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
## Record every n-th tick (--fps=30 records every second one); frames written.
var _every := 1
var _written := 0
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
## How far the hero's crown (hat, ears, hair) and head width exceed a plain
## head, in metres: the over-the-shoulder camera lifts and widens by it.
var _hero_extra := 0.0
## Worst strike-into-guard overlap left after contacts resolve (look-dev check).
var _guard_overlap := 0.0
## Whether the hero reached KNOCKDOWN in the knockdown segment (look-dev check).
var _knocked_down := false
## Ticks stepped (recorded or not), for the surface cache.
var _ticks := 0
## Over-the-shoulder camera: how far it lifted to clear the hero's head and
## shoulders (0..1 of its lift range; negative: not measured for this shot).
var _shoulder_lift := -1.0
## Look-dev checks for the beam charge: worst hips-to-camera angle (degrees)
## once squared, and the orb's smallest clearance from the hand surfaces (m).
var _charge_square_err := 0.0
var _orb_clearance := INF
## Cupped-hands pose per hero, from the measured hand, forearm and belly.
var _cup := {}
## Look-dev checks for the melee: the smallest clearance of the hero's head,
## hair and hat from the dummy's surface beyond HEAD_SKIN (m; negative sinks
## in), the hero's measured head reach from the neck (brim radius), and the
## hits that landed.
var _head_clear := INF
var _head_reach := 0.0
var _hits := 0
## Flight dash: the hero's smallest margin to the safe area (fraction of the
## frame; negative: outside it) and the frames checked.
var _dash_margin := INF
var _dash_frames := 0
var _dashing := false
## Parent of the render viewport: the main root, or a test's node.
var _host: Node


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
	_every = maxi(1, roundi(60.0 / float(args.get_option("fps", "60"))))
	DirAccess.make_dir_recursive_absolute(_out)
	_build(root)
	_run.call_deferred(what)


## Test entry: the reel without frames, under `host` (a node in the running
## tree). Then await combo_check() or dash_check(); free host's children after.
func setup(host: Node, scene: String, moves: String, dummy := DEFAULT_DUMMY) -> void:
	_scene = scene
	MOVES = moves if moves.ends_with("/") else moves + "/"
	_dummy_scene = dummy
	PUSHBOX_RADIUS = FighterStats.new().pushbox_radius
	_out = ""
	_build(host)


func _build(host: Node) -> void:
	_host = host
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	LookdevStage.configure_viewport(_viewport)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_host.add_child(_viewport)
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
	await _prepare()
	if what == "poses":
		await _pose_stills()
		quit()
		return
	if what == "beam":
		await _beam()
		quit()
		return
	if what == "shots":
		# Energy-colour check: the ki volley and the beam only.
		await _ki_volley()
		await _beam()
		print("frames: %d (ticks %d)" % [_written, _frame])
		quit()
		return
	if what == "travel":
		await _locomotion("Run", 9.0, 2.5)
		await _takeoff_and_hover()
		await _flight()
		await _flight_dash()
		print("frames: %d (ticks %d)" % [_written, _frame])
		quit()
		return
	if what == "guard":
		await _guard()
		print("frames: %d (ticks %d), guard overlap after contact %.3f m" % [_written, _frame, _guard_overlap])
		quit()
		return
	if what == "knockdown":
		await _knockdown()
		print("frames: %d (ticks %d), knocked down %s" % [_written, _frame, _knocked_down])
		quit()
		return
	if what == "combat":
		await _strikes("3-hit combo", ["light_1", "light_2", "light_3"], 1)
		await _heavy_launcher()
		await _kick()
		await _guard()
		print("frames: %d (ticks %d), guard overlap after contact %.3f m" % [_written, _frame, _guard_overlap])
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
	print("frames: %d (ticks %d)" % [_written, _frame])
	quit()


func _prepare() -> void:
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
	# Plain heads with spiky hair (Kael) measure ~0.5 m; only what's beyond it
	# (tall hats, ears) lifts the camera.
	_hero_extra = clampf((_crown_extra(_hero) - 0.5) * 1.6, 0.0, 1.0)
	print("crown extra %.2f m" % _hero_extra)
	for i in 30:  # settle the pose and scarf without recording
		await _tick(false)
	_head_reach = _measure_head_reach(_hero)
	print("head reach (brim radius) %.3f m" % _head_reach)


## Test: the 3-hit combo and the hit react against the dummy, no frames.
## Returns the head clearance (m), the measured head reach and hits landed.
func combo_check() -> Dictionary:
	await _prepare()
	await _strikes("3-hit combo", ["light_1", "light_2", "light_3"], 1)
	var combo_hits := _hits
	await _knockdown()
	return {"head_clear": _head_clear, "head_reach": _head_reach, "combo_hits": combo_hits, "react_hits": _hits - combo_hits}


## Test: the flight dash. Returns the worst safe-area margin and frames checked.
func dash_check() -> Dictionary:
	await _prepare()
	_hero.f.position.y = STAND + 1.6
	_hero.f.enter_state(S.FLYING)
	await _flight_dash()
	return {"margin": _dash_margin, "frames": _dash_frames}


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
	_dashing = true
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
	_dashing = false
	print("flight dash: hero's worst margin to the %d%% safe area %.3f of the frame over %d frames" % [roundi(SAFE_PAD * 100), _dash_margin, _dash_frames])


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
	_reset_hero(Vector3(0.0, 0, 4.6), 0.0)  # facing -Z: shots fly toward the back wall
	_place_dummy(5.5)
	_cam_mode = "shoulder"
	_shoulder_lift = -1.0
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
	_reset_hero(Vector3(0.0, 0, 4.6), 0.0)  # facing -Z: shots fly toward the back wall
	_place_dummy(5.0)
	_cam_mode = "charge"
	# Charge facing the camera, hips and chest squared to it whatever the
	# character's stance, so the cupped hands and the orb read; turn to the
	# dummy on the cut to the over-the-shoulder fire.
	_hero.f.facing_yaw = PI
	_cam_snap = true
	_hero.f.enter_state(S.CHARGING)
	var cup := _cup_pose(_hero)
	_set_pose(_hero, cup["aims"], CHARGE_TURNS, true, 1.0, 0.1)
	_hero.pose.reach = cup["reach"]
	var orb := _glow_orb(ORB_RADIUS)
	for t in 150:
		_hero.pose.square = _toward_camera(_hero)
		var grow := 1.0 + t / 150.0 * 2.4 + 0.2 * sin(t * 0.7)
		orb.scale = Vector3.ONE * grow
		var hands := _hand_surface(_hero)
		orb.global_position = orb_centre(_palms_point(), _hero.forward(), hands, ORB_RADIUS * grow)
		if t >= 30:
			_orb_clearance = minf(_orb_clearance, nearest(orb.global_position, hands) - ORB_RADIUS * grow)
			_charge_square_err = maxf(_charge_square_err, _hips_camera_angle(_hero))
		await _tick()
	print("beam charge: hips-to-camera %.1f deg, orb clear of hands by %.3f m" % [_charge_square_err, _orb_clearance])
	_hero.pose.square = Vector3.ZERO
	_hero.pose.reach = {}
	_caption.text = "Beam fire"
	_hero.f.facing_yaw = 0.0
	_cam_mode = "shoulder"
	_shoulder_lift = -1.0
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
		_knocked_down = _knocked_down or _hero.f.state == S.KNOCKDOWN
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
	_hits += 1
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
		var arms := _guard_segments(target)
		if arms.size() == 4:
			at = (arms[1] + arms[3]) * 0.5 - away * 0.08
		else:
			at -= away * 0.25
		_flash_at(at, 0.22, 8, Color(0.6, 0.85, 1.0))
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
	return glow_material(energy, KI_COLOR if color.a == 0.0 else color)


## Lit, black albedo: the emission alone gives the colour (an unshaded
## material ignores emission and showed its pale albedo instead).
static func glow_material(energy: float, color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy * GLOW_GAIN
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
	mat.albedo_color = Color(0, 0, 0, 0.5)
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
	mat.albedo_color = Color(0, 0, 0, 0.9)
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
	mat.albedo_color = Color(0, 0, 0, 0.45)
	shell.material_override = mat
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(shell)
	var core := MeshInstance3D.new()
	var line := CylinderMesh.new()
	line.top_radius = 0.03
	line.bottom_radius = 0.04
	line.height = 1.01
	core.mesh = line
	core.material_override = _glow_material(4.5, CORE_COLOR)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(core)
	_stage.add_child(beam)
	_fx.append(beam)
	return beam


## A fading translucent copy of Kael's current pose (dodge / dash afterimage).
func _afterimage(color: Color) -> void:
	if DisplayServer.get_name() == "headless":
		return  # no skinning on the dummy renderer, and nothing to see
	var ghost := Node3D.new()
	_stage.add_child(ghost)
	for node in _hero.view.model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or mi.skin == null:
			continue
		if not (mi.get_node_or_null(mi.skeleton) is Skeleton3D):
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


## Crown height above the head bone (hat, ears, hair) and half-width around
## the head (brims, long hair), beyond a plain head, from rest-pose vertices.
func _crown_extra(actor: Actor) -> float:
	var sk := actor.skeleton()
	var hb := sk.find_bone(&"Head")
	var rest := sk.get_bone_global_rest(hb).origin
	var top := 0.0
	var half := 0.0
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		for si in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				if v.y < rest.y - 0.08 or Vector2(v.x - rest.x, v.z - rest.z).length() > 0.6:
					continue
				top = maxf(top, v.y - rest.y)
				half = maxf(half, absf(v.x - rest.x))
	return clampf(top - 0.32, 0.0, 0.9) + clampf(half - 0.2, 0.0, 0.5)


## Between the two palms: the centroid of both hands' posed surfaces (the
## bones' lerp sat inside big gauntlets and stone fists).
func _palms_point() -> Vector3:
	var hands := _hand_surface(_hero)
	if hands.is_empty():
		return (_hero.bone(&"LeftHand") + _hero.bone(&"RightHand")) * 0.5
	var sum := Vector3.ZERO
	for q in hands:
		sum += q
	return sum / float(hands.size())


## Where the beam leaves: just in front of both hands' real surfaces.
func _hands_point() -> Vector3:
	var mid := (_hero.bone(&"LeftHand") + _hero.bone(&"RightHand")) * 0.5
	return orb_centre(mid, _hero.forward(), _hand_surface(_hero), 0.1)


## Centre for an orb of `radius` held in front of the palms: past the hands'
## frontmost surface point along `forward`, so no hand surface covers it.
static func orb_centre(palms: Vector3, forward: Vector3, hand_points: PackedVector3Array, radius: float, margin := 0.02) -> Vector3:
	var front := 0.0
	for q in hand_points:
		front = maxf(front, (q - palms).dot(forward))
	return palms + forward * (front + radius + margin)


## Distance from `p` to the nearest of `points` (INF if none).
static func nearest(p: Vector3, points: PackedVector3Array) -> float:
	var best := INF
	for q in points:
		best = minf(best, p.distance_squared_to(q))
	return sqrt(best)


## Posed surface points on both hands (fingers included).
func _hand_surface(actor: Actor) -> PackedVector3Array:
	var surf := _surface(actor)
	var sk := actor.skeleton()
	var out := PackedVector3Array()
	for i in surf.size():
		var bone := actor.probe_bone[i]
		if bone >= 0 and is_hand(sk.get_bone_name(bone)):
			out.append(surf[i])
	return out


static func is_hand(bone: String) -> bool:
	for part: String in ["Hand", "Thumb", "Index", "Middle", "Ring", "Little"]:
		if bone.contains(part):
			return true
	return false


## The cupped-hands charge pose for this actor: the wrists are placed (as
## hips-relative reach targets) so the palms meet in front of the waist, clear
## of the belly by the forearm's and the hand's measured thickness.
func _cup_pose(actor: Actor) -> Dictionary:
	if _cup.has(actor):
		return _cup[actor]
	var m := measure_cup(_rest_surface(actor), actor.probe_bone, actor.skeleton())
	var hand := CUP_HAND.normalized()
	var half: float = m["hand_half"]
	var palm_x := half * 0.5 + 0.015
	var cup_z: float = m["belly"] + maxf(m["forearm"], half) + 0.03
	cup_z = maxf(cup_z, m["belly"] + m["forearm"] + hand.z * m["palm"] + 0.02)
	var left_palm := Vector3(palm_x, 0.12, cup_z)
	var left_wrist: Vector3 = left_palm - hand * m["palm"]
	var mirror := Vector3(-1, 1, 1)
	var aims := CHARGE_AIMS.duplicate()
	aims[&"LeftHand"] = hand
	aims[&"RightHand"] = hand * mirror
	var reach := {
		&"LeftUpperArm": [left_wrist, CUP_POLE],
		&"RightUpperArm": [left_wrist * mirror, CUP_POLE * mirror],
	}
	print("cup: belly %.2f, forearm r %.3f, hand half %.3f, palm %.3f -> palms at z %.2f" % [m["belly"], m["forearm"], half, m["palm"], cup_z])
	_cup[actor] = {"aims": aims, "reach": reach}
	return _cup[actor]


## Rest-pose measurements in skeleton space (+Z front), relative to the hips:
## belly: the torso's front at the waist; forearm: the right forearm's radius
## around elbow-wrist; palm: wrist to the right hand's centroid; hand_half:
## the hand's radius around that axis.
static func measure_cup(points: PackedVector3Array, bones: PackedInt32Array, sk: Skeleton3D) -> Dictionary:
	var hips := sk.get_bone_global_rest(sk.find_bone(&"Hips")).origin
	var wrist := sk.get_bone_global_rest(sk.find_bone(&"RightHand")).origin
	var elbow := sk.get_bone_global_rest(sk.find_bone(&"RightLowerArm")).origin
	var belly := 0.12
	var forearm := 0.04
	var hand := PackedVector3Array()
	for i in points.size():
		if bones[i] < 0:
			continue
		var name := sk.get_bone_name(bones[i])
		var p := points[i]
		if name in ["Hips", "Spine", "Chest"] and p.y > hips.y - 0.05 and p.y < hips.y + 0.3 and absf(p.x - hips.x) < 0.25:
			belly = maxf(belly, p.z - hips.z)
		elif name == "RightLowerArm":
			forearm = maxf(forearm, p.distance_to(Geometry3D.get_closest_point_to_segment(p, elbow, wrist)))
		elif name.begins_with("Right") and is_hand(name):
			hand.append(p - wrist)
	var centre := Vector3.ZERO
	for o in hand:
		centre += o
	centre = centre / float(maxi(hand.size(), 1))
	var axis := centre.normalized() if centre.length() > 0.001 else Vector3.DOWN
	var half := 0.03
	for o in hand:
		half = maxf(half, (o - axis * o.dot(axis)).length())
	return {"belly": belly, "forearm": forearm, "palm": maxf(centre.length(), 0.04), "hand_half": half}


## Surface points in the rest pose, skeleton space.
func _rest_surface(actor: Actor) -> PackedVector3Array:
	_surface(actor)
	return _skin_points(actor, actor.probe_rest, actor.probe_binds, actor.probe_weights, actor.probe_skin_of, true)


## Direction from the hips to the camera, in the actor's skeleton space.
func _toward_camera(actor: Actor) -> Vector3:
	var sk := actor.skeleton()
	var to := _stage.camera.global_position - actor.bone(&"Hips")
	return sk.global_basis.inverse() * to


## Horizontal angle (degrees) between the posed hips' front and the camera.
func _hips_camera_angle(actor: Actor) -> float:
	var sk := actor.skeleton()
	var hb := sk.find_bone(&"Hips")
	var front := sk.global_basis * (actor.pose.bone_pose(sk, hb).basis * sk.get_bone_global_rest(hb).basis.inverse() * Vector3.BACK)
	var to := _stage.camera.global_position - actor.bone(&"Hips")
	return rad_to_deg(absf(LookdevPoseOverride.yaw_to_face(front, to)))


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
			mat.emission_energy_multiplier = 5.0 * GLOW_GAIN * (1.0 - t)
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
	_ticks += 1
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
	if not frozen:
		_step_in()
	_contacts()
	_body_contacts()
	_check_head()
	var shadow := _stage.contact_shadow
	shadow.position = Vector3(_hero.f.position.x, 0.002, _hero.f.position.z + 0.02)
	shadow.visible = _hero.f.position.y < STAND + 0.35
	_update_fx()
	_camera()
	if _dashing:
		_check_dash_frame()
	if record:
		await _save()
	else:
		await _host.get_tree().process_frame


## A strike whose clip falls short at this spacing (the 4 cm body contact
## keeps bulky fighters further apart than the clips were authored for) steps
## the attacker in over its strike window, by the measured gap between its hit
## volume and the target, so it lands on its first touch. Further than
## MAX_STEP_IN it whiffs.
func _step_in() -> void:
	if not (_hero.body.visible and _dummy.body.visible):
		return
	for att: Actor in [_hero, _dummy]:
		var f := att.f
		var def := _dummy if att == _hero else _hero
		if f.state != S.ATTACKING or f.move == null or att.landed or not att.striking:
			continue
		if def.f.state in [S.DASHING, S.KNOCKDOWN]:
			continue
		var gap := _strike_gap(att, def)
		var left := maxi(f.move.recovery_start_tick() - f.move_tick, 1)
		if gap <= TOUCH or gap > MAX_STEP_IN:
			continue
		var dir := def.f.position - f.position
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.001 else att.forward()
		# Never past the bodies' touch (a brim, a crown, shoulders), so the body
		# contact has nothing to push back and no part sinks in first.
		var room := step_to_touch(_surface(att), _surface(def), dir, BODY_GAP)
		var step := minf(gap / float(left), room)
		if step <= 0.0:
			continue
		f.position += dir * step
		att.body.position = f.position
		att.stepped += step


## How far the attacker must move toward the target before its hit volume
## first touches: its posed hand, forearm, shin and foot surfaces against the
## target's posed surface (kept BODY_GAP apart), or its strike points against
## the target's body capsule, whichever is nearer. INF: never, along this line.
func _strike_gap(att: Actor, def: Actor) -> float:
	var dir := def.f.position - att.f.position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.001 else att.forward()
	var limbs := PackedVector3Array()
	var surf := _surface(att)
	for i in att.probe_limb:
		limbs.append(surf[i])
	var gap := step_to_touch(limbs, _surface(def), dir, BODY_GAP)
	var a := def.bone(&"Hips")
	var b := def.bone(&"Head")
	for point in _strike_points(att):
		var off := Geometry3D.get_closest_point_to_segment(point, a, b) - point
		gap = minf(gap, off.length() - BODY_RADIUS - STRIKER_RADIUS)
	return gap


## Distance `points` must move along `dir` (horizontal) before one comes
## within `gap` of a `target` point; negative: already that much too close.
## Pairs more than MAX_OVERLAP past each other are ignored (other side). Both
## sets are binned across the line of travel in cells of gap / 2, keeping
## only the leading point of `points` and the nearest of `target` per cell.
static func step_to_touch(points: PackedVector3Array, target: PackedVector3Array, dir: Vector3, gap: float) -> float:
	dir.y = 0.0
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var cell := gap * 0.5
	var near := _bin_leading(target, side, dir, cell, -1.0)
	var lead := _bin_leading(points, side, dir, cell, 1.0)
	var best := INF
	for key: Vector2i in lead:
		var p: Vector3 = lead[key]
		for x in range(-2, 3):
			for y in range(-2, 3):
				var q: Variant = near.get(key + Vector2i(x, y))
				if q == null:
					continue
				var du: float = q.x - p.x
				var dy: float = q.y - p.y
				var lat := du * du + dy * dy
				if lat >= gap * gap:
					continue
				var s: float = q.z - p.z - sqrt(gap * gap - lat)
				if s >= -MAX_OVERLAP:
					best = minf(best, s)
	return best


## Points as (across, height, along dir), one per cell across the line of
## travel: the one furthest along `sign` * dir.
static func _bin_leading(points: PackedVector3Array, side: Vector3, dir: Vector3, cell: float, sign: float) -> Dictionary:
	var bins := {}
	for q in points:
		var v := Vector3(q.dot(side), q.y, q.dot(dir))
		var key := Vector2i(floori(v.x / cell), floori(v.y / cell))
		var have: Variant = bins.get(key)
		if have == null or (v.z - (have as Vector3).z) * sign > 0.0:
			bins[key] = v
	return bins


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
## boots are tested against the target's body capsule (hips to head) and, while
## it guards, its forearms, so a blocked strike stops at the arms. The
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
		var guard := _guard_segments(def)
		var away := def.f.position - att.f.position
		away.y = 0.0
		for point in _strike_points(att):
			var on := Geometry3D.get_closest_point_to_segment(point, a, b)
			var off := on - point
			var pen := BODY_RADIUS + STRIKER_RADIUS - off.length()
			if pen > deepest:
				deepest = pen
				push_dir = Vector3(off.x, 0, off.z)
			for k in range(0, guard.size(), 2):
				var arm := Geometry3D.get_closest_point_to_segment(point, guard[k], guard[k + 1])
				var arm_pen := FOREARM_RADIUS + STRIKER_RADIUS - arm.distance_to(point)
				if arm_pen > deepest:
					deepest = arm_pen
					# The guard is pushed straight back, not sideways off the arm.
					push_dir = away
		if deepest <= 0.0:
			if not att.landed and att.f.state == S.ATTACKING and _strike_gap(att, def) <= TOUCH:
				# Touched the real surface (boulders, belly) outside the capsule:
				# the hit lands; the body contact pushes both back equally.
				att.landed = true
				var touched: MoveData = att.f.move
				var big := touched.knockback_type != MoveData.KnockbackType.NONE
				_hit(def, 1.0 if big else 0.7, 7 if big else 4, def.f.blocking, touched)
			continue
		if push_dir.length() < 0.001:
			push_dir = def.f.position - att.f.position
			push_dir.y = 0.0
		push_dir = push_dir.normalized()
		def.f.position += push_dir * deepest
		def.body.position = def.f.position
		if not guard.is_empty():
			# A horizontal push clears an oblique arm overlap only partly; repeat.
			var back := away.normalized() if away.length() > 0.001 else push_dir
			for it in 8:
				var left := _arm_overlap(att, def)
				if left <= 0.002:
					break
				def.f.position += back * left
				def.body.position = def.f.position
			_guard_overlap = maxf(_guard_overlap, _arm_overlap(att, def))
		if not att.landed:
			att.landed = true
			var move: MoveData = att.f.move if att.f.state == S.ATTACKING else null
			var heavy := move == null or move.knockback_type != MoveData.KnockbackType.NONE
			_hit(def, 1.0 if heavy else 0.7, 7 if heavy else 4, def.f.blocking, move)


## Bodies never pass into each other: sampled surface points of both posed
## meshes (boulders, back, beard, the dummy's thrown arms) are kept BODY_GAP
## apart by pushing both fighters back equally along the line between them,
## like the pushboxes but with the real silhouettes.
func _body_contacts() -> void:
	if not (_hero.body.visible and _dummy.body.visible):
		return
	var a := _hero.f
	var b := _dummy.f
	var d := Vector3(b.position.x - a.position.x, 0, b.position.z - a.position.z)
	if absf(a.position.y - b.position.y) > 1.2 or d.length() > 3.0:
		return
	var dir := d.normalized() if d.length() > 0.001 else _hero.forward()
	var shift := -step_to_touch(_surface(_hero), _surface(_dummy), dir, BODY_GAP)
	if shift <= 0.0:
		return
	shift += 0.002
	a.position -= dir * shift * 0.5
	b.position += dir * shift * 0.5
	_hero.body.position = a.position
	_dummy.body.position = b.position


## Look-dev check: how far the hero's head, hair and hat points could still move
## toward the dummy before coming within HEAD_SKIN of its surface (_head_clear).
func _check_head() -> void:
	if not (_hero.body.visible and _dummy.body.visible):
		return
	var d := _dummy.f.position - _hero.f.position
	d.y = 0.0
	if d.length() > 2.5 or absf(_dummy.f.position.y - _hero.f.position.y) > 1.2:
		return
	var dir := d.normalized() if d.length() > 0.001 else _hero.forward()
	var clear := step_to_touch(_posed_head(_hero), _surface(_dummy), dir, HEAD_SKIN)
	if clear < _head_clear:
		_head_clear = clear
		if clear < 0.0:
			print("head into the dummy by %.3f m at frame %d (%s)" % [-clear, _frame, _caption.text])


## The actor's posed surface this tick (moved along if the body moved since).
func _surface(actor: Actor) -> PackedVector3Array:
	var at := actor.body.global_position
	if actor.surface_tick != _ticks:
		actor.surface = _posed_surface(actor)
		actor.surface_tick = _ticks
		actor.surface_at = at
	elif at != actor.surface_at:
		var delta := at - actor.surface_at
		for i in actor.surface.size():
			actor.surface[i] += delta
		actor.surface_at = at
	return actor.surface


## The actor's sampled surface points, skinned to its current pose (global).
func _posed_surface(actor: Actor) -> PackedVector3Array:
	if actor.probe_rest.is_empty():
		_sample_surface(actor, actor.skeleton())
	return _skin_points(actor, actor.probe_rest, actor.probe_binds, actor.probe_weights, actor.probe_skin_of, false)


## The actor's head, hair and hat points (HEAD_CELL grid), posed (global).
func _posed_head(actor: Actor) -> PackedVector3Array:
	if actor.probe_rest.is_empty():
		_sample_surface(actor, actor.skeleton())
	return _skin_points(actor, actor.head_rest, actor.head_binds, actor.head_weights, actor.head_skin_of, false)


## Skins rest-space points (4 binds and weights each) with the override's bone
## poses, or with the skeleton's rest when `rest` is set; global unless rest.
func _skin_points(actor: Actor, pts: PackedVector3Array, binds: PackedInt32Array, weights: PackedFloat32Array, skin_of: PackedInt32Array, rest: bool) -> PackedVector3Array:
	var sk := actor.skeleton()
	var mats: Array[Transform3D] = []
	var bind_base := PackedInt32Array()
	for skin in actor.probe_skins:
		bind_base.append(mats.size())
		for k in skin.get_bind_count():
			var bone := skin.get_bind_bone(k)
			if bone < 0:
				bone = sk.find_bone(skin.get_bind_name(k))
			bone = maxi(bone, 0)
			if rest:
				mats.append(sk.get_bone_global_rest(bone) * skin.get_bind_pose(k))
			else:
				mats.append(sk.global_transform * actor.pose.bone_pose(sk, bone) * skin.get_bind_pose(k))
	var out := PackedVector3Array()
	out.resize(pts.size())
	for i in pts.size():
		var base := bind_base[skin_of[i]]
		var p := Vector3.ZERO
		for j in 4:
			var w := weights[i * 4 + j]
			if w > 0.0:
				p += (mats[base + binds[i * 4 + j]] * pts[i]) * w
		out[i] = p
	return out


## Samples every visible skinned mesh: triangle points (corners, centroid and
## a stratified fill of big triangles) kept one per SURFACE_CELL rest-space cell
## per bone, so the probes cover thin and low-poly parts without holes; plus
## the head, hair and hat vertices on the finer HEAD_CELL grid.
func _sample_surface(actor: Actor, sk: Skeleton3D) -> void:
	var cells := {}
	var head_cells := {}
	for node in actor.view.model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.skin == null or not mi.is_visible_in_tree():
			continue
		var m := actor.probe_skins.size()
		actor.probe_skins.append(mi.skin)
		var names := {}
		for si in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / maxi(verts.size(), 1)
			if per < 4:
				continue
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(verts.size() - verts.size() % 3)
				for i in idx.size():
					idx[i] = i
			# The strongest bone per vertex, by name.
			var top_bone := PackedInt32Array()
			top_bone.resize(verts.size())
			for v in verts.size():
				var top := 0
				for j in 4:
					if ws[v * per + j] > ws[v * per + top]:
						top = j
				var bind := bones[v * per + top]
				if not names.has(bind):
					var bone := mi.skin.get_bind_bone(bind)
					if bone < 0:
						bone = sk.find_bone(mi.skin.get_bind_name(bind))
					names[bind] = bone
				top_bone[v] = names[bind]
				var bname := sk.get_bone_name(top_bone[v]) if top_bone[v] >= 0 else ""
				if is_head_part(bname):
					_keep(head_cells, verts[v], HEAD_CELL, top_bone[v], [m, v, per, bones, ws])
			for t in range(0, idx.size() - 2, 3):
				var a := verts[idx[t]]
				var b := verts[idx[t + 1]]
				var c := verts[idx[t + 2]]
				var area := (b - a).cross(c - a).length() * 0.5
				var n := clampi(ceili(sqrt(area) / SURFACE_CELL), 1, 24)
				for u in n + 1:
					for w in n + 1 - u:
						var bu := float(u) / n
						var bw := float(w) / n
						var bv := 1.0 - bu - bw
						var p := a * bv + b * bu + c * bw
						# Binds and weights of the nearest corner.
						var corner := idx[t] if bv >= bu and bv >= bw else (idx[t + 1] if bu >= bw else idx[t + 2])
						_keep(cells, p, SURFACE_CELL, top_bone[corner], [m, corner, per, bones, ws])
	for key: Vector4i in cells:
		var e: Array = cells[key]
		_add_probe(actor, e, false, sk)
	for key: Vector4i in head_cells:
		_add_probe(actor, head_cells[key], true, sk)


## Keeps the first point per (cell, bone) key in `cells`.
static func _keep(cells: Dictionary, p: Vector3, cell: float, bone: int, src: Array) -> void:
	var key := Vector4i(floori(p.x / cell), floori(p.y / cell), floori(p.z / cell), bone)
	if not cells.has(key):
		cells[key] = [p, bone] + src


func _add_probe(actor: Actor, e: Array, head: bool, sk: Skeleton3D) -> void:
	var p: Vector3 = e[0]
	var bone: int = e[1]
	var m: int = e[2]
	var v: int = e[3]
	var per: int = e[4]
	var bones: PackedInt32Array = e[5]
	var ws: PackedFloat32Array = e[6]
	if head:
		actor.head_rest.append(p)
		actor.head_skin_of.append(m)
		for j in 4:
			actor.head_binds.append(bones[v * per + j])
			actor.head_weights.append(ws[v * per + j])
		return
	actor.probe_rest.append(p)
	actor.probe_skin_of.append(m)
	for j in 4:
		actor.probe_binds.append(bones[v * per + j])
		actor.probe_weights.append(ws[v * per + j])
	actor.probe_bone.append(bone)
	if is_limb(sk.get_bone_name(bone) if bone >= 0 else ""):
		actor.probe_limb.append(actor.probe_rest.size() - 1)


## Head, jaw, eyes, hair, ears and a hat bone: what a brim or crown is on.
static func is_head_part(bone: String) -> bool:
	for part: String in ["Head", "Jaw", "Eye", "Hair", "Ear", "Hat", "Neck"]:
		if bone.contains(part):
			return true
	return false


## Furthest the head, hair and hat reach sideways from the neck (the brim
## radius on a hat), from the posed head points.
func _measure_head_reach(actor: Actor) -> float:
	var neck := actor.bone(&"Head")
	var reach := 0.0
	for p in _posed_head(actor):
		reach = maxf(reach, Vector2(p.x - neck.x, p.z - neck.z).length())
	return reach


## Bones that strike: hands and fingers, forearms, shins, feet and toes.
static func is_limb(bone: String) -> bool:
	for part: String in ["Hand", "LowerArm", "LowerLeg", "Foot", "Toes", "Thumb", "Index", "Middle", "Ring", "Little"]:
		if bone.contains(part):
			return true
	return false


## A guarding fighter's forearms as segment pairs (elbow, past the fist); empty
## when not guarding.
func _guard_segments(actor: Actor) -> PackedVector3Array:
	var segs := PackedVector3Array()
	if not (actor.f.blocking or actor.f.state in [S.BLOCKING, S.BLOCKSTUN]):
		return segs
	for side: String in ["Left", "Right"]:
		var elbow := actor.bone(StringName(side + "LowerArm"))
		var wrist := actor.bone(StringName(side + "Hand"))
		segs.append(elbow)
		segs.append(wrist + (wrist - elbow) * FIST_PAST_WRIST)
	return segs


## Deepest overlap left between att's strike points and def's guard arms (m).
func _arm_overlap(att: Actor, def: Actor) -> float:
	var guard := _guard_segments(def)
	var worst := 0.0
	for point in _strike_points(att):
		for k in range(0, guard.size(), 2):
			var arm := Geometry3D.get_closest_point_to_segment(point, guard[k], guard[k + 1])
			worst = maxf(worst, FOREARM_RADIUS + STRIKER_RADIUS - arm.distance_to(point))
	return worst


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
		"charge":
			# Nearly frontal and waist-to-crown, so the cupped hands and the orb read.
			target = Vector3(k.x, k.y - STAND + 0.92, k.z)
			height = 1.5
			yaw_goal = rad_to_deg(_hero.f.facing_yaw - PI) + 16.0
			pitch = -5.0
		"dash":
			# A tracking shot that leads: the hero sits behind centre with room
			# ahead, the afterimages trailing out behind (see _dash_correct).
			height = 2.2
			yaw_goal = 10.0
			var heading := Vector3(_hero.f.dash_direction.x, 0, _hero.f.dash_direction.z)
			var width := height / 0.62 * FOV_ASPECT
			target += heading.normalized() * width * DASH_LEAD if heading.length() > 0.01 else Vector3.ZERO
			_cam_target = target
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
			# Tall hats, ears, long hair or shoulder boulders would hide the
			# dummy: lift and widen the camera until every sight line to the
			# dummy clears the hero's measured head, shoulders and body.
			if _shoulder_lift < 0.0:
				_shoulder_lift = _measure_shoulder_lift(ground, fwd, right)
			var lift := maxf(_hero_extra, _shoulder_lift * SHOULDER_LIFT)
			var eye := ground + Vector3(0, 1.55 + lift * 1.1, 0) - fwd * (3.6 + lift) + right * (1.5 + lift * 1.4)
			var look := ground + fwd * 2.4 + Vector3(0, 0.9 - lift * 0.2, 0)
			_stage.camera.global_position = eye
			_stage.camera.look_at(look, Vector3.UP)
			_cam_snap = true
			return
		"orbit":
			yaw_goal = _cam_yaw + 0.18
			_cam_yaw = yaw_goal
	if _cam_snap:
		_cam_target = target
		_cam_height = height
		_cam_yaw = yaw_goal
		_cam_snap = false
	_cam_target = _cam_target.lerp(target, 0.12)
	_cam_height = lerpf(_cam_height, height, 0.06)
	_cam_yaw = rad_to_deg(lerp_angle(deg_to_rad(_cam_yaw), deg_to_rad(yaw_goal), 0.06))
	# Stay on the open side of the cyclorama (the back wall is at -Z).
	_cam_yaw = clampf(wrapf(_cam_yaw, -180.0, 180.0), -58.0, 58.0)
	_stage.frame(_cam_target, _cam_height, 0.62, pitch, _cam_yaw)
	if _cam_mode == "dash":
		_dash_correct()


## Slides the dash camera (parallel to its image plane) until the hero's
## projected surface sits inside the SAFE_PAD safe area.
func _dash_correct() -> void:
	var cam := _stage.camera
	var surf := _surface(_hero)
	for it in 4:
		var box := screen_box(surf, cam.global_transform, cam.fov, FOV_ASPECT)
		var shift := Vector2(safe_shift(box.position.x, box.end.x, SAFE_PAD), safe_shift(box.position.y, box.end.y, SAFE_PAD))
		if shift.length() < 1e-4:
			return
		# A screen fraction at the hero's depth, in metres.
		var depth := (cam.global_transform.affine_inverse() * _hero.bone(&"Chest")).z * -1.0
		var span_y := 2.0 * depth * tan(deg_to_rad(cam.fov) * 0.5)
		var basis := cam.global_transform.basis
		# Moving the camera right moves the hero left on screen; y is down.
		cam.global_position += basis.x * (-shift.x * span_y * FOV_ASPECT) + basis.y * (shift.y * span_y)


## Look-dev check: the hero's smallest margin to the safe area this frame.
func _check_dash_frame() -> void:
	var cam := _stage.camera
	var box := screen_box(_surface(_hero), cam.global_transform, cam.fov, FOV_ASPECT)
	var margin := minf(minf(box.position.x, 1.0 - box.end.x), minf(box.position.y, 1.0 - box.end.y)) - SAFE_PAD
	_dash_margin = minf(_dash_margin, margin)
	_dash_frames += 1


## Screen-space bounds (0..1, x right, y down) of `points` seen by a camera at
## `xf` with a vertical `fov_deg` and `aspect` (points behind it are skipped).
static func screen_box(points: PackedVector3Array, xf: Transform3D, fov_deg: float, aspect: float) -> Rect2:
	var inv := xf.affine_inverse()
	var ty := tan(deg_to_rad(fov_deg) * 0.5)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		var q := inv * p
		if q.z > -0.01:
			continue
		var s := Vector2(0.5 + q.x / (-q.z * ty * aspect) * 0.5, 0.5 - q.y / (-q.z * ty) * 0.5)
		lo = Vector2(minf(lo.x, s.x), minf(lo.y, s.y))
		hi = Vector2(maxf(hi.x, s.x), maxf(hi.y, s.y))
	return Rect2(lo, hi - lo)


## How far (screen fraction) a span [lo, hi] must move to sit inside
## [pad, 1 - pad]; centred if it's wider than that.
static func safe_shift(lo: float, hi: float, pad: float) -> float:
	if hi - lo > 1.0 - 2.0 * pad:
		return 0.5 - (lo + hi) * 0.5
	if lo < pad:
		return pad - lo
	if hi > 1.0 - pad:
		return (1.0 - pad) - hi
	return 0.0


## Fraction (0..1) of the shoulder camera's lift range needed so the sight
## lines to the dummy's head, chest, hips, sides and feet clear the hero's
## posed surface (all but the forearms and hands, which move in the shots).
func _measure_shoulder_lift(ground: Vector3, fwd: Vector3, right: Vector3) -> float:
	var targets := _dummy_marks()
	var surf := _surface(_hero)
	var sk := _hero.skeleton()
	var body := PackedVector3Array()
	for i in surf.size():
		var bone := _hero.probe_bone[i]
		var name := sk.get_bone_name(bone) if bone >= 0 else ""
		if not (is_hand(name) or name.contains("LowerArm")):
			body.append(surf[i])
	var base_lift := _hero_extra / SHOULDER_LIFT
	var eye := func(t: float) -> Vector3:
		var l := t * SHOULDER_LIFT
		return ground + Vector3(0, 1.55 + l * 1.1, 0) - fwd * (3.6 + l) + right * (1.5 + l * 1.4)
	var t := 1.0
	for i in 41:
		var ti := maxf(base_lift, i / 40.0)
		if LookdevFraming.clearance(eye.call(ti), targets, body, SHOULDER_MARGIN) >= 0.0:
			t = ti
			break
	var clear := LookdevFraming.clearance(eye.call(t), targets, body, 0.0)
	print("shoulder cam: lift %.2f m, sight lines clear the hero by %.3f m" % [t * SHOULDER_LIFT, clear])
	return t


## Points on the dummy that must stay visible: crown, chest, hips, both sides, feet.
func _dummy_marks() -> PackedVector3Array:
	var side := Basis(Vector3.UP, _dummy.f.facing_yaw) * Vector3.RIGHT
	var chest := _dummy.bone(&"Chest")
	return PackedVector3Array([
		_dummy.bone(&"Head") + Vector3(0, 0.25, 0), chest, _dummy.bone(&"Hips"),
		chest + side * 0.35, chest - side * 0.35, _dummy.bone(&"LeftFoot"), _dummy.bone(&"RightFoot"),
	])


func _save() -> void:
	if _out == "":
		await _host.get_tree().process_frame
		_frame += 1
		return
	if _frame % _every != 0:
		# A tick between recorded frames: step without rendering.
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		await _host.get_tree().process_frame
		_frame += 1
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await _host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_jpg(_out.path_join("f_%05d.jpg" % _written), 0.93)
	_written += 1
	_frame += 1


## --hide-stowed: look-dev only, hides a view's stowed weapons (views with
## stowed_weapons(); they're still the old smooth meshes).
func _hide_weapons(view: CharacterView) -> void:
	if _hide_stowed and view.has_method(&"stowed_weapons"):
		for w: Node3D in view.call(&"stowed_weapons"):
			w.visible = false
