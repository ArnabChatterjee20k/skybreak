class_name VfxCatalog
extends RefCounted
## Every T-D27 effect: how to build it, its pool size, and the prewarm set.

## Pool capacity per effect kind; pools never grow past it.
const CAPACITY := {
	&"anime_burst": 4, &"guard_shatter": 2, &"ko_burst": 1, &"lightning": 2,
	&"petals": 4, &"sparkles": 4, &"blast_impact": 6, &"aura_flare": 2,
	&"sonic_ring": 3, &"afterimage": 14, &"vanish_burst": 4, &"landing_dust": 4,
	&"ki_blast": 24, &"ki_beam": 6,
	&"smear_fist": 4, &"smear_gauntlets": 4, &"smear_blade": 4, &"smear_lance": 4,
	&"smear_hammer": 3, &"smear_chakram": 3, &"smear_scythe": 3,
}
## Effects built ahead of time per pool at match load.
const PREFILL := 2

const WARM := Color(1.0, 0.55, 0.15)
const RED := Color(1.0, 0.22, 0.2)
const PETAL := Color(1.0, 0.62, 0.78)
const STORM := Color(0.72, 0.8, 1.0)
## KO burst sprite sizes (m): the star stays inside the loser's body height, the ring a bit wider.
const KO_STAR := 1.4
const KO_RING := 1.5
## Power-up flare shell radii (m); it grows to 1.35x over its life.
const AURA_FLARE_SHELL := Vector3(0.75, 1.1, 0.75)


static func kinds() -> Array[StringName]:
	var found: Array[StringName] = []
	for kind: StringName in CAPACITY:
		found.append(kind)
	return found


## A new, idle effect of one kind.
static func build(kind: StringName) -> VfxEffect:
	var effect: VfxEffect
	if kind == &"ki_blast":
		effect = KiBlastEffect.new()
	elif kind == &"ki_beam":
		effect = KiBeamEffect.new()
	else:
		effect = VfxEffect.new()
		_fill(effect, kind)
	effect.name = String(kind)
	return effect


