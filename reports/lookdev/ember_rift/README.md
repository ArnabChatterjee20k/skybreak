# Ember Rift voxel look-dev v1

Sheet: `docs/lookdev/ember_rift.md`. Code: `game/world/zones_voxel/ember_rift/` (`EmberRiftVoxel`,
`EmberRiftDesigns`, `ember_terrain.gdshader`, `ember_lava.gdshader`), test `tests/world/test_ember_rift_voxel.gd`.
Built on the shared kit `game/world/voxel_zone_kit/`, which this lane did not change (no kit bugs found).

Rendered with official Godot 4.7.2 (linux x86_64, SHA-512 checked against `SHA512-SUMS.txt`) on **lavapipe**
under xvfb, 1920×1080, MSAA 4×, the kit's stack (SSAO + baked AO, soft sun shadow, glow, fog, rim). Every still
here was looked at before committing. **Not yet seen on a real GPU.**

```sh
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json GALLIVM_PERF=no_aos_sampling LP_PERF=no_rast_linear
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --disable-vsync --resolution 1280x720 \
  -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out> heroes \
  --zone=res://game/world/zones_voxel/ember_rift/ember_rift_voxel.gd
```

## The sim stays the truth
- Ground = the baked `TerrainHeightmap` (`TerrainShape._ember`). Walkable ash is a smooth top on exactly that
  surface (test: vertices within 4.4 cm at both spawns). Lava plane at the sim's 31 m.
- All 55 spires, 10 vents and 24 fissure strips come from `EmberRiftProps.build` run as `ZoneMatch` runs it
  (`PropKit` seed 4242, the ground zones' 26 m spawn keep-clear circles). Spire meshes are 6 built variants
  scaled to each sim spire's radius and height.
- Visual-only additions: storytelling props at authored spots found clear of spawns (12 m), vents (20 m), spires
  and fissures; the Breach lava fall (stepped glowing cells on the wall, no hazard); plume, geyser blobs, particles.
- Known deviation: the columnar basalt wall quantises the wall into 2.45 m plan columns, so on the steep wall the
  visible top is up to ~1.5 m off the sim surface (the floor is exact). Rim blocks are 4.2 m T3 blocks.

## Detail at three scales
- **Big:** T1/T2 smooth ash floor with wind ripples and drifts; stepped crust banks; columnar basalt inner wall
  (staggered columns, drum joints) with an obsidian cap band; T3 rim crowns; vent pool; Breach fall; plume.
- **Medium:** 6 faceted obsidian spire variants (stepped taper, split tip, chip scars, crust band, edge glints);
  2 vent variants (terraced crust, sulphur rim, cracked rim, glowing throat); pumice boulders; crust rafts;
  lava tubes; forge-shrine; survey bridge; fallen spire.
- **Tiny:** sulphur crystal clusters (T0), obsidian shards (T0), survey stakes with emblem tags (T0), glass drips,
  pinprick glow cracks, scorch rings, pumice pebble dots, ash and spark particles.
- **Storytelling (6):** forge-shrine (cracked anvil with the Rising Ember, braziers, hammer notch in the step);
  half-burnt survey bridge with a hanging charred plank; survey stakes in a line to the vent, the last ones melted;
  fallen spire fossil in three pieces with cooled crust between; offering cairn on the north rim; a vent cracked
  open on one side with a sulphur fan on the floor. The **Rising Ember** emblem (flame on three strata bars) is on
  the anvil and the stake tags.

## Stills (`ember_rift_v1_*.jpg`, 1920×1080)
Heroes: `vent_plume_night` (key), `geyser_night` (Kael for scale), `breach_night`, plus `vent_plume_dusk/day`,
`breach_dusk`, `shrine_dusk` (Kael), `bridge_dusk` (Kael), `overview_day/night`, `kael_floor_day/dusk/night`
(gameplay-ish camera at spawn 1), `spire_forest_day`.

## Fly-through
`ember_rift_flythrough_v1.mp4`: see the status line at the end of this file.

## Mesh budget (lavapipe counts per still)
| Shot | Visible tris | Draws | Shadow tris | Shadow draws |
|---|---|---|---|---|
| vent_plume | 0.69 M | 351 | 0.25–0.36 M | 46–98 |
| geyser | 0.63 M | 165 | 0.83 M | 127 |
| breach | 0.23 M | 131 | 0.20–0.87 M | 76–183 |
| shrine | 1.00 M | 418 | 0.96 M | 205 |
| bridge | 0.79 M | 298 | 0.72 M | 187 |
| overview | 1.15 M | 700 | 0.13 M | 61 |
| kael_floor | ~1.0 M | ~400 | ~0.8 M | ~130 |

Terrain quads (2 tris each): ash T1 9 k, banks T1 125 k, ash T2 31 k, basalt wall 131 k, rim T3 55 k
(351 k quads = 0.70 M tris for the whole crater). Near-tier props if all were near: spires 0.88 M quads,
vents 0.37 M quads (LOD ranges keep only a few at that tier). Zone build: ~80 s with a warm prop cache.

**Estimate, GTX 1650 at 1080p60 (medium):** the sheet asks ≤ 1.2 M visible tris and ≤ 250 draws. Triangles fit
(0.2–1.15 M) but shadow tris add up to ~1 M and draws reach 300–700 (the overview: every 48 m prop tile is a draw
per LOD tier). Likely **4–6 ms GPU** for the world: fine for a 16.6 ms frame, **over the zone's 3 ms target**.
Fixes: bigger tiles or merged far tiers, vents to a 2×T1 middle tier, T1 banks to 2×T1, a shadow distance under
120 m. **Web (≤ 500 k tris, ≤ 120 draws):** about 2× over on tris and 3–5× on draws; needs a web preset (T2 floor
only, T3 spires past 60 m, no prop shadows, half particles). Not measured: run `game/debug/render_benchmark.gd`
on the dev PC.

## Self-critique, ranked
1. **Plume** reads as a stack of separate flat discs (a "rock tower" up close), not a billowing column, and it
   isn't lit amber from below at night. Needs overlapping, varied puffs and an emissive underside term.
2. **Overview night and dusk turn single-hue** (warm brown floor, wall, outer slopes and fog). The wall
   and outer slopes are big, featureless, dark dune-like planes from far away; the T3 outer slopes have no detail.
3. **Day ash is too bright** (near-white, L* ~85 against the sheet's 45–62) and the dusk floor goes orange.
4. **Fissure strips** read as flat decals with a thin seam on a dark frame, not crust plates in the T1 shell.
5. **Geyser column** is a straight yellow stack of blobs; no telegraph, no falling droplets readable; too bright.
6. **Banks** (T1 stepped crust) show a diagonal herringbone pattern and lava-bounce orange; heavy (125 k quads).
7. **Spire forest still** frames one spire close up; it doesn't show the forest. Spire facets are good, but
   their colour leans mauve in day light.
8. Bridge shot: the bridge is small and off-centre; the shrine's braziers' coals are tiny.
9. Missing from the sheet's deliverables: readability strip (four legends, Brann vs lava), dusk/day for
   every key image, contact sheet, render benchmark before/after, heat shimmer, lava light falloff on spires.
10. Perf numbers are lavapipe counts and estimates only.
