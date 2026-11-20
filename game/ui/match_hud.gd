class_name MatchHud
extends Control
## Match HUD for 2-4 fighters, drawn in a 1920x1080 design space and scaled to
## the window, so it reads the same at 1080p, 720p and in the web build.
## Per fighter: a name plate in team colour, health with a chip-damage trail
## and the recoverable grey part, ki in 4 bars, guard, burst stocks, round-win
## pips, the held weapon and inventory slots (only while armed). Centre: round
## clock and banners. With 3+ fighters (FFA, 2v2) only the player keeps a full
## plate; teammates (left) and opponents (right) get compact ones (T-UX1).

const DESIGN := Vector2(1920, 1080)
const PLATE_SIZE := Vector2(560, 132)
const MARGIN := 32.0
const ROW_GAP := 14.0
## Compact plate (3+ fighters): name, health and ki only.
const COMPACT_SIZE := Vector2(340, 62)
const COMPACT_GAP := 8.0
## The chip trail waits this long after a hit, then drains at TRAIL_SPEED
## (fraction of the bar per second).
const TRAIL_HOLD := 0.5
const TRAIL_SPEED := 0.8
## Weapon slots per fighter (FighterState.weapons, T-D14).
const INVENTORY_SLOTS := 3
const KI_BARS := 4
## Banner baseline height as a fraction of the screen height.
const BANNER_HEIGHT_FRACTION := 0.3

const INK := Color(0.05, 0.05, 0.08, 0.85)
const PANEL := Color(0.08, 0.09, 0.13, 0.72)
const HEALTH := Color(0.96, 0.96, 0.92)
const GREY := Color(0.62, 0.62, 0.66)
const CHIP := Color(0.95, 0.25, 0.2)
const KI := Color(0.35, 0.8, 1.0)
const GUARD := Color(0.95, 0.8, 0.3)
const GUARD_LOW := Color(0.95, 0.35, 0.2)
const BANNER := Color(1.0, 0.85, 0.25)
## Kael's Momentum pips and Vexa's afterimage marker.
const MOMENTUM := Color(1.0, 0.62, 0.22)
const AFTERIMAGE := Color(0.72, 0.38, 1.0)

## Set by the arena.
var sim: CombatSim
var flow: MatchFlow
var names: Array[String] = []
var team_colors: Array[Color] = []
## Team per fighter and AI flags, for the 3+ fighter layout and name tags; optional.
var teams: Array[int] = []
var is_ai: Array[bool] = []
## The fighter this screen belongs to (keeps the full plate).
var player := 0

var _trail: Array[float] = []
var _trail_hold: Array[float] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if sim == null:
		return
	while _trail.size() < sim.fighters.size():
		_trail.append(health_fraction(sim.fighters[_trail.size()]))
		_trail_hold.append(0.0)
	for i in sim.fighters.size():
		var result := chip_trail_step(_trail[i], health_fraction(sim.fighters[i]), _trail_hold[i], delta)
		_trail[i] = result.trail
		_trail_hold[i] = result.hold
	queue_redraw()


## The chip trail of fighter index (fraction of the bar), for tests.
func trail_of(index: int) -> float:
	return _trail[index] if index < _trail.size() else 1.0


func _draw() -> void:
	if sim == null:
		return
	var scale_factor := design_scale(size)
	var offset := design_offset(size)
	draw_set_transform(offset, 0.0, Vector2.ONE * scale_factor)
	var rects := plate_layout(sim.fighters.size(), player, teams)
	for i in rects.size():
		if rects[i].size == COMPACT_SIZE:
			_draw_compact_plate(i, rects[i])
		else:
			_draw_plate(i, rects[i])
	# No clock or banners when the round flow is off (scripted playtests).
	if flow != null and flow.enabled:
		_draw_clock()
		_draw_banner()
	draw_set_transform(Vector2.ZERO)


func _name_of(index: int) -> String:
	var tagged := plate_names(names, is_ai, player)
	return tagged[index] if index < tagged.size() and tagged[index] != "" else "P%d" % (index + 1)


