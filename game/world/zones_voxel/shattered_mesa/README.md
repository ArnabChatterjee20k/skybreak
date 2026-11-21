# Shattered Mesa: voxel look-dev

Visual pass over the sim's Shattered Mesa (`docs/lookdev/shattered_mesa.md`). Built
with the shared zone kit (`game/world/voxel_zone_kit/`), rendered with its
`zone_capture.gd`:

```sh
export VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json GALLIVM_PERF=no_aos_sampling LP_PERF=no_rast_linear
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --disable-vsync --resolution 1280x720 \
    -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out> heroes \
    --zone=res://game/world/zones_voxel/shattered_mesa/shattered_mesa_voxel.gd
```

**The sim stays the truth.** Nothing here is read by the sim or changes it:

- Ground: the baked `TerrainHeightmap` (from `TerrainShape._mesa`). The floor mesh
  uses the heightmap's own 2 m samples as vertices, split along the flatter
  diagonal, so the visible floor stays within a few cm of `ZoneGround`
  (`tests/world/test_shattered_mesa_voxel.gd` checks 4.4 cm on the floor and
  on mesa tops).
- Hoodoos, boulders and the Red Arch: the transforms `ShatteredMesaProps` makes
  with `PropKit` seed 4242 (the same calls `WorldMap._build_props` makes;
  Shattered Mesa is the first zone, so the RNG state matches).
- Everything else (scrub, talus, dead trees, story props) is visual only, low,
  and off the open floor lines.

## Files

| File | What |
|---|---|
| `shattered_mesa_voxel.gd` | `ShatteredMesaVoxel` (a `VoxelZone`): build, presets, shots, flight, sand bounce light |
| `mesa_terrain.gd` | `MesaTerrain`: the floor (2 m sim grid, 8 m far tier, skirts under tread edges) and the cliffs (`VoxelHeightfield` of rock columns at T2, tops snapped to 2.8 m strata bands; T3 far tier and ring) |
| `mesa_floor.gdshader` | floor look per T1 cell: macro colour (1 m texture), noise, wind ripples, pebbles, mud cracks in washes; skirts get the caprock band then strata |
| `mesa_rock.gdshader` | cliffs: the kit terrain shader's bevel and step AO with the zone strata on walls and sand-dusted ledges |
| `mesa_strata.gdshaderinc` | the band table: light/dark/pale bands, cross-bedding, seams, lit lips, desert varnish, lichen on north faces |
| `mesa_props.gd` | `MesaProps`: Red Arch (laid slabs over the sim's footprint), 6 hoodoo variants, 4 boulder variants, talus, sage, dead trees, and the story props |
| `rock_cache.gd` | `RockCache`: a built rock field (meshes and shader parameters) on disk |

Caches: `user://voxel_zone_cache/shattered_mesa_v<MesaTerrain.VERSION>/` (terrain)
and `user://voxel_prop_cache/mesa_*` (props, `MesaProps.VERSION`). Bump the version
after changing a design.

## Why the terrain isn't a kit `VoxelHeightfield` lawn

Heartbloom's islands are small; this zone is a 680 x 940 m heightmap. A T1 smooth
top over it would be 80 M columns. Instead the floor reuses the heightmap grid
(the sim's own) and the per-voxel look comes from the shader at T1, while the
cliffs use the kit's stepped `VoxelHeightfield` at T2 (with `chunk` raised to
89.6 m so the draw calls stay low).
