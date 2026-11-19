class_name WeaponMoves
extends RefCounted
## Builds each weapon's MoveSet and projectile hit numbers from the tables
## below, once, then caches them. Numbers are balanced around Kael's unarmed
## set (light 6f / 300 dmg, breaker 18f / 700 dmg). Move ids are
## "<weapon>/<slot>"; the view maps the slot to a clip.
##
## Row: [startup, active, recovery, step, hitbox, damage, hitstun, blockstun,
## hitstop, knockback type, knockback, guard damage, extras]. hitbox is
## [offset, radius, length, axis]; extras may set guard_break_below,
## string_window_start_tick, multi_hit.

const _FWD := Vector3.FORWARD
const _SIDE := Vector3.RIGHT
const _UP := Vector3.UP

## Melee move tables, per weapon: lights in string order, then heavies by slot.
const MELEE_TABLES := {
	Weapon.Kind.KI_GAUNTLETS: {
		"lights": [
			[4, 2, 8, 0.25, [Vector3(0, 0.3, -0.95), 0.45, 0.0, _FWD], 220, 15, 8, 3, MoveData.KnockbackType.NONE, Vector3(0, 0, -2), 5, {}],
			[4, 2, 8, 0.25, [Vector3(0.2, 0.3, -0.95), 0.45, 0.0, _FWD], 230, 15, 8, 3, MoveData.KnockbackType.NONE, Vector3(0, 0, -2), 5, {}],
			[5, 2, 9, 0.25, [Vector3(-0.2, 0.3, -1.0), 0.45, 0.0, _FWD], 240, 16, 9, 3, MoveData.KnockbackType.NONE, Vector3(0, 0, -2), 5, {}],
			[5, 2, 9, 0.3, [Vector3(0, 0.2, -1.0), 0.5, 0.0, _FWD], 250, 16, 9, 3, MoveData.KnockbackType.NONE, Vector3(0, 0, -2), 6, {}],
			[7, 3, 14, 0.4, [Vector3(0, 0.2, -1.05), 0.55, 0.0, _FWD], 380, 24, 12, 6, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, -12), 10, {}],
		],
		"smash": [12, 3, 18, 0.5, [Vector3(0, 0.2, -1.1), 0.6, 0.0, _FWD], 600, 26, 14, 7, MoveData.KnockbackType.BLOWBACK, Vector3(0, 3, -16), 20, {}],
		"breaker": [14, 3, 18, 1.2, [Vector3(0, 0.2, -1.2), 0.6, 0.0, _FWD], 650, 26, 15, 7, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, -14), 24, {}],
		"launcher": [11, 3, 20, 0.3, [Vector3(0, 0.0, -1.0), 0.5, 1.2, _UP], 600, 38, 14, 7, MoveData.KnockbackType.LAUNCH, Vector3(0, 22, -3), 16, {}],
		"rising": [10, 3, 20, 0.2, [Vector3(0, 0.6, -0.9), 0.55, 1.0, _UP], 550, 34, 13, 6, MoveData.KnockbackType.LAUNCH, Vector3(0, 18, -2), 14, {}],
		"spike": [13, 3, 20, 0.2, [Vector3(0, -0.4, -1.0), 0.6, 0.0, _FWD], 600, 30, 14, 8, MoveData.KnockbackType.SPIKE, Vector3(0, -20, -4), 18, {}],
		"sweep": [12, 3, 18, 0.2, [Vector3(0, 0.0, -1.0), 0.5, 1.4, _SIDE], 550, 28, 13, 6, MoveData.KnockbackType.SWEEP, Vector3(8, 1, 0), 14, {}],
	},
	Weapon.Kind.STORM_BLADE: {
		"lights": [
			[7, 3, 11, 0.3, [Vector3(0, 0.3, -1.5), 0.5, 1.4, _SIDE], 340, 17, 10, 4, MoveData.KnockbackType.NONE, Vector3(0, 0, -2.5), 7, {}],
			[7, 3, 11, 0.3, [Vector3(0, 0.3, -1.5), 0.5, 1.4, _SIDE], 350, 17, 10, 4, MoveData.KnockbackType.NONE, Vector3(0, 0, -2.5), 7, {}],
			[8, 3, 12, 0.3, [Vector3(0, 0.1, -1.6), 0.5, 1.5, _UP], 360, 18, 10, 4, MoveData.KnockbackType.NONE, Vector3(0, 0, -2.5), 8, {}],
			[10, 4, 16, 0.5, [Vector3(0, 0.2, -1.7), 0.6, 1.8, _SIDE], 480, 26, 13, 7, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, -16), 12, {}],
		],
		"smash": [16, 4, 22, 0.8, [Vector3(0, 0.2, -1.8), 0.65, 1.8, _SIDE], 850, 30, 18, 9, MoveData.KnockbackType.BLOWBACK, Vector3(0, 4, -22), 30, {}],
		"breaker": [18, 4, 22, 1.6, [Vector3(0, 0.2, -1.9), 0.55, 2.0, _FWD], 800, 28, 18, 8, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, -14), 34, {}],
		"launcher": [14, 3, 24, 0.4, [Vector3(0, 0.0, -1.5), 0.5, 2.0, _UP], 720, 40, 16, 8, MoveData.KnockbackType.LAUNCH, Vector3(0, 23, -3), 18, {}],
		"rising": [13, 4, 24, 0.2, [Vector3(0, 0.9, -1.2), 0.6, 1.8, _UP], 700, 36, 15, 8, MoveData.KnockbackType.LAUNCH, Vector3(0, 20, -2), 16, {}],
		"spike": [16, 4, 24, 0.2, [Vector3(0, -0.6, -1.4), 0.6, 1.6, _SIDE], 750, 32, 16, 9, MoveData.KnockbackType.SPIKE, Vector3(0, -22, -4), 20, {}],
		"sweep": [15, 5, 22, 0.2, [Vector3(0, 0.0, -1.5), 0.55, 2.4, _SIDE], 700, 30, 15, 7, MoveData.KnockbackType.SWEEP, Vector3(9, 1, 0), 16, {}],
	},
	Weapon.Kind.SKY_LANCE: {
		"lights": [
			[9, 3, 14, 0.4, [Vector3(0, 0.3, -2.3), 0.4, 2.2, _FWD], 380, 18, 11, 4, MoveData.KnockbackType.NONE, Vector3(0, 0, -4), 8, {}],
			[9, 3, 14, 0.4, [Vector3(0, 0.3, -2.3), 0.4, 2.2, _FWD], 400, 18, 11, 4, MoveData.KnockbackType.NONE, Vector3(0, 0, -4), 8, {}],
			[12, 4, 18, 0.8, [Vector3(0, 0.3, -2.5), 0.45, 2.4, _FWD], 520, 26, 13, 7, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, -18), 12, {}],
		],
		"smash": [18, 4, 30, 0.6, [Vector3(0, 0.2, -2.6), 0.5, 2.6, _FWD], 900, 30, 18, 9, MoveData.KnockbackType.BLOWBACK, Vector3(0, 3, -24), 28, {}],
		"breaker": [16, 5, 28, 4.0, [Vector3(0, 0.2, -2.8), 0.5, 2.8, _FWD], 900, 30, 18, 9, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, -18), 30, {}],
		"launcher": [16, 3, 30, 0.4, [Vector3(0, 0.2, -2.2), 0.5, 1.6, _UP], 750, 40, 16, 8, MoveData.KnockbackType.LAUNCH, Vector3(0, 22, -4), 18, {}],
		"rising": [15, 4, 28, 0.2, [Vector3(0, 1.4, -1.6), 0.5, 2.4, Vector3(0, 0.7, -0.7)], 720, 36, 15, 8, MoveData.KnockbackType.LAUNCH, Vector3(0, 20, -3), 16, {}],
		"spike": [18, 4, 30, 0.2, [Vector3(0, -1.2, -1.8), 0.5, 2.4, Vector3(0, -0.7, -0.7)], 800, 32, 16, 9, MoveData.KnockbackType.SPIKE, Vector3(0, -22, -5), 20, {}],
		"sweep": [17, 5, 28, 0.2, [Vector3(0, 0.0, -2.0), 0.5, 3.2, _SIDE], 700, 30, 15, 7, MoveData.KnockbackType.SWEEP, Vector3(10, 1, 0), 16, {}],
	},
	Weapon.Kind.TITAN_HAMMER: {
		"lights": [
			[14, 4, 20, 0.4, [Vector3(0, 0.2, -1.8), 0.8, 0.0, _FWD], 620, 24, 15, 7, MoveData.KnockbackType.NONE, Vector3(0, 0, -5), 16, {}],
			[16, 5, 24, 0.6, [Vector3(0, 0.0, -1.9), 0.85, 0.0, _FWD], 900, 32, 18, 10, MoveData.KnockbackType.BLOWBACK, Vector3(0, 3, -20), 26, {}],
		],
		"smash": [26, 5, 32, 0.8, [Vector3(0, 0.2, -2.0), 0.95, 0.0, _FWD], 1500, 46, 24, 14, MoveData.KnockbackType.WALL_SPLAT, Vector3(0, 4, -50), 50, {"guard_break_below": 50}],
		"breaker": [24, 5, 30, 1.4, [Vector3(0, 0.2, -2.0), 0.9, 0.0, _FWD], 1300, 40, 22, 12, MoveData.KnockbackType.BLOWBACK, Vector3(0, 3, -30), 60, {"guard_break_below": 60}],
		"launcher": [22, 4, 32, 0.4, [Vector3(0, -0.2, -1.6), 0.8, 1.6, _UP], 1100, 46, 20, 12, MoveData.KnockbackType.LAUNCH, Vector3(0, 26, -4), 30, {}],
		"rising": [20, 5, 30, 0.2, [Vector3(0, 1.2, -1.2), 0.85, 1.6, _UP], 1000, 42, 20, 11, MoveData.KnockbackType.LAUNCH, Vector3(0, 22, -2), 26, {}],
		"spike": [24, 5, 32, 0.2, [Vector3(0, -1.0, -1.4), 0.9, 0.0, _FWD], 1200, 40, 22, 13, MoveData.KnockbackType.SPIKE, Vector3(0, -26, -4), 34, {}],
		"sweep": [22, 6, 30, 0.2, [Vector3(0, -0.2, -1.6), 0.8, 2.6, _SIDE], 1000, 36, 20, 11, MoveData.KnockbackType.SWEEP, Vector3(12, 2, 0), 30, {}],
	},
	Weapon.Kind.ORBIT_CHAKRAM: {
		"lights": [
			[10, 6, 14, 0.0, [Vector3(0, 0.3, -3.5), 0.45, 3.0, _FWD], 300, 18, 10, 4, MoveData.KnockbackType.NONE, Vector3(0, 0, -3), 6, {}],
			[10, 6, 14, 0.0, [Vector3(0, 0.3, -3.5), 0.45, 3.0, _FWD], 320, 18, 10, 4, MoveData.KnockbackType.NONE, Vector3(0, 0, -3), 6, {}],
			[12, 8, 18, 0.0, [Vector3(0, 0.3, -3.8), 0.5, 3.4, _FWD], 420, 26, 12, 6, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, -14), 10, {}],
		],
		"smash": [16, 8, 22, 0.0, [Vector3(0, 0.2, -4.0), 0.6, 3.6, _FWD], 700, 30, 16, 8, MoveData.KnockbackType.BLOWBACK, Vector3(0, 3, -20), 20, {}],
		"breaker": [16, 8, 24, 0.6, [Vector3(0, 0.2, -4.5), 0.5, 4.0, _FWD], 680, 28, 16, 8, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, -14), 22, {}],
		"launcher": [14, 6, 24, 0.0, [Vector3(0, 0.5, -3.2), 0.6, 2.4, Vector3(0, 0.6, -0.8)], 620, 40, 15, 8, MoveData.KnockbackType.LAUNCH, Vector3(0, 22, -3), 16, {}],
		"rising": [14, 6, 24, 0.0, [Vector3(0, 2.2, -2.2), 0.6, 3.0, Vector3(0, 0.7, -0.7)], 600, 36, 14, 7, MoveData.KnockbackType.LAUNCH, Vector3(0, 18, -2), 14, {}],
		"spike": [16, 6, 24, 0.0, [Vector3(0, -2.2, -2.2), 0.6, 3.0, Vector3(0, -0.7, -0.7)], 650, 32, 15, 8, MoveData.KnockbackType.SPIKE, Vector3(0, -20, -4), 16, {}],
		"sweep": [15, 8, 22, 0.0, [Vector3(0, 0.0, -3.4), 0.5, 4.0, _SIDE], 600, 30, 14, 7, MoveData.KnockbackType.SWEEP, Vector3(9, 1, 0), 14, {}],
	},
	Weapon.Kind.EMBER_SCYTHE: {
		"lights": [
			[12, 5, 14, 0.3, [Vector3(0, 0.3, -1.8), 0.6, 3.4, _SIDE], 380, 20, 11, 5, MoveData.KnockbackType.BLOWBACK, Vector3(0, 1, 6), 8, {}],
			[12, 5, 14, 0.3, [Vector3(0, 0.3, -1.8), 0.6, 3.4, _SIDE], 400, 20, 11, 5, MoveData.KnockbackType.BLOWBACK, Vector3(0, 1, 6), 8, {}],
			[14, 6, 18, 0.5, [Vector3(0, 0.2, -2.0), 0.65, 3.8, _SIDE], 560, 28, 14, 7, MoveData.KnockbackType.BLOWBACK, Vector3(0, 3, -18), 12, {}],
		],
		"smash": [20, 5, 26, 0.6, [Vector3(0, 0.2, -2.0), 0.7, 3.8, _SIDE], 950, 34, 18, 10, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, 8), 28, {}],
		"breaker": [20, 5, 26, 1.4, [Vector3(0, 0.2, -2.2), 0.6, 3.6, _SIDE], 900, 32, 18, 9, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, 10), 30, {}],
		"launcher": [18, 4, 28, 0.3, [Vector3(0, 0.2, -1.8), 0.6, 2.4, _UP], 800, 42, 16, 9, MoveData.KnockbackType.LAUNCH, Vector3(0, 22, 2), 18, {}],
		"rising": [17, 5, 26, 0.2, [Vector3(0, 1.2, -1.4), 0.65, 2.6, _SIDE], 760, 38, 16, 8, MoveData.KnockbackType.LAUNCH, Vector3(0, 20, 1), 16, {}],
		"spike": [20, 5, 28, 0.2, [Vector3(0, -1.0, -1.6), 0.65, 2.6, _SIDE], 820, 34, 17, 10, MoveData.KnockbackType.SPIKE, Vector3(0, -22, 2), 20, {}],
		"sweep": [18, 6, 24, 0.2, [Vector3(0, 0.0, -2.0), 0.7, 4.6, _SIDE], 900, 32, 18, 9, MoveData.KnockbackType.SWEEP, Vector3(6, 1, 4), 22, {}],
	},
}