func _draw_plate(index: int, rect: Rect2) -> void:
	var fighter := sim.fighters[index]
	var team := team_colors[index] if index < team_colors.size() else Color.WHITE
	var right_side := index % 2 == 1
	var font := ThemeDB.fallback_font
	draw_rect(rect, PANEL)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6)), team)
	# Name badge with the initial: the portrait slot until characters ship portraits.
	var badge_x := rect.end.x - 96.0 if right_side else rect.position.x
	var badge := Rect2(Vector2(badge_x, rect.position.y + 6), Vector2(96, rect.size.y - 6))
	draw_rect(badge, Color(team, 0.85))
	_text(font, badge.get_center() + Vector2(0, 22), _name_of(index).left(1), 64, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var inner_x := rect.position.x + (16.0 if right_side else 112.0)
	var inner_w := rect.size.x - 128.0
	var name_x := inner_x + inner_w if right_side else inner_x
	_text(font, Vector2(name_x, rect.position.y + 36), _name_of(index), 26, Color.WHITE,
		HORIZONTAL_ALIGNMENT_RIGHT if right_side else HORIZONTAL_ALIGNMENT_LEFT)
	_draw_pips(index, Vector2(inner_x + 6 if right_side else inner_x + inner_w - 52, rect.position.y + 26))
	# Health: chip trail under the grey (recoverable) part under current health.
	var bar := Rect2(inner_x, rect.position.y + 46, inner_w, 26)
	draw_rect(bar, INK)
	var health := health_fraction(fighter)
	_bar(bar, trail_of(index) if index < _trail.size() else health, CHIP, right_side)
	_bar(bar, minf(health + grey_fraction(fighter), 1.0), GREY, right_side)
	_bar(bar, health, HEALTH.lerp(team, 0.15), right_side)
	draw_rect(bar, INK, false, 2.0)
	# Ki in KI_BARS bars, filling from the badge side.
	var ki := ki_fraction(fighter, sim.meter_tuning)
	var ki_w := (inner_w * 0.62 - (KI_BARS - 1) * 6.0) / KI_BARS
	for b in KI_BARS:
		var x := inner_x + inner_w - (b + 1) * ki_w - b * 6.0 if right_side else inner_x + b * (ki_w + 6.0)
		var cell := Rect2(x, rect.position.y + 80, ki_w, 12)
		draw_rect(cell, INK)
		_bar(cell, clampf(ki * KI_BARS - b, 0.0, 1.0), KI, right_side)
	# Guard.
	var guard := guard_fraction(fighter)
	var guard_x := inner_x + inner_w * 0.38 if right_side else inner_x
	var guard_rect := Rect2(guard_x, rect.position.y + 98, inner_w * 0.62, 8)
	draw_rect(guard_rect, INK)
	_bar(guard_rect, guard, GUARD if guard > 0.3 else GUARD_LOW, right_side)
	# Held weapon and inventory slots, on the far side from the badge, only while armed.
	if shows_weapon_box(fighter):
		_draw_weapon(fighter, team, inner_x, inner_w, rect, right_side)
	# Burst stocks.
	var stocks := burst_stocks(fighter, sim.meter_tuning)
	for s in sim.meter_tuning.burst_max_stocks:
		var stock_x := inner_x + inner_w - 8.0 - s * 18.0 if right_side else inner_x + 8.0 + s * 18.0
		draw_circle(Vector2(stock_x, rect.position.y + 120), 6, team if s < stocks else INK)
	_draw_mechanic(fighter, inner_x, inner_w, rect.position.y + 120, right_side,
		sim.meter_tuning.burst_max_stocks * 18.0 + 14.0)


## Legend mechanic pips beside the burst stocks (T-SP1): Kael's Momentum, Vexa's afterimage.
func _draw_mechanic(fighter: FighterState, inner_x: float, inner_w: float, y: float, right_side: bool,
		offset: float) -> void:
	var kit := SpecialRules.kit_of(fighter)
	if kit == null:
		return
	var font := ThemeDB.fallback_font
	var start := inner_x + inner_w - offset if right_side else inner_x + offset
	var step := -9.0 if right_side else 9.0
	match kit.mechanic:
		SpecialKit.Mechanic.MOMENTUM:
			var lit := momentum_pips(fighter)
			for p in kit.momentum_max_stacks:
				var at := Vector2(start + p * step, y)
				var pip := PackedVector2Array([at + Vector2(0, -6), at + Vector2(4, 0), at + Vector2(0, 6), at + Vector2(-4, 0)])
				draw_colored_polygon(pip, MOMENTUM if p < lit else INK)
			if lit > 0:
				var label_x := start + kit.momentum_max_stacks * step + (step * 0.5)
				_text(font, Vector2(label_x, y + 6), "+%d%%" % SpecialRules.momentum_percent(fighter), 16,
					MOMENTUM, HORIZONTAL_ALIGNMENT_RIGHT if right_side else HORIZONTAL_ALIGNMENT_LEFT)
		SpecialKit.Mechanic.AFTERIMAGE:
			var live := fighter.specials.has_decoy()
			draw_circle(Vector2(start, y), 6, AFTERIMAGE if live else INK)
			draw_arc(Vector2(start + step * 1.3, y), 6, 0.0, TAU, 16, AFTERIMAGE if live else INK, 2.0)


## Lit Momentum pips (one per consecutive landed hit, up to the kit's cap); 0 for other legends.
static func momentum_pips(fighter: FighterState) -> int:
	var kit := SpecialRules.kit_of(fighter)
	if kit == null or kit.mechanic != SpecialKit.Mechanic.MOMENTUM:
		return 0
	return mini(fighter.specials.momentum, kit.momentum_max_stacks)


func _draw_weapon(fighter: FighterState, team: Color, inner_x: float, inner_w: float, rect: Rect2,
		right_side: bool) -> void:
	var font := ThemeDB.fallback_font
	var weapon_w := inner_w * 0.34 - 52.0
	var weapon_x := inner_x + 52.0 if right_side else inner_x + inner_w - weapon_w - 52.0
	var weapon_rect := Rect2(weapon_x, rect.position.y + 78, weapon_w, 30)
	draw_rect(weapon_rect, INK)
	var weapon_text := weapon_label(fighter)
	var weapon_size := fit_font_size(font, weapon_text, weapon_rect.size.x - 8.0, 16, 9)
	_text(font, weapon_rect.get_center() + Vector2(0, weapon_size * 0.38), weapon_text, weapon_size,
		Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 4)
	var slots := inventory_slots(fighter)
	for slot_index in slots.size():
		var slot_x := weapon_rect.position.x - 24.0 - slot_index * 22.0 if right_side else weapon_rect.end.x + 6.0 + slot_index * 22.0
		var slot := Rect2(slot_x, weapon_rect.position.y + 4, 18, 22)
		draw_rect(slot, INK)
		if slots[slot_index].filled:
			draw_rect(slot.grow(-4), team)
		if slots[slot_index].active:
			draw_rect(slot, Color.WHITE, false, 2.0)


## Small plate: team stripe, name (plus the held weapon), win pips, health and ki.
func _draw_compact_plate(index: int, rect: Rect2) -> void:
	var fighter := sim.fighters[index]
	var team := team_colors[index] if index < team_colors.size() else Color.WHITE
	var font := ThemeDB.fallback_font
	var faded := fighter.is_knocked_out()
	draw_rect(rect, Color(PANEL, PANEL.a * (0.6 if faded else 1.0)))
	draw_rect(Rect2(rect.position, Vector2(8, rect.size.y)), team)
	var inner_x := rect.position.x + 18.0
	var inner_w := rect.size.x - 30.0
	var label := _name_of(index)
	var name_size := fit_font_size(font, label, inner_w * 0.6, 20, 12)
	_text(font, Vector2(inner_x, rect.position.y + 22), label, name_size, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 4)
	if shows_weapon_box(fighter):
		var weapon_text := weapon_label(fighter)
		var weapon_size := fit_font_size(font, weapon_text, inner_w * 0.38 - 50.0, 13, 9)
		_text(font, Vector2(inner_x + inner_w - 52.0, rect.position.y + 20), weapon_text, weapon_size,
			Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 3)
	for p in MatchFlow.WINS_NEEDED:
		var won := flow != null and index < flow.wins.size() and p < flow.wins[index]
		var centre := Vector2(inner_x + inner_w - 6.0 - p * 16.0, rect.position.y + 15)
		draw_circle(centre, 5, BANNER if won else INK)
		draw_arc(centre, 5, 0, TAU, 12, Color(1, 1, 1, 0.6), 1.0, true)
	var bar := Rect2(inner_x, rect.position.y + 30, inner_w, 14)
	draw_rect(bar, INK)
	var health := health_fraction(fighter)
	_bar(bar, trail_of(index) if index < _trail.size() else health, CHIP, false)
	_bar(bar, minf(health + grey_fraction(fighter), 1.0), GREY, false)
	_bar(bar, health, HEALTH.lerp(team, 0.15), false)
	var ki_rect := Rect2(inner_x, rect.position.y + 49, inner_w, 5)
	draw_rect(ki_rect, INK)
	_bar(ki_rect, ki_fraction(fighter, sim.meter_tuning), KI, false)


func _draw_pips(index: int, at: Vector2) -> void:
	for p in MatchFlow.WINS_NEEDED:
		var won := flow != null and index < flow.wins.size() and p < flow.wins[index]
		var centre := at + Vector2(p * 22 + 8, 0)
		draw_circle(centre, 8, BANNER if won else INK)
		draw_arc(centre, 8, 0, TAU, 16, Color(1, 1, 1, 0.6), 1.5, true)


func _draw_clock() -> void:
	var font := ThemeDB.fallback_font
	var box := Rect2(DESIGN.x / 2 - 60, MARGIN, 120, 84)
	draw_rect(box, PANEL)
	var seconds := flow.seconds_left()
	_text(font, Vector2(DESIGN.x / 2, MARGIN + 62), str(seconds), 56,
		Color.WHITE if seconds > 10 else CHIP, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_banner() -> void:
	var banner := flow.banner(names)
	if banner.title == "":
		return
	var font := ThemeDB.fallback_font
	# Upper third of the real screen (in design space; the design is pinned to
	# the top), clear of the fighters, who sit around the middle: media-1.9's
	# centred K.O.! hid the fall.
	var centre := banner_position(size)
	_text(font, centre, banner.title, 132, BANNER, HORIZONTAL_ALIGNMENT_CENTER, 18)
	if banner.subtitle != "":
		_text(font, centre + Vector2(0, 70), banner.subtitle, 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10)


func _bar(rect: Rect2, fraction: float, color: Color, from_right: bool) -> void:
	var width := rect.size.x * clampf(fraction, 0.0, 1.0)
	if width <= 0.0:
		return
	var x := rect.end.x - width if from_right else rect.position.x
	draw_rect(Rect2(x, rect.position.y, width, rect.size.y), color)


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color,
		align: HorizontalAlignment, outline: int = 6) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= width / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= width
	draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, INK)
	draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# --- Layout and values (static, tested) ---

