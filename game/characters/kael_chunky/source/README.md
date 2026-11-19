# Chunky Kael: generator

Kael in the chunky, Brawlhalla-style look of `docs/GAME_DESIGN.md` §6, built entirely in code:
mesh, face texture, rig, skin weights and his own clips. Same seed and inputs give the same GLBs.
Tooling ported from T-D11 (PR #36): loft toolkit, face texture, pose/FK/two-bone IK, frame data
read from the move `.tres` files.

## Run

Needs Python 3.11 and Blender as a Python module (`bpy` 5.0.1). With `uv`:

```sh
uv venv -p 3.11 /tmp/kael-venv
VIRTUAL_ENV=/tmp/kael-venv uv pip install bpy==5.0.1 pillow
/tmp/kael-venv/bin/python game/characters/kael_chunky/source/build_kael.py
godot --headless --path . --import
godot --headless --path . -s res://game/characters/kael_chunky/tools/build_kael_chunky_clips.gd
```

The build writes `kael_chunky.glb` (the model), `animations/kael_chunky_moves.glb` (his own
clips), `textures/kael_chunky_face.png` and `materials/kael_chunky_*.tres`, and prints the
triangle count and the strike timing table. The Godot tool then merges the shared humanoid
clips he uses with his own into `animations/kael_chunky_clips.res` and writes the ClipSet.

Review renders with the real toon shader (the cloud only has GL Compatibility):

```sh
godot --path . --resolution 1920x1080 -s res://game/characters/kael_chunky/preview/kael_chunky_capture.gd -- /tmp/kael all
```

## Files

| File | What it holds |
|---|---|
| `kael_params.py` | Proportions, colours, hair tufts, scarf length. Start here. |
| `kael_mesh.py` | Coat, tunic, pauldrons, sleeves, gauntlets, belt, pants, boots, head, hair, goggles, scarf. |
| `kael_geometry.py` | Lofted tubes, tufts and ellipsoids as plain vertex/face lists. |
| `face_texture.py` | Eyes, brows, blush and grin drawn into the face texture. |
| `kael_rig.py` | `SkeletonProfileHumanoid` bones (incl. eyes and jaw) plus `Scarf1`–`Scarf5`; distance weights. |
| `kael_pose.py` | Pose maths: joint helpers, FK, two-bone IK. |
| `kael_moves.py` | Reads startup/active/recovery and hitboxes from `game/combat/moves/kael/*.tres`. |
| `kael_anims.py` | His own clips as key poses; attacks are laid out on the move's ticks. |
| `build_kael.py` | Puts it together and exports the GLBs and Godot materials. |

## Conventions

- Blender axes: +Z up, he faces -Y, his left is +X, feet on z = 0. In Godot the model is turned
  to face -Z and lowered 1 m, so the view's origin is the capsule centre.
- Both GLBs import with `rig/kael_chunky_bone_map.tres` (identity map onto the humanoid
  profile), so the skeleton becomes `%GeneralSkeleton` and shared clips retarget onto it.
- A clip frame is a sim tick (60 fps). Attack clip frame `f` is `move_tick` `f`; the strike bone
  (`STRIKE_BONES`) comes closest to the move's mean active hitbox inside the active ticks.
- Squash and stretch are scale tracks on `Chest` and `Hips` (Y along the bone, the sides
  1/sqrt(s)). Hips squash moves the foot goals so the feet stay planted.
- No root motion: the hips keep the clip's first horizontal position; `Root` is never keyed.
- The scarf bones are never keyed: `scarf_lag.gd` (a `SkeletonModifier3D`) moves them after
  every clip, shared or own.
- Changing a move's frame data: re-run both steps; `tests/characters/test_kael_chunky.gd` fails
  if a strike no longer peaks in the active window.
