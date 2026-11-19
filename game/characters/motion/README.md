# Motion: mocap library + realism layer (T-D22a spike)

Real motion capture retargeted onto `SkeletonProfileHumanoid` (chunky Kael's `%GeneralSkeleton`),
cleaned up, and stored in a `MotionLibrary`, plus `MotionLayers`, a procedural layer that runs on
top of any clip. T-D22b wires both into `CharacterView` (see "In game" below).

| File | What it is |
|---|---|
| `motion_library.gd` / `.res` | `MotionLibrary` (an `AnimationLibrary`): in-place clips, plus `root_motion` (x, z, yaw per frame), `foot_contacts` and `strike_bones`. |
| `motion_layers.gd` | `MotionLayers` (`SkeletonModifier3D`): lean, flight banking, hip/spine counter-rotation, look-at, critically damped secondary motion, two-bone foot IK with pelvis drop, flinches, inertialization. |
| `tools/export_rig.gd` | Writes Kael's imported skeleton, move frame data and finger poses to JSON. |
| `tools/bvh.py`, `retarget.py`, `cleanup.py` | BVH reader with FK; position-based retarget; clean-up. |
| `tools/build_motion.py` | The clip manifest (`CLIPS`): source, window, options. Writes `motion_clips.json`. |
| `tools/build_motion_library.gd` | JSON to `motion_library.res`. |
| `tools/motion_metrics.gd` | Old-vs-new realism table. |
| `tools/motion_compare_capture.gd` | Side-by-side contact sheets and strips (`renders/`). |
| `LICENSES.md` | Every clip's source, author and licence. |

## Re-run

Needs Python 3.11 with numpy (`pip install numpy`); no Blender.

```sh
# Sources (no login): CMU BVH mirror (partial clone, fetch only the files in CLIPS) and Bandai Namco.
git clone --depth 1 --filter=blob:none --no-checkout https://github.com/una-dinosauria/cmu-mocap /tmp/cmu
git -C /tmp/cmu checkout HEAD -- data/014/14_01.bvh data/135 ...   # files named in CLIPS
GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 https://github.com/BandaiNamcoResearchInc/Bandai-Namco-Research-Motiondataset /tmp/bn

godot --headless --path . -s res://game/characters/motion/tools/export_rig.gd -- /tmp/kael_rig.json
python3 game/characters/motion/tools/build_motion.py /tmp/kael_rig.json /tmp/cmu/data \
  /tmp/bn/dataset/Bandai-Namco-Research-Motiondataset-1/data /tmp/motion_clips.json
godot --headless --path . -s res://game/characters/motion/tools/build_motion_library.gd -- /tmp/motion_clips.json
godot --headless --path . -s res://game/characters/motion/tools/motion_metrics.gd
xvfb-run -a godot --path . --rendering-method gl_compatibility --resolution 1280x720 \
  -s res://game/characters/motion/tools/motion_compare_capture.gd -- /tmp/renders
```

## Pipeline

1. **Retarget** (`retarget.py`): FK gives world joint positions; named points (pelvis, knee, wrist,
   and so on) map each rig. Every driven bone is rotated so its direction to the next joint, and a
   reference axis, match the source. The reference axis is body-left for the torso and the bend
   normal for limbs, with a small bias so straight limbs stay defined. Working from positions makes
   rest-pose, joint-orient and axis differences (CMU T-pose versus Bandai's X-along-bone rig)
   irrelevant. Hips height scales by leg length, so Kael's short legs keep the source's
   angles. Fingers keep Kael's fist.
2. **Resample** to 60 fps and **trim** to the manifest window. Clips are turned to face +Z.
3. **Strikes** (`time_warp_strike`): find the extension start and the frame where the strike bone
   comes closest to the move's mean hitbox, then remap time with a monotone cubic. The anticipation
   fills startup, the hit lands mid-active and the follow-through fills recovery. Each strike has
   exactly `total_ticks + 1` frames, so its length is `total_ticks / 60`.
4. **Exaggerate** (optional per clip): a temporal unsharp mask on rotations (`exaggerate`) adds
   anime overshoot and snap. `pose_amount` pushes poses away from the clip's mean.
5. **Foot contacts + lock**: a foot is planted when it is near its rest height and slow. Planted
   feet are pinned to their mean position, blended over 4 frames, with two-bone IK. The pelvis
   drops when a leg can't reach.
6. **Root extraction**: `linear` for locomotion loops (constant velocity, plus yaw drift for the
   run and walk), `smooth` for travelling one-shots (falls, jumps, dashes), `none` for fighting
   clips. Fighting clips keep the pelvis weight shift and step-ins, so the feet stay pinned.
7. **Loops**: the best loop end near the asked length (pose and velocity match), then the
   residual is spread so the last frame equals the first.

## MotionLayers

Set `velocity`, `flying`, `look_target`/`look_weight` and `ground` each frame. Call `flinch(dir,
strength)` on hits, `land(strength)` on landings and `inertialize()` just before switching clips.
Inertialization stores the offset (and velocity) from the last output pose to the new clip and
decays it with a critically damped spring, so there's no linear crossfade and no pop.
`process_pose()` runs the same maths on plain arrays (tests).

## In game (T-D22b)

- `ClipSet.motion` turns it on per character (chunky Kael, Vexa). `MotionSlots` picks the mocap
  clip from `FighterState`; a slot without mocap (charging, charge hold, Vexa's moves listed in
  `motion_moves` as `-`) plays the character's own clip, so nothing T-poses.
- `MotionClips` adds the derived clips at load (`launcher_up`, `sweep_low`, `hit_stagger`: a base
  take plus authored overlays, feet re-planted with two-bone IK) and rescales hips heights per rig
  so the stance stands on the floor (the stored heights ignore the skeleton's motion scale).
- Attack clips are seeked by `move_tick` through `ClipSet.phase_clip_time` with Kael's active
  windows, so startup, active and recovery line up for any move timing.
- `MotionLayers` is the skeleton's first modifier (before `ScarfLag`). `CharacterView` feeds it
  velocity, flight, landings, the look target (`set_look_target`), hit flinches
  (`react_to_event`, called by `FighterView.react_to_tick` with `CombatSim.events`) and the weapon
  arm pose. It only reads the sim.
- Review renders: `tools/motion_integration_capture.gd` (old left, new right), committed under
  `renders/integration/`.
