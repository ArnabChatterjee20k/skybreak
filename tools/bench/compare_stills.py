#!/usr/bin/env python3
"""Compares before/after zone stills: SSIM (luma, 8 px windows), mean abs
difference, share of pixels changed by more than 8/255 and 24/255, and a
small sheet per zone (before | after | difference x4) for reports/perf/.

  python3 tools/bench/compare_stills.py <before dir> <after dir> <sheet dir>

Each dir holds <zone>/<shot>.png. Needs numpy and Pillow.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def box(a, k=8):
    """Mean over k x k windows (valid region), via an integral image."""
    c = np.pad(a, ((1, 0), (1, 0))).cumsum(0).cumsum(1)
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


def ssim(x, y):
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    mx, my = box(x), box(y)
    vx, vy = box(x * x) - mx * mx, box(y * y) - my * my
    cxy = box(x * y) - mx * my
    s = ((2 * mx * my + c1) * (2 * cxy + c2)) / ((mx * mx + my * my + c1) * (vx + vy + c2))
    return float(s.mean())


def luma(a):
    return a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114


def main():
    before, after, sheets = (Path(p) for p in sys.argv[1:4])
    sheets.mkdir(parents=True, exist_ok=True)
    print("| Zone | Shot | SSIM | Mean diff (/255) | Pixels > 8/255 | Pixels > 24/255 |")
    print("|---|---|---|---|---|---|")
    for zone in sorted(p.name for p in before.iterdir() if p.is_dir()):
        rows = []
        for shot in sorted((before / zone).glob("*.png")):
            other = after / zone / shot.name
            if not other.exists():
                continue
            a = np.asarray(Image.open(shot).convert("RGB")).astype(np.float64)
            b = np.asarray(Image.open(other).convert("RGB")).astype(np.float64)
            d = np.abs(a - b).max(2)
            print("| %s | %s | %.4f | %.2f | %.2f%% | %.3f%% |" % (zone, shot.stem, ssim(luma(a), luma(b)),
                np.abs(a - b).mean(), (d > 8).mean() * 100, (d > 24).mean() * 100))
            small = (480, 270)
            diff = Image.fromarray(np.clip(np.abs(a - b) * 4, 0, 255).astype(np.uint8))
            rows.append([Image.open(shot).convert("RGB").resize(small, Image.LANCZOS),
                Image.open(other).convert("RGB").resize(small, Image.LANCZOS), diff.resize(small, Image.BOX)])
        if rows:
            sheet = Image.new("RGB", (small[0] * 3, small[1] * len(rows)))
            for r, row in enumerate(rows):
                for c, im in enumerate(row):
                    sheet.paste(im, (c * small[0], r * small[1]))
            sheet.save(sheets / ("%s_before_after.jpg" % zone), quality=82)


if __name__ == "__main__":
    main()
