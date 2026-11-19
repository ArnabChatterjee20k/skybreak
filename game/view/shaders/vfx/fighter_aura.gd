class_name FighterAura
extends Node3D
## Energy aura around a fighter: additive shell, rising motes, and lightning streaks from level 2.

const MAX_POWER_LEVEL := 3.0
## Power levels per second the visible aura moves toward power_level.
const BLEND_RATE := 3.0

## 0 off, 1 charging ki, 2 transformed, 3 ultimate. The look eases toward it.
@export_range(0.0, 3.0, 0.01) var power_level := 0.0:
	set(value):
		power_level = clampf(value, 0.0, MAX_POWER_LEVEL)
## Energy colour, per fighter (shared materials; set through instance uniforms).
@export var color := Color(1.0, 0.62, 0.22):
	set(value):
		color = value
		if is_node_ready():
			_apply_color()
## Particle count scale for graphics presets: 1.0 = high (64 particles max).
@export_range(0.0, 1.0, 0.05) var particle_quality := 1.0

## The level currently shown, easing toward power_level.
var shown_level := 0.0

@onready var _shell: MeshInstance3D = $Shell
@onready var _motes: GPUParticles3D = $Motes
@onready var _streaks: GPUParticles3D = $Streaks


func _ready() -> void:
	shown_level = power_level
	_apply_color()
	_apply_level()


## Jumps straight to power_level without easing.
func snap() -> void:
	shown_level = power_level
	_apply_level()


func _process(delta: float) -> void:
	if is_equal_approx(shown_level, power_level):
		return
	shown_level = move_toward(shown_level, power_level, BLEND_RATE * delta)
	_apply_level()


func _apply_color() -> void:
	_shell.set_instance_shader_parameter("color", color)
	_motes.set_instance_shader_parameter("tint", color)
	_streaks.set_instance_shader_parameter("tint", color)


func _apply_level() -> void:
	var level := shown_level
	_shell.visible = level > 0.01
	_shell.set_instance_shader_parameter("power_level", level)
	_set_ratio(_motes, mote_ratio(level) * particle_quality)
	_set_ratio(_streaks, streak_ratio(level) * particle_quality)
	_motes.speed_scale = 1.0 + 0.4 * clampf(level - 1.0, 0.0, 2.0)


## Share of the mote budget alive at a level: 0, 0.4, 0.7, 1.0 at levels 0 to 3.
static func mote_ratio(level: float) -> float:
	if level <= 1.0:
		return 0.4 * maxf(level, 0.0)
	if level <= 2.0:
		return 0.4 + 0.3 * (level - 1.0)
	return minf(0.7 + 0.3 * (level - 2.0), 1.0)


## Streaks only appear from level 2 (transformed).
static func streak_ratio(level: float) -> float:
	if level < 2.0:
		return 0.0
	return minf(0.4 + 0.6 * (level - 2.0), 1.0)


static func _set_ratio(particles: GPUParticles3D, ratio: float) -> void:
	particles.amount_ratio = ratio
	particles.emitting = ratio > 0.0
