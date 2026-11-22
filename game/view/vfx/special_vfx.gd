class_name SpecialVfx
extends RefCounted
## Specials and legend mechanics on screen (T-SP1), crisp and flat per ART_BIBLE:
## a coloured flare on the tell, an afterimage trail while a special travels, a
## violet ghost standing where Vexa's decoy waits, and a burst when it pops. View only.

## Ticks between trail ghosts while a special travels, and between decoy ghost refreshes.
const TRAIL_EVERY := 3
const DECOY_EVERY := 6
const COUNTER_COLOR := Color(0.85, 0.95, 1.0)

var _tick: int = 0


## What one special event shows: [[effect kind, scale], ...] and a colour (TRANSPARENT = the fighter's).
static func plan_for(event: Dictionary, kit: SpecialKit) -> Dictionary:
	var color := kit.color if kit else Color.TRANSPARENT
	var plan := {"effects": [], "color": color}
	match event.get("type", -1):
		CombatSim.EventType.SPECIAL_START:
			plan.effects = [[&"aura_flare", 0.7]]
		CombatSim.EventType.SPECIAL_COUNTER:
			plan.effects = [[&"anime_burst", 1.0], [&"sonic_ring", 1.0]]
			plan.color = COUNTER_COLOR
		CombatSim.EventType.SPECIAL_BLINK:
			plan.effects = [[&"vanish_burst", 0.9]]
		CombatSim.EventType.DECOY_SPAWN:
			plan.effects = [[&"vanish_burst", 0.6]]
		CombatSim.EventType.DECOY_BURST:
			plan.effects = [[&"blast_impact", 1.6], [&"sonic_ring", 1.2]]
		CombatSim.EventType.DECOY_FADE:
			plan.effects = [[&"vanish_burst", 0.4]]
	return plan


## Plays this tick's special events, then the trails and decoy ghosts.
func react(vfx: MatchVfx, sim: CombatSim, events: Array[Dictionary]) -> void:
	if sim == null:
		return
	_tick += 1
	for event in events:
		var who: int = event.get("fighter", -1)
		if who < 0 or who >= sim.fighters.size():
			continue
		var plan := plan_for(event, SpecialRules.kit_of(sim.fighters[who]))
		for entry: Array in plan.effects:
			vfx.spawn(entry[0], event.get("position", sim.fighters[who].position), plan.color, entry[1])
	for fighter in sim.fighters:
		var kit := SpecialRules.kit_of(fighter)
		if kit == null:
			continue
		if fighter.specials.has_decoy() and _tick % DECOY_EVERY == 0:
			vfx.spawn(&"afterimage", fighter.specials.decoy_position, kit.color, 1.0)
		if wants_trail(fighter) and _tick % TRAIL_EVERY == 0:
			vfx.spawn(&"afterimage", fighter.position, kit.color, 0.9)


## True while a special is moving the fighter (rush, leap, slide): the trail shows its path.
static func wants_trail(fighter: FighterState) -> bool:
	var special := SpecialRules.current(fighter)
	if special == null or special.travel_end_tick <= special.travel_start_tick:
		return false
	return fighter.move_tick >= special.travel_start_tick and fighter.move_tick < special.travel_end_tick
