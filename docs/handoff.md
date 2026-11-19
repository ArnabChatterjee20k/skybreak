# Handoff: 3D anime arena fighter (personal project)

Planned in an earlier Claude Code session on the owner's Mac; development moved
to the owner's Windows PC. Updated 2026-11-19 with the owner's answers and the
team split.

## 0. How to work with the owner

- Plan first, get approval, then act. Confirm before big steps (installs, new
  tools, large structural changes) that are outside the agreed plan.
- Personal and non-commercial. Free assets with personal-use licences are fine.
- They want it "super polished": proper 3D, textures, effects. Build in
  playable milestones, not placeholder quality at the end.
- Be honest about limits. If something can't reach that polish, say so early
  and offer a workaround.
- Original IP only. The feel is inspired by Dragon Ball Z, but no DBZ
  characters, names, designs, attacks or music. Brawlhalla is a reference for
  feel and polish only.
- Rejected ideas: a realistic cricket sim; a 2.5D platform fighter.

## 1. Decisions locked in

- Genre: full 3D arena fighter with free flight (Budokai Tenkaichi / Sparking
  Zero in spirit).
- Platform: Windows, developed and played on the owner's PC.
- Combat: deep, easy to learn, very hard to master.
- Look: anime, cel-shaded 3D characters, big VFX (auras, beams, impact frames).
- Engine: Godot 4 (4.7.2), GDScript.
- Usage: personal, offline, non-commercial.

## 2. Owner's answers

1. Controls: keyboard + mouse only for now. Keep the input layer abstract so a
   gamepad can be added later.
2. Characters: free-to-use VRoid Hub models first (licence must allow
   modification and personal use); the owner may replace them later.
3. Split-screen: later (milestone 7). Build 1 player vs AI now without blocking
   a second local player.
4. Name: **Skybreak** (working title).
5. PC: GTX 1650 4 GB (laptop, plus Intel UHD 630), i5-9300H, 16 GB RAM,
   Windows 11 Home. Everything installs on D:.

## 3. Combat system design

The combat sim runs at a fixed 60 ticks/sec with real frame data (startup,
active, recovery, hitstun, blockstun, frame advantage), separate from
presentation so it is deterministic, tunable and fair.

- Movement: free flight, ground movement, ascend/descend. Lock-on camera with
  target switching (hardest part, comes first). Dash (costs ki), rush dash
  (homing chase after knockback), vanish step (short teleport).
- Meters: health (part regenerates if not hit), ki (blasts, dashes, vanishes;
  recharged by charging, which is vulnerable), guard (drains while blocking;
  empty = guard break), burst (from dealing and taking damage; spent on
  breakers, supers, transformations).
- Offense: light strings; directional heavies (launcher, ground spike,
  wall-splat); chargeable smashes. Cancels light → heavy → special → vanish.
  Wall and ground bounces, aerial chase. Ki blasts (rapid, charged, homing) and
  beam supers.
- Defense: block; perfect block / parry (~6-frame window); vanish counter
  (costs ki, can be countered); push-block, guard-break attacks, combo breaker
  (costs burst). Beam clash = timing/rhythm minigame, not mashing.
- Power: transformations (stat boost, new moves, ki drain); cinematic
  ultimates with camera cuts.
- Training mode: frame data, input history, combo counter, hitbox viewer,
  recording dummy.
- AI: Easy to Brutal; blocks, punishes, adapts, human-like reaction delays, no
  input reading.

Full rules: `docs/GAME_DESIGN.md` (from desktop).

## 4. Tech stack and asset pipeline

- Godot 4.7.2 + export templates, portable, at `D:\Tools\Godot` (self-contained).
- GDScript; moves are data-driven Resources (frame data, hitboxes, damage,
  cancels).
- Fixed-tick sim separate from visuals; per-fighter state machine; input
  buffer; hitstop; hitboxes/hurtboxes via shape queries.
- Characters: VRoid → VRM → Godot via godot-vrm. Animation: Mixamo clips
  (owner downloads), retargeted with BoneMap/SkeletonProfile; flight, charge
  and beam poses authored by hand.
- Look: custom cel, outline, rim, aura, beam, impact-frame, speed-line,
  shockwave, ground-crack shaders.
- Arenas: Poly Haven / ambientCG textures and HDRIs, procedural terrain,
  destructible rocks and pillars.
- Audio: Freesound, Kenney, free music libraries.

## 5. Milestones (each ends playable)

0. Setup: Godot, project skeleton, input, debug overlay, git, CI
1. Flight & camera: placeholder fighters flying, dashing, vanishing with
   lock-on. Goal: flying feels great.
2. Melee core: strings, hitstop, hitstun, knockback, bounces, training dummy
3. Depth: block, perfect block, vanish counter, guard break, burst, 4 meters,
   ki blasts
4. Real characters: VRoid + Mixamo pipeline, toon shader, one finished
   character
5. Spectacle: beams, beam clash, auras, transformations, destructible terrain,
   ultimates
6. AI: Easy to Brutal
7. Content: 4 characters, 3 arenas, Versus AI, optional split-screen, training
   mode, menus, music
8. Polish & ship: VFX, sound, balance, final Windows build

Milestones 1–3 decide whether the game is good. If grey-box combat doesn't
feel great, art won't fix it.

## 6. What the owner handles

Playtesting each milestone, character choice in VRoid, Mixamo downloads.

## 7. Known risks

Flight and camera are the hardest part. Flight and beam poses are hand-made.
Scope creep: 4 polished characters beat 12 rough ones. Laptop GPU: heavy VFX
need tuning to hold 60 fps.

## 8. Performance budget

1080p locked 60 fps; Forward+; no SDFGI/volumetric fog; SSAO/SSR optional;
VRAM < 3 GB (2K textures max, 1K props, compressed); few shadowed lights;
graphics presets + resolution scale early; fps readout in the debug overlay.

## 9. Who does what

- **developer** (Windows PC): owns the repo, integration and feel. Milestone 0,
  milestone 1 (flight, camera, lock-on, dash/vanish feel), scenes and levels,
  input, all playtesting on Windows, reviewing and merging desktop's PRs.
- **desktop** (Mac, cloud agents): the combat sim core (frame-data Resources,
  state machine, hitboxes, stun, hitstop, cancels, meters, defense, vanish
  rules), unit-tested headless; toon/outline/rim/aura shaders; later the AI.
- Tracking: `TODO.md` in the repo (no GitHub Project board).
- Folder ownership and the sim seam: see `AGENTS.md`.
