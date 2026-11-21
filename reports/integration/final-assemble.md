# Final assembly: integration/voxel-art (PR #148)

## Merges (real merge commits, no squash or rebase)
| Order | Branch @ commit | Merge commit | Conflicts |
|---|---|---|---|
| 1 | fix/voxel-soles-perf @e7736e6 (has 1190b4b) | e4d8d7e | none |
| 2 | fix/web-size @8b3cd12 | abdd213 | none |
| 3 | fix/zone-polish @4938c10 | 035886b | none |
| 4 | lookdev/reel-fixes @d3a75e4 | ad81650 | moves_reel.gd: took reel-fixes, which carries the Brann-lane glow (lit, black albedo, emission x GLOW_GAIN 0.27); lookdev_capture.gd: kept the feet shot and the measured head framing |
| 4b | lookdev/reel-fixes @e846428 (GAUNTLET-CLOSEUP FIXED) | 13dd066 | none |

## Extra fixes
- `zone_capture.gd` prints `RenderingServer.get_video_adapter_name()` instead of a fixed "(software)" (`tests/world/test_zone_capture.gd`).
- MOTION-CACHE: `MotionClips.build` cached its rig-fitted clips per library only, so the first legend loaded fixed them for everyone. In the full GUT run `test_brann_voxel_fists` failed (0.248 m, 2463 vs 2496 turns) after the motion tests built the cache on Kael's rig; alone it passed. In a match the clips depended on load order. Now keyed by library and rig; `test_motion_clips_cache.gd` fails without the fix.

## Bakes
- Zones: all 7 zones x 4 tiers rebaked with xvfb + Vulkan (lavapipe), as the kit README says (headless drops MultiMesh buffers). 2 jobs, both exit 0, 28 files, 845 MB, gitignored (VOXEL-BAKES). `voxel_zone_bake.gd --check`: exit 0.
- Bodies: `voxel_bake.gd --check` reported all 16 bakes current before and after. A full rebake gave the same source hashes but byte-noisy files (sizes off by 0-6 bytes), so the committed bakes stay as they are; no binary churn.

## Evidence
Godot: official 4.7.2 linux x86_64, `Godot_v4.7.2-stable_linux.x86_64.zip: OK` against SHA512-SUMS.txt, `4.7.2.stable.official.ed1daf0bf`. `rm -rf .godot`, then `--headless --import`, which logs only the known webrtc_native "no linux.x86_64 library" errors.

GUT on 13dd066 (final head), bakes present:
```
Scripts             174
Tests              1773
Passing Tests      1767
Risky/Pending        10
Asserts           260486
Orphans              15
Time              685.718s
gut exit 0   (0 failing)
```
Pending/risky, all pre-existing: QA-11 x3, QA-12 x3 (VisualQa), T-KI1-b, 2 renderer-only tests (headless), the live Appwrite script. Visual golden tests are renderer-only in GUT, so none needed marking pending.

det_check on 13dd066 (identical to main, and to the run before the last merges):
```
det_check v1
det_math bb73e8392bff37e8
ffa t2000 1fece4bcd9e50b9b 8eda90f0
ffa t4000 9e8d3bf603fe03e1 e16ad7c9
ffa t6000 9d9c7d0532b03aa2 dd98cc98
ffa t8000 ef7b6b8f644b8f2c 2fa9cbac
ffa t10000 cfd39935746aa6f2 7d8dd4ff
bot t600 ebfa31374ff9633b af1e4195
bot t1200 3fb15b2bedbd181d 8bb19cd9
bot t1800 97a0e1d58c6ae775 42b8127c
bot t2400 d241b7436ee1cf99 a28e2700
bot t3000 470b0a3a84e68fc2 2438b04f
bot t3600 c6b16e87c979d8c9 78903b3b
ki t600 788a55bf3a65d004 a17bab09
ki t1200 b7a4a5d3c7175247 e6b77227
ki t1800 54eb6e5578002b9b 95d768f3
ki t2400 834401de5cb5d407 518bb040
ki t3000 7fa8f9291d5b3465 3242dcd4
ki t3600 3e6739a4a7afe0a4 e53c555f
det_check total cc2d8d8a0f6c0594
```

`tools/qa/run_qa.sh --quick` on 713d952 (the four lanes merged, plus the motion fix; the e846428 merge touches only look-dev). Report: `reports/qa/2026-11-21-713d952-quick.md` (text committed, media left out). Exit 1:

| Section | Result |
|---|---|
| Invariant soak (sim) | PASS |
| Invariant soak (view) | FAIL: foot_ground only, 4/21 matches, 8 frames. Pre-existing QA-12, the same Lyra frame (frozen_peaks/117 tick 268) as c4356cd's 4/21, 8 frames |
| Scenario library | PASS (strict) |
| Golden replays | PASS |
| Visual goldens | FAIL: the 14 expected art-change shots (SSIM 0.32-0.71), the same as the last PR table; not re-blessed (one refresh on main) |
| Feel metrics trend | FAIL on ms only; contention on this box, see below |

| Metric | Budget / baseline (160e141) | 8 shards (run_qa default) | 4 shards = cores |
|---|---|---|---|
| pops_per_fighter_minute | <= 2 (QA rule); 0 | **0** | **0** |
| finger_pops_per_fighter_minute | 0.01786 | 0.01786 | 0.0179 |
| foot_error_p95_cm | 5 cm tolerance; 1.725 | **0.934** (-46%, QA-24 fixed) | 0.934 |
| sim_ms_per_tick | 1.167 (+15%) | 2.395 | **1.001** |
| view_ms_per_frame | 1.203 (+15%) | 2.302 | **0.972** |

run_qa defaults to 8 soak shards; this container has 4 cores (Xeon 2.1 GHz). No code in game/combat, game/ai or game/input changed since 160e141 (git diff empty, det_check equal), yet sim_ms doubled with 8 shards. Re-run at 4 shards (21 matches in 119 s): sim 1.001 ms and view 0.972 ms, both under the baseline.

Visual goldens first said "numpy/Pillow missing": a broken system Pillow was shadowing the pip one. After fixing it, the report was regenerated from the same run's shots. I looked at zone_frozen_peaks and heartbloom_brann_light: the intended voxel look, rendered correctly.

## Still open (ranked)
1. GPU-only: Frozen Peaks HIGH/MEDIUM re-bench on the GTX 1650 (render benchmark before/after); also every zone's GTX 1650 ms (LOOKDEV-PERF).
2. VOXEL-BAKES (owner decision): 845 MB of zone bakes aren't in git; a fresh clone builds live until baked.
3. View soak: pre-existing QA-12 foot_ground frames (4/21 matches, 8 frames; worst Lyra +22 cm at frozen_peaks/117 t268).
4. Visual goldens: 14 shots, one refresh pass on main after merge.
5. run_qa.sh's default of 8 jobs inflates sim and view ms on 4-core machines: default QA_JOBS to nproc (developer-owned tools/).
6. Filed: QA-22 (voxel Brann view cost), VOXEL-PALETTE, the classic menu backdrop, Brann's off hand on the cannon fore-grip.
