#!/usr/bin/env bash
# Exports a *debug* web build for tools/net/duo_browser_test.js: the dev-only
# Appwrite endpoint override and DuoTestPilot exist only in debug builds. Mirrors
# tools/web/build_web.sh after the export (sw.js, boot_cache.js, version.json);
# zone packs are added only when the zone bakes exist locally.
# Usage: tools/net/build_web_debug.sh <out dir>   (GODOT=/path/to/godot 4.7.2)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$(mkdir -p "$1" && cd "$1" && pwd)"
GODOT="${GODOT:-godot}"
rm -rf "${OUT:?}"/*
"${GODOT}" --headless --path "${ROOT}" --export-debug "Web" "${OUT}/index.html"
"${GODOT}" --headless --path "${ROOT}" -s res://tools/web/pack_zone_bakes.gd -- "${OUT}" \
	|| echo "build_web_debug: no zone bakes here, zones build live (VOXEL-BAKES)"
cp "${ROOT}/tools/web/sw.js" "${ROOT}/tools/web/boot_cache.js" "${OUT}/"
"${ROOT}/tools/web/write_version.sh" "${OUT}" "duo-test"
