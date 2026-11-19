extends Node3D
## Preview only: keys to drive the aura and fire every T-D09 effect.

const EFFECTS := {
	KEY_Z: preload("res://game/view/shaders/vfx/hit_spark_light.tscn"),
	KEY_X: preload("res://game/view/shaders/vfx/hit_spark_heavy.tscn"),
	KEY_C: preload("res://game/view/shaders/vfx/counter_hit.tscn"),
	KEY_V: preload("res://game/view/shaders/vfx/perfect_block_flash.tscn"),
	KEY_B: preload("res://game/view/shaders/vfx/guard_break_shatter.tscn"),
	KEY_N: preload("res://game/view/shaders/vfx/shockwave.tscn"),
}
const PLAYER_COLOR := Color(1.0, 0.62, 0.22)
const OPPONENT_COLOR := Color(0.35, 0.85, 1.0)

var _opponent_colors := false
var _speed_lines_on := false

@onready var _fighter: MeshInstance3D = $Fighter
@onready var _aura: FighterAura = $Fighter/FighterAura
@onready var _impact_point: Marker3D = $ImpactPoint
@onready var _impact_frame: ImpactFrame = $Screen/ImpactFrame
@onready var _speed_lines: ColorRect = $Screen/SpeedLines


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode >= KEY_0 and key.keycode <= KEY_3:
		_aura.power_level = float(key.keycode - KEY_0)
	elif EFFECTS.has(key.keycode):
		_spawn(EFFECTS[key.keycode])
	elif key.keycode == KEY_M:
		_impact_frame.flash()
	elif key.keycode == KEY_S:
		_speed_lines_on = not _speed_lines_on
		(_speed_lines.material as ShaderMaterial).set_shader_parameter("amount", 1.0 if _speed_lines_on else 0.0)
	elif key.keycode == KEY_O:
		_opponent_colors = not _opponent_colors
		var energy := OPPONENT_COLOR if _opponent_colors else PLAYER_COLOR
		_aura.color = energy
		_fighter.set_instance_shader_parameter("rim_energy_color", energy)


func _spawn(scene: PackedScene) -> void:
	var effect := scene.instantiate() as ImpactEffect
	add_child(effect)
	effect.global_position = _impact_point.global_position
	effect.play(OPPONENT_COLOR if _opponent_colors else Color.TRANSPARENT, 1.0)
