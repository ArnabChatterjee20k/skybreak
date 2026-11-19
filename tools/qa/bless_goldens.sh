#!/usr/bin/env bash
# Re-records the QA goldens. Run it in the PR that intends the change, then commit them.
# Usage: tools/qa/bless_goldens.sh [--replays] [--visual] [--all]   (default: --replays)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

godot_bin="${GODOT:-}"
if [[ -z "$godot_bin" ]]; then
	if command -v godot >/dev/null 2>&1; then
		godot_bin="godot"
	else
		echo "error: Godot not found. Set GODOT=/path/to/godot or put godot on PATH." >&2
		exit 2
	fi
fi

do_replays=0
do_visual=0
if [[ $# -eq 0 ]]; then
	do_replays=1
fi
for arg in "$@"; do
	case "$arg" in
		--replays) do_replays=1 ;;
		--visual) do_visual=1 ;;
		--all) do_replays=1; do_visual=1 ;;
		-h|--help)
			sed -n '2,3p' "$0"
			exit 0
			;;
		*)
			echo "error: unknown flag $arg (use --replays, --visual or --all)" >&2
			exit 2
			;;
	esac
done

if [[ $do_replays -eq 1 ]]; then
	echo "== Recording golden replays"
	"$godot_bin" --headless --path . -s res://game/debug/qa/bless_goldens.gd -- --replays
fi

if [[ $do_visual -eq 1 ]]; then
	if [[ -f tools/qa/visual_goldens.sh ]]; then
		echo "== Blessing visual goldens"
		GODOT="$godot_bin" bash tools/qa/visual_goldens.sh --bless
	else
		echo "== Visual goldens: not available (tools/qa/visual_goldens.sh does not exist)"
	fi
fi

echo
echo "== Changed goldens"
git --no-pager diff --stat -- tests/qa/goldens
new_files="$(git ls-files --others --exclude-standard -- tests/qa/goldens)"
if [[ -n "$new_files" ]]; then
	echo "New:"
	echo "$new_files" | sed 's/^/  /'
fi
if git diff --quiet -- tests/qa/goldens && [[ -z "$new_files" ]]; then
	echo "No golden changed."
fi
echo
echo "Commit the changed goldens in the PR that intends the change, and say in the PR why they changed."
