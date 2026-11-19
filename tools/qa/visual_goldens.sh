#!/usr/bin/env bash
# Renders the QA visual-golden shots (game/debug/qa/qa_shots.gd) under xvfb.
#   tools/qa/visual_goldens.sh --bless   re-approves them into tests/qa/goldens/visual/
#   tools/qa/visual_goldens.sh [DIR]     renders into DIR (run_qa.sh compares them)
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
out="${1:-reports/qa/visual}"
[[ "${1:-}" == "--bless" ]] && out="tests/qa/goldens/visual"
mkdir -p "$out"
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 \
	--rendering-method gl_compatibility --resolution 960x540 --disable-vsync \
	-s res://game/debug/qa/qa_soak.gd -- shots --out "$out" | grep '^\[qa\]'
echo "Shots in $out"
