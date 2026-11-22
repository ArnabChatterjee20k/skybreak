#!/usr/bin/env bash
# Exports the Skybreak web build to build/web/ with the official Godot 4.7.2 templates.
# Usage: tools/web/build_web.sh   (GODOT=/path/to/godot to pick the editor binary)
set -euo pipefail

VERSION="4.7.2"
TAG="${VERSION}-stable"
BASE_URL="https://github.com/godotengine/godot-builds/releases/download/${TAG}"
TPZ="Godot_v${TAG}_export_templates.tpz"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${ROOT}/build/web"
CACHE="${SKYBREAK_CACHE:-${HOME}/.cache/skybreak}"
GODOT="${GODOT:-godot}"

case "$(uname -s)" in
	Darwin) TEMPLATES="${HOME}/Library/Application Support/Godot/export_templates/${VERSION}.stable" ;;
	MINGW*|MSYS*|CYGWIN*) TEMPLATES="${APPDATA}/Godot/export_templates/${VERSION}.stable" ;;
	*) TEMPLATES="${XDG_DATA_HOME:-${HOME}/.local/share}/godot/export_templates/${VERSION}.stable" ;;
esac

if ! "${GODOT}" --version | grep -q "^${VERSION}\.stable"; then
	echo "error: ${GODOT} is not Godot ${VERSION} stable ($("${GODOT}" --version))" >&2
	exit 1
fi

# Templates: download once, verify SHA-512, install only the web ones.
if [[ ! -f "${TEMPLATES}/web_nothreads_release.zip" ]]; then
	mkdir -p "${CACHE}"
	echo "Downloading SHA512-SUMS.txt and ${TPZ}..."
	curl -fsSL -o "${CACHE}/SHA512-SUMS.txt" "${BASE_URL}/SHA512-SUMS.txt"
	if [[ ! -f "${CACHE}/${TPZ}" ]]; then
		curl -fL --retry 4 -o "${CACHE}/${TPZ}.part" "${BASE_URL}/${TPZ}"
		mv "${CACHE}/${TPZ}.part" "${CACHE}/${TPZ}"
	fi
	expected="$(awk -v f="${TPZ}" '$2 == f { print $1 }' "${CACHE}/SHA512-SUMS.txt")"
	actual="$(sha512sum "${CACHE}/${TPZ}" | cut -d' ' -f1)"
	if [[ -z "${expected}" || "${expected}" != "${actual}" ]]; then
		echo "error: SHA-512 mismatch for ${TPZ}" >&2
		echo "  expected ${expected:-<missing>}" >&2
		echo "  actual   ${actual}" >&2
		rm -f "${CACHE}/${TPZ}"
		exit 1
	fi
	echo "SHA-512 OK: ${actual}"
	mkdir -p "${TEMPLATES}"
	unzip -oqj "${CACHE}/${TPZ}" 'templates/web_nothreads_*' 'templates/version.txt' -d "${TEMPLATES}"
fi

# Export.
rm -rf "${OUT}"
mkdir -p "${OUT}"
if [[ ! -d "${ROOT}/.godot/imported" ]]; then
	"${GODOT}" --headless --path "${ROOT}" --import
fi
"${GODOT}" --headless --path "${ROOT}" --export-release "Web" "${OUT}/index.html"
# Zone bakes ship as one pack per zone, fetched when a match needs it (ZoneBakePacks).
"${GODOT}" --headless --path "${ROOT}" -s res://tools/web/pack_zone_bakes.gd -- "${OUT}"

# Service worker and boot cache (sw.js, boot_cache.js), then version.json: the build id and
# each file's SHA-256 and size, which the page checks on launch to update only changed files.
cp "${ROOT}/tools/web/sw.js" "${ROOT}/tools/web/boot_cache.js" "${OUT}/"
"${ROOT}/tools/web/write_version.sh" "${OUT}" "${SKYBREAK_BUILD:-}"

# Pre-compressed copies for hosts that serve them; most hosts compress on the fly.
for f in "${OUT}"/*.{wasm,pck,js}; do
	gzip -9 -k -f "${f}"
	if command -v brotli >/dev/null; then
		brotli -q 11 -k -f "${f}"
	fi
done

echo
echo "Web build in ${OUT}:"
printf '%-34s %12s %12s %12s\n' file raw gzip brotli
total_raw=0; total_gz=0; total_br=0
for f in "${OUT}"/*; do
	case "${f}" in *.gz|*.br) continue ;; esac
	[[ -f "${f}" ]] || continue
	raw=$(stat -c%s "${f}")
	gz=$(if [[ -f "${f}.gz" ]]; then stat -c%s "${f}.gz"; else gzip -9 -c "${f}" | wc -c; fi)
	br=$(if [[ -f "${f}.br" ]]; then stat -c%s "${f}.br"; else echo "${gz}"; fi)
	total_raw=$((total_raw + raw)); total_gz=$((total_gz + gz)); total_br=$((total_br + br))
	printf '%-34s %12s %12s %12s\n' "$(basename "${f}")" "${raw}" "${gz}" "${br}"
done
mb() { awk -v b="$1" 'BEGIN { printf "%.1f MB", b / 1048576 }'; }
printf '%-34s %12s %12s %12s\n' TOTAL "$(mb ${total_raw})" "$(mb ${total_gz})" "$(mb ${total_br})"
echo
echo "Zone packs in ${OUT}/zones (fetched per match, not on first load):"
zones_raw=0
for f in "${OUT}"/zones/*.pck; do
	raw=$(stat -c%s "${f}")
	zones_raw=$((zones_raw + raw))
	printf '%-44s %12s\n' "$(basename "${f}")" "$(mb "${raw}")"
done
printf '%-44s %12s\n' TOTAL "$(mb ${zones_raw})"