static func _fill(effect: VfxEffect, kind: StringName) -> void:
	match kind:
		&"anime_burst":
			# Counter-hit accent: thin rays and sparks around the contact, no solid core or ring.
			effect.lifetime = 0.16
			effect.default_color = WARM
			effect.add_sprite(&"spikes", 1.1)
			effect.add_particles(&"spark", &"burst", 8, 0.15, Vector2(0.05, 0.4))
		&"guard_shatter":
			effect.lifetime = 0.5
			effect.default_color = RED
			var shards := effect.add_particles(&"chunk", &"shards", 12, 0.5, Vector2(0.14, 0.14))
			effect.make_secondary(shards)
		&"ko_burst":
			# The KO's one beat at the contact: a star and one ring, about a body wide.
			effect.lifetime = 0.25
			effect.default_color = Color(1.0, 0.9, 0.7)
			effect.add_sprite(&"spikes", KO_STAR)
			effect.add_sprite(&"ring", KO_RING)
		&"lightning":
			effect.lifetime = 0.65
			effect.default_color = STORM
			for i in 3:
				var bolt := effect.add_mesh(&"bolt", VfxKit.quad(Vector2(3.0, 42.0)))
				bolt.position = Vector3((i - 1) * 1.4, 21.0, (i - 1) * 0.4)
				bolt.rotation = Vector3(0.0, 0.0, (i - 1) * 0.06)
			effect.add_sprite(&"flash", 7.0)
			var ground := effect.add_mesh(&"flat_ring", VfxKit.quad(Vector2(10, 10)))
			ground.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
		&"petals":
			effect.lifetime = 1.5
			effect.default_color = PETAL
			effect.add_particles(&"petal", &"drift", 24, 1.4, Vector2(0.42, 0.42))
		&"sparkles":
			effect.lifetime = 0.8
			effect.default_color = Color(1.0, 0.86, 0.95)
			effect.add_particles(&"sparkle", &"twinkle", 12, 0.75, Vector2(0.8, 0.8))
		&"blast_impact":
			effect.lifetime = 0.45
			effect.default_color = WARM
			effect.add_sprite(&"flash", 2.4)
			effect.add_sprite(&"ring", 2.8)
			effect.add_sprite(&"spikes", 2.2)
			effect.add_particles(&"spark", &"burst", 14, 0.35, Vector2(0.08, 0.6))
		&"aura_flare":
			effect.lifetime = 0.6
			effect.default_color = WARM
			# About the fighter's own size (ART_BIBLE §7), so the caster still reads through it.
			var shell := effect.add_mesh(&"flare", VfxKit.sphere())
			shell.scale = AURA_FLARE_SHELL
			var floor_ring := effect.add_mesh(&"flat_ring", VfxKit.quad(Vector2(3.2, 3.2)))
			floor_ring.position = Vector3(0.0, -0.95, 0.0)
			floor_ring.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
			effect.add_particles(&"streak", &"rise", 22, 0.5, Vector2(0.1, 0.9))
			effect.add_particles(&"mote", &"rise", 16, 0.55, Vector2(0.18, 0.18))
		&"sonic_ring":
			effect.lifetime = 0.45
			effect.default_color = Color(0.9, 0.95, 1.0)
			effect.add_mesh(&"flat_ring", VfxKit.quad(Vector2(5.5, 5.5)))
			var inner := effect.add_mesh(&"flat_ring", VfxKit.quad(Vector2(3.2, 3.2)))
			inner.position = Vector3(0.0, 0.0, -1.2)
			effect.add_sprite(&"flash", 1.6)
		&"afterimage":
			effect.lifetime = 0.28
			effect.default_color = WARM
			effect.add_mesh(&"shell", VfxKit.capsule())
		&"vanish_burst":
			effect.lifetime = 0.35
			effect.default_color = Color(0.9, 0.95, 1.0)
			effect.add_sprite(&"spikes", 2.6)
			effect.add_sprite(&"ring", 2.4)
			effect.add_particles(&"spark", &"burst", 10, 0.25, Vector2(0.06, 0.7))
		&"landing_dust":
			effect.lifetime = 0.9
			effect.default_color = Color(0.75, 0.7, 0.62)
			effect.add_particles(&"dust", &"puff", 10, 0.85, Vector2(1.1, 1.1))
			var chunks := effect.add_particles(&"chunk", &"debris", 8, 0.8, Vector2(0.24, 0.24))
			effect.make_secondary(chunks)
			var ring := effect.add_mesh(&"flat_ring", VfxKit.quad(Vector2(4.0, 4.0)))
			ring.position = Vector3(0.0, 0.05, 0.0)
			ring.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
			effect.make_secondary(ring)
		_:
			var style := StringName(String(kind).trim_prefix("smear_"))
			effect.lifetime = 0.32 if style == &"hammer" else 0.24
			effect.default_color = WARM
			effect.add_mesh(&"smear", VfxKit.smear(style))


## Adds one playing effect of every kind under parent at origin, plus the screen
## overlays at full strength, so every pipeline compiles. Returns what it added.
static func build_prewarm(parent: Node, origin: Vector3) -> Array[Node]:
	var added: Array[Node] = []
	for kind in kinds():
		var effect := build(kind)
		parent.add_child(effect)
		if effect is KiBeamEffect:
			(effect as KiBeamEffect).fire(origin, origin + Vector3(0, 0, -4), WARM, 0.0, 0.3, true)
		elif effect is KiBlastEffect:
			(effect as KiBlastEffect).launch(origin, Vector3(0, 0, -1), WARM, 0.2)
		else:
			effect.play_at(origin)
		added.append(effect)
	var screen := VfxScreen.new()
	parent.add_child(screen)
	screen.show_all()
	added.append(screen)
	return added
