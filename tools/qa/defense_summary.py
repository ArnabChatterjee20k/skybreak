#!/usr/bin/env python3
"""Merges tools/qa/defense_audit.gd shards into per-fighter-minute rates (T-DEF1).

    python3 tools/qa/defense_summary.py DIR [--json OUT]
"""
import json
import pathlib
import sys

d = pathlib.Path(sys.argv[1])
total = {}
for f in sorted(d.glob("defense_*.json")):
    for k, v in json.loads(f.read_text()).items():
        total[k] = total.get(k, 0) + v
minutes = total["fighter_ticks"] / 3600.0
print(f"matches {total['matches']}, fighter-minutes {minutes:.1f}\n")
print("| counter | total | per fighter-minute |\n|---|---:|---:|")
for k in sorted(total):
    if k in ("fighter_ticks", "matches"):
        continue
    print(f"| {k} | {total[k]} | {total[k] / minutes:.2f} |")

strikes = total.get("attack_strike_total", 0)
if strikes:
    print("\nStrike outcomes (share of melee strikes thrown):")
    for k in sorted(total):
        if k.startswith("attack_strike_") and k != "attack_strike_total":
            print(f"  {k[14:]:<24} {100.0 * total[k] / strikes:5.1f}%")
if "--json" in sys.argv:
    pathlib.Path(sys.argv[sys.argv.index("--json") + 1]).write_text(json.dumps(total, indent=1, sort_keys=True))
