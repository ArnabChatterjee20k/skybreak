"""Draws Kael's anime face (eyes, brows, nose line, mouth) as a texture over the skin colour.

UV layout matches kael_mesh.face_uv: the image covers 0.22 m x 0.22 m of the face, centred
0.02 m below the head centre. Shapes are drawn at 4x and scaled down for clean edges.
"""

from PIL import Image, ImageDraw

SIZE = 512
SS = 4


def _px(u, v):
	"""UV (v up) -> supersampled pixel coordinates."""
	return (u * SIZE * SS, (1.0 - v) * SIZE * SS)


def _uv_from_face(x, z):
	"""Face-space metres (x to his left, z up from the head centre) -> UV."""
	return (0.5 + x / 0.22, 0.5 + (z + 0.02) / 0.22)


# Scale applied around the current eye centre (1 = as drawn), set while drawing each eye.
_EYE = {"c": (0.0, 0.0), "k": 1.0}


def _eye(x, z):
	cx, cz = _EYE["c"]
	k = _EYE["k"]
	return (cx + (x - cx) * k, cz + (z - cz) * k)


def _poly(draw, pts, fill):
	draw.polygon([_px(*_uv_from_face(*_eye(x, z))) for x, z in pts], fill=fill)


def _ellipse(draw, cx, cz, rx, rz, fill):
	cx, cz = _eye(cx, cz)
	rx, rz = rx * _EYE["k"], rz * _EYE["k"]
	x0, y0 = _px(*_uv_from_face(cx - rx, cz + rz))
	x1, y1 = _px(*_uv_from_face(cx + rx, cz - rz))
	draw.ellipse([x0, y0, x1, y1], fill=fill)


def _line(draw, pts, width, fill):
	draw.line([_px(*_uv_from_face(*_eye(x, z))) for x, z in pts], fill=fill, width=int(width * SS), joint="curve")


def draw_face(skin_rgb, path):
	skin = tuple(int(c * 255) for c in skin_rgb)
	ink = (28, 20, 34)
	iris = (40, 78, 120)
	iris_dark = (16, 30, 58)
	white = (250, 250, 252)
	img = Image.new("RGB", (SIZE * SS, SIZE * SS), skin)
	d = ImageDraw.Draw(img)
	for s in (1, -1):
		# s = 1 is his left eye (image right). Eye centre, metres in face space.
		cx, cz = s * 0.043, -0.022
		_EYE["c"], _EYE["k"] = (cx, cz), 1.18
		# Sclera: a rounded shape, flatter at the bottom.
		_poly(d, [(cx - s * 0.024, cz + 0.004), (cx - s * 0.016, cz + 0.016), (cx + s * 0.004, cz + 0.02),
			(cx + s * 0.022, cz + 0.014), (cx + s * 0.027, cz + 0.002), (cx + s * 0.02, cz - 0.014),
			(cx, cz - 0.018), (cx - s * 0.016, cz - 0.012)], white)
		# Iris and pupil: tall ovals, looking slightly inward.
		_ellipse(d, cx - s * 0.003, cz - 0.001, 0.0125, 0.0175, iris)
		_ellipse(d, cx - s * 0.003, cz + 0.004, 0.0115, 0.011, iris_dark)
		_ellipse(d, cx - s * 0.003, cz - 0.001, 0.0055, 0.008, (10, 14, 26))
		# Highlights.
		_ellipse(d, cx - s * 0.008, cz + 0.007, 0.0042, 0.0042, white)
		_ellipse(d, cx + s * 0.003, cz - 0.009, 0.002, 0.002, white)
		# Upper lid: a thick ink band with a short flick at the outer corner.
		_poly(d, [(cx - s * 0.026, cz + 0.002), (cx - s * 0.017, cz + 0.017), (cx + s * 0.004, cz + 0.023),
			(cx + s * 0.024, cz + 0.017), (cx + s * 0.034, cz + 0.008), (cx + s * 0.03, cz + 0.007),
			(cx + s * 0.022, cz + 0.011), (cx + s * 0.004, cz + 0.016), (cx - s * 0.016, cz + 0.011),
			(cx - s * 0.023, cz + 0.0)], ink)
		# Lower lid: a thin short line on the outer half.
		_line(d, [(cx - s * 0.004, cz - 0.019), (cx + s * 0.014, cz - 0.016), (cx + s * 0.022, cz - 0.01)],
			3.0, ink)
		_EYE["k"] = 1.0
		# Brows: thick, rising toward the outside for a determined look.
		_poly(d, [(s * 0.016, 0.012), (s * 0.03, 0.022), (s * 0.05, 0.028), (s * 0.068, 0.025),
			(s * 0.066, 0.019), (s * 0.05, 0.02), (s * 0.03, 0.014), (s * 0.018, 0.007)], ink)
	# Nose: a short shadow line on one side.
	_line(d, [(-0.004, -0.045), (-0.007, -0.058), (-0.002, -0.061)], 3.0, (190, 120, 100))
	# Mouth: a short line with a slight smirk.
	_line(d, [(-0.017, -0.089), (0.0, -0.091), (0.016, -0.087)], 4.0, (120, 50, 50))
	img = img.resize((SIZE, SIZE), Image.LANCZOS)
	img.save(path)
