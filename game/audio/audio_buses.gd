class_name AudioBuses
extends RefCounted
## Bus names shared by sound effects and music. The layout itself is
## default_bus_layout.tres; ensure() rebuilds it when a test or tool runs without it.

const MASTER := &"Master"
const MUSIC := &"Music"
const SFX := &"SFX"
const AMBIENCE := &"Ambience"
const UI := &"UI"
const VOICE := &"Voice"
const ALL: Array[StringName] = [MASTER, MUSIC, SFX, AMBIENCE, UI, VOICE]
## The Master limiter ceiling (dB).
const LIMITER_CEILING_DB := -1.0


## Adds any missing bus, sent to Master, and a limiter on Master if it has none.
static func ensure() -> void:
	for bus in ALL:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, MASTER)
	var master := AudioServer.get_bus_index(MASTER)
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMITER_CEILING_DB
	AudioServer.add_bus_effect(master, limiter)
