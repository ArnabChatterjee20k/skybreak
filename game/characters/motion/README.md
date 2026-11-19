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
| `motion_profile.gd`, `profiles/` | `MotionProfile`: each legend's motion personality (T-D22c). |
| `tools/motion_metrics_pass2.gd` | All four legends, on the clips CharacterView plays, plus live pops in two bot matches. Run it on two commits for old vs new. |
| `tools/motion_pass2_capture.gd` | Per-legend contact sheets and the 4-legend lineup (`renders/pass2/`). |
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

## Pass 2 (T-D22c)

- **All four legends** run mocap and `MotionLayers`: `ClipSet.motion` is set for Lyra and Brann too.
- **Fitted strikes** (`MotionClips.fit_strike`) put a take onto another legend's move. A
  `motion_moves` entry of `fit` (the slot's own take) or `fit:<take>` builds `fit_<move>` at load:
  - **Retime:** the take's fullest extension toward the move's hitbox lands mid-active, and the
    clip lasts exactly the move's ticks.
  - **Mirror:** the take is mirrored (`MotionClips.mirror`) when it strikes with the other side,
    and a punch or kick is swapped in when it strikes with the other kind of limb.
  - **Reach:** two-bone IK moves the strike limb's path onto the hitbox, with a wind-up in startup
    and a follow-through arc across the body after active.
  - **Who uses it:** Vexa's breaker, launcher (mirrored uppercut), light_5, push_block, rising and
    grab, and every Lyra and Brann move.
- **Motion profiles** (`ClipSet.motion_profile`, `profiles/*.tres`) carry personality as numbers,
  not code paths:
  - spring frequencies (lean, secondary, blend, flinch)
  - lean and secondary amount
  - landing depth, stance crouch
  - stride (locomotion cadence), reaction timing
  - hover bob, flight arm read and dive pitch
  - impact weight (Brann's hips take the hit on the active tick)

  The four profiles:
  - **Kael** uses the defaults (heroic, balanced).
  - **Vexa** is quick and low: stiff springs, fast blends, a 7 cm crouch, a short stride.
  - **Brann** is heavy: soft, slow springs and blends, deep landings, impact weight, a long stride.
  - **Lyra** is graceful: soft lean, floaty secondary motion, a 7 cm hover bob, light landings.
- **One lean source.** `MotionLayers` is the only thing that leans a motion legend:
  - `FighterView` keeps its body node upright when `leans_itself()`.
  - The views' own procedural lean and hover bob go through `CharacterView.defer_to_layers()`.
  - `FighterView.MAX_LEAN` only applies to the capsule and to characters without layers.
- **Pop guard** (the last layer):
  - Upper and lower arm twist is unwrapped against the last frame and limited (`TWIST_LIMITS`).
  - The two-bone IK keeps its last bend direction while a limb is nearly straight.
  - No body bone turns faster than `MAX_TURN_RATE` in model space, parents first.
  - Inertialization carries in at most `MAX_BLEND_SPEED`.
  - The hips' twist uses a swing-twist yaw, not Euler angles, which flipped near 90° of flight pitch.
- **Derived clips:**
  - `light_1..3` get a 2–3 tick shoulder load inside startup.
  - `sweep_low` gets a follow-through arc.
  - `launcher_up` is smoothed outside its active window (less jerk).
  - `get_up_full` is the tech take plus a rise all the way to the stance. The knockdown falls in
    the first 40 %, and the legend stands by 90 % of the window.
  - `turn_step` is turn_in_place without its body yaw. It plays when an idle legend's facing
    swings past 45°.
- **Flight:**
  - The air dash uses the upright hover base, like flight; the `fly` take's baked pitch doubled
    the layer's.
  - The legs are eased to their straight rest pose.
  - Both arms sweep back at speed, and the lead arm punches ahead in a dive.
  - A dive pitches on to the profile's `dive_pitch`, a horizontal superman line.
  - `burst()` fires on air dashes, including Vexa's and Lyra's dash snaps.
