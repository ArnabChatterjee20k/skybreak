class_name AudioSettings
extends RefCounted
## Player volume per bus (linear 0..1), saved next to the graphics settings in
## user://settings.cfg under [audio].

const SAVE_PATH := "user://settings.cfg"
const SECTION := "audio"
const DEFAULT_VOLUME := 1.0

## Bus name -> linear volume 0..1.
var volumes: Dictionary = {}


func _init() -> void:
	for bus in AudioBuses.ALL:
		volumes[bus] = DEFAULT_VOLUME


func volume(bus: StringName) -> float:
	return volumes.get(bus, DEFAULT_VOLUME)


func set_volume(bus: StringName, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)


## Bus volume in dB for a linear setting; 0 is silent.
func volume_db(bus: StringName) -> float:
	var linear := volume(bus)
	return -80.0 if linear <= 0.0001 else linear_to_db(linear)


func save(path: String = SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	config.load(path)  # Keep other sections; a missing file is fine.
	for bus: StringName in volumes:
		config.set_value(SECTION, String(bus).to_lower(), volumes[bus])
	return config.save(path)


static func load_saved(path: String = SAVE_PATH) -> AudioSettings:
	var settings := AudioSettings.new()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return settings
	for bus in AudioBuses.ALL:
		settings.set_volume(bus, float(config.get_value(SECTION, String(bus).to_lower(), DEFAULT_VOLUME)))
	return settings
