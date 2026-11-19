"""Bakes every Skybreak sound effect to OGG Vorbis, writes the SoundBank .tres files,
the licence manifest and the loudness report.

Usage (from the repo root):
    python3 game/audio/source/bake.py

Needs numpy, scipy, soundfile, pyloudnorm (pip) and ffmpeg with libvorbis.
"""
import os
import subprocess
import sys
import tempfile
import zlib
from collections import defaultdict

import numpy as np
import pyloudnorm
import soundfile
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dsp import SR  # noqa: E402
from sounds import CATEGORY_LUFS, CUES  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
AUDIO = os.path.join(ROOT, "game", "audio")
PEAK_CEILING_DB = -2.0  # Before encoding; Vorbis may add a few tenths, so the shipped limit is -1 dBTP.
SHIPPED_PEAK_DB = -1.0


def res_path(cue, v):
	suffix = "" if cue.variations == 1 else "_%d" % (v + 1)
	return "res://game/audio/sfx/%s/%s%s.ogg" % (cue.category, cue.id, suffix)


def disk_path(res):
	return os.path.join(ROOT, res[len("res://"):])


def true_peak_db(x):
	up = signal.resample_poly(np.atleast_2d(x), 4, 1, axis=-1)
	return 20 * np.log10(np.max(np.abs(up)) + 1e-12)


def loudness(x):
	meter = pyloudnorm.Meter(SR, block_size=0.1)
	data = np.atleast_2d(x).T
	if len(data) < int(0.4 * SR):
		data = np.vstack([data, np.zeros((int(0.4 * SR) - len(data), data.shape[1]))])
	return meter.integrated_loudness(data)


def render(cue, v):
	rng = np.random.default_rng(zlib.crc32(("%s:%d" % (cue.id, v)).encode()))
	x = np.asarray(cue.recipe(rng, v), dtype=np.float64)
	if not cue.loop:
		x = signal.sosfiltfilt(signal.butter(2, 25.0 / (SR / 2), "high", output="sos"), x, axis=-1)
		x = x - np.mean(x, axis=-1, keepdims=True)
		edge = min(64, x.shape[-1] // 4)
		x[..., :edge] *= np.linspace(0, 1, edge)
		x[..., -edge:] *= np.linspace(1, 0, edge)
	x /= np.max(np.abs(x)) + 1e-12
	if not cue.loop:
		# Trim the silent end (below -60 dB) so a voice frees as soon as it is quiet.
		loud = np.nonzero(np.max(np.abs(np.atleast_2d(x)), axis=0) > 1e-3)[0]
		end = min(x.shape[-1], loud[-1] + int(0.02 * SR)) if len(loud) else x.shape[-1]
		x = x[..., :end].copy()
		tail = min(int(0.02 * SR), end // 4)
		x[..., end - tail:] *= np.linspace(1, 0, tail)
	target = CATEGORY_LUFS[cue.category]
	x *= 10 ** ((target - loudness(x)) / 20)
	over = true_peak_db(x) - PEAK_CEILING_DB
	if over > 0 and not cue.loop:
		# Soft-saturate up to 6 dB of transient peak so hits keep their weight, then re-level.
		ceiling = 10 ** ((PEAK_CEILING_DB + min(over, 6.0) - 6.0) / 20)
		drive = 10 ** (min(over, 6.0) / 20)
		x = ceiling * drive * np.tanh(x / (ceiling * drive) * 1.0)
		x *= 10 ** ((target - loudness(x)) / 20)
		over = true_peak_db(x) - PEAK_CEILING_DB
	if over > 0:
		x *= 10 ** (-over / 20)
	return x


def encode(x, out_path, quality):
	os.makedirs(os.path.dirname(out_path), exist_ok=True)
	with tempfile.TemporaryDirectory() as tmp:
		wav = os.path.join(tmp, "in.wav")
		soundfile.write(wav, np.atleast_2d(x).T, SR, subtype="FLOAT")
		subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", str(quality),
			"-ar", str(SR), "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", out_path], check=True)


def analyse(path, loop):
	data, rate = soundfile.read(path, always_2d=True)
	x = data.T
	diffs = np.abs(np.diff(x, axis=-1))
	stats = {
		"rate": rate, "seconds": x.shape[-1] / rate, "channels": x.shape[0],
		"lufs": loudness(x), "true_peak": true_peak_db(x), "sample_peak": 20 * np.log10(np.max(np.abs(x)) + 1e-12),
		"rms_db": 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12), "dc": float(np.max(np.abs(np.mean(x, axis=-1)))),
	}
	if loop:
		# Wrap-around step against the file's own sample-to-sample motion.
		seam = np.max(np.abs(x[:, -1] - x[:, 0]))
		stats["seam_ratio"] = float(seam / (np.percentile(diffs, 99.9) + 1e-12))
	return stats


def tres_value(v):
	if isinstance(v, bool):
		return "true" if v else "false"
	if isinstance(v, float):
		return repr(round(v, 4))
	return str(v)


