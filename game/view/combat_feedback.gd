class_name CombatFeedback
extends Node3D
## Turns CombatSim.events into visual feedback: hit sparks, block flashes,
## guard-break shards, shockwaves, impact frames and camera shake. View only;
## audio reads the same events through its own mapper (game/audio, T-D20).
## The arena calls react() once per sim tick, right after sim.tick().

const E := CombatSim.EventType
const SPARK_LIGHT := preload("res://game/view/shaders/vfx/hit_spark_light.tscn")
const SPARK_HEAVY := preload("res://game/view/shaders/vfx/hit_spark_heavy.tscn")
const COUNTER := preload("res://game/view/shaders/vfx/counter_hit.tscn")
const PERFECT_BLOCK := preload("res://game/view/shaders/vfx/perfect_block_flash.tscn")
const GUARD_BREAK := preload("res://game/view/shaders/vfx/guard_break_shatter.tscn")
const SHOCKWAVE := preload("res://game/view/shaders/vfx/shockwave.tscn")

## Hits with at least this much hitstop (ticks) read as heavy.
const HEAVY_HITSTOP := 7
const BLOCK_COLOR := Color(0.65, 0.85, 1.0)
const ARMOR_COLOR := Color(0.75, 0.75, 0.8)
## Floor impacts of a knocked-out fighter (KO bounce and rest).
const DUST_COLOR := Color(0.8, 0.72, 0.6)
## Weapon events use the gold item colour (GAME_DESIGN §5.11); the weapon layer draws the rest.
const ITEM_COLOR := Color(1.0, 0.8, 0.3)

## Set by the arena.
var camera: FighterCamera
var impact_frame: ImpactFrame


## Spawns the feedback for one tick's events.
func react(events: Array[Dictionary]) -> void:
	for event in events:
		var plan := plan_for(event)
		for scene: PackedScene in plan.effects:
			var effect := scene.instantiate() as Node3D
			add_child(effect)
			effect.global_position = event.get("position", Vector3.ZERO)
			effect.play(plan.color, plan.scale)
		if camera != null and plan.shake > 0.0:
			camera.shake(plan.shake)
		if impact_frame != null and plan.impact_frames > 0:
			impact_frame.flash(plan.impact_frames)


## What one event shows: effects (scenes), color (transparent = the effect's
## own), scale, shake (camera trauma 0-1) and impact_frames (inverted frames).
static func plan_for(event: Dictionary) -> Dictionary:
	var plan := {"effects": [], "color": Color.TRANSPARENT, "scale": 1.0, "shake": 0.0, "impact_frames": 0}
	var heavy: bool = event.get("hitstop", 0) >= HEAVY_HITSTOP
	match event.get("type", -1):
		E.HIT, E.THROW:
			plan.effects = [SPARK_HEAVY if heavy else SPARK_LIGHT]
			plan.shake = 0.35 if heavy else 0.12
		E.COUNTER:
			plan.effects = [COUNTER, SPARK_HEAVY if heavy else SPARK_LIGHT]
			plan.shake = 0.45
		E.ARMOR:
			plan.effects = [SPARK_LIGHT]
			plan.color = ARMOR_COLOR
			plan.scale = 0.8
		E.BLOCK:
			plan.effects = [SPARK_LIGHT]
			plan.color = BLOCK_COLOR
			plan.scale = 0.7
		E.PERFECT_BLOCK:
			plan.effects = [PERFECT_BLOCK]
			plan.shake = 0.15
		E.GUARD_BREAK:
			plan.effects = [GUARD_BREAK]
			plan.shake = 0.6
			plan.impact_frames = 2
		E.KO:
			plan.effects = [SPARK_HEAVY, SHOCKWAVE]
			plan.shake = 0.9
			plan.impact_frames = 3
		E.PUSH_BLOCK:
			plan.effects = [SHOCKWAVE]
			plan.color = BLOCK_COLOR
			plan.scale = 0.5
			plan.shake = 0.1
		E.GRAB, E.GRAB_TECH:
			plan.effects = [SPARK_LIGHT]
			plan.scale = 0.6
		E.KO_BOUNCE:
			plan.effects = [SHOCKWAVE]
			plan.color = DUST_COLOR
			plan.scale = 0.6
			plan.shake = 0.25
		E.KO_REST:
			plan.effects = [SHOCKWAVE]
			plan.color = DUST_COLOR
			plan.scale = 0.35
			plan.shake = 0.08
		E.PICKUP_SPAWN, E.PICKUP, E.PICKUP_DESPAWN, E.WEAPON_SWITCH, E.WEAPON_THROW, \
				E.WEAPON_DROP, E.FIRE, E.PROJECTILE_HIT:
			plan.effects = [SPARK_LIGHT]
			plan.color = ITEM_COLOR
			plan.scale = 0.4
		E.GADGET_EXPLODE, E.MINE_TRIGGER:
			plan.effects = [SHOCKWAVE]
			plan.color = ITEM_COLOR
			plan.shake = 0.25 if event.type == E.GADGET_EXPLODE else 0.08
		E.POWER_PICKUP, E.POWER_END, E.AEGIS_BREAK, E.GADGET_THROW, E.DECOY_POP, E.GADGET_END, \
				E.BOW_DRAW, E.ARROW_PIN, E.TETHER, E.TETHER_YANK, E.TETHER_END, E.OVERHEAT, \
				E.BULLET_ABSORB, E.SWAP_CANCEL, E.DISC_CATCH:
			# T-D26 items and weapon extras: small gold sparks.
			plan.effects = [SPARK_LIGHT]
			plan.color = ITEM_COLOR
			plan.scale = 0.5 if event.type in [E.AEGIS_BREAK, E.ARROW_PIN, E.TETHER_YANK] else 0.35
	return plan