## Ranged weapons: the shot (no hitbox; the projectile spawns on its first
## active tick), then the hit numbers of one projectile (startup..hitbox unused).
const RANGED_TABLES := {
	Weapon.Kind.KI_BOW: {
		"shot": [14, 1, 14],
		"projectile": [700, 28, 14, 6, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, -10), 20],
	},
	Weapon.Kind.ARC_REVOLVER: {
		"shot": [5, 1, 12],
		"projectile": [380, 24, 10, 4, MoveData.KnockbackType.BLOWBACK, Vector3(0, 0, -3), 10],
	},
	Weapon.Kind.STORM_REPEATER: {
		"shot": [1, 1, 4],
		"projectile": [90, 10, 6, 1, MoveData.KnockbackType.NONE, Vector3(0, 0, -1), 6],
	},
	Weapon.Kind.SCATTER_CANNON: {
		"shot": [8, 1, 26],
		"projectile": [160, 26, 10, 3, MoveData.KnockbackType.BLOWBACK, Vector3(0, 3, -22), 8],
	},
	Weapon.Kind.HEARTSTRING_BOW: {
		"shot": [16, 1, 14],
		"projectile": [300, 20, 10, 5, MoveData.KnockbackType.NONE, Vector3(0, 0, -1), 8],
	},
}

