# Shattered Mesa voxel look-dev v1

Sheet: `docs/lookdev/shattered_mesa.md`. Code: `game/world/zones_voxel/shattered_mesa/`
(branch `lookdev/zone-shattered_mesa`). Rendered with lavapipe (software Vulkan,
colour-correct) through the kit's `zone_capture.gd`; every still below is 1920×1080.

No GitHub release: this session has no tool that can create one (the GitHub
connector has no release call and the CLI is limited to search here), so the
previews are committed in this folder instead.

## Files

| File | What |
|---|---|
| `shattered_mesa_flythrough_v1.mp4` | 20 s at 1920×1080, 30 fps (600 frames, H.264 CRF 18): low through the south-west hoodoo cluster, over Mesa 4's shoulder, up the open lane, **through the Red Arch**, a turn and climb round the Anvil Mesa, over the surveyor's camp (Kael stands there), out toward the Great Mesa. Dust devils drift on the floor, birds circle the Great Mesa. |
| `*_red_arch_{day,dusk,night}.jpg` | the key image: the Red Arch at noon from the sand (Kael tiny at its west foot) |
| `*_hoodoo_field_{day,dusk}.jpg` | **Kael for scale** beside a 48 m hoodoo in the south-west cluster |
| `*_anvil_camp_{day,dusk,night}.jpg` | **Kael for scale** at the surveyor's camp on the Anvil Mesa (lean-to, theodolite aimed at the arch, Banded Sun barrel, ledger and stone, lantern) |
| `*_spawn_gameplay_{day,dusk,night}.jpg` | **Kael for scale**, gameplay-height camera at spawn 1 between two mesa walls |
| `*_well_day.jpg` | story: the stone-lined well, frayed rope, dented bucket, sand drift; Kael beside it |
| `*_petroglyphs_day.jpg` | story: arch, sun, two figures, a spiral and the Banded Sun pecked into a varnished boulder |
| `*_fallen_hoodoo_day.jpg` | story: a hoodoo broken into drums on the floor, its cap upside down |
| `*_overview_{day,dusk,night}.jpg` | wide view over the Canyon Maze plateau: free mesas, the hoodoos, the arch, the far ring |
| `*_contact_sheet.jpg` | every still |

Storytelling props built: petroglyph boulder, surveyor's camp, well, fallen hoodoo, a cairn line (one cairn per free mesa top, 7). Not built: the chockstone in a slot canyon.

## Truth kept

- The floor is triangles on the heightmap's own 2 m samples (the sim's
  `ZoneGround` grid). `tests/world/test_shattered_mesa_voxel.gd`: the visible floor
  stays within 4.4 cm of the sim at both spawns and on the Anvil and Great
  Mesa tops.
- Hoodoos (46), boulders (220) and the Red Arch take `ShatteredMesaProps`'
  transforms (PropKit seed 4242), checked by the same test. The arch keeps its
  footprint (two legs, span, 90 × 70 × 40, yaw 0.6); corbels step 12 m into the
  top corners of the opening so it reads as an arc (the sim has no arch
  collider, so this is visual only, and the fly-through gap stays 37 m wide at
  the top).
- Nothing in `game/combat`, the sim, the zone `.tres` or the props builders changed.

## Perf

