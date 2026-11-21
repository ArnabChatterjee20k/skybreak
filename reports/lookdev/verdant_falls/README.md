# Verdant Falls voxel look-dev, v1

Sheet: `docs/lookdev/verdant_falls.md`. Code: `game/world/zones_voxel/verdant_falls/` on branch
`lookdev/zone-verdant_falls`. Renders: Godot 4.7.2 official (linux x86_64, SHA-512 checked against
`SHA512-SUMS.txt`) on lavapipe (software Vulkan), 1920×1080, MSAA 4×, full kit lighting stack (SSAO + baked AO,
soft sun shadows, rim, filmic, glow).

| File | What |
|---|---|
| `verdant_falls_v1_falls_key_day.jpg` | key image: the Great Falls across the mirror lake at sunrise, Kael on the south shore |
| `verdant_falls_v1_falls_key_dusk.jpg` | the same at dusk |
| `verdant_falls_v1_shrine_day.jpg` | the overgrown shrine, Kael on the platform (frog guardian, empty heron plinth, Falling Leaf altar, orchids) |
| `verdant_falls_v1_grove_day.jpg` | the Giant Grove: buttress roots, the canopy walkway (planks missing, ring platforms), god-ray cards |
| `verdant_falls_v1_kael_scale_day.jpg` | gameplay-ish camera on Kael on the moss floor by a spawn |
| `verdant_falls_v1_fallen_giant_day.jpg` | the fallen giant (root plate, hollow end), logs, boulders, ferns |
| `verdant_falls_v1_overview_day.jpg` | wide overview: lake, basalt cliff, falls, plateau |
| `verdant_falls_v1_contact.jpg` | contact sheet of the six day stills |
| `verdant_falls_flythrough_v1.mp4` | 20 s fly-through, 1920×1080, 30 fps, H.264 CRF 21 (600 frames, lavapipe, about 4 s a frame): low over the lake to the falls, up the curtain, along the plateau river, a dive over the lake, a run through the Giant Grove under the walkway, past the shrine, ending on the falls |

The prompt asked for a 720p30 video; the look-dev skill's rule (videos 1080p30 or more) overrides that, so the
fly-through is 1920×1080 at 30 fps.

## Sim stays the truth
- Floor: smooth top on `TerrainHeightmap.ground_height_at`, the samples `ZoneGround` bakes. Test: T1 floor vertices
  within 4.4 cm of `ZoneGround.height_at`.
- Trees (150: 40 giants, 110 small), both canopy layers per tree, the falls curtain and its spray: taken from
  `VerdantFallsProps.build` run as a zone match does (`PropKit` seed 4242, all ground-zone spawns kept clear).
- Lake: the plane at y 0. Story props sit outside the 25 m spawn ring (tested).
- No gameplay, sim or shared-kit files changed (`git diff origin/lookdev/heartbloom-zone -- game/world/voxel_zone_kit` is empty).

## Perf (numbers from the capture; lavapipe GPU ms are not comparable to a real GPU)

| Shot | Visible tris | Draws | Shadow tris | Shadow draws |
|---|---|---|---|---|
| falls_key | 1.27 M | 550 | 0.63 M | 41 |
| shrine | 1.14 M | 388 | 1.13 M | 74 |
| grove (worst) | 3.01 M | 890 | 2.35 M | 105 |
| kael_scale | 1.39 M | 537 | 0.91 M | 62 |
| fallen_giant | 0.85 M | 397 | 0.45 M | 41 |
| overview | 1.70 M | 777 | 0.001 M | 1 |

Geometry: floor (T1/T2/T3 smooth quadtree) 12.5 k quads, basalt cliff and plateau 70 k quads, backdrop 39 k quads;
giant tree near tier 145 k tris (base + trunk), canopy near tier 78 k tris; ferns 1.5–2.3 k, elephant ears
3.5–4 k, boulders 3.6 k, logs 7.3 k tris per instance. LOD: giant base 2×T1 → T2 at 35 m → T3 at 120 m; trunk T2 → T3
at 70 m; canopies T2 → T3 at 55 m; ferns and ears T1 → 2×T1 at 30 m, gone at 70–80 m; mushrooms and reeds end at
30–45 m. Only the finest one or two tiers cast shadows; floor tops cast none.

**Estimate.** GTX 1650 at 1080p: most views are 0.9–1.7 M visible tris plus 0.5–1 M shadow tris, about 2–4 ms of
world GPU at medium. That's inside the 3 ms budget at the low end only. The grove (3 M + 2.35 M shadow, 890
draws) is over the sheet's 1.2 M / 250-draw target and probably costs 5–7 ms. Web build (target ≤ 500 k tris and
≤ 120 draws): **not met** anywhere yet. It needs the fixes below.

Fixes in order of payoff:
1. Greedy-merge prop faces in the kit's `VoxelMesher` path for static props, so coplanar voxel faces become one quad (likely 3–6× fewer tris on canopies and trunks).
2. Canopy impostors past 120 m.
3. Merge placement tiles per LOD band to cut the draw count.
4. Web: drop shadows on canopies, halve the scatter.

## Self-critique, ranked by severity
1. **Over the triangle and draw budget** in the dense grove (3 M visible, 890 draws vs 1.2 M / 250), and nowhere near the web target. The look relies on per-voxel-face prop meshes.
2. **The basalt cliff reads as a rough dark wall more than as columns.** The prisms show as vertical streaks, and the light lip on every column top reads like rain marks. It needs real column outlines (hex joints, dark seams) and moss ledges.
3. **The falls are a flat, uniformly bright trapezoid.** There's no thickness, the curtain is narrow at the top (the sim's quad), and there's no plunge-pool spray volume. The lake reflection of the falls is an analytic stepped band that still reads as a slab, and there's no ripple ring you can see.
4. **The value plan is only partly met.** The near moss floor is lighter and more lime (about L\* 60–70) than the sheet's 45–55. The mid-ground frame is dark only under the grove canopies. Far canopies at the T3 LOD go pale and flat. The overview reads mostly mid-light green.
5. **Canopies read as stacked discs ("mushroom trees")**, especially from above and far away. Their outlines are too round and too regular; they need more clusters, more gaps, and lianas or limbs showing between layers.
6. **The fly-through still grazes the fallen giant's root plate twice** (around 13.6 s and 17.5 s): the camera sweeps very close past it and the plate fills a corner of the frame for a few frames. The opening scatter clip from the first render is fixed. The spray and lake-mist puffs read as soft blotches in the dive (6–8 s) and in the overview. About 7 s of the 20 s stay on the falls.
7. **The story props are blocky and plain up close.** The shrine's blocks are big unbevelled cubes. The fallen giant is a straight octagonal prism with stripe furrows. The frog guardian reads as a blob at a distance. The toppled heron and the islet don't appear in any hero still.
8. **Floor scatter**: elephant ears read as floating flat leaves near the camera; ferns are flat stepped stars.
9. **Atmosphere**: the god-rays are additive cards and show hard edges in some frames; the height mist is subtle; the sky is a plain gradient with few clouds. The sheet's rainbow, butterflies, birds and canopy sway aren't built (sway data is collected, but `animate` doesn't move anything yet).
10. **Not delivered from the sheet**: night preset stills, the readability strip with all four legends, benchmark output on a real GPU, the 60 s / 1080p60 version of the fly-through, the overview and key at all three times of day.
