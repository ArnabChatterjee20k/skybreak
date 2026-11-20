extends SceneTree
## Writes the four legends' KiKit resources (game/combat/ki/kits/) from the table below.
## godot --headless --path . -s res://game/combat/ki/make_ki_kits.gd

const B := MoveData.KnockbackType.BLOWBACK
const N := MoveData.KnockbackType.NONE
## move: [id, name, startup, active, recovery, damage, hitstun, blockstun, hitstop, knockback type, knockback, guard, ki]
const KITS := {
	"kael": {
		"blast": ["ki_blast", "Ki Blast", 8, 1, 12, 120, 12, 8, 4, N, Vector3(0, 0, -3), 4, 4],
		"charged": ["charged_blast", "Charged Blast", 22, 1, 18, 700, 34, 18, 10, B, Vector3(0, 5, -20), 16, 20],
		"beam": ["beam", "Dawnspear", 26, 42, 26, 1500, 44, 12, 14, B, Vector3(0, 6, -30), 0, 50],
		"ultimate": ["beam_ultimate", "Zenith Lance", 34, 66, 32, 2800, 60, 12, 20, B, Vector3(0, 10, -40), 0, 0],
		"shape": {"blast_speed": 44.0, "blast_radius": 0.35, "charged_speed": 30.0, "charged_radius": 0.8,
			"beam_radius": 0.9, "beam_range": 55.0, "beam_speed": 120.0, "ultimate_radius": 1.4, "ultimate_range": 70.0,
			"color": Color(1.0, 0.62, 0.25)},
	},
	"vexa": {
		"blast": ["ki_blast", "Hex Bolt", 8, 1, 9, 100, 11, 7, 3, N, Vector3(0, 0, -3), 3, 4],
		"charged": ["charged_blast", "Charged Hex", 22, 1, 16, 620, 32, 16, 9, B, Vector3(0, 5, -20), 14, 20],
		"beam": ["beam", "Hexline", 24, 34, 24, 1300, 40, 12, 13, B, Vector3(0, 6, -28), 0, 45],
		"ultimate": ["beam_ultimate", "Umbral Rift", 30, 56, 30, 2500, 56, 12, 18, B, Vector3(0, 10, -38), 0, 0],
		"shape": {"blast_speed": 52.0, "blast_radius": 0.3, "charged_speed": 36.0, "charged_radius": 0.7,
			"beam_radius": 0.7, "beam_range": 55.0, "beam_speed": 140.0, "ultimate_radius": 1.15, "ultimate_range": 70.0,
			"color": Color(0.74, 0.42, 1.0)},
	},
	"brann": {
		"blast": ["ki_blast", "Ember Shot", 8, 1, 15, 150, 13, 9, 5, N, Vector3(0, 0, -4), 6, 4],
		"charged": ["charged_blast", "Slag Ball", 24, 1, 20, 820, 36, 20, 12, B, Vector3(0, 6, -22), 20, 20],
		"beam": ["beam", "Forgemaw", 30, 40, 30, 1800, 46, 12, 16, B, Vector3(0, 6, -32), 0, 60],
		"ultimate": ["beam_ultimate", "Magma Torrent", 38, 60, 34, 3100, 62, 12, 22, B, Vector3(0, 10, -42), 0, 0],
		"shape": {"blast_speed": 34.0, "blast_radius": 0.45, "charged_speed": 26.0, "charged_radius": 1.0,
			"beam_radius": 1.25, "beam_range": 34.0, "beam_speed": 90.0, "ultimate_radius": 1.7, "ultimate_range": 45.0,
			"color": Color(1.0, 0.34, 0.12)},
	},
	"lyra": {
		"blast": ["ki_blast", "Star Mote", 8, 1, 10, 110, 12, 8, 4, N, Vector3(0, 0, -3), 4, 4],
		"charged": ["charged_blast", "Nova Orb", 22, 1, 18, 700, 34, 18, 10, B, Vector3(0, 5, -20), 16, 20],
		"beam": ["beam", "Constellation Ray", 26, 44, 26, 1300, 42, 12, 14, B, Vector3(0, 6, -28), 0, 40],
		"ultimate": ["beam_ultimate", "Starfall Array", 34, 70, 32, 2700, 58, 12, 20, B, Vector3(0, 10, -40), 0, 0],
		"shape": {"blast_speed": 40.0, "blast_radius": 0.33, "blast_homing": 2.4, "charged_speed": 32.0,
			"charged_radius": 0.85, "beam_radius": 0.75, "beam_range": 62.0, "beam_speed": 130.0,
			"beam_split_angle": 0.21, "ultimate_radius": 1.25, "ultimate_range": 75.0,
			"color": Color(0.55, 0.82, 1.0)},
	},
}


func _initialize() -> void:
	for legend: String in KITS:
		var table: Dictionary = KITS[legend]
		var kit := KiKit.new()
		for slot in ["blast", "charged", "beam", "ultimate"]:
			kit.set(slot, _move(table[slot]))
		var shape: Dictionary = table.shape
		for key: String in shape:
			kit.set(key, shape[key])
		var path := "res://game/combat/ki/kits/%s_ki_kit.tres" % legend
		var error := ResourceSaver.save(kit, path)
		print("%s -> %s" % [path, error_string(error)])
	quit()


func _move(row: Array) -> MoveData:
	var move := MoveData.new()
	move.id = StringName(row[0])
	move.display_name = row[1]
	move.startup_ticks = row[2]
	move.active_ticks = row[3]
	move.recovery_ticks = row[4]
	move.damage = row[5]
	move.hitstun_ticks = row[6]
	move.blockstun_ticks = row[7]
	move.hitstop_ticks = row[8]
	move.knockback_type = row[9]
	move.knockback = row[10]
	move.guard_damage = row[11]
	move.ki_cost = row[12]
	move.cancel_level = MoveData.CancelLevel.ULTIMATE if row[0] == "beam_ultimate" else MoveData.CancelLevel.SPECIAL
	# Shots and beams carry no melee hitbox: the projectile or beam is the hitbox.
	move.resource_local_to_scene = false
	return move
