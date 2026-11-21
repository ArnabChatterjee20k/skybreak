# Voxel art ship: integration/voxel-art -> main

Ship agent run, 2026-11-21 19:41-22:20 UTC. Everything below was run in this session; nothing was copied
from `reports/integration/final-assemble.md` without being re-checked.

## Result

| | |
|---|---|
| Merge | `62cd986f` = `git merge --no-ff origin/integration/voxel-art` (8e57c5f1, PR #148) on main 7695141; tree identical to the verified integration head |
| Golden refresh | `46da3b20`: the 14 visual goldens re-blessed once on main |
| Fix after merge | `012ec23d`: zone bakes embed the cached meshes held in script state (see "Found and fixed") |
| Board + this report | the commit that adds this file |
| Web build | `web-build` @ `dff67a8f`, from 012ec23: index.pck 56,542,000 B (< 60 MB), first load 91.9 MB (53.3 MB gzip), 7 zone packs 192.4 MB |
| Windows build | `play-windows` @ `7653a74e` (orphan), from 46da3b2: zip 724,862,052 B, split in 8 parts (7 x 94,371,840 + 64,259,172), sha256 `89024aa44340ebe0c52fa274a503a9c874b797a25de578f2be191ec986a8ec26`; README has the `copy /b` join |

## Godot

Official `Godot_v4.7.2-stable_linux.x86_64.zip`, SHA-512 `9aa00f7a...ed54c65` equal to `SHA512-SUMS.txt`;
`--version` = `4.7.2.stable.official.ed1daf0bf`. Export templates `Godot_v4.7.2-stable_export_templates.tpz`,
SHA-512 `ca4d71c4...ccb84079` equal to `SHA512-SUMS.txt`.

## Step 0: assembly

`reports/integration/final-assemble.md` was already on `origin/integration/voxel-art` (8e57c5f1) at the first
fetch (19:44 UTC). `origin/lookdev/reel-fixes` (e846428) was already merged into integration (13dd066), with
no newer commits. Main had not moved (7695141, an ancestor of integration).

## Step 1: verification of 8e57c5f1 (fresh worktree, `rm -rf .godot`, `--headless --import`)

Import: exit 0; only the known `webrtc_native` "no linux.x86_64 library" errors.

GUT, no zone bakes (fresh checkout):
```
Scripts             174
Tests              1773
Passing Tests      1764
Risky/Pending        13
Asserts           260446
Time              1480.129s
gut exit 0   (0 failing)
```
Pending: VOXEL-BAKES x3 (no local bakes), QA-11 x3, QA-12 x3, T-KI1-b, 2 renderer-only tests, plus the
skipped live Appwrite script. Nothing was pended by this run.

det_check:
```
det_math bb73e8392bff37e8
det_check total cc2d8d8a0f6c0594
```
Equal to main's `cc2d8d8a0f6c0594` (all 17 checkpoint lines equal to the assembly report). Re-run on 012ec23:
`det_check total cc2d8d8a0f6c0594`.

Zone bakes: all 7 zones x 4 tiers baked with `xvfb-run ... --rendering-driver vulkan` (lavapipe), 2 jobs, both
exit 0, 844 MB, `voxel_zone_bake.gd --check` exit 0.

`tools/qa/run_qa.sh --quick` (QA_JOBS=4 = cores, bakes present): `reports/qa/2026-11-21-8e57c5f1-quick.md`.
21 matches, 50,400 ticks, exit 1:

| Section | Result |
|---|---|
| Invariant soak (sim) | PASS |
| Invariant soak (view) | FAIL: foot_ground only, 4/21 matches, 8 frames (QA-12; main's own quick runs fail the same way: 2-4/21) |
| Scenario library | PASS (38/38, strict) |
| Golden replays | PASS (11/11) |
| Visual goldens | FAIL: the 14 intended art-change shots (SSIM 0.39-0.71), refreshed in Step 3 |
| Feel metrics trend | PASS |

| Metric | Value | Budget / previous |
|---|---|---|
| pops_per_fighter_minute | **0** | <= 2; 0 |
| finger_pops_per_fighter_minute | 0.01786 | 0.01786 |
| foot_error_p95_cm | **0.934** | 5 cm tolerance; 0.934 |
| view_ms_per_frame | **1.012** | 2.302 at 8 jobs (713d952) |
| sim_ms_per_tick | 1.017 | 2.395 at 8 jobs |
| locked_on_screen_share | 0.9849 | 0.9849 |

The system Pillow in this container is broken (`cannot import name '_imaging'`), so the visual section first
said "numpy/Pillow missing"; the report was regenerated from the same run's shots with a venv Pillow.

## Step 2: merge

Clean `--no-ff` merge, pushed `76951410..62cd986f main -> main`.

## Step 3: golden refresh

`tools/qa/bless_goldens.sh --visual` on 62cd986 (bakes current): 14 goldens changed. Looked at all 14: voxel
Brann, Kael, Lyra and Vexa (idle and light) on the voxel Heartbloom lawn with HUD; voxel Ember Rift, Frozen
Peaks, Shattered Mesa, Skyhold Ruins, Stormfall City, Verdant Falls with voxel Kael. None black, none missing.
A second render compared with the new goldens: all 14 PASS (SSIM 0.959-1.000, changed tiles <= 1.0%).

GUT after the refresh (bakes present):
```
Tests              1773
Passing Tests      1767
Risky/Pending        10
Asserts           260486
Time              630.135s
gut exit 0   (0 failing)
```
Pushed `62cd986f..46da3b20`.

## Found and fixed: Shattered Mesa's web bake depended on the baking machine

The web smoke test (`tools/web/match_smoke_test.js`) on the 46da3b2 build FAILED with 16 console errors:
`Cannot open file 'user://voxel_prop_cache/mesa_boulder{0..3}_c176_v6_m3.res'`. Cause: `VoxelZoneBake.pack`
embedded `user://` prop-cache meshes found on nodes only; `MesaProps` holds its boulder LOD meshes in an
array (script state), so the WEB bake saved links to the baker's cache. With the cache moved away, all 28
bakes were loaded: 27 loaded, `shattered_mesa_web.scn` failed to load (the zone would be built live). The
desktop tiers were not affected.

Fix (012ec23): `pack()` also embeds resources in the state (`_embed_state`). Regression test
`test_a_cached_mesh_held_only_in_script_state_is_embedded` fails without the fix (bake fails to load) and
passes with it. All 28 bakes rebaked (exit 0); with the cache moved away all 28 load, 0 errors. GUT:
```
Tests              1774
Passing Tests      1768
Risky/Pending        10
Asserts           260491
Time              602.26s
gut exit 0   (0 failing)
```

## Step 4: builds

Web (`tools/web/build_web.sh`, 012ec23): index.pck 56,542,000 B, index.wasm 39,514,754 B. Smoke test after
the fix: **PASS**, "menu -> vs AI match ran 30 s with no console errors": Shattered Mesa voxel zone pack
fetched and mounted, Kael vs Vexa, FIGHT banner and HUD on screen; engine running 23.0 s after the click.
Committed as files under `web/` (the old single tarball would exceed GitHub's 100 MB limit with the zone
packs), `BUILD.md` names the main SHA.

Windows (`Windows Desktop` preset, 46da3b2, release): `Skybreak.exe` 851,242,824 B (PE32+ x86-64 GUI, pck
embedded with the high/medium/low bakes) + `libwebrtc_native...dll` 4,058,112 B; zip -9 724,862,052 B; parts
re-joined to the same sha256. Between 46da3b2 and 012ec23 only the bake packer and its test changed; the
desktop bakes in this build load without the prop cache (checked). Not run on Windows (no Windows here).

Linux boot test (temporary `Linux` preset, not committed; 012ec23; the official templates refuse `-s` and
scene arguments, so a debug export with an `override.cfg` main scene ran a boot runner; the user data dir was
moved away first, like a fresh install):
```
BOOT art_style voxel=true quality=2
BOOT menu scene=res://game/ui/menus/front_end.tscn
BOOT bake=res://game/world/voxel_zone_kit/baked/frozen_peaks_high.scn
BOOT launch=res://game/levels/zone_match.tscn
BOOT match zone=frozen_peaks from_bake=true build_ms=89 zone_node=true frames=855
BOOT PASS                       (exit 0)
BOOT match zone=shattered_mesa from_bake=true build_ms=21 zone_node=true frames=831
BOOT PASS                       (exit 0)
```
No script errors; only Godot's "resources still in use at exit" note from quitting mid-match. Release Linux
export: binary 73,519,416 B + pck 741,997,364 B (not committed).

## Still open (ranked)

1. VOXEL-BAKES (owner decision): bakes (844 MB) are not in git; a fresh clone builds zones live until baked.
2. GTX 1650 render benchmark of the voxel zones (LOOKDEV-PERF); cloud numbers are lavapipe.
3. QA-12 view soak foot_ground: 4/21 quick matches, 8 frames (worst Lyra +22 cm, frozen_peaks/117 t268).
4. Windows build not boot-tested on Windows.
5. Appwrite deploy of the new web build (~250 MB with zone packs): check the site's upload limit.
6. run_qa.sh defaults to 8 jobs; on 4 cores that doubles sim/view ms.
7. Filed earlier: QA-22, VOXEL-PALETTE, classic menu backdrop, Brann's cannon fore-grip hand, T-KI1-b, QA-11.
