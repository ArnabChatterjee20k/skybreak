class_name MatchHud
extends Control
## Match HUD for 2-4 fighters, drawn in a 1920x1080 design space and scaled to
## the window, so it reads the same at 1080p, 720p and in the web build. Styled
## on MenuTheme (T-UI1): skewed navy panels, ink outlines, the display font,
## gold accents and team colours.
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
const CLOCK_SIZE := Vector2(120, 84)

## Colours: the menus' palette (MenuTheme), shared with the training overlays.
const INK := MenuTheme.INK
const PANEL := Color(MenuTheme.PANEL, 0.9)
const HEALTH_GLOSS := Color(1, 1, 1, 0.32)
const GREY := Color(MenuTheme.TEXT_DIM, 0.75)
const CHIP := Color(1.0, 0.3, 0.22)
const KI := MenuTheme.CYAN
const GUARD := MenuTheme.GOLD
const GUARD_LOW := MenuTheme.HOT
const BANNER := MenuTheme.GOLD
## Plate borders (design px) and the low-health pulse.
const BORDER := 4.0
## Share of the plate's inner width for ki and guard; the weapon chip takes the rest.
const METER_WIDTH := 0.5
const LOW_HEALTH := 0.25
const PULSE_HZ := 2.2
## Seconds the freshly lost health flashes white before it turns into the chip trail.
const HIT_FLASH := 0.12
## Banners scale in from BANNER_POP to 1 over BANNER_POP_SECONDS.
const BANNER_POP := 1.35
const BANNER_POP_SECONDS := 0.15
const BANNER_SIZE := 132
const BANNER_OUTLINE := 22
## Kael's Momentum pips and Vexa's afterimage marker (T-SP1).
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
## Legend head shots per fighter for the portrait tiles; optional (initials otherwise).
var portraits: Array[Texture2D] = []
## The fighter this screen belongs to (keeps the full plate).
var player := 0

var _trail: Array[float] = []
var _trail_hold: Array[float] = []
var _last_health: Array[float] = []
var _flash: Array[float] = []
var _clock := 0.0
var _banner_title := ""
var _banner_age := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if sim == null:
		return
	_clock += delta
	while _trail.size() < sim.fighters.size():
		var start := health_fraction(sim.fighters[_trail.size()])
		_trail.append(start)
		_trail_hold.append(0.0)
		_last_health.append(start)
		_flash.append(0.0)
	for i in sim.fighters.size():
		var health := health_fraction(sim.fighters[i])
		var result := chip_trail_step(_trail[i], health, _trail_hold[i], delta)
		_trail[i] = result.trail
		_trail_hold[i] = result.hold
		_flash[i] = HIT_FLASH if health < _last_health[i] else maxf(_flash[i] - delta, 0.0)
		_last_health[i] = health
	var title: String = flow.banner(names).title if flow != null and flow.enabled else ""
	if title != _banner_title:
		_banner_title = title
		_banner_age = 0.0
	else:
		_banner_age += delta
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
		_draw_banner(offset, scale_factor)
	draw_set_transform(Vector2.ZERO)


func _name_of(index: int) -> String:
	var tagged := plate_names(names, is_ai, player)
	return tagged[index] if index < tagged.size() and tagged[index] != "" else "P%d" % (index + 1)


func _team_of(index: int) -> Color:
	return team_colors[index] if index < team_colors.size() else MenuTheme.team_color(index)


