#!/usr/bin/env python3
"""Builds the gameplay QA report from a run directory (tools/qa/run_qa.sh calls it).

Reads <run>/soak/match_*.json, <run>/feel.json, <run>/scenarios.log, <run>/goldens.log,
<run>/visual/*.png, writes <run>/metrics.json, <run>/report.json and the markdown report.
Only needs the Python standard library plus numpy and Pillow for the visual diff.
"""
import argparse
import glob
import json
import os
import re
import statistics
import sys

# Checks that are pending until the lane named lands on main.
PENDING_UNTIL = {"fighter_overlap": "T-D29 (pushboxes)"}
SECTIONS = ["Invariant soak (sim)", "Invariant soak (view)", "Scenario library",
            "Golden replays", "Visual goldens", "Feel metrics trend"]
SIM_CHECKS = {"nan", "meter_range", "stuck_state", "arena_bounds", "fighter_overlap",
              "entity_count", "round_reset"}
# Metric -> True when higher is worse. Regression = worse by more than REGRESSION.
METRICS = {
    "hitstop_consistency": False,
    "pops_per_fighter_minute": True,
    "finger_pops_per_fighter_minute": True,
    "foot_slide_cm_per_frame": True,
    "foot_error_p95_cm": True,
    "camera_jerk_p95": True,
    "locked_on_screen_share": False,
    "sim_ms_per_tick": True,
    "view_ms_per_frame": True,
}
REGRESSION = 0.15
# Metric -> definition version. Bump it when a metric's definition changes; the trend then
# skips that metric against older reports (shown as "re-baselined") and this run becomes its
# new reference. Reports without "metric_versions" are version 1.
# foot_slide_cm_per_frame v2 (T-D34): no slide across teleports, hidden frames or the first
# frames of a round, and only feet within FOOT_TOLERANCE of the ground (floating ones skipped).
METRIC_VERSIONS = {"foot_slide_cm_per_frame": 2}
# Visual goldens: tiles of TILE px; a tile changes when its mean abs delta (0-255) passes
# TILE_DELTA; a shot fails when SSIM < SSIM_MIN or more than TILE_SHARE of tiles change.
TILE = 32
TILE_DELTA = 12.0
TILE_SHARE = 0.05
SSIM_MIN = 0.90


def load_matches(run):
    out = []
    for path in sorted(glob.glob(os.path.join(run, "soak", "match_*.json"))):
        with open(path) as f:
            out.append(json.load(f))
    return out


def repro(match, tick, fighter=0):
    return "tools/qa/run_qa.sh --repro '%s' --tick %d --fighter %d" % (match["id"], tick, max(fighter, 0))


def soak_sections(matches):
    sim, view = [], []
    for m in matches:
        for v in m["violations"]:
            row = dict(v, match=m["id"], seed=m["seed"], zone=m["zone"], mode=m["mode"],
                       repro=repro(m, v["worst_tick"], v["fighter"]))
            row["pending"] = m.get("overlap_pending") and v["check"] in PENDING_UNTIL
            (sim if v["check"] in SIM_CHECKS else view).append(row)
    return sim, view


def summarize(rows):
    by = {}
    for r in rows:
        e = by.setdefault(r["check"], {"matches": set(), "count": 0, "pending": r["pending"]})
        e["matches"].add(r["match"])
        e["count"] += r["count"]
    return {k: {"matches": len(v["matches"]), "frames": v["count"], "pending": v["pending"]}
            for k, v in by.items()}


def severity(row):
    try:
        value, limit = float(row["worst_value"]), float(row["limit"])
    except (TypeError, ValueError):
        return 0.0
    ratio = abs(value - limit) / max(abs(limit), 1e-6)
    return (0 if row["pending"] else 1, row["count"] * (1.0 + ratio))


def top_violations(rows, count):
    """Worst first, taking turns between checks so one noisy check can't fill the list."""
    by = {}
    for r in sorted(rows, key=severity, reverse=True):
        by.setdefault(r["check"], []).append(r)
    order = sorted(by, key=lambda c: severity(by[c][0]), reverse=True)
    out = []
    while len(out) < count and any(by.values()):
        for c in order:
            if by[c] and len(out) < count:
                out.append(by[c].pop(0))
    return out


def hitstop_consistency(matches):
    counts = {}
    for m in matches:
        for move, by in m.get("hitstops", {}).items():
            agg = counts.setdefault(move, {})
            for stop, n in by.items():
                agg[stop] = agg.get(stop, 0) + n
    total = sum(sum(v.values()) for v in counts.values())
    modal = sum(max(v.values()) for v in counts.values())
    return (modal / total if total else 1.0), counts


