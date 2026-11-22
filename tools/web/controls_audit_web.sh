#!/usr/bin/env bash
# Runs the T-UX2 controls audit (tests/combat/controls_audit.gd) inside the wasm build in
# headless Chromium: exports a throwaway copy that keeps tests/, then prints the table.
# Usage: tools/web/controls_audit_web.sh [out dir]   (GODOT=/path/to/godot; web
# templates installed, e.g. by tools/web/build_web.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$(realpath -m "${1:-${ROOT}/build/controls_audit_web}")"
GODOT="${GODOT:-godot}"
COPY="$(mktemp -d)"
trap 'rm -rf "${COPY}"' EXIT

git -C "${ROOT}" ls-files -co --exclude-standard -z | (cd "${ROOT}" && xargs -0 cp --parents -t "${COPY}")
sed -i 's|^exclude_filter=.*|exclude_filter="docs/*, *.md"|' "${COPY}/export_presets.cfg"
# The web template ignores -s, so the audit runs as the main loop instead.
sed -i 's|^\[application\]$|[application]\n\nrun/main_loop_type="ControlsAudit"|' "${COPY}/project.godot"
# Web still needs a main scene: an empty one, so only the audit's front end runs.
printf '[gd_scene format=3]\n\n[node name="Empty" type="Node"]\n' > "${COPY}/empty_main.tscn"
sed -i 's|^run/main_scene=.*|run/main_scene="res://empty_main.tscn"|' "${COPY}/project.godot"
rm -rf "${OUT}"
mkdir -p "${OUT}"
"${GODOT}" --headless --path "${COPY}" --import >/dev/null 2>&1 || true
"${GODOT}" --headless --path "${COPY}" --export-release "Web" "${OUT}/index.html"
node "${ROOT}/tools/web/controls_web.js" audit "${OUT}"
