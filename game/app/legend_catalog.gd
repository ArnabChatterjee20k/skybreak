class_name LegendCatalog
extends RefCounted
## The playable legends for the menus, read from the Roster (and any roster
## entry dropped into its folder), with a title and 1-10 stat bars each.

const ROSTER_DIR := "res://game/characters/roster/"
## Menu order for the launch four; anything else follows alphabetically.
const ORDER: Array[StringName] = [&"kael", &"vexa", &"brann", &"lyra"]
## Titles and stat bars (power, speed, defense, range) from GAME_DESIGN §6.
## A roster entry with its own `title` or `stat_bars` property wins.
const PROFILES := {
	&"kael": {"title": "Sky-Knight Adventurer", "bars": [6, 6, 6, 6], "color": Color(1.0, 0.55, 0.15)},
	&"vexa": {"title": "Shadow Rogue", "bars": [4, 9, 4, 6], "color": Color(0.62, 0.32, 1.0)},
	&"brann": {"title": "Stone-Forged Blacksmith", "bars": [9, 3, 8, 4], "color": Color(0.9, 0.3, 0.15)},
	&"lyra": {"title": "Star-Cartographer Mage", "bars": [5, 5, 4, 9], "color": Color(0.3, 0.6, 1.0)},
}
const BAR_NAMES: Array[String] = ["Power", "Speed", "Defense", "Range"]
const DEFAULT_PROFILE := {"title": "Legend", "bars": [5, 5, 5, 5], "color": Color(0.95, 0.8, 0.2)}


## Every legend id, launch four first.
static func ids() -> Array[StringName]:
	var found: Array[StringName] = Roster.ids()
	var dir := DirAccess.open(ROSTER_DIR)
	if dir != null:
		for file in dir.get_files():
			var path: String = ROSTER_DIR + file.trim_suffix(".remap")
			if not path.ends_with(".tres"):
				continue
			var entry := load(path) as RosterCharacter
			if entry != null and entry.id != &"" and not found.has(entry.id):
				found.append(entry.id)
	var ordered: Array[StringName] = []
	for id in ORDER:
		if found.has(id):
			ordered.append(id)
	var rest: Array[StringName] = []
	for id in found:
		if not ordered.has(id):
			rest.append(id)
	rest.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	ordered.append_array(rest)
	return ordered


static func character(id: StringName) -> RosterCharacter:
	var entry := Roster.character(id)
	if entry != null:
		return entry
	var path := ROSTER_DIR + String(id) + ".tres"
	return load(path) as RosterCharacter if ResourceLoader.exists(path) else null


static func display_name(id: StringName) -> String:
	var entry := character(id)
	if entry != null and not entry.display_name.is_empty():
		return entry.display_name
	return String(id).capitalize()


static func title(id: StringName) -> String:
	var entry := character(id)
	var own: Variant = entry.get(&"title") if entry != null else null
	if own is String and not (own as String).is_empty():
		return own
	return PROFILES.get(id, DEFAULT_PROFILE).title


## Power, speed, defense, range on a 1-10 scale.
static func stat_bars(id: StringName) -> Array[int]:
	var entry := character(id)
	var own: Variant = entry.get(&"stat_bars") if entry != null else null
	var bars: Array[int] = []
	bars.assign(own if own is Array and (own as Array).size() == 4 else PROFILES.get(id, DEFAULT_PROFILE).bars)
	for i in bars.size():
		bars[i] = clampi(bars[i], 1, 10)
	return bars


static func color(id: StringName) -> Color:
	return PROFILES.get(id, DEFAULT_PROFILE).color