def metrics_of(matches, feel):
    vals = {k: [] for k in METRICS}
    for m in matches:
        for k in ("sim_ms_per_tick", "view_ms_per_frame"):
            vals[k].append(m[k])
        for k, v in m.get("view", {}).items():
            if k in vals:
                vals[k].append(v)
    out = {k: (statistics.mean(v) if v else None) for k, v in vals.items()}
    out["hitstop_consistency"], _ = hitstop_consistency(matches)
    out["metric_versions"] = dict(METRIC_VERSIONS)
    out["latency_ticks"] = {legend: {probe: r["ticks"] for probe, r in per.items()}
                            for legend, per in (feel or {}).items()}
    return out


def previous_metrics(reports_dir, current_run, mode):
    """Newest earlier run of the same mode (quick and full play different matrices)."""
    candidates = sorted(glob.glob(os.path.join(reports_dir, "*-" + mode, "metrics.json")),
                        key=os.path.getmtime)
    candidates = [c for c in candidates if os.path.dirname(os.path.abspath(c)) != os.path.abspath(current_run)]
    if not candidates:
        return None, None
    with open(candidates[-1]) as f:
        return json.load(f), candidates[-1]


def trend(current, previous):
    rows = []
    then_versions = (previous or {}).get("metric_versions", {})
    for k, higher_worse in METRICS.items():
        now, then = current.get(k), (previous or {}).get(k)
        if then is not None and then_versions.get(k, 1) != METRIC_VERSIONS.get(k, 1):
            rows.append((k, now, then, "rebaselined", False))
            continue
        if now is None or then is None or then == 0:
            rows.append((k, now, then, None, False))
            continue
        change = (now - then) / abs(then)
        worse = change > REGRESSION if higher_worse else change < -REGRESSION
        rows.append((k, now, then, change, worse))
    for legend, per in current.get("latency_ticks", {}).items():
        for probe, ticks in per.items():
            then = (previous or {}).get("latency_ticks", {}).get(legend, {}).get(probe)
            if then:
                change = (ticks - then) / then
                if change > REGRESSION:
                    rows.append(("latency %s %s" % (legend, probe), ticks, then, change, True))
    return rows


