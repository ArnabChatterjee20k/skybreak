#!/usr/bin/env bash
# Gameplay QA harness (T-D31). One command, markdown + JSON report.
# QA_KEEP_FRAMES=1 keeps all 120 frames of each capture (default: the violation frame + clip.mp4).
#   tools/qa/run_qa.sh [--quick|--full] [--jobs N] [--ticks N] [--skip-visual] [--out DIR]
#       (--out with an earlier run's folder reuses its soak and redoes the other stages)
#   tools/qa/run_qa.sh --repro '<seed:zone:mode:legends:levels>' --tick T [--fighter N]
#       (one violation: its checks up to T, then the last 2 s of frames with the camera on fighter N)
# Needs: Godot 4.7.2 ($GODOT or `godot`), xvfb-run for rendering, python3 with numpy + Pillow,
# ffmpeg (optional, for 2 s clips). Exit 1 when any section FAILs.
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT="${GODOT:-godot}"
MODE=quick; JOBS="${QA_JOBS:-8}"; TICKS=""; VISUAL=1; OUT=""; REPRO=""; REPRO_TICK=0; FIGHTER=0
while [[ $# -gt 0 ]]; do
	case "$1" in
		--quick) MODE=quick ;;
		--full) MODE=full ;;
		--jobs) JOBS="$2"; shift ;;
		--ticks) TICKS="$2"; shift ;;
		--skip-visual) VISUAL=0 ;;
		--out) OUT="$2"; shift ;;
		--repro) REPRO="$2"; shift ;;
		--tick) REPRO_TICK="$2"; shift ;;
		--fighter) FIGHTER="$2"; shift ;;
		*) echo "unknown option $1" >&2; exit 2 ;;
	esac
	shift
done

render() {  # Godot with a real GL renderer under a virtual display.
	xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-driver opengl3 \
		--rendering-method gl_compatibility --resolution 960x540 --disable-vsync "$@"
}

clip() {  # Folder of frame_*.png -> clip.mp4 (2 s at 60 fps) when ffmpeg is there.
	if command -v ffmpeg >/dev/null; then
		ffmpeg -loglevel error -y -framerate 60 -pattern_type glob -i "$1/frame_*.png" \
			-c:v libx264 -pix_fmt yuv420p "$1/clip.mp4" < /dev/null || true
	fi
}

prune() {  # Keeps the violation frame and the clip; the other frames are ~1 MB each.
	if [[ -f "$1/clip.mp4" && -z "${QA_KEEP_FRAMES:-}" ]]; then
		ls "$1"/frame_*.png 2>/dev/null | head -n -1 | xargs -r rm -f
	fi
}

if [[ ! -d .godot ]]; then "$GODOT" --headless --path . --import >/dev/null 2>&1 || true; fi

if [[ -n "$REPRO" ]]; then
	dir="${OUT:-reports/qa/repro}/$(echo "$REPRO" | tr ':,' '_-')_t$REPRO_TICK"
	mkdir -p "$dir"
	"$GODOT" --headless --path . -s res://game/debug/qa/qa_soak.gd -- soak --only "$REPRO" \
		--ticks "$REPRO_TICK" --out "$dir" | grep '^\[qa\]' || true
	render -s res://game/debug/qa/qa_soak.gd -- capture --spec "$REPRO" --tick "$REPRO_TICK" --fighter "$FIGHTER" --out "$dir" \
		| grep '^\[qa\]' || true
	clip "$dir"
	echo "Violations up to tick $REPRO_TICK: $dir/match_000.json; frames and clip in $dir"
	exit 0
fi

SHA="$(git rev-parse --short HEAD)"
NAME="$(date -u +%Y-%m-%d)-$SHA-$MODE"
RUN="${OUT:-reports/qa/$NAME}"
mkdir -p "$RUN/soak"
started=$(date +%s)
echo "QA $MODE on $SHA -> $RUN ($JOBS jobs)"

# 1. Invariant soak, sharded across headless processes (skipped when --out already holds one).
pids=()
if ls "$RUN"/soak/match_*.json >/dev/null 2>&1; then JOBS=0; echo "reusing the soak results in $RUN"; fi
for ((i = 0; i < JOBS; i++)); do
	"$GODOT" --headless --path . -s res://game/debug/qa/qa_soak.gd -- soak --matrix "$MODE" \
		--shard "$i/$JOBS" ${TICKS:+--ticks "$TICKS"} --out "$RUN/soak" > "$RUN/soak/shard_$i.log" 2>&1 &
	pids+=($!)
done
"$GODOT" --headless --path . -s res://game/debug/qa/qa_soak.gd -- feel --out "$RUN" > "$RUN/feel.log" 2>&1 || true

# 2 and 3. Scenario library (strict: known issues fail) and golden replays.
SKYBREAK_QA_STRICT=1 "$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd \
	-gdir=res://tests/qa/scenarios -ginclude_subdirs -gexit > "$RUN/scenarios.log" 2>&1 || true
printf '{"tests": ["res://tests/qa/test_golden_replays.gd"], "should_exit": true, "log_level": 1}\n' > "$RUN/goldens.gutconfig.json"
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig="$RUN/goldens.gutconfig.json" \
	> "$RUN/goldens.log" 2>&1 || true
for pid in "${pids[@]+"${pids[@]}"}"; do wait "$pid" || true; done
grep -h '^\[qa\]' "$RUN"/soak/shard_*.log | sort > "$RUN/soak/matches.txt" || true
echo "soak: $(ls "$RUN"/soak/match_*.json 2>/dev/null | wc -l) matches in $(( $(date +%s) - started )) s"

# 4. Visual goldens.
if [[ "$VISUAL" == 1 ]]; then
	mkdir -p "$RUN/visual"
	render -s res://game/debug/qa/qa_soak.gd -- shots --out "$RUN/visual" > "$RUN/visual.log" 2>&1 || true
fi

# 5 and 6. Metrics, report, then frames + clips of the top violations, then the report again with them.
REPORT="reports/qa/$NAME.md"
python3 tools/qa/qa_report.py "$RUN" --markdown "$REPORT" --sha "$SHA" --mode "$MODE" > /dev/null || true
if [[ "$VISUAL" == 1 ]]; then
	while read -r spec tick name fighter; do
		dir="$RUN/captures/$name"; mkdir -p "$dir"
		render -s res://game/debug/qa/qa_soak.gd -- capture --spec "$spec" --tick "$tick" --fighter "${fighter:-0}" --out "$dir" < /dev/null \
			> "$dir/capture.log" 2>&1 || true
		clip "$dir"
		prune "$dir"
	done < "$RUN/capture_list.txt"
fi
set +e
python3 tools/qa/qa_report.py "$RUN" --markdown "$REPORT" --sha "$SHA" --mode "$MODE"
status=$?
echo "Report: $REPORT  (JSON: $RUN/report.json, metrics: $RUN/metrics.json) in $(( $(date +%s) - started )) s"
exit $status
