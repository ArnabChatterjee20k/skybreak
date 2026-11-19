class_name GraphicsSettings
extends RefCounted
## Player-chosen graphics quality, saved to user://settings.cfg and applied to
## a viewport. Presets stay inside the GTX 1650 budget: high is the 1080p60 target.

enum Quality { LOW, MEDIUM, HIGH }

const SAVE_PATH := "user://settings.cfg"
const SECTION := "graphics"
const MIN_RESOLUTION_SCALE := 0.5
const MAX_RESOLUTION_SCALE := 1.0
## Windowed mode size, shrunk (keeping 16:9) to fit the usable screen area.
const WINDOWED_SIZE := Vector2i(1600, 900)

## Per-quality values. Shadow sizes are in pixels.
const QUALITY_VALUES := {
	Quality.LOW: {
		"msaa_3d": Viewport.MSAA_DISABLED,
		"screen_space_aa": Viewport.SCREEN_SPACE_AA_FXAA,
		"directional_shadow_size": 1024,
		"mesh_lod_threshold": 4.0,
	},
	Quality.MEDIUM: {
		"msaa_3d": Viewport.MSAA_2X,
		"screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED,
		"directional_shadow_size": 2048,
		"mesh_lod_threshold": 2.0,
	},
	Quality.HIGH: {
		"msaa_3d": Viewport.MSAA_4X,
		"screen_space_aa": Viewport.SCREEN_SPACE_AA_DISABLED,
		"directional_shadow_size": 4096,
		"mesh_lod_threshold": 1.0,
	},
}

var quality: Quality = Quality.HIGH
## Fraction of the window resolution the 3D scene renders at, then upscaled.
var resolution_scale: float = 1.0:
	set(value):
		resolution_scale = clampf(value, MIN_RESOLUTION_SCALE, MAX_RESOLUTION_SCALE)
var vsync_enabled: bool = true
## Borderless fullscreen at the desktop resolution; false = centred window.
var fullscreen: bool = true


func apply_to(viewport: Viewport) -> void:
	var values: Dictionary = QUALITY_VALUES[quality]
	viewport.msaa_3d = values.msaa_3d
	viewport.screen_space_aa = values.screen_space_aa
	viewport.mesh_lod_threshold = values.mesh_lod_threshold
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = resolution_scale
	RenderingServer.directional_shadow_atlas_set_size(values.directional_shadow_size, true)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
		_apply_window_mode()


## Centred windowed rect that fits inside the usable screen area (taskbar excluded).
static func windowed_rect(usable: Rect2i) -> Rect2i:
	var fit := minf(1.0, minf(
		float(usable.size.x) / WINDOWED_SIZE.x, float(usable.size.y) / WINDOWED_SIZE.y))
	var size := Vector2i((Vector2(WINDOWED_SIZE) * fit).floor())
	return Rect2i(usable.position + (usable.size - size) / 2, size)


func save(path: String = SAVE_PATH) -> Error:
	var config := ConfigFile.new()
	config.load(path)  # Keep other sections; a missing file is fine.
	config.set_value(SECTION, "quality", quality)
	config.set_value(SECTION, "resolution_scale", resolution_scale)
	config.set_value(SECTION, "vsync_enabled", vsync_enabled)
	config.set_value(SECTION, "fullscreen", fullscreen)
	return config.save(path)


## Loads saved settings; anything missing or invalid keeps its default.
static func load_saved(path: String = SAVE_PATH) -> GraphicsSettings:
	var settings := GraphicsSettings.new()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return settings
	var saved_quality: int = config.get_value(SECTION, "quality", settings.quality)
	if QUALITY_VALUES.has(saved_quality):
		settings.quality = saved_quality as Quality
	settings.resolution_scale = config.get_value(SECTION, "resolution_scale", settings.resolution_scale)
	settings.vsync_enabled = config.get_value(SECTION, "vsync_enabled", settings.vsync_enabled)
	settings.fullscreen = config.get_value(SECTION, "fullscreen", settings.fullscreen)
	return settings


## Switches window mode only when it differs, so repeated applies don't flicker.
func _apply_window_mode() -> void:
	var mode := DisplayServer.window_get_mode()
	if fullscreen:
		if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var screen := DisplayServer.window_get_current_screen()
	var rect := windowed_rect(DisplayServer.screen_get_usable_rect(screen))
	DisplayServer.window_set_size(rect.size)
	DisplayServer.window_set_position(rect.position)
