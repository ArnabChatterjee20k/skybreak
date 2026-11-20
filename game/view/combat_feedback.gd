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
const READ_POP := preload("res://game/view/shaders/vfx/read_pop.tscn")
## Perfect dodge flash: white-blue (T-DEF2).
const PERFECT_DODGE_COLOR := Color(0.75, 0.9, 1.0)
## Special tells (T-SP1): a neutral white-violet puff under the legend's own colour from SpecialVfx.
const SPECIAL_COLOR := Color(0.85, 0.8, 1.0)
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
## Ki blast and beam events (T-KI1).
const KI_COLOR := Color(0.95, 0.97, 1.0)
## Most one-shot sparks alive at once; past it, minor sparks are skipped.
const MAX_LIVE_SPARKS := 6

## Set by the arena.
var camera: FighterCamera
## Unused for hits: the rationed, partial impact moment lives in MatchVfx (ImpactFrameGate).
var impact_frame: ImpactFrame
## Pooled T-D27 effects (smears, afterimages, KO finisher, zone extras); same events.
var vfx := MatchVfx.new()


func _ready() -> void:
	# Internal, so the feedback's own children stay just the one-shot sparks.
	add_child(vfx, false, Node.INTERNAL_MODE_FRONT)


## Spawns the feedback for one tick's events.
func react(events: Array[Dictionary]) -> void:
	if vfx.is_inside_tree():
		vfx.react(events)
	var sim := vfx.sim
	var size := vfx.crowd_scale()
	for event in events:
		var plan := plan_for(event)
		var where: Vector3 = event.get("position", Vector3.ZERO)
		if sim != null:
			where = MatchVfx.spark_point(event, sim.fighters)
		var minor: bool = plan.scale < 1.0 and plan.shake < 0.3
		for scene: PackedScene in plan.effects:
			if minor and live_sparks() >= MAX_LIVE_SPARKS:
				continue
			var effect := scene.instantiate() as Node3D
			add_child(effect)
			effect.global_position = where
			effect.play(plan.color, plan.scale * size)
		if camera != null and plan.shake > 0.0:
			camera.shake(plan.shake)


## One-shot sparks still playing.
func live_sparks() -> int:
	var count := 0
	for child in get_children():
		if child is ImpactEffect and not child.is_queued_for_deletion():
			count += 1
	return count



## What one event shows: effects (scenes), color (transparent = the effect's
## own), scale and shake (camera trauma 0-1). Screen-wide impact frames are
## MatchVfx's, rationed by ImpactFrameGate, so impact_frames stays 0 here.
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
		E.DODGE:
			# A small air puff where the dodge pushes off; the afterimage trail is MatchVfx's.
			plan.effects = [SHOCKWAVE]
			plan.color = DUST_COLOR
			plan.scale = 0.3
		E.PERFECT_DODGE:
			plan.effects = [PERFECT_BLOCK, READ_POP]
			plan.color = PERFECT_DODGE_COLOR
			plan.shake = 0.1
		E.SPECIAL_START, E.SPECIAL_BLINK, E.DECOY_SPAWN, E.DECOY_FADE:
			# A small puff; the coloured flare, trail and decoy ghost are SpecialVfx's.
			plan.effects = [SHOCKWAVE]
			plan.color = SPECIAL_COLOR
			plan.scale = 0.35
		E.SPECIAL_DENIED:
			plan.effects = [SPARK_LIGHT]
			plan.color = ARMOR_COLOR
			plan.scale = 0.3
		E.SPECIAL_COUNTER:
			plan.effects = [PERFECT_BLOCK, READ_POP]
			plan.shake = 0.2
		E.DECOY_BURST:
			plan.effects = [SHOCKWAVE]
			plan.scale = 0.8
			plan.shake = 0.3
		E.GUARD_BREAK:
			plan.effects = [GUARD_BREAK]
			plan.shake = 0.6
		E.KO:
			plan.effects = [SPARK_HEAVY]
			plan.shake = 0.9
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
		E.KI_FIRE, E.KI_CHARGE, E.KI_ABSORB, E.BEAM_END, E.CLASH_BEAT:
			# Ki (T-KI1): small white sparks; KiLayer draws the shots, beams and their flashes.
			plan.effects = [SPARK_LIGHT]
			plan.color = KI_COLOR
			plan.scale = 0.3
		E.BEAM_START, E.BEAM_FIRE:
			plan.effects = [SHOCKWAVE]
			plan.color = KI_COLOR
			plan.scale = 0.5 if event.type == E.BEAM_START else 0.8
			plan.shake = 0.0 if event.type == E.BEAM_START else 0.15
		E.BEAM_CLASH, E.CLASH_END:
			plan.effects = [SHOCKWAVE]
			plan.color = KI_COLOR
			plan.scale = 1.4
			plan.shake = 0.35 if event.type == E.BEAM_CLASH else 0.45
	if event.get("type", -1) == E.PROJECTILE_HIT and event.get("weapon", -1) == Weapon.Kind.NONE:
		plan.color = KI_COLOR # A ki shot, not an item.
	return plan
