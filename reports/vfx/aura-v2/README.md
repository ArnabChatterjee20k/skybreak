# Aura v2: power-up aura and ki charge

Owner feedback: "we make the aura or ki charge animation a bit better. its currently looking like
rectangles. but yeah looking good."

## What was there before
- In a match, charging ki (the CHARGING state) only fired one 0.6 s `aura_flare` burst: a fresnel
  sphere, a floor ring and two particle sprays of quads (streaks 0.1 x 0.9 m, motes 0.18 m) on
  `VfxKit` looks. Those quads are what read as rectangles. After the burst there was only the rim tint.
- `FighterAura` (T-D09) existed but was never put into a match. It was a capsule shell
  (it reads as a glass bubble: see `old_vs_new_*`) with dots and flat streak quads.
- Charged blasts and beam charges had an orb at the hands but nothing flowing into it.

## What it is now (view only, the sim is untouched)
`game/view/shaders/vfx/fighter_aura.gd`, built in code; one per fighter, owned by `MatchVfx`.
1. **Flame silhouette:** three camera-facing flame layers (`aura_flame.gdshader`), back to front:
   a wide energy-coloured layer, a hot inner layer and a front edge layer with no interior, so the
   body shows through. Each is a body-hugging teardrop of noise-scrolled tongues that rise, sway and
   taper to points; a brighter band just inside the edge reads as the drawn outline of an anime aura.
   The back layers sit behind the body (depth test), and the front layer only licks the silhouette.
   A faint fresnel shell (`aura.gdshader`, no glassy rim line any more) adds a hot core near the body.
2. **Rising motes:** small glowing voxel cubes (`aura_voxel.gdshader`) that tumble, shrink and fade,
   each with a round soft halo pass (`aura_spark.gdshader` shape 0, radial falloff, no square edge).
3. **Ki charge:** while CHARGING, soft streaks converge into the chest (negative radial velocity,
   aligned to their flight), a pulsing orb sits in front of the chest, two shock rings run out
   along the floor over a breathing glow pool. Charged blasts and beam charges get the same
   converging streaks into the hands (`KiGather`, driven by `KiLayer`).
4. **Lightning from level 2:** thin jagged arcs (`aura_arc.gdshader`) crawl between random points on
   the body, re-rolled every flash and re-jagged 30 times a second; brighter and more frequent at level 3.
5. **Aura light:** one `OmniLight3D` in the energy colour, no shadows, low on the body with a gentle
   falloff so it tints the fighter and the floor without blowing out the face; it pulses while charging.

Levels in a match: charging ki shows level 1, level 2 after 1 s of continuous charging, level 3 after
2.5 s (`MatchVfx.AURA_LEVEL_TICKS`), with an `aura_flare` burst at each step up. The aura colour is the
legend's ki colour (`KiLayer.color_of`). The aura eases out when charging ends, and stays off for a KO'd
fighter or once the round is over.

Every aura layer clamps its HDR output (`max_hdr` <= 2), so bloom cannot blow out into white blobs.
The aura's uniforms are plain uniforms on materials each aura owns, with no instance uniforms
(GLES3 caps them), so it runs on the Compatibility renderer: see `compat_kael_*` (gl_compatibility,
WEB tier). The voxel-part glow convention (lit, black albedo, emission x 0.27) is untouched.

### Quality tiers (`particle_quality` = `GraphicsSettings` `vfx_density`)
| Tier | Particles (motes + gather) | Arcs | Flame layers | Light range |
|---|---|---|---|---|
| HIGH 1.0 | 60 | 6 | 3 | 4.0 m |
| MEDIUM 0.85 | 51 | 5 | 3 | 3.85 m |
| LOW 0.6 | 36 | 4 | 3 | 3.6 m |
| WEB 0.4 | 24 | 2 | 2 | 3.4 m |
Everything is built once in `_ready`; per frame the aura only sets a few uniforms and the light energy.

## Evidence
- Renders: lavapipe (Vulkan Forward+, llvmpipe) on the look-dev stage, 1920x1080, `aura_capture.gd`
  (`game/view/shaders/preview/`). Colour is right; lavapipe isn't a GPU timing source.
