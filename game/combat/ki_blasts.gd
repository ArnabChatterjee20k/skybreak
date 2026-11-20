class_name KiBlasts
extends RefCounted
## Ki blast moves (GAME_DESIGN §4 frame data, §5.8): Q tap fires a rapid shot,
## holding Q past CHARGE_TICKS turns it into the charged blast. Both are sim
## projectiles with weapon NONE; Projectile.level is 1 (tap) or 2 (charged).

const TAP := 1
const CHARGED := 2
## Holding Q this many ticks from the press switches to the charged blast.
const CHARGE_TICKS := 14
const TAP_KI := 4
const CHARGED_KI := 20
const TAP_SPEED := 40.0
const CHARGED_SPEED := 30.0
const TAP_RADIUS := 0.3
const CHARGED_RADIUS := 0.6
const TAP_LIFETIME := 60
const CHARGED_LIFETIME := 90

## [startup, active, recovery]
const _TAP_TIMING := [8, 1, 12]
const _CHARGED_TIMING := [22, 1, 18]
## [damage, hitstun, blockstun, hitstop, knockback type, knockback, guard damage]
const _TAP_HIT := [120, 8, 8, 2, MoveData.KnockbackType.NONE, Vector3(0, 0, -1.5), 4]
const _CHARGED_HIT := [700, 20, 14, 7, MoveData.KnockbackType.BLOWBACK, Vector3(0, 3, -14), 20]

static var _tap: MoveData
static var _charged: MoveData
static var _tap_hit: MoveData
static var _charged_hit: MoveData


## The attack performed when Q goes down.
static func tap_move() -> MoveData:
	if _tap == null:
		_tap = _attack(&"ki/blast", _TAP_TIMING, MoveData.CancelLevel.LIGHT)
	return _tap


static func charged_move() -> MoveData:
	if _charged == null:
		_charged = _attack(&"ki/charged_blast", _CHARGED_TIMING, MoveData.CancelLevel.HEAVY)
	return _charged


## Hit numbers of the projectile at level TAP or CHARGED.
static func hit_move(level: int) -> MoveData:
	if level == CHARGED:
		if _charged_hit == null:
			_charged_hit = _hit(&"charged_blast/projectile", _CHARGED_HIT)
		return _charged_hit
	if _tap_hit == null:
		_tap_hit = _hit(&"ki_blast/projectile", _TAP_HIT)
	return _tap_hit


static func is_tap(move: MoveData) -> bool:
	return move != null and move.id == &"ki/blast"


static func is_charged(move: MoveData) -> bool:
	return move != null and move.id == &"ki/charged_blast"


## True for a ki blast projectile (not a weapon shot).
static func is_blast(projectile: Projectile) -> bool:
	return projectile.weapon == Weapon.Kind.NONE and not projectile.thrown and projectile.level > 0


static func _attack(id: StringName, timing: Array, level: MoveData.CancelLevel) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.display_name = String(id)
	move.startup_ticks = timing[0]
	move.active_ticks = timing[1]
	move.recovery_ticks = timing[2]
	move.string_window_ticks = 0
	move.cancel_level = level
	return move


static func _hit(id: StringName, row: Array) -> MoveData:
	var move := _attack(id, [0, 1, 0], MoveData.CancelLevel.SPECIAL)
	move.damage = row[0]
	move.hitstun_ticks = row[1]
	move.blockstun_ticks = row[2]
	move.hitstop_ticks = row[3]
	move.knockback_type = row[4]
	move.knockback = row[5]
	move.guard_damage = row[6]
	return move