def ssim(a, b):
    import numpy as np
    a = a.astype(np.float64)
    b = b.astype(np.float64)
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    # SSIM on 8x8 blocks, averaged.
    h, w = (a.shape[0] // 8) * 8, (a.shape[1] // 8) * 8
    a = a[:h, :w].reshape(h // 8, 8, w // 8, 8)
    b = b[:h, :w].reshape(h // 8, 8, w // 8, 8)
    ma, mb = a.mean(axis=(1, 3)), b.mean(axis=(1, 3))
    va, vb = a.var(axis=(1, 3)), b.var(axis=(1, 3))
    cov = ((a - ma[:, None, :, None]) * (b - mb[:, None, :, None])).mean(axis=(1, 3))
    s = ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma ** 2 + mb ** 2 + c1) * (va + vb + c2))
    return float(s.mean())


def visual(run, golden_dir, out_dir):
    try:
        import numpy as np
        from PIL import Image
    except ImportError:
        return None, "numpy/Pillow missing"
    shots = sorted(glob.glob(os.path.join(run, "visual", "*.png")))
    if not shots:
        return None, "no shots rendered"
    rows = []
    os.makedirs(out_dir, exist_ok=True)
    for shot in shots:
        name = os.path.basename(shot)
        golden = os.path.join(golden_dir, name)
        if not os.path.exists(golden):
            rows.append({"shot": name, "status": "NEW", "ssim": None, "tiles": None})
            continue
        a_img = Image.open(golden).convert("RGB")
        b_img = Image.open(shot).convert("RGB").resize(a_img.size)
        a, b = np.asarray(a_img), np.asarray(b_img)
        grey_a, grey_b = a.mean(axis=2), b.mean(axis=2)
        score = ssim(grey_a, grey_b)
        delta = np.abs(a.astype(np.int16) - b.astype(np.int16)).mean(axis=2)
        th, tw = delta.shape[0] // TILE, delta.shape[1] // TILE
        tiles = delta[:th * TILE, :tw * TILE].reshape(th, TILE, tw, TILE).mean(axis=(1, 3))
        changed = float((tiles > TILE_DELTA).mean())
        failed = score < SSIM_MIN or changed > TILE_SHARE
        row = {"shot": name, "status": "FAIL" if failed else "PASS", "ssim": score, "tiles": changed}
        if failed:
            heat = np.clip(delta * 4, 0, 255).astype(np.uint8)
            side = np.concatenate([a, b, np.stack([heat] * 3, axis=2)], axis=1)
            diff_path = os.path.join(out_dir, "diff_" + name)
            Image.fromarray(side).save(diff_path)
            row["diff"] = diff_path
        rows.append(row)
    return rows, None


def gut_summary(log_path):
    if not os.path.exists(log_path):
        return None
    text = re.sub(r"\x1b\[[0-9;]*m", "", open(log_path, errors="replace").read())
    def num(label):
        m = re.search(r"^%s\s+(\d+)" % label, text, re.M)
        return int(m.group(1)) if m else 0
    failing = re.findall(r"^res://\S+\n- (test_\w+)\n\s+\[Failed\]:\s*(.*)$", text, re.M)
    pending = re.findall(r"^- (test_\w+)\n\s+\[Pending\]:\s*(.*)$", text, re.M)
    return {"tests": num("Tests"), "passing": num("Passing Tests"), "failing": num("Failing Tests"),
            "pending": num("Pending Tests"), "failures": failing[:40], "pendings": pending[:40]}


def rel(path, base):
    return os.path.relpath(path, base)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("run")
    p.add_argument("--markdown", required=True)
    p.add_argument("--sha", default="")
    p.add_argument("--mode", default="quick")
    p.add_argument("--reports-dir", default="reports/qa")
    p.add_argument("--golden-dir", default="tests/qa/goldens/visual")
    args = p.parse_args()
    run = args.run
    matches = load_matches(run)
    feel = json.load(open(os.path.join(run, "feel.json"))) if os.path.exists(os.path.join(run, "feel.json")) else None
    sim_rows, view_rows = soak_sections(matches)
    metrics = metrics_of(matches, feel)
    previous, previous_path = previous_metrics(args.reports_dir, run, args.mode)
    trend_rows = trend(metrics, previous)
    json.dump(metrics, open(os.path.join(run, "metrics.json"), "w"), indent=2)
    vis_rows, vis_note = visual(run, args.golden_dir, os.path.join(run, "visual_diff"))
    scenarios = gut_summary(os.path.join(run, "scenarios.log"))
    goldens = gut_summary(os.path.join(run, "goldens.log"))

    def status_rows(rows):
        real = [r for r in rows if not r["pending"]]
        if not matches:
            return "NOT RUN"
        return "FAIL" if real else ("PENDING" if rows else "PASS")

    status = {
        SECTIONS[0]: status_rows(sim_rows),
        SECTIONS[1]: status_rows(view_rows),
        SECTIONS[2]: "NOT RUN" if not scenarios else ("FAIL" if scenarios["failing"] else "PASS"),
        SECTIONS[3]: "NOT RUN" if not goldens else ("FAIL" if goldens["failing"] or not goldens["tests"] else "PASS"),
        SECTIONS[4]: "NOT RUN" if vis_rows is None else (
            "FAIL" if any(r["status"] == "FAIL" for r in vis_rows) else
            ("NEW" if any(r["status"] == "NEW" for r in vis_rows) else "PASS")),
        SECTIONS[5]: "BASELINE" if previous is None else ("FAIL" if any(r[4] for r in trend_rows) else "PASS"),
    }
    top = top_violations(sim_rows + view_rows, 10)
    base = os.path.dirname(os.path.abspath(args.markdown))
    for row in top:
        frames = os.path.join(run, "captures", row["match"].replace(":", "_").replace(",", "-") + "_t%d" % row["worst_tick"])
        if os.path.isdir(frames):
            pngs = sorted(glob.glob(os.path.join(frames, "frame_*.png")))
            if pngs:
                row["image"] = rel(pngs[-1], base)
            clip = os.path.join(frames, "clip.mp4")
            if os.path.exists(clip):
                row["clip"] = rel(clip, base)

    md = []
    md.append("# Gameplay QA report: %s (%s)\n" % (args.sha or "unknown", args.mode))
    md.append("Matches: %d, ticks: %d, total wall %.0f s. Thresholds are documented in `AGENTS.md` (QA).\n" % (
        len(matches), sum(m["ticks"] for m in matches), sum(m.get("wall_seconds", 0) for m in matches)))
    md.append("| Section | Result |\n|---|---|")
    for s in SECTIONS:
        md.append("| %s | **%s** |" % (s, status[s]))
    md.append("")
    for title, rows in (("Invariant soak: sim", sim_rows), ("Invariant soak: view", view_rows)):
        md.append("## %s\n" % title)
        summary = summarize(rows)
        if not summary:
            md.append("No violations.\n")
            continue
        md.append("| Check | Matches hit | Frames | Note |\n|---|---|---|---|")
        for check, e in sorted(summary.items(), key=lambda kv: -kv[1]["matches"]):
            note = "pending %s" % PENDING_UNTIL[check] if e["pending"] else ""
            md.append("| %s | %d / %d | %d | %s |" % (check, e["matches"], len(matches), e["frames"], note))
        md.append("")
    md.append("## Top 10 violations\n")
    for i, r in enumerate(top, 1):
        md.append("%d. **%s**%s, %s, legend %s, weapon %s, zone %s, %s, seed %d, worst at tick %d (first %d, %d frames): %s  " % (
            i, r["check"], " (pending)" if r["pending"] else "", "fighter %d" % r["fighter"] if r["fighter"] >= 0 else "match",
            r.get("legend") or "-", r.get("weapon") or "unarmed", r["zone"], r["mode"], r["seed"],
            r["worst_tick"], r["first_tick"], r["count"], r["detail"]))
        md.append("   `%s`" % r["repro"])
        if "image" in r:
            md.append("\n   ![%s](%s)%s" % (r["check"], r["image"], " [2 s clip](%s)" % r["clip"] if "clip" in r else ""))
        md.append("")
    md.append("## Scenario library\n")
    if scenarios:
        md.append("%d tests: %d passing, %d failing, %d pending (strict mode: known issues fail).\n" % (
            scenarios["tests"], scenarios["passing"], scenarios["failing"], scenarios["pending"]))
        for name, why in scenarios["failures"]:
            md.append("- FAIL `%s`: %s" % (name, why.strip()))
        md.append("")
    md.append("## Golden replays\n")
    if goldens:
        md.append("%d tests, %d failing.\n" % (goldens["tests"], goldens["failing"]))
        for name, why in goldens["failures"]:
            md.append("- FAIL `%s`: %s" % (name, why.strip()))
        md.append("")
    md.append("## Visual goldens\n")
    if vis_rows is None:
        md.append("Not run: %s.\n" % vis_note)
    else:
        md.append("SSIM floor %.2f, tile %dpx changes above %.0f/255, fail above %.0f%% of tiles.\n" % (
            SSIM_MIN, TILE, TILE_DELTA, TILE_SHARE * 100))
        md.append("| Shot | Result | SSIM | Changed tiles |\n|---|---|---|---|")
        for r in vis_rows:
            md.append("| %s | %s | %s | %s |" % (r["shot"], r["status"],
                "-" if r["ssim"] is None else "%.3f" % r["ssim"],
                "-" if r["tiles"] is None else "%.1f%%" % (r["tiles"] * 100)))
            if "diff" in r:
                md.append("\n![diff %s](%s)\n" % (r["shot"], rel(r["diff"], base)))
        md.append("")
    md.append("## Feel metrics\n")
    md.append("Compared with %s; regression = worse by more than %d%%.\n" % (
        previous_path or "nothing (first report: this is the baseline)", REGRESSION * 100))
    md.append("| Metric | Now | Before | Change |\n|---|---|---|---|")
    for k, now, then, change, worse in trend_rows:
        fmt = lambda x: "-" if x is None else ("%.4g" % x)
        md.append("| %s | %s | %s | %s%s |" % (k, fmt(now), fmt(then),
            "-" if change is None else ("re-baselined (v%d)" % METRIC_VERSIONS[k] if change == "rebaselined"
            else "%+.0f%%" % (change * 100)), " **REGRESSION**" if worse else ""))
    if metrics.get("latency_ticks"):
        md.append("\nPress to first active frame (ticks at 60 Hz):\n")
        probes = sorted(next(iter(metrics["latency_ticks"].values())).keys())
        md.append("| Legend | " + " | ".join(probes) + " |\n|---|" + "---|" * len(probes))
        for legend, per in metrics["latency_ticks"].items():
            md.append("| %s | %s |" % (legend, " | ".join(str(per[p]) for p in probes)))
    md.append("")
    with open(args.markdown, "w") as f:
        f.write("\n".join(md) + "\n")
    report = {"status": status, "matches": len(matches), "top": top, "metrics": metrics,
              "trend": trend_rows, "visual": vis_rows, "scenarios": scenarios, "goldens": goldens,
              "sim_summary": summarize(sim_rows), "view_summary": summarize(view_rows)}
    json.dump(report, open(os.path.join(run, "report.json"), "w"), indent=2, default=str)
    # Top-violation list for run_qa.sh to capture: "<spec id> <tick> <dir>".
    with open(os.path.join(run, "capture_list.txt"), "w") as f:
        for r in top:
            name = r["match"].replace(":", "_").replace(",", "-") + "_t%d" % r["worst_tick"]
            f.write("%s %d %s %d\n" % (r["match"], r["worst_tick"], name, max(r["fighter"], 0)))
    print("\n".join("%s: %s" % (s, status[s]) for s in SECTIONS))
    return 1 if "FAIL" in status.values() else 0


if __name__ == "__main__":
    sys.exit(main())