## Weak weapon-bash for every heavy while holding a ranged weapon.
const BASH := [10, 3, 18, 0.3, [Vector3(0, 0.2, -1.2), 0.55, 0.0, _FWD], 350, 20, 11, 5, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, -9), 10, {}]
## A thrown weapon's hit: damage plus a short stun.
const THROWN_HIT := [500, 30, 14, 6, MoveData.KnockbackType.BLOWBACK, Vector3(0, 2, -8), 20]

const _HEAVY_SLOTS: Array[String] = ["smash", "breaker", "launcher", "rising", "spike", "sweep"]

static var _sets: Dictionary = {}
static var _projectiles: Dictionary = {}
static var _thrown: MoveData
static var _throw_move: MoveData
static var _pickup_move: MoveData


## The MoveSet a fighter uses while holding kind. Push-block and grab stay unarmed.
static func move_set(kind: Weapon.Kind, unarmed: MoveSet) -> MoveSet:
	if _sets.has(kind):
		return _sets[kind]
	var moves := MoveSet.new()
	var prefix := String(Weapon.weapon_name(kind))
	if Weapon.is_melee(kind):
		var table: Dictionary = MELEE_TABLES[kind]
		var lights: Array = table.lights
		for i in lights.size():
			var light := _build("%s/light_%d" % [prefix, i + 1], lights[i], MoveData.CancelLevel.LIGHT)
			moves.light_string.append(light)
		for slot in _HEAVY_SLOTS:
			moves.set(slot, _build("%s/%s" % [prefix, slot], table[slot], MoveData.CancelLevel.HEAVY))
	else:
		var shot: Array = RANGED_TABLES[kind].shot
		var shot_move := MoveData.new()
		shot_move.id = StringName("%s/shot" % prefix)
		shot_move.startup_ticks = shot[0]
		shot_move.active_ticks = shot[1]
		shot_move.recovery_ticks = shot[2]
		shot_move.string_window_ticks = 0
		moves.light_string.append(shot_move)
		for slot in _HEAVY_SLOTS:
			moves.set(slot, _build("%s/bash" % prefix, BASH, MoveData.CancelLevel.HEAVY))
	moves.push_block = unarmed.push_block
	moves.grab = unarmed.grab
	_sets[kind] = moves
	return moves