## Full plate: portrait tile in a team-coloured border on the outer edge, then a
## skewed navy panel with the name, win pips, burst stocks, health, ki and guard.
func _draw_plate(index: int, rect: Rect2) -> void:
	var fighter := sim.fighters[index]
	var team := _team_of(index)
	var right := index % 2 == 1
	var font := MenuTheme.font()
	var panel := _mirror(rect, Rect2(rect.position.x + 66, rect.position.y + 10, rect.size.x - 80, 112), right)
	draw_style_box(MenuTheme.box(PANEL, INK, int(BORDER)), panel)
	# Inner column, from the portrait side to the far edge.
	var inner := _mirror(rect, Rect2(rect.position.x + 132, rect.position.y, rect.size.x - 160, rect.size.y), right)
	var align := HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	var near_x := inner.end.x if right else inner.position.x
	var label := _name_of(index)
	var name_size := fit_font_size(font, label, inner.size.x - 150.0, 30, 18)
	_text(font, Vector2(near_x, rect.position.y + 44), label, name_size, MenuTheme.TEXT, align, 8)
	# Round-win pips at the far end of the name row.
	var far_x := inner.position.x if right else inner.end.x
	var step := 1.0 if right else -1.0
	for p in MatchFlow.WINS_NEEDED:
		var won := flow != null and index < flow.wins.size() and p < flow.wins[index]
		var x := far_x + step * (p * 30.0 + 16.0)
		_slant(Rect2(x - 11, rect.position.y + 20, 22, 22), MenuTheme.GOLD if won else Color(INK, 0.8), INK, 3.0)
	# Legend mechanic (T-SP1) just inside the win pips, growing toward the name.
	_draw_mechanic(fighter, inner.position.x, inner.size.x, rect.position.y + 31, not right,
		MatchFlow.WINS_NEEDED * 30.0 + 18.0)
	_health_bar(index, fighter, team, Rect2(inner.position.x, rect.position.y + 52, inner.size.x, 30), right)
	# Ki in KI_BARS cells, filling from the portrait side.
	var ki := ki_fraction(fighter, sim.meter_tuning)
	var ki_w := (inner.size.x * METER_WIDTH - (KI_BARS - 1) * 8.0) / KI_BARS
	for b in KI_BARS:
		var x := inner.end.x - (b + 1) * ki_w - b * 8.0 if right else inner.position.x + b * (ki_w + 8.0)
		var cell := Rect2(x, rect.position.y + 89, ki_w, 12)
		var fill := clampf(ki * KI_BARS - b, 0.0, 1.0)
		_slant(cell, INK)
		_slant_fill(cell, fill, KI if fill >= 1.0 else Color(KI, 0.7), right)
		if fill >= 1.0:
			_slant(Rect2(cell.position, Vector2(cell.size.x, 3)), Color(1, 1, 1, 0.55))
	# Guard.
	var guard := guard_fraction(fighter)
	var guard_x := inner.end.x - inner.size.x * METER_WIDTH if right else inner.position.x
	var guard_rect := Rect2(guard_x, rect.position.y + 107, inner.size.x * METER_WIDTH, 7)
	_slant(guard_rect, INK)
	_slant_fill(guard_rect, guard, GUARD if guard > 0.3 else GUARD_LOW, right)
	# Held weapon and inventory slots, on the far side, only while armed.
	if shows_weapon_box(fighter):
		_draw_weapon(fighter, team, inner, rect, right)
	_draw_portrait(index, fighter, team, _mirror(rect, Rect2(rect.position.x + 12, rect.position.y, 106, rect.size.y), right))


## The portrait tile: legend head shot (or initial) inside a team-coloured border,
## burst stocks on its foot strip.
func _draw_portrait(index: int, fighter: FighterState, team: Color, tile: Rect2) -> void:
	draw_style_box(MenuTheme.box(team.darkened(0.55), team, 5), tile)
	var texture: Texture2D = portraits[index] if index < portraits.size() else null
	if texture != null:
		draw_texture_rect(texture, Rect2(tile.position + Vector2(14, 6), tile.size - Vector2(28, 18)), false)
	else:
		var font := MenuTheme.font()
		_text(font, tile.get_center() + Vector2(4, 26), _name_of(index).left(1), 76, MenuTheme.TEXT,
			HORIZONTAL_ALIGNMENT_CENTER, 14)
	var foot := Rect2(tile.position.x - 2, tile.end.y - 16, tile.size.x + 4, 16)
	_slant(foot, team, INK, 3.0)
	var stocks := burst_stocks(fighter, sim.meter_tuning)
	var count := sim.meter_tuning.burst_max_stocks
	for s in count:
		var x := foot.get_center().x + (s - (count - 1) * 0.5) * 20.0
		_slant(Rect2(x - 7, foot.position.y + 3, 14, 10), MenuTheme.GOLD if s < stocks else INK, INK, 2.0)


## Legend mechanic pips in the name row (T-SP1): Kael's Momentum, Vexa's afterimage.
func _draw_mechanic(fighter: FighterState, inner_x: float, inner_w: float, y: float, right_side: bool,
		offset: float) -> void:
	var kit := SpecialRules.kit_of(fighter)
	if kit == null:
		return
	var font := MenuTheme.font()
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


## Cyan info chip with the weapon name, then the inventory slots.
func _draw_weapon(fighter: FighterState, team: Color, inner: Rect2, rect: Rect2, right: bool) -> void:
	var font := MenuTheme.font()
	var slots := inventory_slots(fighter)
	var slots_w := slots.size() * 16.0
	var weapon_w := inner.size.x * (1.0 - METER_WIDTH) - 18.0 - slots_w
	var weapon_x := inner.position.x + slots_w + 4.0 if right else inner.end.x - weapon_w - slots_w - 4.0
	var chip := Rect2(weapon_x, rect.position.y + 86, weapon_w, 30)
	var style := MenuTheme.box(MenuTheme.CYAN, INK, 3)
	draw_style_box(style, chip)
	var weapon_text := weapon_label(fighter)
	var weapon_size := fit_font_size(font, weapon_text, chip.size.x - 14.0, 18, 12)
	_text(font, chip.get_center() + Vector2(0, weapon_size * 0.36), weapon_text, weapon_size, INK,
		HORIZONTAL_ALIGNMENT_CENTER, 0)
	for slot_index in slots.size():
		var slot_x := chip.position.x - 16.0 - slot_index * 16.0 if right else chip.end.x + 6.0 + slot_index * 16.0
		var slot := Rect2(slot_x, chip.position.y + 5, 11, 20)
		_slant(slot, team if slots[slot_index].filled else INK,
			MenuTheme.GOLD if slots[slot_index].active else INK, 3.0)


