# Voxel zone kit

Code-built voxel zones in Skybreak's look-dev style: the same voxel density, colour
recipe and lighting stack as the voxel characters (`game/characters/voxel_kit/`), at
island scale. Heartbloom Gardens (`game/world/voxel_zones/heartbloom/`) is the first
client and the worked example. The process (design sheet, build, stage, owner gates)
is the character one: `.claude/skills/voxel-character-lookdev/SKILL.md`, "Applying it
to a zone".

**Rule zero: the sim is the truth.** A voxel zone is a visual pass over the zone's
existing geometry and layout (`IslandField`, the zone's `.tres`, its props builder and
seed). Never move a walkable surface or a prop the sim knows about. The lawn must stay
within 4.4 cm of the sim's surface (the QA foot check allows 5 cm).

## Pieces

| File | Class | What it is |
|---|---|---|
| `voxel_zone.gd` | `VoxelZone` | Base class of a zone. Override `build()`, `ground_at()`, `shots()`, `flight()`; optionally `presets()`, `cloud_sea()`, `flight_kael()`, `animate(t)`. Holds `stats` (for the perf report) and `lantern_materials` (driven per preset). Defines the cell ladder `T0`–`T3`. |
| `voxel_heightfield.gd` | `VoxelHeightfield` | Terrain as columns of cells. Greedy chunk meshing (64×64 columns per chunk, so each chunk is frustum-culled on its own). Baked AO and painted detail go in a per-column colour texture. Per-voxel noise and bevels come from the shader. |
| `voxel_terrain.gdshader` | | Reads each pixel's cell from the world position: column colour, ±5% per-cell noise, bevel highlight and tilt on convex edges, step AO at concave feet, grass lip → soil → rock on walls, strata slabs on undersides. |
| `voxel_prop.gd` | `VoxelProp` | Static voxel meshes from the character kit's `VoxelGrid` + `VoxelMesher` (cavity AO, corner AO, bevels), cached on disk. Tiled MultiMesh placement with LOD tiers. |
| `voxel_stage.gd` | `VoxelStage` | Sky, sun with soft 2-split shadows, rim, ambient, fog, cloud sea. Value presets `day` / `dusk` / `night`. |
| `voxel_sky.gdshader` | | Gradient sky, white cloud sea below the horizon, fbm puff clouds in a band, sun disc with halo, or moon and stars. |
| `voxel_cloud_deck.gdshader` | | The cloud sea's floor: a flat deck with billows snapped to T3 cells. |
| `zone_capture.gd` | (SceneTree script) | Hero stills, the fly-through video, voxel Kael for scale, and render stats per shot. |

### Cell ladder

| Tier | Cell | Use |
|---|---|---|
| `T0` | 2.2 cm | hand-scale props ≤ 1 m (lanterns, locks, flowers, rope). Same cell as a fighter's body. |
| `T1` | 8.8 cm | the walkable lawn, trees, most props 1–15 m |
| `T2` | 35 cm | cliffs, undersides near the lip, big landmark cores, far LOD |
| `T3` | 1.4 m | deep undersides, clouds |

## Heightfield (`VoxelHeightfield`)

```gdscript
var hf := VoxelHeightfield.new(VoxelZone.T1, world_min, world_max)   # down=true for an underside
for z in hf.size.y:
	for x in hf.size.x:
		var w := hf.centre(x, z)                       # world (x, z) of the column
		hf.set_column(x, z, shown_level, hidden_level, colour)   # levels in cells; NONE = no column
hf.smooth_height = func(x, z): return surface(x, z)  # optional: exact smooth top (lawns)
hf.bake_step_ao(0.3, 2)                               # optional: stepped fields only
var mat := ShaderMaterial.new()
mat.shader = preload("res://game/world/voxel_zone_kit/voxel_terrain.gdshader")
hf.bind(mat)                                          # cell, origin, colour and level textures
var node := hf.build(self, mat, "IsleTop")            # one MeshInstance3D per 64x64 chunk
```

- **Stepped fields** (undersides, terraces): shown faces are merged into the biggest
  rectangles of equal level (greedy 2D), and walls into runs along each line. A flat
  10×10 field is 5 quads.
- **Smooth tops** (walkable lawns): a quadtree of quads (32, 8, 2, 1 cells) whose corners
  lie exactly on `smooth_height`. Big quads cover the interior, single cells follow
  the rim, and there are walls only at the rim. The T-junction gap on a gentle dome is
  under 1 mm. The look stays per voxel: the shader picks the colour of the cell under
  each pixel.
