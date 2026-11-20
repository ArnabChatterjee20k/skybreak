# Look-direction mockups (T-LOOK)

Prototype only: nothing here is loaded by the game, and no shipping file is changed.
Every shot is the real `ZoneMatch` (sim, AI, fighters, animation, VFX, HUD) with a
view-only style layered on top. Same seed, so every style shows the same fight.

| Style | Script | What it overrides |
|---|---|---|
| A | `styles/look_style.gd` | nothing (main as is) |
| B | `styles/style_anime.gd` | own cinematic camera, cel 2-band fighters with hard rim + thicker ink, painted terrain/prop shaders, set dressing near the fight (basalt columns, rubble, blossom trees, bushes, flowers, lanterns), smoke cards, ACES + bloom grade, depth-free anime impact frame |
| C | `styles/style_painterly.gd` | B's rig with soft wrap light, Kuwahara brush filter, paper grain, light ink, light shafts, golden palette |
| D | `styles/style_side.gd` | B's shading, fixed side camera with auto-zoom, fighters pinned to a plane (view only), stage slab, painted backdrop, two platforms |

## Render

Linux with lavapipe (Vulkan, Forward+):

```sh
VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --rendering-driver vulkan --resolution 1920x1080 --fixed-fps 60 \
  -s res://prototypes/look/look_capture.gd -- <a|b|c|d> <ember_rift|heartbloom_gardens> <melee|beam|wide|ffa|strip> <out> [seed] [skip]
```

`melee` wants `LOOK_TICK` from a headless scout run of the same command (it prints
`LOOK hit tick N`), so rendering stays off until just before the hit. Seed 7 throughout.
`python tools/compose.py renders /path/to/strips` builds `COMPARE*.png` and the motion
contact sheets.

Renders live in `renders/` (`.gdignore` keeps Godot from importing them).
