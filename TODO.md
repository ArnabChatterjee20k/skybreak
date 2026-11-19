# TODO (project board)

One task = one PR. Move a task between sections as it progresses and keep its
`T-` id in the branch name and PR title. Owner tags: `[developer]` (Windows PC)
and `[desktop]` (cloud agents). See `AGENTS.md` for folder ownership.

## In progress

- T-001 [developer] Milestone 0 skeleton: Godot 4.7.2 project, combat seam
  (`FighterInput`, `CombatSim` fixed 60 Hz tick, seeded RNG, determinism
  test), keyboard/mouse bindings, debug overlay (fps, frame time), GUT, CI,
  `AGENTS.md`. Remaining: CI green on GitHub.

## In review

- T-D18 [desktop] Vexa built natively in Godot code as a rigid action figure
  (FigureKit mesh kit, humanoid-profile rig, procedural layer), stacked on
  T-D10.
- T-D12 [desktop] World map grey-block: 2 km procedural terrain (chunked, 4 LODs),
  six zones with landmarks, atmosphere/time of day/weather, energy dome,
  `WorldMap` API and flythrough preview, PR #39.
- T-D12b [desktop] Heartbloom Gardens, the 7th zone: floating cherry-blossom
  archipelago over the map centre, Heart Arch, Wishing Fountain, lantern
  bridges, `IslandField` second ground layer, whirlwind/fountain markers.
- T-116 [developer] VFX prewarm at arena load behind a short loading cover.
- T-D09b [desktop] VFX fixes from the GTX 1650 check of T-D09: shockwave no
  longer cut by the ground, aura never darkens the body, flames break into
  tongues, PR #18.
- T-D03 [desktop] `MoveData` Resource + light string + cancels, PR #15.
- T-D04 [desktop] Hitbox/hurtbox collision + hitstun, blockstun, hitstop,
  damage scaling, hitstun decay, knockback, hit events, PR #26.
- T-D05 [desktop] Defense: block, perfect block + lockout, grab and tech,
  push-block, PR #35.
- T-D10 [desktop] First real character: Kael (CC0 VRoid body, toon look) on a
  retargeted humanoid clip library (Quaternius UAL, CC0), `CharacterView`
  driven by sim state, preview scene, PR #34. Swap into FighterView is T-122.
- T-D01b [desktop] Movement fixes from playtest #1: locked strafe orbits at
  constant radius, dash-away goes straight back, rush brakes over 0.15 s,
  vanish keeps distance and height to the target, climb eases out, held
  BLOCK + DASH press vanishes. PR #40.
- T-D10b [desktop] Original fighting clips authored as keyframes in code
  (stance, power-up, superhero flight, air dash, kicks, uppercut); Kael
  remapped to them. Stacked on PR #34.
- T-D11b [desktop] Kael in the chunky Brawlhalla-style look (GAME_DESIGN §6),
  built procedurally: humanoid-profile rig + scarf chain with procedural lag,
  shared clips plus snappy own clips, stacked on T-D10.
- T-117 [developer] Range-band framing (near side swing with ≥10% screen gap, far
  zoom with 40° floor, band hysteresis) and shoulder frozen during a re-lock.

## Backlog

### Milestone 1: flight and camera (goal: flying feels great)

Playtest #1 (flight and camera) scored movement 2/5, camera 1/5. Target after
T-113–T-115 and T-D01b: camera and movement ≥ 4/5, then re-run the playtester.

- T-103 [developer] Lock-on polish: camera transition when the target changes;
  dash bank capped at about 20° (playtester saw about 45°). The off-screen
  arrow (§4.7) is done in T-113 (OpponentMarker).
- T-104 [developer] Movement VFX: dash streaks/afterimage, small FOV kick on
  sustained dash and rush, vanish afterimage at the old spot, rush recovery
  pose (view side); reuse T-D09 speed lines and impact pieces once merged.
- T-105 [developer] Camera occlusion: terrain between camera and fighters
  dithers out, no snapping, no cuts during control.
- T-106 [developer] Grey-box arena: about 600 m × 600 m, soft ceiling at 250 m,
  energy-dome boundary; ground grid/texture and landmarks (rock pillars,
  towers) every ~50–100 m so speed reads; sky/horizon so the dark ground-edge
  band disappears.
- T-109 [developer] Debug overlay text clipped at the left edge. Likely cause:
  windowed 1920x1080 is clamped to the screen (1920x991 with the taskbar), so
  the window sits partly off-screen. Fullscreen renders a true 1080p.
