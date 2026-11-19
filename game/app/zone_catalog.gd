class_name ZoneCatalog
extends RefCounted
## The seven fighting zones for zone select: name, tagline, card art and colours.

## Card art: copies of the T-D12 flythrough renders (that folder is not imported).
const ART_DIR := "res://game/ui/menus/zone_cards/"
const ROMANTIC_ZONE := &"heartbloom_gardens"
const TAGLINES := {
	&"stormfall_city": "Neon rooftops under an endless storm",
	&"verdant_falls": "Cliffs, mist and roaring waterfalls",
	&"frozen_peaks": "Ice spires above the clouds",
	&"skyhold_ruins": "A fallen sky-fortress, still floating",
	&"ember_rift": "Lava rivers through a split canyon",
	&"shattered_mesa": "Red rock pillars and desert wind",
	&"heartbloom_gardens": "Blossom isles where hearts take flight",
}


static func ids() -> Array[StringName]:
	return ZoneLayout.ZONE_IDS.duplicate()


static func zone(id: StringName) -> ZoneData:
	var path := ZoneLayout.ZONE_DIR + String(id) + ".tres"
	return load(path) as ZoneData if ResourceLoader.exists(path) else null


static func display_name(id: StringName) -> String:
	var data := zone(id)
	return data.display_name if data != null else String(id).capitalize()


static func tagline(id: StringName) -> String:
	return TAGLINES.get(id, "")


## The preview render for the card, or null.
static func art(id: StringName) -> Texture2D:
	var path := ART_DIR + String(id) + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Sky top and horizon at dusk, for card gradients.
static func colors(id: StringName) -> PackedColorArray:
	var data := zone(id)
	if data == null:
		return PackedColorArray([Color(0.2, 0.3, 0.6), Color(0.8, 0.6, 0.5)])
	return PackedColorArray([data.sky_top_colors[1], data.sky_horizon_colors[1]])
