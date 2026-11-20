class_name HintSettings
extends RefCounted
## Whether the in-match control hints show, saved in user://settings.cfg under
## [hints]: on for the first FIRST_MATCHES matches, then off, unless the player
## toggled them with H, which is remembered from then on.

const SAVE_PATH := "user://settings.cfg"
const SECTION := "hints"
const FIRST_MATCHES := 5

## Matches started with hints available.
var matches_played := 0
## The player pressed H at least once; `shown` is then their choice.
var chosen := false
var shown := true


## Whether hints show at the start of a match.
func shows_by_default() -> bool:
	return shown if chosen else matches_played < FIRST_MATCHES


func choose(show: bool) -> void:
	chosen = true
	shown = show


func save(path: String = SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	config.load(path)  # Keep other sections; a missing file is fine.
	config.set_value(SECTION, "matches_played", matches_played)
	config.set_value(SECTION, "chosen", chosen)
	config.set_value(SECTION, "shown", shown)
	return config.save(path)


static func load_saved(path: String = SAVE_PATH) -> HintSettings:
	var settings := HintSettings.new()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return settings
	settings.matches_played = int(config.get_value(SECTION, "matches_played", 0))
	settings.chosen = bool(config.get_value(SECTION, "chosen", false))
	settings.shown = bool(config.get_value(SECTION, "shown", true))
	return settings