## Health: ink track, chip trail (white just after a hit), recoverable grey, then
## health in the team colour with a gloss line; pulses below LOW_HEALTH.
func _health_bar(index: int, fighter: FighterState, team: Color, bar: Rect2, from_right: bool) -> void:
	var health := health_fraction(fighter)
	var low := health > 0.0 and health <= LOW_HEALTH
	var pulse := low_health_pulse(_clock) if low else 0.0
	_slant(bar.grow(BORDER * 0.5), INK)
	var flashing := index < _flash.size() and _flash[index] > 0.0
	_slant_fill(bar, trail_of(index) if index < _trail.size() else health, Color.WHITE if flashing else CHIP, from_right)
	_slant_fill(bar, minf(health + grey_fraction(fighter), 1.0), GREY, from_right)
	var fill := team.lightened(0.12 + 0.45 * pulse)
	_slant_fill(bar, health, fill, from_right)
	_slant_fill(Rect2(bar.position + Vector2(0, 4), Vector2(bar.size.x, 5)), health, HEALTH_GLOSS, from_right)
	_slant_outline(bar.grow(BORDER * 0.5), MenuTheme.HOT.lerp(INK, 1.0 - pulse) if low else INK, BORDER)


## Small plate: skewed panel, team stripe, name (plus the held weapon), win
## pips, health and ki.
func _draw_compact_plate(index: int, rect: Rect2) -> void:
	var fighter := sim.fighters[index]
	var team := _team_of(index)
	var font := MenuTheme.font()
	var faded := fighter.is_knocked_out()
	var panel := Rect2(rect.position.x + 8, rect.position.y, rect.size.x - 16, rect.size.y)
	draw_style_box(MenuTheme.box(Color(PANEL, PANEL.a * (0.55 if faded else 1.0)), INK, 3), panel)
	_slant(Rect2(rect.position.x + 14, rect.position.y + 6, 10, rect.size.y - 12), team)
	var inner_x := rect.position.x + 34.0
	var inner_w := rect.size.x - 56.0
	var label := _name_of(index)
	var name_size := fit_font_size(font, label, inner_w * 0.58, 21, 12)
	_text(font, Vector2(inner_x, rect.position.y + 25), label, name_size,
		MenuTheme.DISABLED if faded else MenuTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 6)
	if shows_weapon_box(fighter):
		var weapon_text := weapon_label(fighter)
		var weapon_size := fit_font_size(font, weapon_text, inner_w * 0.42 - 54.0, 14, 9)
		_text(font, Vector2(inner_x + inner_w - 54.0, rect.position.y + 23), weapon_text, weapon_size,
			MenuTheme.CYAN, HORIZONTAL_ALIGNMENT_RIGHT, 4)
	for p in MatchFlow.WINS_NEEDED:
		var won := flow != null and index < flow.wins.size() and p < flow.wins[index]
		_slant(Rect2(inner_x + inner_w - 14.0 - p * 20.0, rect.position.y + 9, 14, 14),
			MenuTheme.GOLD if won else INK, INK, 2.0)
	_health_bar(index, fighter, team, Rect2(inner_x, rect.position.y + 32, inner_w, 13), false)
	var ki_rect := Rect2(inner_x, rect.position.y + 50, inner_w * 0.7, 5)
	_slant(ki_rect, INK)
	_slant_fill(ki_rect, ki_fraction(fighter, sim.meter_tuning), KI, false)


## Round clock: a skewed navy chip, gold-bordered; hot and pulsing in the last 10 s.
func _draw_clock() -> void:
	var font := MenuTheme.font()
	var box := Rect2(DESIGN.x / 2 - CLOCK_SIZE.x / 2, MARGIN, CLOCK_SIZE.x, CLOCK_SIZE.y)
	var seconds := flow.seconds_left()
	var urgent := seconds <= 10 and flow.phase == MatchFlow.Phase.FIGHT
	var pulse := low_health_pulse(_clock) if urgent else 0.0
	draw_style_box(MenuTheme.box(PANEL, MenuTheme.HOT if urgent else INK, int(BORDER)), box)
	_slant(Rect2(box.position.x + 10, box.end.y - 10, box.size.x - 20, 5), MenuTheme.HOT if urgent else MenuTheme.GOLD)
	_text(font, Vector2(DESIGN.x / 2 + 3, MARGIN + 62), str(seconds), 58,
		MenuTheme.TEXT.lerp(MenuTheme.HOT, 0.6 + 0.4 * pulse) if urgent else MenuTheme.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, 10)


