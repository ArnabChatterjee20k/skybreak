# Voxel zone perf pass (branch `lookdev/zone-perf`)

All seven voxel zones (Heartbloom plus the six `lookdev/zone-*` builders) on one branch, with the
kit changes that cut their cost without changing how they look, a zone benchmark, and before/after
stills.

**Numbers here are lavapipe counts** (Mesa's software Vulkan, the real Forward+ pipeline). Triangle
and draw counts are exact; lavapipe's milliseconds mean nothing for a GPU. The GTX 1650 ms come from
running the benchmark on the owner's PC (command below).

## What changed

Kit level (`game/world/voxel_zone_kit/`), so every zone gets it:

1. **Lossless greedy merge of prop faces** (`VoxelFaceMerge`, `voxel_merged_prop.gdshader`). The
   character kit's mesher writes one quad per voxel face, with colour, corner AO and bevel flags per
   vertex, so no two faces can share a quad. The merge moves those per-face values into a small face
   texture (4 texels per face) and merges coplanar faces into rectangles; the shader finds the voxel
   face under each pixel and shades it exactly as before: the same two-triangle colour interpolation,
   the same bilinear AO and bevel ramps. The material type (matte, metal, glow...) is per face too,
   so a merged prop is one surface: one draw per copy, whatever its materials. Props drop to
   about a fifth of their triangles in both the main and the shadow pass, and the face texture is
   16 bytes per face against 256 for the per-face vertices.
2. **HLOD far regions** (`VoxelProp.place`). Each 4 x 4 block of placement tiles also gets one node
   with the last LOD tier of all its copies. It shows only from far enough away that every tile in
   the block would show its last tier anyway (its begin plus the farthest tile centre), and the tiles
   take it as their `visibility_parent`, so they hide while it shows. Same picture, one draw per block.
3. **Occluders**: every heightfield chunk gets a conservative occluder (4 m boxes that stay inside
   the solid), and Stormfall's buildings get one box inside each building's body. The stage turns
   occlusion culling on for its viewport (no project setting needed).
4. **Quality tiers** (`VoxelQuality`, `GraphicsSettings.Quality`): HIGH, the GTX 1650's 1080p60
   default, draws exactly the authored look. MEDIUM keeps everything at gameplay distance as it is
   and pulls far LOD switches in (0.8x, including zones' own terrain and building LOD distances),
   with a 150 m sun whose near split covers the same 32 m as before (contact shadows just as sharp)
   and no shadows from props under 0.5 m. LOW and WEB shorten ranges further, cast from the first
   LOD tier only, use bigger terrain chunks and a shorter sun (WEB: one split, no SSAO).
   `VoxelQuality.tier` defaults to the player's saved quality, and to WEB in a web build.
5. Zone fixes: Stormfall's outer ground ring (8 m tier only) merges 4 x 4 tiles into one mesh.
   Skyhold's islands get a 2 x T2 far tier below HIGH: each island switches as a whole (one box
   for all its chunks, so no seams) at 300 m on MEDIUM. Shattered Mesa's rock/floor, Frozen Peaks'
   mountains and Stormfall's block and ground tiers scale their authored switch distances with the
   tier (`VoxelQuality.far`), HIGH unchanged.
6. WEB also starts props at their second LOD tier.

Tried and reverted: blocks for short-range scatter (dense tufts drawn a block radius further cost
more triangles than the draws they saved), and 64 m terrain chunks on HIGH/MEDIUM. Frozen Peaks sets its mountain LOD per
chunk after building, so bigger chunks dropped a shadow-casting mountain chunk early and the valley
lost a big shadow (caught by the stills). HIGH/MEDIUM keep the authored 32 m chunks.

## Before / after

BENCH_TABLE

## Visual proof

STILLS_TABLE

Previews (before | after | difference x4) are in this folder: `<zone>_before_after_high.jpg` and
`<zone>_before_after_medium.jpg`.

## Benchmark

`tools/bench/zone_bench.gd` builds each zone at each tier, flies the zone's fly-through path
(`flight()`, 48 samples by default) with four voxel Kaels standing in for the fighters, and prints
visible and shadow triangles, draw calls and CPU/GPU render ms (avg, p95, max). `--breakdown` lists
the node groups that draw at the worst sample.

On the owner's PC (Windows, GTX 1650):

```sh
D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe --path . --fullscreen --resolution 1920x1080 --disable-vsync -s res://tools/bench/zone_bench.gd -- --tiers=high,medium,low,web --json=zone_bench.json
```

It exits 1 if any zone misses the medium budget (p95 <= 300k visible triangles and <= 250 draws).

## Not done / open

- **Medium misses the 300k-triangle target in every zone but Stormfall** (see the table). After the
  merge, what's left is mostly terrain with no LOD of its own (Heartbloom's island undersides,
  Skyhold's islands, Shattered Mesa's T2 rock, Frozen Peaks' foothills and mountains) and the big
  canopies and puff clouds. Getting to 300k means coarser terrain within view, which the owner would
  see; I stopped at "invisible at gameplay distance". Next levers, in order: a kit-level far tier
  for any heightfield (the Skyhold island pattern), Heartbloom's puff clouds at T3 x 2 past 150 m,
  Verdant canopy impostors past 120 m.
- **Draws**: Medium meets 250 in Heartbloom only; Verdant (grove scatter on 16 m tiles), Stormfall
  (ground tiles), Ember and Skyhold remain over. Short-range scatter is the main source.
- **GPU ms are not measured**: run the benchmark on the GTX 1650 (command above) and paste the
  output here. Lavapipe ms in the JSON are meaningless.
- **Web**: the WEB tier is measured with Forward+ counts; a real web export (Compatibility renderer)
  hasn't been run with the voxel zones. WEB is still over its 500k / 120 target in most zones.
- Occlusion culling helps only the main pass and needs a few frames to warm up after a camera cut.
- The benchmark's `--breakdown` ignores `visibility_parent` and occlusion, so it over-counts; the
  totals come from the renderer and are exact.
