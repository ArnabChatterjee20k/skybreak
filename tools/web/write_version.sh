#!/usr/bin/env bash
# Writes <build dir>/version.json for the boot cache (tools/web/boot_cache.js):
# {"build": "<git sha>", "files": {path: sha256}, "sizes": {path: bytes}} over every file
# except the .gz/.br copies and version.json itself. A dirty tree adds "-dirty-<content hash>".
# Usage: tools/web/write_version.sh <build dir> [build id]
set -euo pipefail

OUT="$(cd "$1" && pwd)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${2:-}"

cd "${OUT}"
mapfile -t paths < <(find . -type f ! -name '*.gz' ! -name '*.br' ! -name 'version.json' -printf '%P\n' | LC_ALL=C sort)
files=""
sizes=""
sums=""
for p in "${paths[@]}"; do
	sha="$(sha256sum "${p}" | cut -d' ' -f1)"
	size="$(stat -c%s "${p}")"
	sums+="${sha}  ${p}"$'\n'
	files+="${files:+,}"$'\n'"    \"${p}\": \"${sha}\""
	sizes+="${sizes:+,}"$'\n'"    \"${p}\": ${size}"
done
if [[ -z "${BUILD}" ]]; then
	BUILD="$(git -C "${ROOT}" rev-parse HEAD)"
	if [[ -n "$(git -C "${ROOT}" status --porcelain --untracked-files=no)" ]]; then
		BUILD+="-dirty-$(printf '%s' "${sums}" | sha256sum | cut -c1-8)"
	fi
fi
printf '{\n  "build": "%s",\n  "files": {%s\n  },\n  "sizes": {%s\n  }\n}\n' "${BUILD}" "${files}" "${sizes}" > version.json
echo "version.json: build ${BUILD}, ${#paths[@]} files"
