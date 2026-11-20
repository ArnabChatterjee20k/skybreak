"""Builds COMPARE images and motion contact sheets from the look renders.
python compose.py <renders dir> [strips dir]"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

R = sys.argv[1]
STRIPS = sys.argv[2] if len(sys.argv) > 2 else None
STYLES = [("a", "A  Current (main)"), ("b", "B  3D anime arena"), ("c", "C  Painterly"), ("d", "D  2.5D side view")]
MOMENTS = [("1_melee", "Melee hit + impact frame"), ("2_beam", "Ki beam"), ("3_wide", "Wide establishing"), ("4_ffa", "FFA-4")]


def font(size):
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def compare(zone, styles, out, tile=(440, 248)):
    label_w, head_h = 230, 50
    w = label_w + tile[0] * len(MOMENTS)
    h = head_h + tile[1] * len(styles)
    img = Image.new("RGB", (w, h), (18, 16, 22))
    d = ImageDraw.Draw(img)
    for c, (_, name) in enumerate(MOMENTS):
        d.text((label_w + c * tile[0] + 12, 12), name, fill=(240, 236, 230), font=font(20))
    for r, (sid, name) in enumerate(styles):
        y = head_h + r * tile[1]
        z = zone if sid != "a" else "ember"
        d.text((16, y + tile[1] // 2 - 40), name.split("  ")[0], fill=(255, 190, 90), font=font(56))
        d.text((16, y + tile[1] // 2 + 34), name.split("  ")[1], fill=(230, 226, 220), font=font(20))
        for c, (mid, _) in enumerate(MOMENTS):
            p = os.path.join(R, f"{sid}_{z}_{mid}.jpg")
            if os.path.exists(p):
                img.paste(Image.open(p).convert("RGB").resize(tile, Image.LANCZOS), (label_w + c * tile[0], y))
            else:
                d.text((label_w + c * tile[0] + 20, y + 20), "missing", fill=(255, 80, 80), font=font(24))
        d.line([(0, y), (w, y)], fill=(18, 16, 22), width=4)
    img.save(out, optimize=True)
    print(out, os.path.getsize(out) // 1024, "KB")


def sheet(sid, name, out, cols=7, thumb=(320, 180)):
    frames = sorted(glob.glob(os.path.join(STRIPS, sid, "f*.jpg")))
    if not frames:
        return
    rows = (len(frames) + cols - 1) // cols
    head = 50
    img = Image.new("RGB", (cols * thumb[0], head + rows * thumb[1]), (18, 16, 22))
    d = ImageDraw.Draw(img)
    d.text((12, 10), f"{name}: Ember Rift, 7 s, every 4th frame",
           fill=(240, 236, 230), font=font(20))
    for i, f in enumerate(frames):
        t = Image.open(f).convert("RGB").resize(thumb, Image.LANCZOS)
        img.paste(t, ((i % cols) * thumb[0], head + (i // cols) * thumb[1]))
        d.text(((i % cols) * thumb[0] + 4, head + (i // cols) * thumb[1] + 2), str(i * 4), fill=(255, 255, 255), font=font(14))
    img.save(out, quality=85)
    print(out, os.path.getsize(out) // 1024, "KB")


compare("ember", STYLES, os.path.join(R, "COMPARE.png"))
compare("heartbloom", STYLES[1:], os.path.join(R, "COMPARE_heartbloom.png"))
if STRIPS:
    for sid, name in STYLES:
        sheet(sid, name, os.path.join(R, "strips", f"{sid}_motion_strip.jpg"))