## True if move is a ranged weapon's shot: it fires on its first active tick.
static func is_shot(move: MoveData) -> bool:
	return move != null and String(move.id).ends_with("/shot")


## Hit numbers of one projectile fired by kind.
static func projectile_move(kind: Weapon.Kind) -> MoveData:
	if not _projectiles.has(kind):
		_projectiles[kind] = _hit_move("%s/projectile" % Weapon.weapon_name(kind), RANGED_TABLES[kind].projectile)
	return _projectiles[kind]


## Hit numbers of a thrown weapon.
static func thrown_move() -> MoveData:
	if _thrown == null:
		_thrown = _hit_move("weapon/thrown", THROWN_HIT)
	return _thrown


## Recovery after throwing the held weapon.
static func throw_move() -> MoveData:
	if _throw_move == null:
		_throw_move = _bare_move(&"weapon/throw", 4, 1, 12)
	return _throw_move


## Recovery after picking a weapon up (6 ticks after the instant grab).
static func pickup_move() -> MoveData:
	if _pickup_move == null:
		_pickup_move = _bare_move(&"weapon/pickup", 1, 0, 6)
	return _pickup_move


static func _bare_move(id: StringName, startup: int, active: int, recovery: int) -> MoveData:
	var move := MoveData.new()
	move.id = id
	move.startup_ticks = startup
	move.active_ticks = active
	move.recovery_ticks = recovery
	move.string_window_ticks = 0
	return move


