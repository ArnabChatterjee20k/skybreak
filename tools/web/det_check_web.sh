#!/usr/bin/env bash
# Runs tools/diag/det_check.gd in headless Chromium (wasm): exports a throwaway copy of the
# project with the det-check scene as main scene, then prints the browser's det_check lines.
# Usage: tools/web/det_check_web.sh [out dir]   (GODOT=/path/to/godot; web templates installed,
# e.g. by tools/web/build_web.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$(realpath -m "${1:-${ROOT}/build/det_check_web}")"
GODOT="${GODOT:-godot}"
COPY="$(mktemp -d)"
trap 'rm -rf "${COPY}"' EXIT

git -C "${ROOT}" ls-files -co --exclude-standard -z | (cd "${ROOT}" && xargs -0 cp --parents -t "${COPY}")
sed -i 's|^run/main_scene=.*|run/main_scene="res://tools/web/det_check_main.tscn"|' "${COPY}/project.godot"
sed -i 's|^exclude_filter=.*|exclude_filter="docs/*, *.md"|' "${COPY}/export_presets.cfg"
rm -rf "${OUT}"
mkdir -p "${OUT}"
"${GODOT}" --headless --path "${COPY}" --import >/dev/null 2>&1 || true
"${GODOT}" --headless --path "${COPY}" --export-release "Web" "${OUT}/index.html"
node "${ROOT}/tools/web/det_check_web.js" "${OUT}"
