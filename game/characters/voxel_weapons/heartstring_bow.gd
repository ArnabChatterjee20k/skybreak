extends "res://game/characters/voxel_weapons/lyra_ki_bow.gd"
## The Heartstring Bow (Heartbloom Gardens pickup, docs/lookdev/weapons.md):
## Lyra's recurve build in the item gold family with Heartbloom pink: rose
## lacquered limbs, gold edge strips, pink-white heart lights, a heart medallion.


func kind() -> Weapon.Kind:
	return Weapon.Kind.HEARTSTRING_BOW


func palette() -> Dictionary:
	return {
		Mat.WOOD: Color("#c24a78"), Mat.BODY_DARK: Color("#7e2a4c"),
		Mat.TRIM: Color("#d9a441"), Mat.TRIM_DARK: Color("#8c6020"), Mat.EDGE: Color("#f0cd78"),
		Mat.RIVET: Color("#f0cd78"), Mat.ENGRAVE: Color("#5a3a12"), Mat.EMBLEM: Color("#ffd9ec"),
		Mat.GRIP: Color("#6e2a40"), Mat.GRIP_DARK: Color("#3e1424"), Mat.LEATHER: Color("#6e2a40"),
		Mat.ACCENT: Color("#ffb3d1"), Mat.CLOTH: Color("#fff0f6"), Mat.CLOTH_DARK: Color("#e7b9cc"),
		Mat.STITCH: Color("#6e2a40"),
		Mat.GLOW: Color("#ff80bf"), Mat.GLOW_CORE: Color("#ffe8f3"),
	}


func emblem() -> Callable:
	return heart
