extends SceneTree
## T-DEF1 'player' defense matrix: scripted inputs, one attack x one defensive option per
## run, for every legend. A dry run (no defence) finds the attack's first contact tick T;
## the option is then input at T - lead (an ideal read), and the outcome and the frame
## advantage after it are recorded. T-DEF2: dodge options are Shift taps (sidestep = locked
## Shift+D, back dodge = Shift+S, spot = Shift alone); PERFECT_DODGE marks a perfect dodge.
##   godot --headless --path . -s res://tools/qa/defense_matrix.gd -- --out DIR
## Writes DIR/defense_matrix.json and prints a markdown table.

const A := FighterInput.Action
const E := CombatSim.EventType
const S := FighterState.State
const LEGENDS: Array[StringName] = [&"kael", &"vexa", &"brann", &"lyra"]
const MELEE_GAP := 1.8
const RANGED_GAP := 10.0
const WATCH_TICKS := 150
const FREE: Array[FighterState.State] = [S.IDLE, S.MOVING, S.FLYING, S.FALLING, S.BLOCKING]

## Attack name -> {press, move (planar), vertical, weapon, gap, hold}
const ATTACKS := {
	"light_1": {"press": A.LIGHT},
	"smash": {"press": A.HEAVY},
	"breaker": {"press": A.HEAVY, "move": Vector2(0, 1)},
	"sweep": {"press": A.HEAVY, "move": Vector2(1, 0)},
	"launcher": {"press": A.HEAVY, "move": Vector2(0, -1)},
	"charged_smash_3": {"press": A.HEAVY, "hold": 70},
	"grab": {"press": A.GRAB},
	"blade_light": {"press": A.LIGHT, "weapon": Weapon.Kind.STORM_BLADE},
	"hammer_heavy": {"press": A.HEAVY, "weapon": Weapon.Kind.TITAN_HAMMER},
	"revolver_shot": {"press": A.LIGHT, "weapon": Weapon.Kind.ARC_REVOLVER, "gap": RANGED_GAP},
	"bow_shot": {"press": A.LIGHT, "weapon": Weapon.Kind.KI_BOW, "gap": RANGED_GAP},
	"repeater_shot": {"press": A.LIGHT, "weapon": Weapon.Kind.STORM_REPEATER, "gap": RANGED_GAP},
}

## Option name -> {press, held, move, vertical, lead (ticks before contact)}
const OPTIONS := {
	"none": {},
	"hold_block": {"held": A.BLOCK, "lead": 999},
	"perfect_block": {"press": A.BLOCK, "lead": 3},
	"sidestep": {"press": A.DASH, "move": Vector2(1, 0), "lead": 4},
	"back_dodge": {"press": A.DASH, "move": Vector2(0, -1), "lead": 4},
	"spot_dodge": {"press": A.DASH, "lead": 4},
	# Dodged too early: the attack meets the recovery (T-DEF2 S5: grabs counter-hit it).
	"spot_dodge_early": {"press": A.DASH, "lead": 22, "delay_attack": true},
	"jump_ascend": {"press": 0, "vertical": 1, "lead": 8},
	"vanish_neutral": {"press": A.DASH | A.BLOCK, "lead": 2},
	"vanish_side": {"press": A.DASH | A.BLOCK, "move": Vector2(1, 0), "lead": 2},
	"rising_reversal": {"press": A.HEAVY, "vertical": 1, "lead": 5},
	"jab_mash": {"press": A.LIGHT, "lead": 6},
	"grab_tech": {"tech": true},
}

var sim: CombatSim
var _previous: Array[FighterInput] = []