Counts from the capture (lavapipe, the real Forward+ pipeline; the software GPU time isn't comparable to a GPU):

| Shot | Visible triangles | Draw calls | Shadow triangles | Shadow draws |
|---|---|---|---|---|
| red_arch (day) | 1,485,414 | 230 | 1,656,794 | 119 |
| hoodoo_field (day) | 1,008,910 | 143 | 1,334,952 | 81 |
| anvil_camp (day) | 903,770 | 216 | 762,778 | 74 |
| spawn_gameplay (day) | 754,616 | 190 | 1,086,264 | 113 |
| petroglyphs (day) | 1,359,926 | 174 | 2,253,956 | 119 |
| fallen_hoodoo (day) | 1,332,464 | 380 | 1,227,550 | 69 |
| overview (day) | 849,030 | 437 | 184,166 | 8 |

Built totals (everything, all tiers): floor 493 k triangles (near tier counted), cliff rock 1.53 M (T2 near + T3 ring),
hoodoos 1.0 M quads at T2 if every one were at the near tier (they switch to 2×T2 at 110 m and T3 at 260 m),
220 boulders + 490 talus, 2,600 sage, 57 dead trees. Build: about 110 s cold (cached afterwards: about 1 s).

**Estimate, GTX 1650 at 1080p (medium):** ground-level shots push 0.7–1.5 M visible plus 0.8–2.3 M
shadow triangles through about 200 draws. On that GPU I expect about **4–6 ms** for the world (triangle
setup for the main and shadow passes dominates, plus SSAO), so 60 fps holds but the zone is **over the
sheet's 3 ms budget** and over its 1.2 M / 250 targets in the busiest shots (arch, petroglyphs; the
overview has 437 draws). Not measured: the render benchmark needs the GTX 1650.
**Web build:** about 3× over its 500 k / 120-draw target; it needs a web preset (hoodoos and boulders one
tier coarser, scrub range halved, shadows from the arch and mesas only, T3 rock past 150 m).
The main costs and fixes: the VoxelMesher writes one quad per open voxel face (no greedy merge) for
props, so hoodoos and boulders are face-heavy; shadow casters reach 180 m.

## Self-critique (ranked, worst first)

1. **Over the perf budget** (above): about 1.49 M visible + 1.66 M shadow triangles at the key shot, 437 draws in the overview; web far over. Props need greedy-merged faces and a shorter T2 range.
2. **The Red Arch still reads partly as a gate.** The sim's footprint is two boxes and a beam; corbels round the top corners, but the opening is still mostly rectangular, and the chipped holes in the slabs read as little windows. v2: fewer, larger chips, a thicker, sagging span, irregular leg outlines.
3. **The mesas are round layer cakes.** The sim's free mesas are circular, and the 2.8 m bands are uniform in thickness, so every mesa looks alike; no caprock overhang lip (the column field can't overhang); the T2 column steps show as vertical fluting on curved walls.
4. **Hoodoos are too regular:** stacked plates with similar drums; all at T2 (the sheet asks for T1 bases); octagon faces show stair-step fluting.
5. **Sand is bright and plain at distance.** Dunes are faint, washes read as thin pale lines (almost roads) from above, and the near ripple and pebble detail is only visible close up. Values sit near the top of the L* 70–85 plan.
6. **Plateau tops (the Canyon Maze) are a dull caprock field** with blotchy sand pockets; no slot-canyon hero shot and no chockstone were made.
7. **Fly-through:** 20 s (the sheet asks for 60 s); it skims Mesa 4's shoulder and some mesa walls quite closely, and the turn after the arch is abrupt. Motion is limited to two rigid dust devils and three far birds. No scrub sway, canvas flap, sand drift or heat shimmer.
8. **The far ring is other zones' terrain** painted in desert colours (the Frozen Peaks' spikes read as pale red mountains on the horizon).
9. **Not judged on a real GPU:** lavapipe only, and no render benchmark.
10. The first final stills were made before a floor fix: two triangles per 2 m cell missed the sim's bilinear ground by up to 27 cm on mesa tops (caught by the new feet test). The published stills and video are the re-render with the fix (twisted cells now split onto the exact surface, within 4.4 cm).

## Kit changes

- `zone_capture.gd` (bug): an unnamed zone node named the video `@node_3d@6_flythrough.mp4`; it
  now falls back to the zone script's file name. Nothing else in `voxel_zone_kit/` changed.
  `VoxelHeightfield.chunk` is set per field (89.6 m / 179.2 m) from the zone, not edited in the kit.
