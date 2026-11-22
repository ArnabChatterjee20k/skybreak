# Camera round 3 (T-135): evidence

Run 2026-11-22 07:30-10:10 UTC, cloud container (4 cores, llvmpipe/lavapipe only). Godot official
4.7.2 linux x86_64, SHA-512 `9aa00f7a...ed54c65` = `SHA512-SUMS.txt` (`4.7.2.stable.official.ed1daf0bf`).
`rm -rf .godot`, `--headless --import`; all 28 zone bakes rebuilt here (xvfb, 3 jobs),
`tools/voxel_zone_bake.gd -- --check` exit 0 (28 current).

Branch `T-135-camera-round3`: bce74bb8, merged with `origin/main` 7cad3855 (60e685b0, clean), then
73142ecf and e6bf7d31 (this round).

## What was wrong

Diagnosed with `game/debug/camera_offscreen_diag.gd` (every locked frame with a fighter off screen,
with the obstacle that moved the camera) on the seed-7 Kael vs Vexa fight:

| Zone | Off-screen frames (before) | Cause |
|---|---|---|
| shattered_mesa | 54 | 11 + 23: the **locked opponent's own body** on the boom pulled the camera to 1.6 m in front of them, leaving them beside the lens, then a slow ease back out; 12: the exchange-cam swing narrowed the FOV to 40 deg before the camera arrived; 8: terrain on the boom |
| stormfall_city | 51 | 43 + 8: the opponent's body on the boom (same as above) |
| verdant_falls | (90.2% both-on in the last run) + 6-8 clip frames | the voxel FloorT2 tier stands ~0.65 m above the sim heightmap at (-639, 615); the camera kept 0.4 m above the sim ground only |

## What changed

- `CameraObstacles.target_body`: the locked target's body is no longer a boom obstacle (other
  fighters still are, issue #107); the camera only keeps out of it (`out_of_target`: up over its head
  or out through a side, the shortest way).
- `FighterCamera.fit_fov`: while locked, the FOV widens at once to keep both fighters inside 95% of
  the frame, up to 95 deg; it eases back with the normal FOV smoothing. Not past the pitch limits:
  there `locked_fov` and the opponent marker rule (as designed, `test_fov_widens_for_a_big_height_gap`).
- `CameraFloor`: the visible voxel floor's height from the zone's floor chunks (wide, <= 12 m tall,
  solid, near-LOD meshes), one 1 m grid per chunk, rasterized when the camera nears it (sloped faces
  at their plane height, step sides at their top). `CameraObstacles.floor_near` (highest floor within
  the 0.4 m clearance radius, centre + 8) is the camera's height clamp.
- The first QA quick (73142ecf) flagged `view_ms_per_frame` +24%: the floor grid then stamped every
  cell into a dictionary and was queried by every boom sample. Fixed in e6bf7d31 (final clamp only,
  packed grids, 1 m cells): +11% in the re-run, under the 15% bar.

Tests: `tests/view/test_camera_keeps_both_fighters.gd` (5), `tests/view/test_camera_floor.gd` (6).
Mutation check: with the fit widening and the target-body handling removed, the crossing test fails.

## Results

### Voxel zone fight camera (`voxel_camera_qa.gd -- 1200 7`, `voxel_camera_qa.txt`)

| Zone | Both on (before) | Both on (now) | Clip frames |
|---|---|---|---|
| heartbloom_gardens | 100% | 100.0% | 0 |
| shattered_mesa | 94.5% | **99.4%** | 0 |
| skyhold_ruins | 100% | 100.0% | 0 |
| stormfall_city | 94.8% | **100.0%** | 0 |
| frozen_peaks | 94.96% | **97.5%** | 0 |
| verdant_falls | 90.2% | **98.8%** | **0** (was 6-8; min clearance now 0.59 m) |
| ember_rift | 100% | 100.0% | 0 |