- **Colour**: alpha in `set_column`'s colour is free (a material code if you need one).
  Paint paths, petals, clover and baked canopy shade straight into the colour.
- **Strata**: an underside whose bottoms are quantised to slabs of `strata_cells` cells
  (wobbled per slab, see Heartbloom's `_island_underside`) reads as stacked rock layers.
  The shader alternates `under_color` / `under_alt` per slab, puts a dark seam at
  each slab's foot and darkens with depth (`under_top`, `under_depth`) toward
  `under_deep`.

Terrain shader uniforms worth tuning: `rock_color`, `rock_shadow`, `soil_color`,
`under_color`, `under_alt`, `under_deep`, `strata_cells`, `noise_amount` (0.05),
`bevel_width`, `edge_lift`, `step_ao`, `crack_amount`.

## Props (`VoxelProp`)

```gdscript
var paint := func(g: VoxelGrid) -> void:
	g.paint(bounds, func(p): return VoxelSdf.box(p, c, half, 0.03), Mat.STONE)
	g.paint_surface(bounds, func(p, c): return p.y < 0.3 and VoxelSdf.hash3(c, 7) < 0.4, Mat.MOSS, [Mat.STONE])
# One mesh (cached as user://voxel_prop_cache/<key>_c<cell mm>_v<version>.res):
var m := VoxelProp.mesh("my_rock", VERSION, bounds, VoxelZone.T1, paint, color, surface_of)
# The same design at several cells (LOD tiers, finest first). If the paint closure
# uses an RNG, reseed it inside the closure so every tier gets the same shape.
var tiers := VoxelProp.tiers("my_tree", VERSION, bounds, [VoxelZone.T1, VoxelZone.T1 * 2, VoxelZone.T2], paint, color, surface_of)
# Place: tiled MultiMeshes (VoxelProp.TILE = 24 m). Each tier ends at its range
# (0 = never); only the first `shadow_tiers` tiers cast shadows.
VoxelProp.place(self, "Trees", tiers, [32.0, 110.0, 0.0], transforms, 2)
VoxelProp.place(self, "Tufts", [tuft], [30.0], tuft_transforms, 0)
```

- `color(mat, p, c, n, occlusion, exposure) -> Color` and `surface(mat) -> VoxelProp.Surf`
  work like a character's `VoxelDesign`. `VoxelDesign.default_color` gives the shared
  recipe (±2–6% noise, cavity shade, wear on exposed edges).
- `Surf`: `MATTE` (stone, wood), `METAL`, `WATER`, `PETAL`, `GLOW` (paper lanterns,
  emission driven by the preset's `lantern`), `BARK`.
- **Caching**: the first build of a design voxelises and meshes on the CPU (seconds to
  minutes). Later builds load from the cache. **Bump your zone's `VERSION` after
  changing any design.** Delete `user://voxel_prop_cache/` to force everything.
- **LOD rules of thumb**: T0 scatter ends at 30–40 m and casts no shadow. T1 props
  swap to 2×T1 at about 30 m and to T2 at about 100 m, and only the first two tiers
  cast. Landmarks are single meshes.
- `VoxelProp.quads(mesh)` counts quads (2 triangles each) for the perf report.

## Stage (`VoxelStage`)

```gdscript
VoxelStage.shadow_quality()                   # once per process: 4096 atlas, soft medium
var stage := VoxelStage.new()
add_child(stage)
stage.setup(zone.presets(), zone.cloud_sea()) # sea: {rect: Rect2, height, puffs, seed}
stage.lantern_materials = zone.lantern_materials
stage.apply("dusk")                           # or a Dictionary of values
```

The stack: filmic tonemap, SSAO (radius 1.2, intensity 1.4) on top of the baked AO,
glow (threshold 1.2), exponential distance fog with aerial perspective, one
shadowed sun (2 blended splits, 180 m), an unshadowed rim, an ambient colour and
sky reflections.

Preset keys (see `VoxelStage.PRESETS` for the default values): `sky_top`,
`sky_horizon`, `sky_below` (the cloud sea), `cloud`, `cloud_shadow`, `cloud_cover`,
`sun_dir` (towards the ground), `sun_color`, `sun_energy`, `sun_size` (0 = no disc),
`moon`, `stars`, `rim_color`, `rim_energy`, `ambient_color`, `ambient_energy`,
`fog_color`, `fog_density`, `exposure`, `lantern`. Override `presets()` in your zone
with a copy of the defaults: `var p := VoxelStage.PRESETS.duplicate(true); p.dusk.sun_color = ...`.

Readability (from the design sheets): the world's mid-ground sits at L* 55–80 and
nothing goes above ~45% saturation except accents and sparkles, so the fighters
(main mass L* ≤ 45) always read. Keep pink, energy colours and saturated violet or
cerulean out of the sky and fog.

## Capture (`zone_capture.gd`)

```sh
# Lavapipe on a cloud agent (software Vulkan, colour-correct but slow: 5–15 s a frame at 1080p)
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json GALLIVM_PERF=no_aos_sampling LP_PERF=no_rast_linear
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --disable-vsync --resolution 1280x720 \
    -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out> heroes \
    --zone=res://game/world/voxel_zones/<zone>/<zone>_voxel.gd
```

| Mode / option | Does |
|---|---|
| `draft` | every shot once, at `--time` (default dusk) |
| `heroes` | every shot at each of its `times` |
| `flythrough` | `--fps` (30) × `--seconds` (20) JPG frames to `<out>/frames`, then `ffmpeg` → `<out>/<zone>_flythrough.mp4` (H.264, CRF 18). `--from=N` resumes at frame N (earlier frames are stepped but not rendered). |
| `all` | heroes, then the fly-through |
| `--size=WxH` | output size (default 1920x1080, the published minimum) |
| `--shots=a,b` | only these stills |
| `--kael=<scene>` / `--kael=none` | the character for scale (default voxel Kael) |

`shots()` entries: `{name, from, at, fov, kael: [Vector2 at, yaw], kael_y, times}`.
`flight()` is a list of `{from, at, fov}` control points, evenly spaced in time and
joined by a Catmull-Rom spline. Space them evenly in distance too, or the speed
jumps. `flight_kael()` stands Kael somewhere on the way. Each still prints its
software GPU time, visible primitives and draw calls, and the same for the shadow
pass. Use the counts for the budget. The software GPU time is not comparable to a
real GPU.

Rules (from the skill): published stills are 1920×1080 or larger, videos 1080p at
30 fps or more. Look at every frame before publishing, and check that the process
exited.

## How to build a zone (recipe)

1. **Design sheet** `docs/lookdev/<zone>.md` (copy `heartbloom.md`): identity, layout
   from the sim, detail at three scales, palette with shadow tones, cell tiers,
   lighting presets, motion, perf budget.
2. **Folder** `game/world/voxel_zones/<zone>/<zone>_voxel.gd`:
   ```gdscript
   class_name EmberRiftVoxel
   extends VoxelZone
   const VERSION := 1
   func build() -> void:
       # 1. read the sim's truth: field / heightmap, zone .tres, prop placements (run the
       #    sim's props builder on a scratch node with its seed, like Heartbloom's _placements)
       # 2. terrain: a VoxelHeightfield per island/area (smooth top at T1 where fighters
       #    stand, stepped strata undersides at T2/T3), colours painted per column
       # 3. landmarks: VoxelProp.mesh + MeshInstance3D at the sim's positions
       # 4. repeated props: VoxelProp.tiers + VoxelProp.place with ranges
       # 5. scatter (tufts, stones, flowers, debris): place() with 30-40 m ranges, no shadows
       # 6. motion: particles, animate(t) for sway
   func ground_at(x, z): return <the sim's surface function>
   func shots() -> Array[Dictionary]: ...   # the sheet's hero list, Kael in at least three
   func flight() -> Array[Dictionary]: ...  # 10-12 points for 20 s
   ```
3. **Draft** at a small size first (`draft --size=960x540`), look at everything, fix,
   then `heroes` and `flythrough` at 1920×1080.
4. **Report** tris and draw calls per shot (printed), terrain and prop quads
   (`stats`), and the budget estimate. Publish the pre-release with an honest, ranked
   critique.

## Lessons from Heartbloom

- A whole-zone MultiMesh with a visibility range uses the AABB of the *whole zone*, so
  the LOD never switches. Always place through `VoxelProp.place`, which tiles.
- Contour terraces on a lawn read as rings from above. Use a smooth top for walkable
  ground and keep the steps for rock.
- Pink sky + pink fog + pink clouds made one flat pink. The sky, fog and cloud sea
  stay neutral, and the accent lives in props.
- Emissive paper at full emission blows out to white under filmic. Drive emission per
  preset (`lantern`: 0.4 day, 1.0 dusk, 1.5 night).
- RNGs used inside a paint closure must be reseeded inside it, or every LOD tier
  builds a different tree.