## Round, count, FIGHT!, K.O.!: the menu header type (display font, heavy ink
## outline) on a skewed ink band with a hot-orange underline, popping in.
func _draw_banner(offset: Vector2, scale_factor: float) -> void:
	var banner := flow.banner(names)
	if banner.title == "":
		return
	var font := MenuTheme.font()
	# Upper third of the real screen (in design space; the design is pinned to
	# the top), clear of the fighters, who sit around the middle: media-1.9's
	# centred K.O.! hid the fall.
	var centre := banner_position(size)
	var pop := banner_pop(_banner_age)
	draw_set_transform(offset + centre * scale_factor, 0.0, Vector2.ONE * scale_factor * pop)
	var width := font.get_string_size(banner.title, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_SIZE).x
	var band := Rect2(-width / 2.0 - 70.0, -BANNER_SIZE * 0.86, width + 140.0, BANNER_SIZE * 1.04)
	_slant(band, Color(MenuTheme.PANEL, 0.86), INK, 5.0)
	_slant(Rect2(band.position.x + 30, band.end.y - 4, band.size.x - 60, 10), MenuTheme.HOT, INK, 3.0)
	_text(font, Vector2(4, 0), banner.title, BANNER_SIZE, banner_color(banner.title), HORIZONTAL_ALIGNMENT_CENTER,
		BANNER_OUTLINE)
	if banner.subtitle != "":
		_text(font, Vector2(0, 74), banner.subtitle, 40, MenuTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 10)
	draw_set_transform(offset, 0.0, Vector2.ONE * scale_factor)


## A parallelogram leaning like the menus' panels (top edge to the right).
func _slant(rect: Rect2, color: Color, border := Color.TRANSPARENT, border_width := 0.0) -> void:
	var points := slant_points(rect)
	draw_colored_polygon(points, color)
	if border_width > 0.0:
		_slant_outline(rect, border, border_width)
	else:
		# A hairline in the fill colour smooths the slanted edges.
		points.append(points[0])
		draw_polyline(points, color, 1.0, true)


func _slant_outline(rect: Rect2, color: Color, width: float) -> void:
	var points := slant_points(rect)
	points.append(points[0])
	draw_polyline(points, color, width, true)


## Fills fraction of a slanted bar from its left (or right) end.
func _slant_fill(rect: Rect2, fraction: float, color: Color, from_right: bool) -> void:
	var width := rect.size.x * clampf(fraction, 0.0, 1.0)
	if width <= 0.5:
		return
	var x := rect.end.x - width if from_right else rect.position.x
	_slant(Rect2(x, rect.position.y, width, rect.size.y), color)


## rect (given for a left-side plate) mirrored inside plate for right-side plates.
func _mirror(plate: Rect2, rect: Rect2, right: bool) -> Rect2:
	if not right:
		return rect
	return Rect2(Vector2(plate.position.x + plate.end.x - rect.end.x, rect.position.y), rect.size)


func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color,
		align: HorizontalAlignment, outline: int = 6) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= width / 2.0
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= width
	if outline > 0:
		draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, INK)
	draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Corners of a parallelogram with the menus' skew, centred on rect.
static func slant_points(rect: Rect2) -> PackedVector2Array:
	var lean := MenuTheme.SKEW * rect.size.y * 0.5
	return PackedVector2Array([
		Vector2(rect.position.x + lean, rect.position.y), Vector2(rect.end.x + lean, rect.position.y),
		Vector2(rect.end.x - lean, rect.end.y), Vector2(rect.position.x - lean, rect.end.y),
	])


## 0..1 pulse for low health and the last seconds on the clock.
static func low_health_pulse(seconds: float) -> float:
	return 0.5 + 0.5 * sin(seconds * TAU * PULSE_HZ)


## Banner scale at age seconds: BANNER_POP easing out to 1.
static func banner_pop(age: float) -> float:
	var t := clampf(age / BANNER_POP_SECONDS, 0.0, 1.0)
	return lerpf(BANNER_POP, 1.0, 1.0 - pow(1.0 - t, 3.0))


## Title colour: hot orange for FIGHT!, gold for K.O.!/TIME!, the count and the winner, white otherwise.
static func banner_color(title: String) -> Color:
	if title == "FIGHT!":
		return MenuTheme.HOT
	if title.begins_with("ROUND"):
		return MenuTheme.TEXT
	return MenuTheme.GOLD


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
