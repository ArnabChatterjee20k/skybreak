class_name FigureGround
extends RefCounted
## Figure-ground readability of a rendered frame: how far a fighter's pixels stand out
## from the pixels just around it, and how much of the frame is clipped near white.

## Pixels whose luminance is above this count as near white.
const NEAR_WHITE := 0.95
## Background ring width around a fighter mask, in pixels.
const RING := 12
## Two renders differ at a pixel when any channel moves by more than this.
const MASK_THRESHOLD := 0.04


## Relative luminance (0..1) of an sRGB colour, as WCAG defines it.
static func luminance(c: Color) -> float:
	return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b)


## Weber contrast of a figure against its background luminance, as a magnitude.
static func weber(figure: float, background: float) -> float:
	return absf(figure - background) / maxf(background, 0.02)


## APCA-style lightness contrast Lc (0..~106) between text-like figure and background
## colours, sign dropped. Follows the SAPC 0.0.98G constants.
static func apca(figure: Color, background: Color) -> float:
	var yf := _apca_y(figure)
	var yb := _apca_y(background)
	if absf(yb - yf) < 0.0005:
		return 0.0
	var lc := 0.0
	if yb > yf:
		lc = (pow(yb, 0.56) - pow(yf, 0.57)) * 1.14
		lc = 0.0 if lc < 0.1 else lc - 0.027
	else:
		lc = (pow(yb, 0.65) - pow(yf, 0.62)) * 1.14
		lc = 0.0 if lc > -0.1 else lc + 0.027
	return absf(lc) * 100.0


## Share (0..1) of pixels in `image` brighter than NEAR_WHITE.
static func near_white_fraction(image: Image) -> float:
	var count := 0
	var w := image.get_width()
	var h := image.get_height()
	for y in h:
		for x in w:
			if luminance(image.get_pixel(x, y)) > NEAR_WHITE:
				count += 1
	return float(count) / float(maxi(w * h, 1))


## Pixels where `with_figure` differs from `without`; empty when nothing differs.
static func mask(with_figure: Image, without: Image) -> PackedByteArray:
	var w := with_figure.get_width()
	var h := with_figure.get_height()
	var out := PackedByteArray()
	out.resize(w * h)
	for y in h:
		for x in w:
			var a := with_figure.get_pixel(x, y)
			var b := without.get_pixel(x, y)
			var d := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
			out[y * w + x] = 1 if d > MASK_THRESHOLD else 0
	return out


## Contrast of the masked figure in `frame` against a RING-pixel band around it.
## `blocked` marks pixels that belong to no background (other fighters). Returns
## figure/background luminance, Weber and APCA contrast and the pixel counts.
static func measure(frame: Image, figure: PackedByteArray, blocked: PackedByteArray) -> Dictionary:
	var w := frame.get_width()
	var h := frame.get_height()
	var box := Rect2i()
	var any := false
	for i in figure.size():
		if figure[i] == 1:
			var p := Vector2i(i % w, i / w)
			box = Rect2i(p, Vector2i.ONE) if not any else box.expand(p).expand(p + Vector2i.ONE)
			any = true
	if not any:
		return {"figure_pixels": 0, "ring_pixels": 0, "weber": 0.0, "apca": 0.0, "figure_l": 0.0, "ring_l": 0.0}
	box = box.grow(RING).intersection(Rect2i(0, 0, w, h))
	# Distance-limited dilation inside the box: horizontal then vertical max filter.
	var bw := box.size.x
	var bh := box.size.y
	var near_h := PackedByteArray()
	near_h.resize(bw * bh)
	for y in bh:
		var last := -100000
		for x in bw:
			if figure[(box.position.y + y) * w + box.position.x + x] == 1:
				last = x
			near_h[y * bw + x] = 1 if x - last <= RING else 0
		last = 100000
		for x in range(bw - 1, -1, -1):
			if figure[(box.position.y + y) * w + box.position.x + x] == 1:
				last = x
			if last - x <= RING:
				near_h[y * bw + x] = 1
	var figure_sum := Color(0, 0, 0, 0)
	var ring_sum := Color(0, 0, 0, 0)
	var figure_l := 0.0
	var ring_l := 0.0
	var figure_n := 0
	var ring_n := 0
	for x in bw:
		for y in bh:
			var in_ring := false
			for k in range(maxi(y - RING, 0), mini(y + RING + 1, bh)):
				if near_h[k * bw + x] == 1:
					in_ring = true
					break
			if not in_ring:
				continue
			var i := (box.position.y + y) * w + box.position.x + x
			var c := frame.get_pixel(box.position.x + x, box.position.y + y)
			if figure[i] == 1:
				figure_sum += c
				figure_l += luminance(c)
				figure_n += 1
			elif blocked.is_empty() or blocked[i] == 0:
				ring_sum += c
				ring_l += luminance(c)
				ring_n += 1
	if figure_n == 0 or ring_n == 0:
		return {"figure_pixels": figure_n, "ring_pixels": ring_n, "weber": 0.0, "apca": 0.0, "figure_l": 0.0, "ring_l": 0.0}
	figure_l /= figure_n
	ring_l /= ring_n
	var figure_mean := figure_sum / figure_n
	var ring_mean := ring_sum / ring_n
	return {
		"figure_pixels": figure_n, "ring_pixels": ring_n, "figure_l": figure_l, "ring_l": ring_l,
		"weber": weber(figure_l, ring_l), "apca": apca(figure_mean, ring_mean),
	}


static func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _apca_y(c: Color) -> float:
	var y := 0.2126729 * pow(c.r, 2.4) + 0.7151522 * pow(c.g, 2.4) + 0.0721750 * pow(c.b, 2.4)
	return y if y >= 0.022 else y + pow(0.022 - y, 1.414)
