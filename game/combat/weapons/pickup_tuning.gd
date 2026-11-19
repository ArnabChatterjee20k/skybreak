class_name PickupTuning
extends Resource
## Weapon spawner constants and the per-zone spawn tables. Configuration, so
## not in the state hash. Distances in metres, durations in ticks.

## Ticks from match start to the first drop.
@export var first_spawn_ticks: int = 120
## Ticks between drops, picked by the sim rng in this range (12-18 s).
@export var spawn_interval_min_ticks: int = 720
@export var spawn_interval_max_ticks: int = 1080
## Planar distance of a drop from the fighters' midpoint.
@export var spawn_distance_min: float = 25.0
@export var spawn_distance_max: float = 60.0
## At most this many spawned pickups on the map at once.
@export var max_pickups: int = 3
## Light-pillar telegraph before the drop starts falling (2 s).
@export var telegraph_ticks: int = 120
## Height above the floor the drop falls from.
@export var drop_height: float = 40.0
@export var drop_gravity: float = 40.0
@export var drop_max_speed: float = 45.0
## Height of a resting pickup's centre above the floor.
@export var rest_height: float = 0.6
## A spawned pickup despawns this long after it spawns (30 s); a dropped one after 10 s.
@export var spawn_lifetime_ticks: int = 1800
@export var dropped_lifetime_ticks: int = 600
## G picks up within this distance (fighter centre to pickup centre).
@export var pickup_reach: float = 2.5
## Next/previous weapon switch: no attacks for this long.
@export var switch_lockout_ticks: int = 6
## Smitten (Heartstring Bow): duration, drift speed toward the shooter, and the
## window in which a repeat lasts half as long.
@export var smitten_ticks: int = 90
@export var smitten_drift_speed: float = 4.0
@export var smitten_repeat_window_ticks: int = 360
## Powers and gadgets alternate with weapons in the sky drops (T-D26); off drops weapons only.
@export var powers_enabled: bool = true
## Power kind -> weight for power drops.
@export var power_table: Dictionary = {
	Power.Kind.OVERDRIVE_ORB: 10, Power.Kind.BURST_SHARD: 8, Power.Kind.AEGIS: 10,
	Power.Kind.HASTE: 10, Power.Kind.SPIKE_BOMB: 10, Power.Kind.GRAVITY_MINE: 8,
	Power.Kind.MIRROR_DECOY: 8,
}
## Weapon kind -> weight, per zone. Zones not listed use the default table.
@export var default_table: Dictionary = {
	Weapon.Kind.KI_GAUNTLETS: 10, Weapon.Kind.STORM_BLADE: 10, Weapon.Kind.SKY_LANCE: 10,
	Weapon.Kind.TITAN_HAMMER: 10, Weapon.Kind.ORBIT_CHAKRAM: 10, Weapon.Kind.EMBER_SCYTHE: 10,
	Weapon.Kind.KI_BOW: 10, Weapon.Kind.ARC_REVOLVER: 10, Weapon.Kind.STORM_REPEATER: 10,
	Weapon.Kind.SCATTER_CANNON: 10,
}
@export var zone_tables: Dictionary = {
	&"shattered_mesa": {
		Weapon.Kind.KI_BOW: 16, Weapon.Kind.ARC_REVOLVER: 14, Weapon.Kind.SKY_LANCE: 12,
		Weapon.Kind.STORM_REPEATER: 10, Weapon.Kind.STORM_BLADE: 8, Weapon.Kind.ORBIT_CHAKRAM: 8,
		Weapon.Kind.SCATTER_CANNON: 6, Weapon.Kind.KI_GAUNTLETS: 6, Weapon.Kind.TITAN_HAMMER: 6,
		Weapon.Kind.EMBER_SCYTHE: 6,
	},
	&"skyhold_ruins": {
		Weapon.Kind.KI_GAUNTLETS: 14, Weapon.Kind.STORM_BLADE: 12, Weapon.Kind.SCATTER_CANNON: 12,
		Weapon.Kind.TITAN_HAMMER: 10, Weapon.Kind.EMBER_SCYTHE: 10, Weapon.Kind.SKY_LANCE: 8,
		Weapon.Kind.ORBIT_CHAKRAM: 8, Weapon.Kind.ARC_REVOLVER: 8, Weapon.Kind.KI_BOW: 6,
		Weapon.Kind.STORM_REPEATER: 6,
	},
	&"ember_rift": {
		Weapon.Kind.EMBER_SCYTHE: 16, Weapon.Kind.TITAN_HAMMER: 14, Weapon.Kind.SCATTER_CANNON: 10,
		Weapon.Kind.STORM_BLADE: 10, Weapon.Kind.KI_GAUNTLETS: 8, Weapon.Kind.SKY_LANCE: 8,
		Weapon.Kind.ORBIT_CHAKRAM: 8, Weapon.Kind.ARC_REVOLVER: 8, Weapon.Kind.KI_BOW: 6,
		Weapon.Kind.STORM_REPEATER: 6,
	},
	&"heartbloom_gardens": {
		Weapon.Kind.HEARTSTRING_BOW: 20, Weapon.Kind.KI_BOW: 10, Weapon.Kind.ORBIT_CHAKRAM: 10,
		Weapon.Kind.STORM_BLADE: 10, Weapon.Kind.SKY_LANCE: 8, Weapon.Kind.KI_GAUNTLETS: 8,
		Weapon.Kind.ARC_REVOLVER: 8, Weapon.Kind.EMBER_SCYTHE: 6, Weapon.Kind.TITAN_HAMMER: 6,
		Weapon.Kind.STORM_REPEATER: 6, Weapon.Kind.SCATTER_CANNON: 6,
	},
}


## The spawn table (kind -> weight) for a zone id.
func table_for(zone: StringName) -> Dictionary:
	return zone_tables.get(zone, default_table)