static func _hit_move(id: String, row: Array) -> MoveData:
	var move := _bare_move(StringName(id), 0, 1, 0)
	move.damage = row[0]
	move.hitstun_ticks = row[1]
	move.blockstun_ticks = row[2]
	move.hitstop_ticks = row[3]
	move.knockback_type = row[4]
	move.knockback = row[5]
	move.guard_damage = row[6]
	move.cancel_level = MoveData.CancelLevel.SPECIAL
	return move


static func _build(id: String, row: Array, level: MoveData.CancelLevel) -> MoveData:
	var move := MoveData.new()
	move.id = StringName(id)
	move.display_name = id
	move.startup_ticks = row[0]
	move.active_ticks = row[1]
	move.recovery_ticks = row[2]
	move.step_distance = row[3]
	var hitbox: Array = row[4]
	for _i in move.active_ticks:
		move.hitbox_offsets.append(hitbox[0])
	move.hitbox_radii = PackedFloat32Array([hitbox[1]])
	move.hitbox_lengths = PackedFloat32Array([hitbox[2]])
	move.hitbox_axes = PackedVector3Array([hitbox[3]])
	move.damage = row[5]
	move.hitstun_ticks = row[6]
	move.blockstun_ticks = row[7]
	move.hitstop_ticks = row[8]
	move.knockback_type = row[9]
	move.knockback = row[10]
	move.guard_damage = row[11]
	move.cancel_level = level
	move.cancel_start_tick = move.startup_ticks
	move.cancel_end_tick = move.total_ticks() - move.recovery_ticks / 3
	move.string_window_start_tick = move.startup_ticks
	move.string_window_ticks = move.active_ticks + move.recovery_ticks
	var extras: Dictionary = row[12]
	for key: String in extras:
		move.set(key, extras[key])
	return move