## Uniform scale from the 1920x1080 design to a screen size (fits inside).
static func design_scale(screen: Vector2) -> float:
	if screen.x <= 0.0 or screen.y <= 0.0:
		return 1.0
	return minf(screen.x / DESIGN.x, screen.y / DESIGN.y)


## Where the scaled design starts: centred across, pinned to the top so the
## plates stay in the corners on tall (web) canvases.
static func design_offset(screen: Vector2) -> Vector2:
	return Vector2((screen.x - DESIGN.x * design_scale(screen)) / 2.0, 0.0)


## Where banners are centred, in design space: the upper third of the screen,
## below the plates and clock.
static func banner_position(screen: Vector2) -> Vector2:
	var scale_factor := design_scale(screen)
	var top_third := Vector2(screen.x / 2.0, screen.y * BANNER_HEIGHT_FRACTION)
	return (top_third - design_offset(screen)) / scale_factor


## Plate for fighter index, in design space: even indices on the left, odd on
## the right, a second row for fighters 3 and 4.
static func plate_rect(index: int, _count: int) -> Rect2:
	var row := index / 2
	var x := DESIGN.x - MARGIN - PLATE_SIZE.x if index % 2 == 1 else MARGIN
	return Rect2(Vector2(x, MARGIN + row * (PLATE_SIZE.y + ROW_GAP)), PLATE_SIZE)