- `contact_sheet.png`: each hero (rows) charging ki, then levels 1, 2 and 3.
- `<hero>_kicharge.png`, `<hero>_level1..3.png`, `<hero>_level3_close.png`: full-res stills.
- `aura_v2_heroes.mp4`: each hero 6 s at 30 fps, 1920x1080: off, ki charge, then levels 1, 2 and 3.
- `old_vs_new_kael_*.png`: the old T-D09 aura against v2 at the same frames.
- `compat_kael_*.png`: the same scene under `--rendering-method gl_compatibility` at WEB quality (0.4).
- `fix_kael_level*.png`: after the flame-base fix (see critique 1).

## Verification (official Godot 4.7.2 linux x86_64, SHA-512 checked against SHA512-SUMS.txt)
- Fresh clone of the merged branch (b432603, main 17b9609 merged in), `rm -rf .godot`, `--headless --import`,
  full GUT: **1868 tests, 1857 passing, 15 pending, 0 failing** (824 s).
- `det_check total 65ec2f54272115fd`, the same as main (the sim is untouched).
- QA quick, main 7cad385 and the branch 4bc95d3 run side by side on the same 4-core box (QA_JOBS=2 each):
  view_ms/frame **1.773 (main) vs 1.755 (branch)**, sim_ms/tick 1.84 vs 1.98 (noise; no sim change).
  Both runs: the same FAIL sections (view soak: foot_ground 3/21, camera_on_screen 2/21, pop 1/21; the
  feel trend against the committed 8-job baseline), identical top violations, visual goldens PASS
  (no shot shows a charging fighter, so no golden refresh). Report: `reports/qa/2026-11-22-4bc95d3-quick.md`.
- New tests: `tests/shaders/test_fighter_aura.gd` (21: soft round halos, no hard-edged quad shaders,
  particle counts per tier, arcs and flame layers per tier, Compatibility-safe shaders and nodes, colour
  per aura, HDR clamps, no per-frame material allocation), 6 in `test_match_vfx.gd` (aura per fighter,
  levels by charge time, follows the fighter, flares per level, off after KO, tier share), 1 in
  `test_ki_view.gd` (streaks gather at the hands while a beam charges).

## Ranked critique (worst first, honest)
1. **The level-3 renders in the hero set show a hard horizontal cut at the flame's base.** The
   flame layers scaled about the capsule centre, so at level 3 the base sank about 0.4 m into
   the floor and the floor cut it in a straight line. Fixed in the shader (the flame now grows
   from the feet); `fix_kael_level*.png` shows the fix. The 4-hero stills and the mp4 were rendered
   before it, and there wasn't time to re-render them.
2. **The aura is one size for every legend.** Brann's oversized shoulders and fists stick out of
   the flame silhouette, so it reads as a flame behind him rather than around him. It needs a
   per-legend width/height (from the character's measured silhouette) before it's final.
3. **On the light grey look-dev stage the aura reads pale, peach rather than saturated orange.**
   Additive light on a bright background washes out. In darker zones it will read stronger. This
   needs a GTX 1650 look on real arenas before calling it final.
4. **The chest orb is small and faint on Kael** (his scarf and the gold trim compete with it);
   it reads clearly on Vexa. It may want to be bigger, or an energy-coloured flash on each pulse.
5. **The fresnel shell still shows a faint curved bubble edge around the boots** at levels 2 and 3.
   It's much weaker than the old glass capsule, but it's still there.
6. **Flame layers are camera-facing sheets.** From directly above (a flight camera looking down)
   the silhouette flattens. In side and 3/4 views, which is how the game usually frames charging,
   it reads correctly.
7. **At level 3 the stills' framing crops the flame tips** (the camera, not the effect).
8. **No GPU measurement.** QA view_ms (headless, CPU side) is unchanged, but the fill cost of three
   flame sheets per charging fighter in a 4-player FFA was not measured on the GTX 1650. Run the
   render benchmark with four fighters charging.
9. Dust puffs were tried and dropped: on bright floors they read as soft grey squares, the exact
   complaint. The floor shock rings and the light pulse carry the ground beat now.