func _initialize() -> void:
	var out_dir := "user://defense"
	var raw := OS.get_cmdline_user_args()
	var at := raw.find("--out")
	if at >= 0 and at + 1 < raw.size():
		out_dir = raw[at + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var results := {}
	for legend in LEGENDS:
		for attack: String in ATTACKS:
			var contact: int = _run(legend, attack, "none", -1).first_contact
			for option: String in OPTIONS:
				var result := _run(legend, attack, option, contact)
				results["%s|%s|%s" % [legend, attack, option]] = result
	var file := FileAccess.open(out_dir.path_join("defense_matrix.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	_print_table(results)
	quit()


func _run(legend: StringName, attack: String, option: String, contact_tick: int) -> Dictionary:
	var spec: Dictionary = ATTACKS[attack]
	var opt: Dictionary = OPTIONS[option]
	var gap: float = spec.get("gap", MELEE_GAP)
	sim = CombatSim.new(7)
	# The defender is always Kael so only the attacker's legend changes.
	sim.add_fighter(Vector3(0, 0, gap), Roster.character(legend).stats)
	sim.add_fighter(Vector3.ZERO, Roster.character(&"kael").stats)
	sim.lock_everyone_onto_nearest()
	_previous = [FighterInput.new(), FighterInput.new()]
	for f in sim.fighters:
		f.ki = 100 * FighterState.METER_UNIT
	if spec.has("weapon"):
		_arm(spec.weapon)
	_step(0, 0, 0, 0, 10)
	var attacker_held := 0
	var hold: int = spec.get("hold", 0)
	var first_contact := -1
	var outcome := ""
	var attacker_free := -1
	var defender_free := -1
	var defender_held: int = opt.get("held", 0)
	var lead: int = opt.get("lead", -1)
	# An early option before a fast attack: the attack starts later instead.
	var delay := 0
	if opt.get("delay_attack", false) and contact_tick >= 0:
		delay = maxi(lead - contact_tick, 0)
		contact_tick += delay
	for t in WATCH_TICKS + delay:
		var a_press := 0
		var a_move: Vector2 = spec.get("move", Vector2.ZERO) if t - delay < 2 else Vector2.ZERO
		if t == delay:
			a_press = spec.press
		if hold > 0 and t >= delay and t - delay < hold:
			attacker_held = spec.press
		else:
			attacker_held = 0
		var d_press := 0
		var d_move := Vector2.ZERO
		var d_vertical := 0
		if lead >= 0 and contact_tick >= 0 and t == maxi(contact_tick - lead, 0):
			d_press = opt.get("press", 0)
			d_move = opt.get("move", Vector2.ZERO)
			d_vertical = opt.get("vertical", 0)
		if opt.get("tech", false) and sim.fighters[1].state == S.GRABBED and sim.fighters[1].state_ticks == 2:
			d_press = A.GRAB
		var events := _step_once(attacker_held | a_press, a_move, 0,
			defender_held | d_press, d_move, d_vertical)
		for event: Dictionary in events:
			var against: bool = event.get("target", event.get("fighter", -1)) == 1
			var label := ""
			match event.type:
				E.HIT, E.COUNTER, E.ARMOR, E.THROW:
					label = "HIT" if against else ""
				E.GRAB:
					label = ("GRABBED_CH" if event.counter else "GRABBED") if against else ""
				E.PERFECT_DODGE:
					label = "PERFECT_DODGE" if against else ""
				E.BLOCK:
					label = "BLOCKED" if against else ""
				E.PERFECT_BLOCK:
					label = "PERFECT" if against else ""
				E.GRAB_TECH:
					label = "TECHED"
				E.PROJECTILE_HIT:
					if against:
						label = "REFLECTED" if event.reflected else ("BLOCKED" if event.blocked else "HIT")
				E.GUARD_BREAK:
					label = "GUARD_BREAK" if against else ""
			if label != "":
				if first_contact < 0:
					first_contact = t
				if outcome == "" or label in ["HIT", "TECHED", "GUARD_BREAK"]:
					outcome = label if not outcome.begins_with("GRABBED") or label == "TECHED" else outcome
			# The defender's own reversal landing on the attacker.
			if event.type in [E.HIT, E.COUNTER] and event.get("target", -1) == 0 and outcome == "":
				outcome = "TRADE_WON"
		if t > delay + 1:
			if attacker_free < 0 and sim.fighters[0].state in FREE:
				attacker_free = t
			if defender_free < 0 and sim.fighters[1].state in FREE and _defender_acted(t, contact_tick, lead):
				defender_free = t
	if outcome == "":
		outcome = "EVADED" if contact_tick >= 0 else "MISS"
	return {
		"first_contact": first_contact, "outcome": outcome,
		# Positive: the defender can act this many ticks before the attacker (a punish window).
		"advantage": (attacker_free - defender_free) if attacker_free >= 0 and defender_free >= 0 else null,
		"defender_health_lost": sim.fighters[1].stats.max_health - sim.fighters[1].health / FighterState.METER_UNIT,
	}


## Only counts the defender free once its option has started (it is free before it acts).
func _defender_acted(t: int, contact_tick: int, lead: int) -> bool:
	if lead < 0 or contact_tick < 0:
		return t > maxi(contact_tick, 1)
	return t > maxi(contact_tick - lead, 0) + 1 and t > contact_tick


func _arm(kind: Weapon.Kind) -> void:
	var pickup := WeaponPickup.new()
	pickup.id = sim._new_entity_id()
	pickup.kind = kind
	pickup.ammo = Weapon.full_ammo(kind)
	pickup.position = sim.fighters[0].position + Vector3(0, -0.4, 0)
	pickup.phase = WeaponPickup.Phase.GROUNDED
	pickup.ticks_left = 600
	sim.pickups.append(pickup)
	_step_once(A.PICKUP, Vector2.ZERO, 0, 0, Vector2.ZERO, 0)
	_step(0, 0, 0, 0, 30)


func _step(a_held: int, _a: int, d_held: int, _d: int, ticks: int) -> void:
	for _i in ticks:
		_step_once(a_held, Vector2.ZERO, 0, d_held, Vector2.ZERO, 0)


func _step_once(a_held: int, a_move: Vector2, a_vertical: int, d_held: int, d_move: Vector2,
		d_vertical: int) -> Array[Dictionary]:
	var a := FighterInput.from_held(a_held, _previous[0])
	a.move = a_move
	a.vertical = a_vertical
	var d := FighterInput.from_held(d_held, _previous[1])
	d.move = d_move
	d.vertical = d_vertical
	var inputs: Array[FighterInput] = [a, d]
	sim.tick(inputs)
	_previous = inputs
	return sim.events.duplicate()


func _print_table(results: Dictionary) -> void:
	for legend in LEGENDS:
		print("\n### attacker %s (defender kael)\n" % legend)
		var header := "| attack | " + " | ".join(PackedStringArray(OPTIONS.keys())) + " |"
		print(header)
		print("|---" .repeat(OPTIONS.size() + 1) + "|")
		for attack: String in ATTACKS:
			var row := PackedStringArray([attack])
			for option: String in OPTIONS:
				var r: Dictionary = results["%s|%s|%s" % [legend, attack, option]]
				var adv = r.advantage
				row.append("%s%s" % [r.outcome, "" if adv == null else " (%+d)" % int(adv)])
			print("| " + " | ".join(row) + " |")
