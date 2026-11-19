class_name MatchHud
extends Control
## Match HUD for 2-4 fighters, drawn in a 1920x1080 design space and scaled to
## the window, so it reads the same at 1080p, 720p and in the web build.
## Per fighter: a name plate in team colour, health with a chip-damage trail
## and the recoverable grey part, ki in 4 bars, guard, burst stocks, round-win
## pips, the held weapon and inventory slots. Centre: round clock and banners.

const DESIGN := Vector2(1920, 1080)
const PLATE_SIZE := Vector2(560, 132)
const MARGIN := 32.0
const ROW_GAP := 14.0
## The chip trail waits this long after a hit, then drains at TRAIL_SPEED
## (fraction of the bar per second).
const TRAIL_HOLD := 0.5
const TRAIL_SPEED := 0.8
## Weapon slots per fighter (FighterState.weapons, T-D14).
const INVENTORY_SLOTS := 3
const KI_BARS := 4

const INK := Color(0.05, 0.05, 0.08, 0.85)
const PANEL := Color(0.08, 0.09, 0.13, 0.72)
const HEALTH := Color(0.96, 0.96, 0.92)
const GREY := Color(0.62, 0.62, 0.66)
const CHIP := Color(0.95, 0.25, 0.2)
const KI := Color(0.35, 0.8, 1.0)
const GUARD := Color(0.95, 0.8, 0.3)
const GUARD_LOW := Color(0.95, 0.35, 0.2)
const BANNER := Color(1.0, 0.85, 0.25)

## Set by the arena.
var sim: CombatSim
var flow: MatchFlow
var names: Array[String] = []
var team_colors: Array[Color] = []

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
	var count := sim.fighters.size()
	for i in count:
		_draw_plate(i, plate_rect(i, count))
	# No clock or banners when the round flow is off (scripted playtests).
	if flow != null and flow.enabled:
		_draw_clock()
		_draw_banner()
	draw_set_transform(Vector2.ZERO)


func _name_of(index: int) -> String:
	return names[index] if index < names.size() and names[index] != "" else "P%d" % (index + 1)


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
	# Held weapon and inventory slots, on the far side from the badge.
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
	# Burst stocks.
	var stocks := burst_stocks(fighter, sim.meter_tuning)
	for s in sim.meter_tuning.burst_max_stocks:
		var stock_x := inner_x + inner_w - 8.0 - s * 18.0 if right_side else inner_x + 8.0 + s * 18.0
		draw_circle(Vector2(stock_x, rect.position.y + 120), 6, team if s < stocks else INK)


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
	# The real screen centre, in design space (the design is pinned to the top).
	var centre := (size / 2.0 - design_offset(size)) / design_scale(size) + Vector2(0, -60)
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


## Plate for fighter index, in design space: even indices on the left, odd on
## the right, a second row for fighters 3 and 4.
static func plate_rect(index: int, _count: int) -> Rect2:
	var row := index / 2
	var x := DESIGN.x - MARGIN - PLATE_SIZE.x if index % 2 == 1 else MARGIN
	return Rect2(Vector2(x, MARGIN + row * (PLATE_SIZE.y + ROW_GAP)), PLATE_SIZE)


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