- T-108 [developer] Graphics presets follow-up (from PR #2): try
  `SCALING_3D_MODE_FSR` instead of bilinear when resolution scale < 1.0. The
  high preset is fine on the grey-box arena (T-107: GPU p95 1.8 ms); recheck
  once real content lands.

- T-118 [developer] Fighter identity (PR open): P2 palette swap + stronger
  team rim, height drop-line + ground ring, off-screen arrow with distance,
  above/below and "behind". Fill light and back cue dropped: the toon
  shader's shadow tint keeps backlit Kael readable and the model's front and
  back are distinct (both were capsule-era problems).
- T-117b [developer] Point-blank framing (0-1 m gap, fighters overlapping):
  the camera can put a fighter at the screen edge or cut it off (media-1.5).
  After T-118.
- T-119 [developer] Playtest capture: render key motion events (re-lock, vanish,
  rush arrival) at every frame for the playtester. Add a check for Space+RMB
  on the ground giving Rising only on the same tick (T-D03 feel note).
- T-120 [developer] Attack pose placeholder on the capsule (lunge/scale per
  `attack_phase()`, armor/invincibility flash) and the T-201 hitbox debug draw
  from `active_hitboxes()`, interpolated like the fighter.
- T-121 [developer] Combat feedback (PR open): `CombatSim.events` -> T-D09 VFX,
  hit camera shake, impact frames on KO/guard break, combo counter. Stun
  poses come from Kael's clips (T-D10b); no audio (T-D20 owns it).
- T-122 [developer] Swap the capsule for `kael_chunky.tscn` in `FighterView`
  (PR open). No hit-reaction VFX (T-121); team colour is a rim tint only (T-118).
- T-126 [developer] Match HUD + round flow (PR open; covers T-111 and T-112):
  plates for 2-4 fighters (name badge, health with chip trail and grey part,
  ki x4, guard, burst, win pips, weapon "UNARMED" + 2 inventory slots read
  generically until T-D14), round clock, ROUND n / FIGHT! intro holding
  input, K.O.!/TIME! with 1 s slow motion, best of 3. Scales from a
  1920x1080 design, pinned to the top. Open: positions are not reset between
  rounds (sim-side, ask desktop), and the name badge stands in for portraits.

### Combat sim (desktop)

- T-D06 [desktop] Vanish rules: direction guess, Sense, max 2, then Clash.
- T-D07 [desktop] Chase/tech and wall-splat.
- T-D09b [desktop] VFX fixes from the PR #12 Windows check: shockwave clipped by
  the ground, aura darkening the body at power 3, glassy flames (cloud).
- T-D10 [desktop] Character pipeline: free-licence rigged anime humanoid + animations,
  toon/outline materials, humanoid retarget, AnimationTree driven by
  `FighterState`; delivers `CharacterView` (see AGENTS.md).
- T-D08b [desktop] Outline on hard-edged props: bake smoothed normals into
  vertex colour/UV2, or use bevelled prop meshes (box outline nearly invisible
  in the PR #3 check).

### Milestone 2–3 (developer side)

- T-201 [developer] Training dummy scene and combat debug view (hitboxes,
  frame data, input history) wired to sim state.
- T-301 [developer] Playtest milestone 3 depth on Windows and report feel notes.

## Done

- T-D18b [desktop] Vexa playable: own 16-move set (5-hit string, launcher, spike,
  chakram heavies), IK-posed clips timed to each move, `Roster` (kael/vexa ->
  scene, stats, slot palettes), test arena P1 Kael vs P2 Vexa (alt palette,
  team rim), merged assembly (10 draw calls). Contains #44. Follow-ups:
  render benchmark on the dev PC; fighters can overlap (no pushbox).
- T-D00 [desktop] Game design document (`docs/GAME_DESIGN.md`), PR #1.
- T-002 [developer] Graphics presets + resolution scale + vsync, F10 menu, PR #2.
- T-003 [developer] Windows export preset (single exe), PR #4.
- T-D08 [desktop] Toon + outline + rim shaders, PR #3.
- T-102 [developer] Fight camera: free orbit + lock-on framing, PR #5.
- T-D01 [developer, from desktop] Combat sim skeleton: input buffer, movement,
  `MovementTuning`, sim-owned lock-on, PR #6.
- T-101 [developer] Flight view: facing, lean, vanish hide, PR #7.
- T-113 [developer] Camera distance model, opponent marker, scripted playtest
  harness, PR #14.
- T-110 [developer] Borderless fullscreen default + windowed option, PR #11.
- T-107 [developer] Render benchmark (GPU/CPU frame time per preset), PR #10.
- T-102b [developer] Locked camera pitch limits, PR #8 (pull-back later replaced by T-113).
- T-D02 [desktop] Meters, PR #9.
- T-D09 [desktop] Aura and impact VFX, PR #12.
- T-114 [developer] Shoulder offset: player a third from the edge, PR #16.
- T-115 [developer] Camera turn limits and teleport glide, PR #17.
- T-D11c [desktop] Re-bake chunky Kael clips for push_block 2/4/14 (T-D05); fixes the clip-length test.
- T-116 [developer] VFX prewarm at arena load, PR #19.
- T-D09b [desktop] VFX fixes (ground shockwave, aura, flame tongues), PR #18.
- T-D03 [desktop] Moves, light string and cancels, PR #15.
