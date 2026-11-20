# Voxel kit

Code-built, skinned voxel characters in Skybreak's look-dev style (the process is in
`.claude/skills/voxel-character-lookdev/SKILL.md`). Voxel Kael
(`game/characters/kael_voxel/`) is the first client and the worked example.

## Pieces

| File | What it is |
|---|---|
| `voxel_sdf.gd` (`VoxelSdf`) | SDF primitives: sphere, ellipsoid, capsule, rounded box, tapered cylinder, torus, slice, smooth union, `hash3` for per-voxel noise. |
| `voxel_grid.gd` (`VoxelGrid`) | A dense grid of (material, rig tag) cells. `paint(bounds, sdf, mat, tag, mode)` with `FILL`/`ADD`/`CARVE`/`PAINT` (PAINT recolours its own tag's cells and never retags), `paint_surface(bounds, test, mat, only)` for decals, stitches and emblems, `smooth(soft_materials)` to clean single-voxel noise. |
| `voxel_mesher.gd` (`VoxelMesher`) | One face per open voxel side, skinned. Bakes per-voxel colour (via the design), cavity AO from a blurred occupancy field, corner AO (CUSTOM0) and convex-edge flags (CUSTOM1). Weights are computed per corner, so shared corners always match. |
| `voxel_figure.gdshader` | sRGB vertex colour, corner AO, a bevel highlight on convex voxel edges. Varyings are clamped: MSAA extrapolation on edge-on faces otherwise makes HDR fireflies that bloom turns into blobs. |
| `voxel_design.gd` (`VoxelDesign`) | The base class a character's design extends (below), with the shared colour recipe and weight helpers. |
| `voxel_body.gd` (`VoxelBody`) | A node that builds a design's mesh (cached per design) and swaps it onto the rig's skeleton, with a rest-pose Skin. |

## Adding a character

1. Write the design sheet `docs/lookdev/<name>.md` first (skill, step 1).
2. `game/characters/<name>_voxel/<name>_voxel_design.gd`:

   ```gdscript
   class_name VexaVoxelDesign
   extends VoxelDesign

   enum Mat { EMPTY, ... }        # 0 must be EMPTY
   enum Tag { TORSO, ARM_L, ... } # rig tags: one per rigid part, one per finger

   func build_grids() -> Array[VoxelGrid]:   # body at ~1/64-1/82 of the height, face/hands at half
       return [build_body(), build_head(), build_hand(1.0), build_hand(-1.0)]

   func color(mat, p, c, n, occlusion, exposure) -> Color:
       return default_color(COLORS[mat], mat, c, occlusion, exposure, mat in QUIET, mat in WEARS, mat == Mat.HAIR)

   func surface_of(mat: int) -> int:          # Surf.CLOTH/METAL/GLASS/SKIN/GLOW/HAIR
       ...

   func weights(tag: int, p: Vector3) -> Array:
       var w := {}
       ...                                     # _add / _piecewise / _chain_w with bone names
       return _pack(w)

   func soft_materials() -> Array:            # optional: materials smooth() may clean
       return [Mat.CLOTH, Mat.SKIN, Mat.HAIR]
   ```

   Paint in the skeleton's rest pose: `rest[&"LeftHand"]` and the other bones' rest
   positions are in skeleton space, with +Y up, +Z the character's front and +X its
   left. `bones` maps bone names to indices.
3. `<name>_voxel.tscn`: a copy of the character's existing view scene, plus a child
   node with `voxel_body.gd`. Set `design` to your design script and `mesh_path` to
   the rig's MeshInstance3D. The old model stays untouched.
4. Look-dev (needs a real GPU):

   ```
   godot --path . --disable-vsync -s res://game/lookdev/lookdev_capture.gd -- <out> all \
       --scene=res://game/characters/<name>_voxel/<name>_voxel.tscn --compare=<old scene>
   godot --path . --disable-vsync -s res://game/lookdev/moves_reel.gd -- <out> full \
       --scene=<same> --moves=res://game/combat/moves/<name>/ --stats=<fighter stats .tres> --energy=#rrggbb
   ```

## Rigid props (weapons)

`VoxelDesign` also builds props with no skeleton (`_init(null)`). Weapons extend
`VoxelWeaponDesign` (`game/characters/voxel_weapons/`, sheet `docs/lookdev/weapons.md`):
shared material roles filled per owner palette, grip-wrap / rivet / engraved-mark /
seam helpers, and `VoxelWeapons.build_mesh`, which merges the grids into one static
mesh (no bones; it rides a `BoneAttachment3D`). Put fine grids (emblems) on the same
lattice as the coarse one (`grid()` snaps origins; split heights with `snap()`), or
they gap or overlap by up to half a cell.

## Rules learned on Kael

- **Rig tags.** Give each rigid part one tag. Give each finger its own tag, and keep
  thumbs rigid with the hand: the clips splay the thumb bones, and blending a thumb
  tip onto a finger bone smears it across the guard pose.
- **Paint each side's parts in their own pass.** Test `p.x * side`, never `abs(p.x)`,
  inside a per-side loop. Otherwise the second pass repaints the first side with its
  own tags and weights, which is how Kael's left pauldron was stretched by the right arm.
- **Big cloth and armour are planar panels** with fold ridges and hard hems. Keep
  curves for the head, hair, lenses and scarf, at the fine cell size.
- **Don't lighten convex edges on big cloth.** On a 45° chamfer every voxel step is a
  convex edge, so the lightening draws stripes. Keep wear on leather, metal and trims.
- **Before publishing, run a stretch scan:** no face should grow more than 3× between
  rest and the idle/guard pose.
