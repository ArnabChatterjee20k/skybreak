# Gameplay agent run: specials merged, camera round 3 pushed, builds refreshed

Run 2026-11-21 23:30 - 2026-11-22 02:10 UTC, cloud container (4 cores, llvmpipe/lavapipe only). Godot
official 4.7.2 linux (SHA-512 `9aa00f7a...ed54c65` = SHA512-SUMS.txt, `4.7.2.stable.official.ed1daf0bf`),
export templates SHA-512 `ca4d71c4...ccb84079` = SHA512-SUMS.txt. Everything below was run in this session.

## Result

| | |
|---|---|
| main | **`746036c1`** = `git merge --no-ff claude/T-SP1-specials` (PR #141, shown merged on GitHub) on 364f4b8; tree identical to the verified branch head 20f2f429 |
| Camera round 3 | `T-135-camera-round3` @ `bce74bb8`, pushed, **not merged** (1 failing test, see Step 2) |
| Web build | `web-build` @ `26f0849c` from 746036c1: index.pck 56,594,896 B (< 60 MB), smoke test PASS |
| Windows build | `play-windows` @ `437297bb` from 746036c1: zip 727,574,429 B in 8 parts, sha256 `08d60957...44ab8b` |

## Step 0

`git fetch` at 23:31: `origin/integration/voxel-art` already an ancestor of `origin/main` (364f4b8) and
`reports/ship/voxel-ship.md` on main. No wait needed.

## Step 1: PR #141 specials

Merge: `git merge --no-ff origin/main` into `claude/T-SP1-specials` (071544c8). One conflict,
`game/characters/roster/kael.tres`: kept the specials' `kael_fighter_stats.tres` and main's voxel scene.

Voxel rigs (ede05c3d): voxel Kael and Vexa share `%GeneralSkeleton` and `CharacterView`, so every special's
retimed take plays through `MotionSlots`. Added `SpecialHandGlow`: one orb per `RightHand`/`LeftHand` bone
(`BoneAttachment3D`), visible while a special runs and swelling through startup; `StandardMaterial3D`
lit, black albedo, emission = the special's colour, energy 5 x GLOW_GAIN 0.27. Tests
`tests/characters/test_special_voxel_rig.gd` (6): every special/variant/riposte move resolves to a clip on
both voxel rigs; orbs ride their hand bones and sit on their own hand; material; swell; off after the
special and on a normal; none for a kit-less fighter. `special_strip.gd` now renders the art style's scene;
strips of the 7 specials on voxel bodies in `reports/specials/voxel/`.

GUT (worktree without bakes, `--import` then full run) on ede05c3d:
```
Tests              1826
Passing Tests      1817
Risky/Pending        13
Time              920.236s
gut exit 0   (0 failing)
```
The merge alone before my changes (071544c8): 1820 / 1811 passing / 0 failing / 13 pending.
`test_golden_replays`, `test_rollback_session`, `test_escape_rollback`, `test_determinism_lint`: 0 failing.
Commits after ede05c3d add only a debug tool, reports and the board.

det_check (full output `reports/gameplay/det_check_746036c1.txt`), run twice:
```
det_check total 65ec2f54272115fd
det_check total 65ec2f54272115fd
```
Main before was `cc2d8d8a0f6c0594`. The difference is the specials sim (Momentum, AI special use, the new
`specials` duel line), not the merge: the unmerged branch head be647cc1 gives the same `65ec2f54272115fd`,
and main's voxel merge kept main's hash. The `af2792e6...` in the old `reports/specials/det_check.txt` was
recorded before the branch's T-DEF3 merge; the file now holds the current output.

QA quick (`QA_JOBS=4`, bakes present) on 6ea2e918: `reports/qa/2026-11-22-6ea2e918-quick.md`, exit 1.
Sim soak PASS; scenarios 38/38 strict PASS; golden replays 11/11 PASS; visual goldens 14/14 PASS (SSIM
0.960-1.000). View soak FAIL: foot_ground 3/21 (QA-12, main had 4/21), camera_on_screen 2/21 (90.5%,
94.8%: SP1-5, accepted by the owner until T-135), one pop (QA-23). Feel: sim 1.137 ms/tick (+12%), view
1.072 ms (+6%), pops 0.036/fighter-min (limit 2), finger pops 1 -> 2 events in 46.7 fighter-minutes flagged
+100%: the new event is Vexa's RightHand at 1.205 rad (limit 1.2) in HITSTUN `hit_light`, not a special
clip; filed QA-23. locked_on_screen_share 0.9784 and camera_jerk_p95 equal to the branch's own run
before the merge (1a814a6).

Versus soak (`game/debug/versus_soak.gd`, headless, voxel Shattered Mesa from its bake, Kael vs Vexa AI 5,
MEDIUM): `SOAK matches=3 ticks=10799 fight_seconds=150.0 specials kael=9 vexa=8 lit_frames=735 kos=5`,
0 script errors (only Godot's leak notes at quit). A rendered run (xvfb, OpenGL on llvmpipe) captured
`reports/specials/voxel/versus_shattered_mesa_vexa_special.png`.

Zone bakes: all 28 rebaked here (xvfb, 3 jobs), `voxel_zone_bake.gd --check` clean on 746036c1.

## Step 2: camera round 3 (not merged)

Read fae758f (hybrid exchange cam, terrain-wall push, closer base framing; "not PR-ready"). Merged main
364f4b8 (e539026b; conflict in `graphics_settings.gd`, kept the exchange-cam toggle and the art style)
and later 746036c1 (bce74bb8, clean). Added (de4b99e1): `CameraClearance` (camera points vs a voxel
zone's solid triangles, under the visible ground, inside a closed prop by ray parity), `VoxelCameraFight`
(all-AI fight per zone, near < 3.5 m / far > 12 m framing; player pinned with the back to a tall prop),
`game/debug/voxel_camera_qa.gd`, low voxel props (<= 6 m) as `CameraObstacles`, and tests
`test_voxel_zone_camera`, `test_camera_clearance`, `test_voxel_camera_obstacles` (the obstacle test fails
with the wiring disabled: 120/120 frames inside the wall).

Measured before #141 (camera branch on 364f4b8, seed 7, 1200 ticks): every zone 0 clip frames, both on
screen 95.8-100% (near 95.9-100%, far 100%). Full voxel-prop wiring was rejected: Verdant near-wall
100% -> 86.7% and the camera pushed into a fern patch for 211 frames; tall props stay out.

det_check on bce74bb8, twice: `65ec2f54272115fd` (= main; camera code changes no sim state).
Full GUT on bce74bb8 with bakes: 1839 tests, 1832 passing, **1 failing**, 10 pending (828 s). The failing
test is the new zone camera test after specials joined the fight: both-on 94.5% Shattered Mesa,
94.8% Stormfall, 95.0% (961/1012) Frozen Peaks, 90.2% Verdant; Verdant also has the camera 8 cm from a voxel
floor chunk in 6 frames. Not merged; what's left is listed under T-135 in `TODO.md`.

## Step 3: builds

Web (`tools/web/build_web.sh` on 746036c1): index.pck 56,594,896 B (sha256 `9509a72c...ab682f150`), wasm
39,514,754 B, first load 92.0 MB (gzip 53.4 MB), 7 zone packs 192.4 MB. `node tools/web/match_smoke_test.js
build/web`: **PASS**, menu -> Vs AI match 30 s, no console errors, engine running 22.1 s after the click
(`reports/gameplay/web_smoke_746036c1_15s.png`: voxel Shattered Mesa, Kael's Momentum pips on the HUD).

Windows (`Windows Desktop` preset, release, 746036c1): Skybreak.exe 853,978,264 B (PE32+ x86-64 GUI, pck
embedded) + webrtc dll 4,058,112 B; zip -9 727,574,429 B, `split -b 90m` into 8 parts, re-joined sha256
equal. Not run on Windows.

## Open, ranked

1. T-135 camera: framing with specials on is 90-95% vs the 95% bar on 4 zones (SP1-5 root), plus the Verdant
   voxel-floor near-clip; then QA quick and merge (branch pushed).
2. VOXEL-BAKES (owner decision): bakes not in git; fresh clones build zones live.
3. GTX 1650 benchmarks (LOOKDEV-PERF): no real GPU numbers yet for voxel zones or specials VFX.
4. QA-23 pop / finger-pop trend; QA-12 foot_ground (3/21).
5. SP1-7 hand glow too small to read at range (owner look review); SP1-1 Brann/Lyra kits; SP1-2 ultimates.
6. Windows build not boot-tested on Windows; Appwrite upload limit for the ~250 MB web build.
7. SP1-8 `ZoneMatch` ignores `rounds`.
