"""Draws chunky Kael's face (big eyes, bold brows, grin) as a texture over the skin colour.

UV layout matches kael_mesh.face_uv: the image covers FACE_SIZE x FACE_SIZE metres of the face,
centred FACE_DROP below the head centre. Shapes are drawn at 4x and scaled down for clean edges.
"""

from PIL import Image, ImageDraw

from kael_mesh import FACE_SIZE

SIZE = 512
SS = 4


def _px(x, z):
	"""Face-space metres (x to his left, z up from the face centre) -> supersampled pixels."""
	u = 0.5 + x / FACE_SIZE
	v = 0.5 + z / FACE_SIZE
	return (u * SIZE * SS, (1.0 - v) * SIZE * SS)


def _poly(draw, pts, fill):
	draw.polygon([_px(x, z) for x, z in pts], fill=fill)


def _ellipse(draw, cx, cz, rx, rz, fill):
	x0, y0 = _px(cx - rx, cz + rz)
	x1, y1 = _px(cx + rx, cz - rz)
	draw.ellipse([x0, y0, x1, y1], fill=fill)


def _line(draw, pts, width, fill):
	draw.line([_px(x, z) for x, z in pts], fill=fill, width=int(width * SS), joint="curve")


def draw_face(skin_rgb, path):
	skin = tuple(int(c * 255) for c in skin_rgb)
	ink = (34, 22, 30)
	white = (252, 252, 250)
	iris = (26, 120, 140)
	iris_dark = (12, 58, 78)
	blush = (244, 160, 140)
	img = Image.new("RGB", (SIZE * SS, SIZE * SS), skin)
	d = ImageDraw.Draw(img)
	for s in (1, -1):
		cx, cz = s * 0.07, 0.0
		_ellipse(d, cx + s * 0.03, cz - 0.06, 0.026, 0.013, blush)
		# Sclera: a tall rounded shape.
		_ellipse(d, cx, cz, 0.036, 0.047, white)
		# Iris looking slightly inward, with a darker top and a pupil.
		ix = cx - s * 0.006
		_ellipse(d, ix, cz - 0.004, 0.026, 0.036, iris)
		_ellipse(d, ix, cz + 0.008, 0.025, 0.024, iris_dark)
		_ellipse(d, ix, cz - 0.002, 0.011, 0.016, (8, 20, 30))
		# Highlights: one big, one small.
		_ellipse(d, ix - s * 0.01, cz + 0.014, 0.009, 0.011, white)
		_ellipse(d, ix + s * 0.008, cz - 0.018, 0.0045, 0.0045, white)
		# Upper lid: a thick ink arc with a flick at the outer corner.
		_poly(d, [(cx - s * 0.04, cz + 0.006), (cx - s * 0.03, cz + 0.038), (cx, cz + 0.05),
			(cx + s * 0.03, cz + 0.042), (cx + s * 0.05, cz + 0.03), (cx + s * 0.044, cz + 0.022),
			(cx + s * 0.03, cz + 0.03), (cx, cz + 0.038), (cx - s * 0.026, cz + 0.028), (cx - s * 0.034, cz + 0.0)],
			ink)
		# Lower lid: a short line under the outer half.
		_line(d, [(cx - s * 0.006, cz - 0.047), (cx + s * 0.018, cz - 0.042), (cx + s * 0.03, cz - 0.03)], 4.0, ink)
		# Brows: thick, low at the centre and lifting outward: determined, not angry.
		_poly(d, [(s * 0.028, 0.06), (s * 0.06, 0.074), (s * 0.1, 0.08), (s * 0.108, 0.07),
			(s * 0.07, 0.062), (s * 0.034, 0.05)], ink)
	# Grin: a wide curve lifting at his left, with a hint of open mouth.
	_poly(d, [(-0.035, -0.098), (-0.012, -0.108), (0.016, -0.108), (0.04, -0.094), (0.036, -0.09),
		(0.012, -0.1), (-0.012, -0.1), (-0.032, -0.094)], (110, 40, 44))
	_line(d, [(-0.04, -0.094), (-0.012, -0.104), (0.016, -0.104), (0.044, -0.088)], 3.5, ink)
	img = img.resize((SIZE, SIZE), Image.LANCZOS)
	img.save(path)
