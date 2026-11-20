class_name LookGrade
extends RefCounted
## The shared filmic grade (ART_BIBLE §10). Forward+ uses the Environment in world_map.tscn
## as is; the web renderer (gl_compatibility) draws lighting brighter and more saturated and
## crushes dark zones (Ember Rift goes black) under ACES, so it keeps the Filmic curve
## with a neutral adjustment and softer glow.

const COMPATIBILITY := "gl_compatibility"
## Compatibility: exposure gain on top of each zone's exposure, and the adjustments.
const COMPAT_EXPOSURE_GAIN := 1.0
const COMPAT_CONTRAST := 1.0
const COMPAT_SATURATION := 1.0
const COMPAT_GLOW_INTENSITY := 0.4


static func is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == COMPATIBILITY


## Exposure to set for a zone's exposure target on this renderer.
static func exposure(zone_exposure: float, compatibility: bool = is_compatibility()) -> float:
	return zone_exposure * (COMPAT_EXPOSURE_GAIN if compatibility else 1.0)


## Adapts the shared Environment to the renderer once, when the world is built.
static func apply(env: Environment, compatibility: bool = is_compatibility()) -> void:
	if not compatibility:
		return
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.0
	env.adjustment_contrast = COMPAT_CONTRAST
	env.adjustment_saturation = COMPAT_SATURATION
	env.glow_intensity = COMPAT_GLOW_INTENSITY
