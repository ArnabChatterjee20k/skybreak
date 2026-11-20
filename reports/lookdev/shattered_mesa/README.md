# Shattered Mesa voxel look-dev v1

Sheet: `docs/lookdev/shattered_mesa.md`. Code: `game/world/zones_voxel/shattered_mesa/`
(branch `lookdev/zone-shattered_mesa`). Rendered with lavapipe (software Vulkan,
colour-correct) through the kit's `zone_capture.gd`; every still below is 1920×1080.

No GitHub release: this session has no tool that can create one (the GitHub
connector has no release call and the CLI is limited to search here), so the
previews are committed in this folder instead.

## Files

STILLS_TABLE

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

PERF_TABLE

## Self-critique (ranked, worst first)

CRITIQUE