## Plates for count fighters, in design space. Up to two: plate_rect. With more,
## the player's full plate top left, teammates' compact plates under it and
## opponents' compact plates stacked top right. Without teams everyone else is
## an opponent.
static func plate_layout(count: int, player_index: int, team_of: Array[int]) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if count <= 2:
		for i in count:
			rects.append(plate_rect(i, count))
		return rects
	var me := clampi(player_index, 0, count - 1)
	var my_team := team_of[me] if me < team_of.size() else -1
	var left_y := MARGIN + PLATE_SIZE.y + COMPACT_GAP
	var right_y := MARGIN
	for i in count:
		if i == me:
			rects.append(Rect2(Vector2(MARGIN, MARGIN), PLATE_SIZE))
			continue
		var teammate := my_team >= 0 and i < team_of.size() and team_of[i] == my_team
		if teammate:
			rects.append(Rect2(Vector2(MARGIN, left_y), COMPACT_SIZE))
			left_y += COMPACT_SIZE.y + COMPACT_GAP
		else:
			rects.append(Rect2(Vector2(DESIGN.x - MARGIN - COMPACT_SIZE.x, right_y), COMPACT_SIZE))
			right_y += COMPACT_SIZE.y + COMPACT_GAP
	return rects


## Plate names; a legend picked more than once gets a slot tag, "VEXA (P1)" for
## the player and "VEXA (CPU 3)" for an AI in slot 3 ("P3" for other humans).
static func plate_names(base: Array[String], ai: Array[bool], player_index: int) -> Array[String]:
	var counts := {}
	for n in base:
		counts[n] = int(counts.get(n, 0)) + 1
	var out: Array[String] = []
	for i in base.size():
		var n := base[i]
		if n == "" or int(counts[n]) < 2:
			out.append(n)
		elif i == player_index:
			out.append("%s (P1)" % n)
		elif i < ai.size() and ai[i]:
			out.append("%s (CPU %d)" % [n, i + 1])
		else:
			out.append("%s (P%d)" % [n, i + 1])
	return out


