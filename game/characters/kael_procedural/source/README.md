# Procedural Kael: generator

Kael is built entirely in code: mesh, face texture, rig, skin weights and every clip. Change the
design by editing parameters and re-running the build. The output is deterministic (same inputs,
same `kael.glb`).

## Run

Needs Python 3.11 and Blender as a Python module (`bpy` 5.0.1). With `uv`:

```sh
uv venv -p 3.11 /tmp/kael-venv
VIRTUAL_ENV=/tmp/kael-venv uv pip install bpy==5.0.1 pillow
/tmp/kael-venv/bin/python game/characters/kael_procedural/source/build_kael.py
godot --headless --path . --import
```

The build writes `kael.glb`, `textures/kael_face.png` and `materials/kael_*.tres`, and prints the
triangle count and the strike timing table. Options: `--renders DIR` (quick Cycles turnaround),
`--no-export`, `--no-anim`.

Review renders with the real toon shader (any renderer; the cloud has only GL Compatibility):

```sh
godot --path . --resolution 960x1080 -s res://game/characters/kael_procedural/preview/kael_capture.gd -- /tmp/kael all
```

## Files

| File | What it holds |
|---|---|
| `kael_params.py` | Proportions, radii, colours, hair spikes and bangs. Start here. |
| `kael_mesh.py` | Body, gi top (V neck, armholes, trim), belt, pants, boots, wristbands, head, hair. |
| `kael_geometry.py` | Lofted tubes, spikes and ellipsoids as plain vertex/face lists. |
| `face_texture.py` | Eyes, brows, nose line and mouth drawn into the face texture. |
| `kael_rig.py` | Humanoid skeleton (Godot `SkeletonProfileHumanoid` names) plus 5 hair bones; distance-based weights. |
| `kael_pose.py` | Pose maths: joint helpers, FK, two-bone IK for planted feet and aimed fists. |
| `kael_moves.py` | Reads startup/active/recovery and hitboxes from `game/combat/moves/kael/*.tres`. |
| `kael_anims.py` | Every clip as key poses; attacks are laid out on the move's ticks. |
| `build_kael.py` | Puts it together and exports the GLB and Godot materials. |
| `render_kael.py` | Quick Cycles preview renders. |

## Conventions

- Blender axes: +Z up, he faces -Y, his left is +X, feet on z = 0. In Godot the model is turned
  to face -Z and lowered 1 m, so the view's origin is the capsule centre.
- A clip frame is a sim tick (60 fps). Attack clip frame `f` is `move_tick` `f`; the strike bone
  (`STRIKE_BONES`) comes closest to the move's mean active hitbox inside the active ticks.
- Side bones are authored with left-side meaning; right-side values are mirrored automatically.
- No root motion: the `Root` bone is never keyed; the sim moves the fighter.
- Changing a move's frame data: re-run the build; `tests/characters/test_kael_procedural.gd`
  fails if a strike no longer peaks in the active window.
