class_name EngagementBand
extends RefCounted
## Each legend's preferred fighting distance (planar metres, [near, far]): Brann
## close, Vexa close/mid, Kael mid, Lyra mid/far. The AI spaces inside its band.

const BANDS := {
	&"brann": Vector2(2.6, 3.8),
	&"vexa": Vector2(3.0, 4.6),
	&"kael": Vector2(3.6, 5.0),
	&"lyra": Vector2(4.6, 6.6),
}
## Stats resource of each legend, to tell which legend a sim fighter is.
const STATS := {
	&"kael": "res://game/combat/default_fighter_stats.tres",
	&"vexa": "res://game/combat/vexa_fighter_stats.tres",
	&"brann": "res://game/combat/moves/brann/brann_fighter_stats.tres",
	&"lyra": "res://game/combat/moves/lyra/lyra_fighter_stats.tres",
}


## The band for legend, Kael's for an unknown one.
static func for_legend(legend: StringName) -> Vector2:
	return BANDS.get(legend, BANDS[&"kael"])


## The legend whose stats these are, or Kael's id when unknown.
static func legend_of(stats: FighterStats) -> StringName:
	if stats != null:
		for legend: StringName in STATS:
			if stats.resource_path == STATS[legend]:
				return legend
	return &"kael"


## Fighter stats of legend (Kael's for an unknown one).
static func stats_for(legend: StringName) -> FighterStats:
	return load(STATS.get(legend, STATS[&"kael"])) as FighterStats
