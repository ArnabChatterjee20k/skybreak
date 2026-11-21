class_name ArtStyle
extends RefCounted
## Which art the view draws: the voxel look (default) or the classic models and
## zones. View-only: the sim never reads it. Saved with the graphics settings.

enum Kind { VOXEL, CLASSIC }

const NAMES := {Kind.VOXEL: "Voxel", Kind.CLASSIC: "Classic"}

## -1 until first read, then the saved choice (or one set_current made).
static var _current := -1


## The style views should draw now.
static func current() -> Kind:
	if _current < 0:
		_current = GraphicsSettings.load_saved().art_style
	return _current as Kind


static func is_voxel() -> bool:
	return current() == Kind.VOXEL


## Switches the style for views built from now on (levels and menus build their
## models when they open).
static func set_current(kind: Kind) -> void:
	_current = kind


## Forgets the in-memory choice, so the next read loads the saved one.
static func reset() -> void:
	_current = -1