def write_bank(category, cues):
	lines = ['[gd_resource type="Resource" script_class="SoundBank" format=3]', "",
		'[ext_resource type="Script" path="res://game/audio/sound_bank.gd" id="bank"]',
		'[ext_resource type="Script" path="res://game/audio/sound_cue.gd" id="cue"]']
	stream_ids = {}
	for cue in cues:
		for v in range(cue.variations):
			sid = "s%d" % (len(stream_ids) + 1)
			stream_ids[(cue.id, v)] = sid
			lines.append('[ext_resource type="AudioStreamOggVorbis" path="%s" id="%s"]' % (res_path(cue, v), sid))
	for cue in cues:
		streams = ", ".join('ExtResource("%s")' % stream_ids[(cue.id, v)] for v in range(cue.variations))
		layers = ", ".join('&"%s"' % layer for layer in cue.layers)
		lines += ["", '[sub_resource type="Resource" id="%s"]' % cue.id, 'script = ExtResource("cue")',
			'id = &"%s"' % cue.id,
			"streams = Array[AudioStream]([%s])" % streams,
			'bus = &"%s"' % cue.bus,
			"volume_db = %s" % tres_value(float(cue.volume_db)),
			"pitch_min = %s" % tres_value(float(cue.pitch[0])),
			"pitch_max = %s" % tres_value(float(cue.pitch[1])),
			"volume_jitter_db = %s" % tres_value(float(cue.volume_jitter_db)),
			"max_voices = %d" % cue.max_voices,
			"priority = %d" % cue.priority,
			"cooldown = %s" % tres_value(float(cue.cooldown)),
			"positional = %s" % tres_value(cue.positional),
			"unit_size = %s" % tres_value(float(cue.unit_size)),
			"max_distance = %s" % tres_value(float(cue.max_distance)),
			"loop = %s" % tres_value(cue.loop),
			"layers = Array[StringName]([%s])" % layers,
			"duck_db = %s" % tres_value(float(cue.duck_db)),
			"duck_seconds = %s" % tres_value(float(cue.duck_seconds))]
	refs = ", ".join('SubResource("%s")' % cue.id for cue in cues)
	lines += ["", "[resource]", 'script = ExtResource("bank")', 'category = &"%s"' % category,
		'cues = Array[ExtResource("cue")]([%s])' % refs, ""]
	with open(os.path.join(AUDIO, "banks", "%s_bank.tres" % category), "w") as f:
		f.write("\n".join(lines))


def main():
	by_category = defaultdict(list)
	report = []
	only = set(sys.argv[1:])
	for cue in CUES:
		by_category[cue.category].append(cue)
		if only and cue.id not in only:
			continue
		for v in range(cue.variations):
			res = res_path(cue, v)
			x = render(cue, v)
			encode(x, disk_path(res), 3 if cue.category == "ambience" else 4)
			stats = analyse(disk_path(res), cue.loop)
			report.append((cue, res, stats))
			print("%-48s %5.2fs %6.1f LUFS %5.1f dBTP" % (res[len("res://game/audio/sfx/"):], stats["seconds"], stats["lufs"], stats["true_peak"]))
	for category, cues in by_category.items():
		write_bank(category, cues)
	if not only:
		write_reports(report)
	failures = [r for r in report if r[2]["true_peak"] > SHIPPED_PEAK_DB or r[2]["rms_db"] < -60 or r[2]["dc"] > 0.002
		or r[2].get("seam_ratio", 0) > 1.0 or r[2]["rate"] != SR]
	for cue, res, stats in failures:
		print("FAIL", res, stats)
	return 1 if failures else 0


def write_reports(report):
	rows = defaultdict(list)
	for cue, res, stats in report:
		rows[cue.category].append(stats)
	total = sum(os.path.getsize(disk_path(res)) for _, res, _ in report)
	table = ["| Category | Files | Target LUFS | LUFS min / mean / max | Max true peak (dBTP) | Max DC | Worst loop seam |",
		"|---|---|---|---|---|---|---|"]
	for category in CATEGORY_LUFS:
		s = rows[category]
		lufs = [x["lufs"] for x in s]
		seams = [x["seam_ratio"] for x in s if "seam_ratio" in x]
		table.append("| %s | %d | %.0f | %.1f / %.1f / %.1f | %.2f | %.4f | %s |" % (category, len(s), CATEGORY_LUFS[category],
			min(lufs), float(np.mean(lufs)), max(lufs), max(x["true_peak"] for x in s), max(x["dc"] for x in s),
			"%.2f" % max(seams) if seams else "-"))
	table.append("")
	table.append("%d files, %.2f MB of OGG Vorbis at 44.1 kHz." % (len(report), total / 1e6))
	with open(os.path.join(AUDIO, "source", "loudness.md"), "w") as f:
		f.write("# Loudness report (written by bake.py)\n\nMeasured on the shipped OGG files: ITU-R BS.1770 "
			"integrated loudness with 100 ms blocks (pyloudnorm), true peak at 4x oversampling. Short "
			"transient cues sit below their category target when the -2 dBTP pre-encode ceiling caps "
			"them. Loop seam = wrap-around step / 99.9th percentile sample step (< 1 means no click).\n\n")
		f.write("\n".join(table) + "\n")
	lines = ["# Audio licences", "",
		"Every file under `game/audio/sfx/` is synthesised from scratch by `game/audio/source/bake.py`",
		"(the recipe named below, in `sounds.py`). No samples, recordings or third-party packs are used.",
		"", "- Author: Skybreak contributors (generated code), 2026", "- Licence: CC0 1.0 (public domain dedication)",
		"- Source URL: this repository, `game/audio/source/`", "",
		"| File | Recipe | Source | Licence | Author |", "|---|---|---|---|---|"]
	for cue, res, _ in report:
		lines.append("| `%s` | `%s` | game/audio/source/sounds.py | CC0 1.0 | Skybreak contributors |" % (
			res[len("res://game/audio/"):], getattr(cue.recipe, "__name__", "lambda").replace("<lambda>", "inline")))
	with open(os.path.join(AUDIO, "LICENSES.md"), "w") as f:
		f.write("\n".join(lines) + "\n")
	print("total %.2f MB in %d files" % (total / 1e6, len(report)))


if __name__ == "__main__":
	sys.exit(main())
