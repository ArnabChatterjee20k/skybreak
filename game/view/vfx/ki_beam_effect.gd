class_name KiBeamEffect
extends VfxEffect
## Ki beam: a charge-up sphere at the hands, then a thick scrolling energy body to the
## end point with a flaring tip (a clash point when two beams meet) and one light.

const CHARGE_RADIUS := 0.9
const BEAM_RADIUS := 0.75
const RELEASE_SECONDS := 0.25

var charge_time := 0.6
var sustain_time := 1.2
var clashing := false

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _charge: MeshInstance3D
var _charge_glow: MeshInstance3D
var _body: MeshInstance3D
var _halo: MeshInstance3D
var _tip: MeshInstance3D
var _tip_ring: MeshInstance3D
var _clash_spikes: MeshInstance3D
var _motes: GPUParticles3D
var _light: OmniLight3D


func _init() -> void:
	super._init()
	default_color = Color(0.4, 0.8, 1.0)
	_charge_glow = add_sprite(&"glow", 3.0 * CHARGE_RADIUS)
	_charge = add_sprite(&"orb", 2.0 * CHARGE_RADIUS)
	_body = add_mesh(&"beam", VfxKit.beam_cylinder())
	_halo = add_mesh(&"beam_halo", VfxKit.beam_cylinder())
	_tip = add_sprite(&"orb", 3.0)
	_tip_ring = add_sprite(&"ring", 5.0)
	_clash_spikes = add_sprite(&"spikes", 6.0)
	_motes = add_particles(&"mote", &"twinkle", 20, 0.4, Vector2(0.2, 0.2), false)
	_light = OmniLight3D.new()
	_light.omni_range = 14.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	add_child(_light)


## Charges at `from` for `charge` seconds, then fires to `to` for `sustain` seconds.
func fire(from: Vector3, to: Vector3, color: Color, charge: float, sustain: float, clash: bool = false) -> void:
	charge_time = maxf(charge, 0.0)
	sustain_time = maxf(sustain, 0.05)
	clashing = clash
	lifetime = charge_time + sustain_time + RELEASE_SECONDS
	_from = from
	_to = to
	play_at(from, color)
	_light.light_color = Color(color, 1.0) if color.a > 0.0 else default_color
	_place_body(0.0)


## Moves the beam's end, e.g. to follow a clash point.
func set_end(to: Vector3) -> void:
	_to = to


func _advanced(_delta: float) -> void:
	var firing := _age >= charge_time
	var t := _age - charge_time
	var width := 0.0
	if firing:
		# Pops wide, settles, then thins out on release.
		var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - t * 6.0)
		var release := clampf((lifetime - _age) / RELEASE_SECONDS, 0.0, 1.0)
		width = pop * release
	_place_body(width)
	var charge := clampf(_age / maxf(charge_time, 0.001), 0.0, 1.0) if not firing else 1.0
	var pulse := 1.0 + 0.12 * sin(_age * 40.0)
	var hand := (0.35 + 0.65 * charge) * pulse * (1.0 if not firing else maxf(width, 0.0) * 0.9)
	_charge.scale = Vector3.ONE * hand
	_charge_glow.scale = Vector3.ONE * hand
	_motes.emitting = not firing
	_light.global_position = (_from + _to) * 0.5 if firing else _from
	_light.light_energy = (0.6 * charge if not firing else 2.2 * width)


func _place_body(width: float) -> void:
	var span := _to - _from
	var length := maxf(span.length(), 0.01)
	var axis := span / length
	var side := Vector3.UP if absf(axis.y) < 0.99 else Vector3.RIGHT
	var x := side.cross(axis).normalized()
	var z := x.cross(axis)
	var visible_width := maxf(width, 0.0)
	var to_local := global_transform.affine_inverse()
	var beam_basis := Basis(x * BEAM_RADIUS * visible_width, axis * length, z * BEAM_RADIUS * visible_width)
	_body.visible = visible_width > 0.01
	_halo.visible = _body.visible
	_tip.visible = _body.visible
	_tip_ring.visible = _body.visible
	_clash_spikes.visible = _body.visible and clashing
	if not _body.visible:
		return
	_body.transform = to_local * Transform3D(beam_basis, _from)
	_halo.transform = to_local * Transform3D(beam_basis.scaled_local(Vector3(1.8, 1.0, 1.8)), _from)
	var tip_pulse := (1.0 + 0.2 * sin(_age * 55.0)) * visible_width * (1.6 if clashing else 1.0)
	_tip.transform = to_local * Transform3D(Basis.from_scale(Vector3.ONE * tip_pulse), _to)
	_tip_ring.transform = to_local * Transform3D(Basis.from_scale(Vector3.ONE * tip_pulse), _to)
	_clash_spikes.transform = to_local * Transform3D(Basis.from_scale(Vector3.ONE * tip_pulse), _to)


func _set_progress(_value: float) -> void:
	# The body and charge loop; the ring and spikes re-fire every 0.2 s at the tip.
	var loop := fmod(_age, 0.2) / 0.2
	VfxKit.set_param(_tip_ring, &"progress", loop)
	VfxKit.set_param(_clash_spikes, &"progress", loop)