Near and far bands 100% on every zone. Pinned "back to a tall prop" scenarios: every case 100%
both-on, 0 clip frames (heartbloom gap 2 m side 0 was 87.2%). No threshold or test was changed.

### Full GUT (e6bf7d31, bakes present, `gut_totals.txt`)

```
Tests              1850
Passing Tests      1844
Risky/Pending        10
Time              819.473s
gut exit 0   (0 failing)
```
The pending ones are the same as on main (QA-11/QA-12 visual QA, T-KI1-b, two renderer-only tests).
`test_voxel_zone_camera.gd`: 2/2 passed.

### det_check (`det_check.txt`)

`det_check total 65ec2f54272115fd`, twice, identical line for line to main's
`reports/gameplay/det_check_746036c1.txt`. Camera code changes no sim state.

### QA quick (e6bf7d31, `reports/qa/2026-11-22-e6bf7d31-quick.md`)

| | main (6ea2e918) | now |
|---|---|---|
| locked_on_screen_share | 0.9784 | **0.9816** |
| camera_jerk_p95 | 0.01052 | **0.00873** (-17%) |
| view_ms_per_frame | 1.072 | 1.193 (+11%, PASS) |
| sim_ms_per_tick | 1.137 | 1.085 |
| camera_on_screen violations | 2/21 (90.5%, 94.8%) | 2/21 (94.2% heartbloom 2v2, 94.8% skyhold FFA-4) |

Sim soak PASS, scenarios 38/38 strict PASS, golden replays 11/11 PASS, feel metrics PASS. View soak
FAIL as on main: foot_ground 3/21 (QA-12), the two camera_on_screen matches above (T-135-c), one pop
(QA-23).

Visual goldens: FAIL, also on `origin/main` in this container. Rendered from main with the same
bakes, the shots score heartbloom 0.873-0.882, ember 0.885, shattered 0.929, frozen 0.847, verdant 0.79
against the committed goldens (props missing in this container's renders), so they were not re-blessed
here. Branch shots against main's shots in the same container: 12 of 14 identical or nearly
(SSIM >= 0.956), `zone_frozen_peaks` 0.503 and `zone_verdant_falls` 0.897: the round-3 base framing
(boom 4.0 m, height 1.2 m, from fae758f), the intended camera change. Filed as T-135-b.

### Stills (`contact_sheet.jpg`, `stills.txt`)

Vulkan Forward+ on lavapipe (llvmpipe, LLVM 20.1.2), 1920x1080, `game/debug/camera_stills.gd`, the
seed-7 fight at ticks 800 and 1040 on every zone (scaled to 480x270 in the sheet). Both fighters locked
and on screen in all 14. Looked at: framing reads well on every zone; tight but correct on Shattered
Mesa t1040 (Vexa half behind Kael at point-blank) and Ember Rift t800 (close exchange); Frozen Peaks t800
shows the fit widening (FOV 69.5). The first capture per zone (t560) still showed the loading overlay
(capture artefact) and was dropped.

## Merge and builds

- `main` = `61925008`: `git merge --no-ff T-135-camera-round3` (PR #149, shown merged on GitHub) on
  51275e98 (WEB-CACHE, web tooling only after the evidence runs).
- Web (`web-build` @ `66250942`, from 61925008): `tools/web/build_web.sh`, index.pck 56,638,004 B
  (< 60 MB, sha256 `b22992e3...0367d967`), first load 92.0 MB, zone packs 191.3 MB;
  `node tools/web/match_smoke_test.js build/web`: **PASS** (menu -> Vs AI match 30 s, no console errors).
- Windows (`play-windows` @ `05e02e73`, from 61925008): `Windows Desktop` preset, release; Skybreak.exe
  848,409,448 B (PE32+ x86-64, pck embedded) + webrtc dll; zip -9 722,251,866 B in 8 parts
  (`split -b 90m`), rejoined sha256 `ce8f31b3...d08eeffc` = the zip's; `unzip -t` clean. Not run on Windows.