static func health_fraction(fighter: FighterState) -> float:
	return clampf(fighter.health_display() / maxf(fighter.stats.max_health, 1.0), 0.0, 1.0)


static func grey_fraction(fighter: FighterState) -> float:
	return clampf(fighter.grey_health_display() / maxf(fighter.stats.max_health, 1.0), 0.0, 1.0)


static func ki_fraction(fighter: FighterState, tuning: MeterTuning) -> float:
	return clampf(fighter.ki_display() / maxf(tuning.ki_max, 1.0), 0.0, 1.0)


static func guard_fraction(fighter: FighterState) -> float:
	return clampf(fighter.guard_display() / maxf(fighter.stats.guard_max, 1.0), 0.0, 1.0)


static func burst_stocks(fighter: FighterState, tuning: MeterTuning) -> int:
	return floori(fighter.burst_display() / maxf(tuning.burst_stock_size, 1.0))


## Chip trail: holds after the health drops, then drains toward it.
## Returns {trail, hold}.
static func chip_trail_step(trail: float, health: float, hold: float, delta: float) -> Dictionary:
	if health >= trail:
		return {"trail": health, "hold": TRAIL_HOLD}
	if hold > 0.0:
		return {"trail": trail, "hold": maxf(hold - delta, 0.0)}
	return {"trail": maxf(trail - TRAIL_SPEED * delta, health), "hold": 0.0}


## What the weapon box says: the held weapon's name, plus ammo for ranged
## weapons ("ARC REVOLVER 12", "RELOAD" while reloading); "UNARMED" when empty.
static func weapon_label(fighter: FighterState) -> String:
	var kind := fighter.held_weapon()
	if kind == Weapon.Kind.NONE:
		return "UNARMED"
	var label := String(Weapon.Kind.find_key(kind)).replace("_", " ")
	if Weapon.is_ranged(kind):
		label += " RELOAD" if fighter.reload_ticks > 0 else " %d" % fighter.ammo[fighter.active_slot]
	return label


## The weapon box (and inventory slots) only shows while a weapon is held.
static func shows_weapon_box(fighter: FighterState) -> bool:
	return fighter.held_weapon() != Weapon.Kind.NONE


## Largest font size from largest down to smallest at which text fits width.
static func fit_font_size(font: Font, text: String, width: float, largest: int, smallest: int) -> int:
	var font_size := largest
	while font_size > smallest and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		font_size -= 1
	return font_size


## One entry per weapon slot: {filled, active}.
static func inventory_slots(fighter: FighterState) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i in mini(fighter.weapons.size(), INVENTORY_SLOTS):
		slots.append({"filled": fighter.weapons[i] != Weapon.Kind.NONE, "active": i == fighter.active_slot})
	return slots
