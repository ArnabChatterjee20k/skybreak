# TODO (project board)

One task = one PR. Move a task between sections as it progresses and keep its
`T-` id in the branch name and PR title. Owner tags: `[developer]` (Windows PC)
and `[desktop]` (cloud agents). See `AGENTS.md` for folder ownership.

## In progress

- NO-NUMPAD [desktop] Owner: "dont use any numpad keys for any fight techniques". `fix/no-numpad`:
  Pure Fight P2 moves off Num0-6 / Num. to arrows + `, . /` `; ' ]` `[` + Right Shift dash (P1 dash
  pinned to Left Shift); hints, docs and tests updated (`reports/controls/no-numpad/README.md`).
  Open: physical ghosting on the owner's laptops is untested (headless Chromium only); the combat
  training room still uses F1-F7 (Fn on a Mac) [developer, game/modes/training]. Not merged yet:
  GUT 0 failing and det_check equal on the merge with 3b86467c, but main has moved again and QA ms
  needs a re-run at main's job count; the rollover matrix against a running web build stalls
  (stub page passes).

- MOVE-ESCAPE [desktop] #150 "can't move away or get behind while the opponent attacks": fixed on
  `fix/move-escape` (see `reports/combat/move-escape/README.md`). Dash presses wait out stun, 4-tick
  gaps in continued blocked strings, 15 deg follow-up turn cap, a dodged light ends the string, side
  vanish really goes round (was 3 deg), guard drift 4 m/s with climb and jump-out, AI dodges out and
  punishes dodges. Open: rush tailgating a retreating target for 90 ticks; owner play of the
  held-Shift air tech; strafe still capped at the camera's 180 deg/s [developer]; QA view soak
  after the change: camera_on_screen 1 -> 4 of 21 long matches at 92-95 % (T-135-c, hybrid camera)
  [developer] and cliff-ledge landings the voxel art does not show (+2.6-3.1 m, Shattered Mesa seed
  107) [desktop, terrain].
- #106-KI-DUEL [owner/desktop decision] #106 AI variety (re-applied on `fix/issue-106-ai-variety`
  2330020c) fails `test_a_ki_heavy_ai_duel_is_deterministic_and_uses_blasts_and_beams` (7 blasts, needs
  > 10). Main passes only by seed luck: blasts over seeds 2026-2035 mean 5.5 on main (only 2026 > 10),
  5.1 with #106. Decide: L5 AI zones more, or the test checks several seeds; then re-bless goldens and
  merge. Evidence: `reports/builds/2026-11-23-3b86467c.md`.
- DUO-ICE-RACE [desktop, net] Under CPU load the Duo browser test logged a host
  `addIceCandidate` before the remote description was set (and a short match); alone it passes.
  Queue ICE candidates until the remote description is set.

- VOXEL-SHIP open items [desktop unless tagged] (voxel art shipped on `main`, see
  `reports/ship/voxel-ship.md`), ranked:
  1. VOXEL-BAKES [owner decision]: the 28 zone bakes (844 MB) are still not in git; a fresh clone
     builds zones live until `tools/voxel_zone_bake.gd` runs (~20 min, 2 jobs). The play builds on
     `web-build` and `play-windows` carry them.
  2. LOOKDEV-PERF [developer, GPU]: GTX 1650 render benchmark for every voxel zone (Frozen Peaks
     HIGH/MEDIUM first); cloud ms are lavapipe only.
  3. QA-12 view soak: foot_ground 4/21 quick matches, 8 frames (worst Lyra +22 cm, frozen_peaks seed
     117 t268), same as main before the merge.
  4. Windows build (`play-windows` fb267e32, from fe71e7c8) not boot-tested on Windows; the Linux export of
     012ec23 boots the menu and voxel Frozen Peaks / Shattered Mesa matches from their bakes.
  5. Live web site (fe71e7c8, deployed by the `Deploy web build` workflow): only checked by size and
     `version.json`; play one Vs AI and one Duo match on it [owner] (the cloud proxy blocks the site).
  6. run_qa.sh defaults to 8 soak jobs; on a 4-core box that doubles sim/view ms (use QA_JOBS=nproc)
     [developer, tools/].
  7. Filed earlier, still open: QA-22 (voxel Brann view cost), VOXEL-PALETTE, the classic menu
     backdrop, Brann's off hand on the cannon fore-grip, T-KI1-b, QA-11.

- T-001 [developer] Milestone 0 skeleton: Godot 4.7.2 project, combat seam
  (`FighterInput`, `CombatSim` fixed 60 Hz tick, seeded RNG, determinism
  test), keyboard/mouse bindings, debug overlay (fps, frame time), GUT, CI,
  `AGENTS.md`. Remaining: CI green on GitHub.

- LOOKDEV-FP [desktop] Frozen Peaks voxel look v1 (`game/world/zones_voxel/frozen_peaks/`, branch
  `lookdev/zone-frozen_peaks`, report `reports/lookdev/frozen_peaks/v1/`). Waiting on the owner's
  draft-stills gate. Open for v2:
  - perf: greedy face merging for static props, T3 foothills past 120 m, web preset (~3.5x over)
  - a readable Ice Crown summit; spire facet/value breakup; planar strata slabs and cornices on cliffs
  - smooth floor normals (dusk facets); snowstorm shot, spindrift, readability strip, benchmark on the 1650
  - kit: a per-zone sky shader hook (the zone swaps VoxelStage's private sky material today)
- LOOKDEV-SM [desktop] Shattered Mesa voxel look v1 (`game/world/zones_voxel/shattered_mesa/`, branch
  `lookdev/zone-shattered_mesa`, report `reports/lookdev/shattered_mesa/`). Waiting on the owner's
  draft-stills gate. Open for v2 (ranked in the report's critique):
  - triangle and draw-call budget: about 1.5 M visible + 1.7 M shadow triangles at the arch (target
    1.2 M / 250 draws; web 500 k / 120): greedy-merge prop faces, T2 hoodoo tier ends sooner
  - hoodoo lower 12 m and boulders at T1 (now T2 and 2xT1), caprock overhang lips, sand drifts
  - slot-canyon hero shot and chockstone, heat shimmer, sand drift off crests, scrub sway
  - the render benchmark on the GTX 1650
- LOOKDEV-SC [desktop] Stormfall City voxel look v1 (`game/world/zones_voxel/stormfall_city/`, branch
  `lookdev/zone-stormfall_city`, report `reports/lookdev/stormfall_city/v1/`). Waiting on the owner's
  draft-stills gate. Open for v2:
  - sim bug (gameplay lane): the Spire Tower landmark has no building in the sim; its block sits on the
    raised district's slope, so `StormfallCityProps` skips it. The voxel Spire is visual only (no collider)
  - bridges over the canal (sheet) need sim collision first; not built in v1
  - draw calls: up to ~640 in the wide overview (budget 250): merge ground into 96 m chunks, cars per 96 m tile
  - facade windows are shader colour above the third storey; real recesses only as sills/hoods (storeys 2-4)
  - lightning is timed, not yet synced to `stormfall_thunder`; no flicker on signs; no puddle ripples
  - readability strip (all four legends, Vexa row) and the render benchmark on the GTX 1650 not done
- LOOKDEV-VF [desktop] Verdant Falls voxel look v1 (`game/world/zones_voxel/verdant_falls/`, branch
  `lookdev/zone-verdant_falls`, report `reports/lookdev/verdant_falls/`). Waiting on the owner's
  draft-stills gate. Open for v2:
  - greedy-merged static prop meshes (grove 3 M tris / 890 draws vs 1.2 M / 250; web not met)
  - basalt columns with real joints and moss ledges; a falls curtain with thickness and spray
  - darker near moss (L* 45-55), canopy outlines that aren't discs, night stills, the readability strip
  - the render benchmark on the GTX 1650
- LOOKDEV-PERF [desktop] Voxel zone perf pass (branch `lookdev/zone-perf`, report `reports/perf/`):
  all seven voxel zones on one branch; lossless prop face merge, HLOD far regions, terrain and
  building occluders, quality tiers incl. a web tier (`VoxelQuality`), `tools/bench/zone_bench.gd`.
  Open: GTX 1650 ms from the benchmark on the owner's PC; Medium still over 300k tris (see report);
  the web tier measured with Forward+ counts, not yet in a real web export.

- LOOKDEV-HB [desktop] Heartbloom voxel look v2 + the voxel zone kit (`game/world/voxel_zone_kit/`,
  branch `lookdev/heartbloom-zone`, report `reports/lookdev/heartbloom/v2/`). Waiting on the owner's
  draft-stills gate. Open for v3:
  - the arch as true per-block voussoirs at T1, with a bigger keystone heart
  - strata contrast and ledges on the undersides
  - a web preset (about 3x over its triangle target now)
  - the render benchmark on the GTX 1650 (estimated 4-6 ms against the 3 ms budget)
  - stream, Blossom Falls, petal whirlwinds, fireflies, the nearest-4 lantern OmniLights

- T-135 [developer/desktop] Camera round 3: see Done (merged). Open follow-ups:
  - T-135-a [developer] Tall voxel props (trees, spires) still aren't camera obstacles; as AABBs they
    pushed the camera off framing (verdant 100% -> 87%). Needs triangle-level avoidance.
  - T-135-b [developer] Visual goldens disagree with this cloud container's renders on main itself
    (heartbloom x8, ember, shattered, frozen, verdant: props missing, SSIM 0.79-0.93), so they weren't
    re-blessed here. The camera branch changes only `zone_frozen_peaks` (SSIM 0.50 vs main's render)
    and `zone_verdant_falls` (0.90): the round-3 base framing (boom 4.0 m, height 1.2 m). Re-bless
    both (`tools/qa/bless_goldens.sh --visual`) in an environment whose main renders match the goldens.
  - T-135-c [developer] QA quick `camera_on_screen` still trips in 2 of 21 multi-fighter matches
    (heartbloom 2v2 seed 120 94.2%, skyhold FFA-4 seed 101 94.8%; main had 90.5% and 94.8%).
  - T-135-d [developer] `CameraFloor` rasterizes floor chunks on the main thread as the camera nears
    them (up to ~10 ms once per chunk, not seen in view_ms). Could move into the zone bake.

## In review
- ISSUE-SWEEP [desktop] Open GitHub issues triaged against main (`reports/issues/triage.md`); fixes on
  `fix/issue-sweep`: #128 FFA-4 spawns on a 12 m ring (were 0.92 m apart), #127 dash afterimage is the
  fighter's silhouette (`PoseGhost`) and the sonic ring is half the size, #73 `BodySeparation` eases drawn
  bodies apart (Frozen Peaks VisualQa overlap 410/1679 -> 34/1628 close frames) and stacked fliers out
  sideways. Open:
  - ISSUE-SWEEP-c [desktop] (see #106-KI-DUEL under In progress) #106 AI string variety is on `fix/issue-106-ai-variety` (3+ hit back-to-back
    repeats 22.5% -> 7.5% over 5 seeds x 4 matchups). Not merged: any AI change reshuffles the seeded AI
    fights; it failed the seed-2026 ki duel (7 blasts vs > 10; main clears 10 only on that seed of
    2026-2035) and needs the golden replays re-recorded.
  - ISSUE-SWEEP-a [developer] Locked camera with a vertical gap over `STACK_MAX_HEIGHT` (12 m): the
    target leaves the frame for ~1 s while a flier dives onto it (Heartbloom seed 7 with an AI variant:
    far band 65/108 frames). Raising the limit to 24 m broke 10 flight-camera asserts, so it was not
    changed; `camera_offscreen_diag.gd` shows the frames.
  - ISSUE-SWEEP-b [desktop] QA-11 drawn overlap left after `BodySeparation`: ~2% of close frames, mostly
    the first frame of a lunge (poses are a frame old). #109 needs the GTX 1650 PC.
- T-PF1 [desktop] Pure Fight, 2.5D 1v1 martial-arts mode (`feature/pure-fight`, report
  `reports/pure-fight/README.md`, GAME_DESIGN §16): `PureFightSim` (a `CombatSim` subclass, integer
  fight-line sim: walls, rounds, 99 s timer, crouch/low/air block, just defend, throws and techs,
  motion inputs + technique key, target combos, cancels, juggles, wall/ground bounce, counters,
  armour, counter stance, finishers and meter), 4 legends x 19-20 moves with frame data, styled
  keyframed poses on the voxel rigs by IK (`game/characters/fight_styles/`), side camera, platform per
  zone, HUD, effects, AI levels 1-5, Play/Training menu entries, local 2P, pause-menu move list,
  online 1v1 through the Duo lobby (host picks Game: Pure Fight 1v1; `PureFightNet`). Open, ranked in
  the report: two-device online playtest, Lyra's robe hides her kicks, shared reaction poses,
  code-keyframed poses (no Animation resources), no gamepad, no Pure Fight QA soak, human balance.
- T-LD-W [desktop] Voxel weapons look-dev (`lookdev/voxel-weapons`, sheet `docs/lookdev/weapons.md`):
  all 11 weapons rebuilt as rigid voxel models with the voxel kit (1.1 cm world cell, owner palettes,
  energy on GLOW, emblems at 5.5 mm), drop-in behind `VoxelArmory` / `WeaponModels.voxel_everywhere`
  (old meshes stay the default). Voxel Kael uses them. Open: owner look review on a real GPU; hook
  `VoxelArmory` into the Vexa/Lyra/Brann voxel scenes when those branches merge; voxel nocked arrow
  and projectiles (still the old meshes); weapon clearance boxes are still the old models' parts.
  - T-LD-Wa [desktop] `test_an_ai_costs_at_most_0_05_ms_per_tick` is wall-clock and flaky on the cloud
    CPU: 0.0372 and 0.0528 ms on an untouched 3246c72 (same box, back to back). Needs a CPU-relative
    budget or a median of runs; threshold left as is.
- T-UI1 [desktop] HUD restyle (`claude/T-UI1-hud-restyle`, #117): plates, clock, banners (pop-in),
  combo, READ!, control hints, fly-down and beam-clash prompts on `MenuTheme` (skewed navy panels,
  ink borders, display font, gold/cyan/hot, team colours); legend portraits in the plate tiles, hit
  flash + chip trail, low-HP pulse. `game/debug/hud_capture.gd` renders the review shots. Heartbloom
  visual goldens re-blessed (HUD only). Open: on the web build `SystemFont` falls back to the default
  face for menus and HUD alike; bundling a licensed heavy display font would fix both.
- T-ART2 [desktop] Art round 2 (#99, #135, #137, #120, #138, #118, #121, #98, #124): crisp opaque
  Skyhold cloud sea and lighter haze, Heartbloom lawn shader (petals, stepping-stone walk, no fan
  shading), Stormfall neon night city with skyline and wet-street neon, shaded Ember spires, no prop
  stripe aliasing, KO beat at the contact, readable beam clash, Brann's cannon and hammer guard,
  Lyra's hip star-chart case, full zone card names. Follow-ups:
  - T-ART2a [desktop] Combo breaker (#129, not merged yet): one shockwave instead of a dome + 3 rings.
  - T-ART2b [desktop] Main-menu backdrop: stray dark spike shadow on the grass (world flythrough scene).
  - T-ART2c [desktop] Re-render the zone select cards (`game/ui/menus/zone_cards/*.png`), Skyhold's still shows stripes.
  - T-ART2d [developer] `ZoneMatch.step_tick` never calls `FighterView.react_to_tick`, so hit flinches are missing in matches.
- T-DEF2 dodge [desktop] (`claude/T-DEF2-dodge`): tap Shift = directional / spot / sidestep dodge with
  i-frames, chain and cooldown, air limits, perfect dodge (attacker freeze, READ pop, +10 ki once per
  3 s), Sweep tracks sidesteps, recovery grabs are untechable counter-hits; `DodgeTuning`,
  `DodgePose`, dodge audio cues, training input notes. Goldens re-blessed (dodge fields only).
- polish batch 3 [desktop] (`claude/polish-batch-3`): media-2 flaws. Lyra UNARMED (#78 follow-up) is
  the design-correct auto-throw of an emptied 12-arrow Ki Bow (regression test added); KO drops its
  burst lines and post-KO trails/rings/smears; Ember Rift lava fissures around the spawns
  (`zone_ember_rift` re-blessed); 1v1 drops land 8-16 m out (`pickups_heartbloom` replay and the
  flat-floor `bot_match` re-blessed at the first drop). Open: 4 Heartbloom character shots fail the
  visual tiles (6-7%) because the duel drop's telegraph pillar is now in frame; owner to decide
  whether to re-bless them.

- T-ART1 [desktop] Zone art pass, Brawlhalla-clean look in all 7 zones: terrain reads zone
  colours as sRGB (they were 3x too bright), 3-band ramp, crisp per-zone ground detail
  (cracks, grass tufts, basalt, streets, sastrugi), inked cliff lips and silhouettes, prop ink
  outlines, fog only on the far backdrop, a contact shadow under each fighter, re-tuned
  palettes. Open: ART1-a Frozen Peaks snow still reads blue-lilac under Filmic (white = 1);
  ART1-b a tonemap pass (Filmic white / AgX) would need a fighter look review.
  Merged with main 26019b8 (ART1-c done): `ContactShadows` is the one ground marker per fighter
  (dark disc plus a team-colour rim from 0.4 m that widens and quiets with height, #122's look);
  `HeightMarker` keeps only #122's faint 3-dash tick above 3 m, no disc and no drop line.
- T-WEB2 [desktop] Web crash `RuntimeError: remainder by zero` on FIGHT: `ZoneMatch.spawn_positions`
  took `side % points.size()` with no spawn points (Godot 4.7.2's binary export conversion empties
  packed arrays; #112 already keeps text resources, so main is fine). `ZoneData.fighter_spawns`
  now falls back to two points across the zone centre, used by `ZoneMatch` and `WorldMap`.
- T-KI1 [desktop] Ki blasts and beams as sim attacks (GAME_DESIGN §5.8): `KiRules` + per-legend
  `KiKit` (`game/combat/ki/`): tap Q blast (4 ki), hold Q charged blast (20 ki, not dash-soaked),
  beam special on 1 (40-60 ki, 24-30 f tell, aim locks 12 f before firing, +30 f whiff recovery),
  beam ultimate on 4 (2 burst stocks); perfect block reflects blasts, dash soaks tap blasts for
  2 ki, blocked beams grind 2 guard/tick, beams eat blasts and stop at the first body; Lyra's tap
  blasts home and her beam splits in three; rhythm beam clash (6 beats on Q/E/F/R, mashing loses
  ground, ki spends push, winner +50 burst, loser takes the beam). `KiLayer` view (shots, charge
  orb, beams at sim thickness, clash prompt), ki sounds and charge hum, `AIKi` zoning/beams/tell
  reading/clash beats, QA ki counts, DetCheck ki duel. Open: beam ultimate cinematic, beam clash
  camera framing (developer), dedicated ki clips per legend (palm thrust stands in), new ki
  sounds (existing cues re-pitched), dodge (T-DEF2) i-frames vs beams once it lands.
- T-DEF3 [desktop] Escape tools (defense proposal S1, S2, S3, C1): combo breaker (X in
  hitstun, 1 burst stock, blows attackers to 5.5 m, 20 f intangible, 5 s cooldown), air tech
  (Dash + way in knockback ticks 12-24) with the §5.6 chase read, tech roll and neutral/delayed
  wakeups, perfect block needs a fresh press within 6 f plus the 0.8x view slow. `EscapeRules`,
  `EscapeTuning`, `EscapeAI` (per-level rates, own rng), `EscapeVfx`, two new cues.
  Follow-ups: dedicated breaker/tech clips per legend (S4, uses push_block/tech now); HUD
  "READ"/"BREAK" text pops (T-UX1 owns the HUD); gl_compatibility visual goldens not re-shot.
  Fixed in this lane: the `pickups_heartbloom` record/replay desync (armed move sets were cached per
  weapon with the first legend's grab/push-block); fighters creeping up >60 degree faces at an angle
  or in tiny steps, and the leading foot standing inside a face (cliff rule checks the face's own
  slope and looks a foot ahead); ESCAPING ground slides follow the terrain.
  Open, [developer] camera: locked camera_on_screen dips to ~94% in the stormfall 2v2 seed 102 QA
  match. Not escape-related (no escape state on any missed frame); the misses are a target 4-6 m
  straight below at 5-9 m, and a target 1.1 m away while blocking. Breaker blow-out and chase rush
  stay on screen (`tests/playtest/test_escape_camera.gd`). Accepted for now (owner): escape
  blow-out/chase camera_on_screen dips; developer's hybrid camera (T-135) is the fix.
  Merged with main 68f6429 (#130 dodge, #131 ki): no dodge in hitstun or ESCAPING; an air tech
  spends no air dodge (the hit refreshed them); a breaker blows a beam's owner away and the beam
  ends; a beam clash locks out breakers (clashers can't break and aren't pushed). Combo breaker
  VFX cut to one beat (art bible §7): one shockwave ring at 1.2x under 0.25 s plus the 2-frame
  hitstop flash and shake. Defense matrix gets a `spike` row, the knockdown setup for tech_roll.
  Open: T-KI1-b [desktop] the L5 ki AI duel in `test_ki_blasts.gd` (also DetCheck's ki line)
  beamed once in 60 s on main only by seed luck (seeds 2026-2029 on main: 1, 0, 0, 0 beams;
  with escapes: 0, 0, 0, 0, the duel stays close as techs recover knockback). The beam assert is
  pending when no beam fires; `BEAM_CHANCE` / `target_busy` in `AIKi.zone` need a look.
  Open: QA-19 [desktop, characters] Brann's Ki Bow string clips his head (up to 10 cm) in
  bow/shot startup ticks 4-7 when he shoots while FLYING at near-zero pitch; the seed-3
  shattered_mesa visual QA run reaches it after the escape merge (4 frames, tolerance 1).
  `test_visual_qa.gd` reports it pending under QA-19 (fails under run_qa.sh strict).
  Open: QA-20 [desktop, characters] Lyra's Heartstring Bow sinks 2-5 cm into her chest capsule
  while she is in HITSTUN, then ESCAPING (air tech), then FLYING (seed-3 shattered_mesa visual QA,
  12-30 frames depending on run order, QA-17). Reached once specials landed on the escape merge;
  pending under QA-20 in `test_visual_qa.gd` (fails under run_qa.sh strict).
  Open: T-DEF3-pop, Lyra RightUpperArm turns 1.21 rad in one frame entering hitstun hit_light
  (1 frame in QA quick; limit 1.2), characters lane.

- T-UX1 [desktop] Controls and readability (owner feedback "how to get to the ground"): descend
  moves from Left Ctrl to `C` (Ctrl stays a desktop-only alternate, never on the web; Ctrl/Cmd/Alt
  rebinds refused on the web), quick-swap moves from `C` to `Y`; double-tap `C` dives until landing
  (input side, no sim change); in-match controls strip (`H`, on for the first 5 matches, then
  remembered) with a "fly down" prompt after 3 s hovering; ground disc + short dashed tick replace
  the drop lines; compact FFA/2v2 plates, slot tags on duplicate legends, no weapon box unarmed.
  Follow-ups: gamepad bindings (none exist yet: the strip says so on a pad).
- T-D36 [desktop] Playable web build: exports kept as text resources (Godot 4.7.2's binary
  conversion emptied zone spawn points, so every exported match crashed), webrtc-native left
  out of the Web preset, no Quit on web, `tools/web/match_smoke_test.js` (menu -> vs AI, 30 s).
  Build on the `web-build` branch; deploy to Appwrite Sites from the Mac. Duo's Appwrite
  traffic from the browser is unverified (CORS: add the site as a Web platform if needed).
- T-D35 [desktop] #107 Heartbloom: the sim floor matches the drawn island outline (`ZoneGround`
  25 cm outline mask, 0.25 m inset); falls/dives/vanish anchors can no longer pass through an
  island top (`CombatSim._stop_on_skipped_island`); the camera pulls in front of other fighters;
  QA `camera_cover` skips camera-faded bodies; `run_qa.sh --zone`.
- T-D30e [desktop] Weapon holds, view-only port of #70 (supersedes it): `WeaponGrip`, per-build
  holds, clearance solver with carry-over, KO weapon drop, bow reach, `VisualQa`; plus fixed
  one-hand hit-reaction tuck and flight hold, heavies at the side in flight, eased hold changes,
  clear-then-limit rounds after the turn cap, a short equip moment. Open: VisualQa
  weapon_vs_holder 9 and bow_vs_head 14 (3 zones x seeds 1-3), not 0; armed layers cost
  ~2.9-3.3 ms for 4 fighters here (target 0.5 ms; unarmed 0.54-0.78 vs main 0.47); VisualQa
  ground_contact / fighter_vs_fighter tracked under QA-12 / QA-11; the strip's flight column
  renders upright (preview does not reach the flight body).

- QA-11 [desktop] `fighter_overlap` measures pushboxes (`Pushboxes.gap`, skipping the pairs
  `Pushboxes.collide` lets through) instead of hurtboxes. Quick soak: sim invariants PASS, no real
  pushbox overlap left (was 5/21 matches, 128 frames).

- T-131 [developer] Camera #75, PR #97: `CameraObstacles` (prop boxes, terrain, island bodies
  by shape), turn-acceleration cap, target glide, big-jump cut, KO framing. Finished by the cloud
  controller: main merged, 5_rush_from_far near-gap floor 0.099 (the cap eases the swing in),
  Heartbloom KO drop rechecked (gone since #94).

- T-D34 [desktop] QA cleanup: QA-ID hygiene (#95's harness item is QA-16 now; QA-15 stays
  #94's FFA stacking, done), QA-16 (foot slide resets on vanish/teleport, hidden frames and
  round starts; floating feet skipped and counted; trend re-baselined as foot slide v2),
  QA-12c (a grounded fighter stops at faces steeper than 60 degrees instead of being lifted up
  them), QA-14 (zone shots hide the HUD; cause was #81, re-blessed).

- T-D32 [desktop] Cross-platform determinism: `DetMath` (fdlibm sin, cos, atan2,
  acos, exp, log, pow on + - * / and sqrt) replaces every libm call in the sim and
  AI, -0.0 canonicalised each tick, lint test for banned calls, goldens re-blessed,
  `tools/diag/det_check.gd` hash chain. Open: `developer` runs det_check on Windows
  and compares with the Linux output in the PR (acceptance gate).
  `test_re_simulating_8_frames_for_4_fighters_takes_at_most_4_ms` fails in the
  cloud container on main too (5.2 ms); DetMath adds ~1 us per sin/cos/atan2 call.
- [desktop] QA re-baseline after #69/#72: golden replays and character visual goldens re-blessed
  (causes in `tests/qa/goldens/README.md`), rollback timing bound made machine-relative, VFX
  node-growth assert counts lazy pool fills instead of a fixed slack.
- T-D31 [desktop] Gameplay QA harness: `tools/qa/run_qa.sh --quick|--full` (AI soak over
  every legend x zone x 1v1/FFA-4/2v2 with sim and view invariants, scenario library in
  `tests/qa/scenarios/`, golden replays, visual goldens, feel-metric trend, markdown/JSON
  report with frames, clips and repro commands). Found QA-1 to QA-9 below.
- T-D13 fix [desktop] Flat floor bit-identical to pre-terrain: floor epsilon and
  ledge drop only apply with an injected `ground_height`; golden per-tick
  fingerprints from f1d2dba (`tests/combat/test_flat_floor_equivalence.gd`).
  Open: goldens recorded on Linux; confirm they also match on the Windows PC.
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
- DUO-1 [desktop owner action] Appwrite Web platform for `skybreak-web-6a113777000db893b12e.appwrite.network`
  if sign-in from the web build says "Invalid Origin" (unverified: the cloud agent cannot reach
  Appwrite). See `reports/net/duo-online/README.md`.
- DUO-2 [desktop] TURN relay for networks where STUN-only P2P fails (the lobby says so after 30 s).
- DUO-3 [desktop] Rejoin after a real drop: re-signal and resync the sim (today: short drops recover,
  long ones offer "continue vs AI" or leave).
- DUO-4 [desktop] Respawn invincibility (2 s, GAME_DESIGN §8.1) and shared combo across partners
  (§8.2 team assists): both need sim fields, so they change det_check; not in T-D15b.
- DUO-5 [developer] ZoneMatch ignores the configured `team` for non-Duo modes (2v2/FFA teams hit each
  other and AIDriver sees everyone as an enemy); Duo sets it. Fixing it for all modes shifts QA 2v2.
- DUO-6 [desktop] Cross-platform determinism Windows <-> web is covered by det_check, not by a live
  Windows-vs-browser Duo session: run one owner PC + partner browser match and compare hashes.
- ZONE-POLISH [desktop] open after `fix/zone-polish` (report `reports/perf/zone-polish/`): run the
  zone bench on the GTX 1650 for Frozen Peaks HIGH and MEDIUM (target HIGH p95 under ~14 ms; HIGH
  now drops foothill shadows past 120 m, -39% shadow triangles in the opening). If HIGH still
  misses, the 2xT2 foothill tier MEDIUM uses is the next lever (measured; it changes the far
  foothills in the overview). Fly-through clearance runs only with local bakes (VOXEL-BAKES).
- DEF2-1 [desktop] Perfect-dodge view slow (0.85x for 8 frames, local offline only), proposal M2; not
  built in T-DEF2.
- DEF2-2 [desktop] An ideal-read spot dodge evades all 12 matrix attacks (like vanish). It is minus
  against lights and shots, but the proposal wants no option to beat everything: decide on a tracking
  or long-active answer (or a shorter spot window) with the defense matrix.
- DEF2-3 [developer] Proposal §5 AI-match dodge metrics (dodged share, dodge success, whiff punish,
  vanish share) need AI dodging (T-DEF4) and `defense_audit` in `run_qa.sh` (T-DEF6).
- PB3-1 [developer] AI pickup interest: in 14 seeded 60 s duels a level-3 AI picks up a weapon in
  only ~half, even with the drop 4-9 m away (PRESSURE outscores PICKUP up close, `fighter_ai.gd`
  `_choose_plan`). Raise the duel pickup weight so a typical duel shows a weapon.

- QA-18 [desktop] Godot 4.7.2 text-to-binary export conversion drops `Packed*Array` values in
  `ZoneData` .tres; re-enable `editor/export/convert_text_resources_to_binary` once fixed
  upstream (smaller pck, faster load).
- QA-13 [desktop] Landing frame: the first IDLE frame after flight can dip a sole up to 34 cm
  under the floor (vexa `fight_idle`, `1623:heartbloom_gardens:2v2:lyra,kael,vexa,brann:3235`
  tick 423). Ground sample is right (island top 272.03 m); the landing blend is not.
- QA-14 [developer] AI under an island: in 3600-tick soaks an AIDriver fighter can dive under
  Picnic Meadow and keep descending while its locked target stays on top (3602 1v1 80.1%,
  2623 66.1%, 2621 87.2%). Gaps > STACK_MAX_HEIGHT are off-screen by design, so this needs an
  AI fix (climb back) or a framing decision.

- QA-3 [developer] Bug (T-D31): `ZoneMatch` keeps teams only in its own `teams` array and never sets `sim.fighters[i].team`, so in a real 2v2 the sim treats teammates as opponents (friendly fire, the round only ends with one fighter left).
- QA-4 [developer] Bug (T-D31): `ZoneMatch._make_driver` looks for `next_input`/`setup` on `AIDriver`, which has neither, so every AI slot in a real zone match silently falls back to `WeaponBot`; the T-D23 `FighterAI` never plays there.
- QA-5 [developer] Bug (T-D31): `ZoneMatch.spawn_positions` with more than two teams puts teams 0 and 2 (and 1 and 3) on the same spawn point with the same offset, so FFA-4 starts with fighters inside each other.
- QA-7 [desktop] Bug (T-D31): animation pops far over budget: ~29 body-bone pops (> 1.2 rad in one frame) per fighter-minute against 2 allowed. Worst: forearms flipping ~3.1 rad in run/strafe (Kael, Vexa mocap), RightLowerLeg 2.8 rad in Kael's light_4, Vexa's sash, Lyra's cape and Brann's beard braid chains; fingers pop ~29/min too.
- QA-8 [desktop] Bug (T-D31): feet off the visible ground while standing: Kael and Vexa sink 5–11 cm in `fight_idle`, Brann's `idle` stands 9 cm in the ground at round start; Brann and Lyra also read +41–50 cm in IDLE mid-match (cause not isolated yet). Worst: in Shattered Mesa a fighter running along a pillar is up to 3 m inside the visible rock (the sim's baked `ZoneGround` interpolates across the cliff edge). Repro commands in the QA report.
- QA-12 [desktop] Bug (T-D22d): foot_ground still fails in 18/21 quick matches (545 frames, down from 3190). T-D22e (`claude/T-D22e-foot-grounding`): 542 -> 19 frames in a local replay of the quick matrix, all 19 in QA-12c. T-D34 quick run on 93ca66b: 3 frames in 2/21, both view-side: Brann's first IDLE frame after a vanish reappears (+10.2 cm, Stormfall t1902) and Lyra's `guard` +6.6 cm on flat Frozen Peaks ground (t1178-1181). Owner: characters (T-D22 motion).
- QA-13 [developer] Bug (T-D22d): `ZoneMatch` never calls `FighterView.react_to_tick`, so in real matches nobody flinches at hits or looks at the lock-on target (FighterView now finds the sim's floor itself).
- QA-9 [desktop] Bug (T-D31): a held bow's string passes within 1.5–8 cm of the head centre (Brann blocking, attacking or in blockstun; Kael dashing), 7 of 252 full-soak matches.
- QA-17 [desktop] Bug (T-D30e): a VisualQa seed plays a different match depending on what ran earlier in the process (Frozen Peaks s2: 9860 samples in `visual_qa_run.gd`, 10055 for the test alone, 10886 in the full GUT suite). The AI seeds lazily from `sim.rng.seed`, so some other state leaks between scripts; find it so GUT and the runner agree.
- QA-10 [desktop] Bug (QA re-baseline): the Skyhold Ruins cloud sea renders differently on every run (SSIM 0.944, 4.2% tiles between two renders of the same commit), so `zone_skyhold_ruins` sits just above the visual-golden threshold on noise alone. Make the cloud layer's time deterministic in the QA shots.
- [desktop] Bug (found in T-D22b): `WeaponMoves.move_set(kind, unarmed)` caches by weapon kind only, so the first fighter to arm a kind (e.g. Vexa) fixes its unarmed grab/push_block for everyone after. Key the cache by the unarmed set too.


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
- T-117b [developer] Point-blank framing (PR open): side-on view for stacked
  fighters, offset turns around (never over) the player, widen + pull back
  when the view lags. Bot fight vs main: off-screen frames 289 -> 152,
  mostly-ground 458 -> 61, over-pitch 248 -> 0. Left: an opponent dashing
  past at ~5 m outruns the 180 deg/s turn cap (decision for owner: raise the
  near-band cap?).
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

- T-D21b [developer] Wire `MusicDirector` (T-D21) into the game: `start_battle(zone)`
  on arena load, `observe_sim(sim, final_round)` each tick, `set_zone()` when the
  fight crosses a zone border, `round_started()` / `round_ended()`, `set_paused()`,
  `play_menu()` / `play_character_select()` once menus exist.

- T-201 [developer] Training dummy scene and combat debug view (hitboxes,
  frame data, input history) wired to sim state.
- T-301 [developer] Playtest milestone 3 depth on Windows and report feel notes.

## Done

- MOVE-ESCAPE-CAM [desktop] merged 3b86467c: a clipped boom turns to keep both fighters framed after
  the #150 escapes (Verdant 926 -> 948/976); `SKYBREAK_REQUIRE_BAKES=1` fails bake-dependent tests.
  Live on web 6c9d5cc6 and Windows 259519c1. `reports/builds/2026-11-23-3b86467c.md`.
- BUILD-DUO-TEST [desktop] the Duo browser test finds the Duo button from `main_menu.gd` (PASS on 3b86467c).
- BUILD 2026-11-22 [desktop] Build of `main` fe71e7c8 with all four lanes (camera round 3, WEB-CACHE,
  aura v2, Duo online): GUT 1894 / 0 failing, det_check stable; web on `web-build` 0cc630f0
  (index.pck 56.7 MB, smoke PASS, cache 6/6, Duo browser test PASS), live on Appwrite (deployment
  6b02e1ce83ba5adf73d3); Windows on `play-windows` fb267e32 (zip 726 MB, 8 parts).
  Report: `reports/builds/2026-11-22-fe71e7c8.md`.
- T-D15b [desktop] Duo online end to end (`net/duo-online`, report `reports/net/duo-online/`):
  Main menu -> Duo -> sign in (remembered) -> Host (5-letter code) / Join -> legends, host's
  zone/AI/lives/minutes -> Ready -> Start; `DuoLink` keeps the WebRTC link across menu and match;
  TablesDB rows; `ZoneMatch` runs `RollbackSession` (2 delay, 8 rollback, hash desync check) with
  `DuoFlow` (shared team lives, respawns, friendly fire off, time limit); ping/lives HUD, waiting,
  disconnected (continue vs AI / leave) and out-of-sync panels. Tests: GUT loopback 150 ms RTT /
  20 ms jitter / 2% loss + rollback burst; `tools/net/duo_browser_test.js` (two Chromium pages,
  real WebRTC, Appwrite mock). Open (ranked) in the report README.
- T-VFX-AURA2 [desktop] Aura v2 (owner: "looking like rectangles"), merged into `main` `--no-ff` from
  `vfx/aura-v2`; evidence and ranked critique in `reports/vfx/aura-v2/README.md`. `FighterAura` rebuilt
  and now in every match (`MatchVfx`, one per fighter): three noise-scrolled flame layers hugging the body,
  a faint fresnel core, tumbling voxel motes with round halos, the ki gather while CHARGING (converging
  streaks, chest orb, floor shock rings, light pulse), lightning arcs from level 2, one shadowless
  OmniLight3D in the ki colour. Levels 1/2/3 by charge time (0 / 1 s / 2.5 s); `KiGather` streaks into
  the hands for charged blasts and beam charges. HDR clamped, no instance uniforms (Compatibility/web OK),
  `particle_quality` from `vfx_density` (60/51/36/24 particles, 6/5/4/2 arcs). Sim untouched (det_check
  65ec2f54272115fd); QA quick view_ms 1.755 vs main 1.773 (same box, same load). Follow-ups:
  - AURA2-1 [developer, GPU] Look on the GTX 1650 in real zones (it reads pale on the grey look-dev stage)
    and render-benchmark four fighters charging at once (three flame sheets each).
  - AURA2-2 [desktop] One aura size for every legend: Brann's shoulders and fists stick out of the
    flame (needs a per-legend size from the measured silhouette). The chest orb is faint on Kael; the shell keeps a faint bubble edge at the boots;
    the flame sheets flatten from directly above. The 4-hero stills and mp4 predate the flame-base fix
    (re-render them).
- T-135 [developer/desktop] MERGED into `main` at 61925008 (PR #149, `--no-ff`; web-build 66250942, play-windows 05e02e73; evidence in
  `reports/camera/round3/README.md`). Hybrid exchange cam, terrain-wall push, closer base framing,
  low voxel props as obstacles, `CameraClearance` no-clip measure, `VoxelCameraFight` tests; plus this
  round: the locked target's body no longer pulls the boom in front of them (the main cause of lost
  frames since #141), a fit-to-frame FOV safety net (up to 95 deg, not past the pitch limits),
  and `CameraFloor` (visible voxel floor height, Verdant's FloorT2 tier) in the camera's ground clamp
  with the highest floor within the clearance radius. Seed-7 fight both-on: shattered 99.4%,
  stormfall 100%, frozen 97.5%, verdant 98.8%, others 100%; 0 clip frames; every pinned-wall case 100%.
  SP1-5 framing addressed by this (QA on-screen share 0.9816 vs 0.9784).
- WEB-CACHE [desktop] The browser keeps the web build in Cache Storage (`web/cache-sw`, evidence in
  `reports/web/cache/README.md`): `tools/web/sw.js` serves the cached build, `boot_cache.js` (loaded
  by the shell before the engine) checks `version.json` with a 3 s timeout and downloads only files
  whose SHA-256 changed into a new cache, then swaps with one pointer write; timeout/offline boots
  the cache, too little storage loads from the network. Zone packs are cached on demand.
  `build_web.sh` writes `version.json` (`write_version.sh`). Test: `tools/web/cache_test.js`
  (6 scenarios). Open:
  - WEB-CACHE-1 [desktop] On-demand zone packs are stored twice (the worker's cache and the game's
    user:// copy in IndexedDB, ~15-57 MB each); drop one once the cache is on the live site.
  - WEB-CACHE-2 [owner, Mac] Appwrite's CDN headers for `version.json` are unverified on the live
    site; the page asks with `cache: no-store` and a `?t=` query, so a CDN that ignores both could
    delay an update by its cache time.
- T-SP1 [desktop] MERGED into `main` at 746036c1 (PR #141, `--no-ff`; evidence in
  `reports/gameplay/resume.md`). Specials framework + Kael and Vexa kits (`claude/T-SP1-specials`): `game/combat/specials/`
  (`SpecialKit` .tres per legend, `SpecialRules`, small `combat_sim.gd` hooks), keys 1/2/3 with
  rise/dive variants, ki costs, Special level of the cancel hierarchy, counter/rush/leap/blink/decoy
  effects, AI hooks per level (`game/ai/ai_specials.gd`), Kael Momentum (HUD pips), Vexa Afterimage.
  Salvaged from #132: controls audit, web keyboard lock, §3 table. Merged with main 364f4b8 (voxel
  art): every special plays its take on voxel Kael/Vexa, `SpecialHandGlow` lights both voxel hand
  bones (lit, black albedo, emission x 0.27) while a special runs. Follow-ups:
  - SP1-7 [desktop] Hand glow reads only up close (7.5 cm orb; a few px at 15 m in the versus capture):
    owner look review on a real GPU, maybe a bigger orb or a short trail.
  - QA-23 [desktop] QA quick 6ea2e918: one pop, Vexa RightHand 1.205 rad (limit 1.2) in HITSTUN on
    hit_light with the repeater, ember_rift seed 112 t1690; feel trend flags finger pops 1 -> 2 events
    in 46.7 fighter-minutes. Not a special clip. Repro:
    `tools/qa/run_qa.sh --repro '112:ember_rift:1v1:kael,vexa:45' --tick 1690 --fighter 1`.
    ISSUE-SWEEP merge 3fb4bc4e: a second instance, Vexa LeftHand 1.24 rad in HITSTUN hit_light (repeater),
    `100:shattered_mesa:1v1:kael,vexa:54` t1477; BodySeparation's offsets there are 2-3 cm and smooth, so
    it is this borderline flip tipped over 1.2, not a jump.
  - SP1-8 [developer] `ZoneMatch` ignores the config's `rounds` (versus_soak chains matches instead).
  - SP1-1 [desktop] Brann and Lyra kits (they keep the T-KI1 beam on `1` until then).
  - SP1-2 [desktop] Ultimates (`SpecialKit.ultimate`, 2 burst) and transformations (`T`, 1 burst,
    `FighterSpecials.transform_ticks`) on the hooks this lane put in place.
  - SP1-3 [desktop] Dedicated special clips (they borrow retimed mocap takes today) and a decoy
    mesh ghost (today an afterimage refreshed every 6 ticks).
  - SP1-4 [desktop] Done in this PR: merged with T-KI1; `SpecialRules.start` runs before `KiRules.start`,
    and `KiRules.beam_special()` gives key 1 to a kit that owns it.
  - SP1-5 [developer] QA quick view soak `camera_on_screen`: Kael vs Vexa, seed 100, shattered_mesa,
    both locked fighters on screen in 93.4% of frames (limit 95%). Probe: 79 of the 146 off-screen
    frames are Kael firing the Storm Repeater at Vexa in hitstun, 15 are Shade Flicker; without those
    15 it is still 94.1%. Locked-camera framing of a ranged juggle. Repro:
    `tools/qa/run_qa.sh --repro '100:shattered_mesa:1v1:kael,vexa:54' --tick 2400 --fighter 0`.
    Accepted for now (owner): developer's hybrid camera (T-135) is the fix; not blocking.
  - SP1-6 [desktop] Done in the merge with main 7695141 (T-DEF3): no special from hitstun, an
    escape or a dodge; a special ends wakeup/breaker intangibility; a breaker ends a special; a
    special that hits chases only inside its Vanish cancel window (GAME_DESIGN §6). Specials fire
    no beams of their own: key 4 stays the KiRules beam ultimate. Kael/Vexa HUD pips moved into
    the restyled plate's name row (#143 put the burst stocks on the portrait foot).

- T-VOX-INT [desktop] SHIPPED: merged into `main` at 62cd986 (PR #148, `--no-ff`), goldens refreshed at
  46da3b2; evidence in `reports/ship/voxel-ship.md`. Voxel art in the game (`integration/voxel-art`): the look-dev branches merged
  (squashed, render media left on them), Art style Voxel (default) / Classic in settings, roster and
  CharacterView on the baked voxel legends, voxel weapons held, stowed and as pickups (baked), the
  voxel zone builders in zone_match for all 7 zones (VoxelZoneView, visual only, sim bit-identical),
  voxel zone cards, quality tie-in (Low: LOD ranges x0.6, far tiers shadowless, 2K atlas, no SSAO).
  Open:
  - VOXEL-LOAD [desktop] done on the branch: zones load from offline bakes per tier
    (`tools/voxel_zone_bake.gd`, `VoxelZoneBake`) behind a threaded `LoadingScreen`: 1.0-2.0 s per
    zone on lavapipe (were 1-484 s live builds). Stale bakes fail `test_voxel_zone_bake`.
  - VOXEL-BAKES [desktop, owner decision] the 28 zone bakes are 836 MB (14-58 MB each; terrain
    triangles dominate), so they are gitignored and baked locally (~15 min, 2 jobs, see the kit
    README). Owner: pick storage (Git LFS, a release asset fetched by a script, or a smaller bake
    format, e.g. indexed terrain chunks). Until then CI marks the bake test pending.
  - VOXEL-PALETTE [desktop, characters] voxel bodies bake their colours, so team palettes don't
    apply: a mirror match tells P1 from P2 only by energy rim and team ring.
  - QA-20 done on the branch: the clearance solver keeps out the voxel weapon a voxel legend draws,
    and voxel Brann's stone torso keeps bone scale 1 (weapon_vs_holder 3667 -> 7 frames over 9 runs).
    FIXED on fix/brann-weapon-grip@20a9655: merge that branch, do not re-fix (it already merges
    5c8f5af; optional on top of 6b145f7: arm turn without scale writes, classic + voxel boxes for every
    weapon, per-pose test, previews in reports/integration/brann_grip/). VisualQa heartbloom/1,
    frozen/2, mesa/3 weapon_vs_holder kael/vexa/lyra/brann 0/0/1/1126 -> 0/0/0/0; weapon_vs_body
    (all Ki Gauntlets) 0/6/4/8 -> 0/6/4/1, same as 5c8f5af alone. Open: Brann's off hand misses the
    Scatter Cannon fore-grip in guard (before and after).
  - QA-21 done on the branch: fix/lyra-cape-pops@295bd83 merged (cape clearance inside the chain sim);
    regression tests `test_lyra_cape.gd`, `test_lyra_voxel_cape.gd` (150 pops -> 0).
  - VOXEL-COMPAT / VOXEL-WEB done on the branch: zone-perf's merged props use no instance uniforms
    (0 overflow errors in a gl_compatibility WEB-tier match); web ships only the `*_web.scn` bakes,
    zone lamps drop shadows and fade past 60 m on the web tier.
    - FIXED on fix/web-voxel-compat@626d3c6: merge that branch, do not re-fix. Cause confirmed in the
      engine: each instance-uniform user takes 16 slots of Compatibility's 4096 (256 instances; WebGL2
      reports the same 64 KiB). Unmerged props now use voxel_prop.gdshader (no instance uniforms; figures
      keep the rim via voxel_surface.gdshaderinc), WebTierBudget + tests check all 7 zones at WEB (0 slots,
      lights, 1 shadowed, textures) and a 4-player match with worst VFX (<= 256); previews in
      reports/integration/web/. Merges cleanly onto 8ee1ee7, voxel tests 81/81 there. Pre-existing on
      22d7008: test_moves_reel glow_material fails (unshaded vs the test), not touched.
    - FIXED on fix/web-size@8b3cd12: merge that branch. pck 254.3 -> 56.5 MB (index.pck bytes, official
      4.7.2). The 7 WEB bakes (187.6 MiB, 15-57 MB each) leave index.pck; build_web.sh packs each byte for
      byte into zones/<zone>_web.<sha>.pck + manifest.json (stale bakes refused) and the LoadingScreen
      fetches, SHA-checks, caches (user://) and mounts the zone's pack. WEB-tier gl_compatibility stills
      of 3 zones byte-identical before/after; headless Chromium: 1.0-2.0 s fetch+mount, 1.4-1.9 s load.
      A lossless compact format doesn't reach the budget (bakes ~gzip floor; indexed layout was bigger).
      DONE: merged into integration/voxel-art (final assembly, reports/integration/final-assemble.md).
  - QA-23 done on the branch: voxel Brann's braid popped (Braid2 1.7 rad on weapon pickups, 42 pop
    frames in the quick run): it is now posed by a last skeleton modifier on the drawn body and
    turns at most 54 rad/s (`test_brann_voxel_braid.gd`).
  - QA-24 [desktop, characters] voxel soles sit ~1 cm lower than the classic ones on the same clips:
    foot_error_p95 is +1.0 cm in every quick-run match (kael/vexa-only too; 1.0 -> 2.0 cm, tolerance
    5 cm). The voxel boots reach below the classic mesh bottom (sole below the ankle: Kael 13.0 ->
    14.0 cm, Vexa 10.4 -> 10.7, Lyra 10.4 -> 14.0, Brann 11.0 -> 12.0). Fix: lift each voxel model by
    its delta (or trim the boot soles), then re-check feet and weapon clearance.
    FIXED on fix/voxel-soles-perf@1190b4b (also carries lyra v4, kael and vexa polish): merge that branch.
    DONE: merged at e7736e6 into integration/voxel-art (final assembly).
  - QA-22 [desktop, characters] voxel Brann's view still costs ~2x a classic legend per frame
    (1.20 vs ~0.55 ms for two fighters, headless) after the perf pass: `_keep_fist_clear` dominates.
  - Visual goldens: DONE, the 14 shots re-blessed once on main (46da3b2) and checked by eye.
  - The menu backdrop is still the classic world fly-through; MotionLayers' weapon clearance uses the
    classic weapon boxes (voxel models keep the old size and grip).
  - ZONE-POLISH FIXED on fix/zone-polish@4938c10: merge that branch. DONE: merged into integration/voxel-art.
  - REEL-FIXES DONE: lookdev/reel-fixes@d3a75e4 merged into integration/voxel-art (moves_reel takes
    the reel-fixes side, which carries the Brann-lane lit glow: black albedo, emission x GLOW_GAIN 0.27).
  - zone_capture.gd prints the real video adapter instead of a fixed "(software)" (test_zone_capture.gd).
  - VOXEL-BAKE-EMBED done on main (012ec23): `VoxelZoneBake.pack` embedded user:// prop-cache meshes
    found on nodes only; Shattered Mesa's WEB bake linked the baking machine's cache for its boulder
    LOD meshes (held in `MesaProps`), so it failed to load on every other machine (web smoke test: 16
    console errors). The state's resources are embedded too
    (`test_a_cached_mesh_held_only_in_script_state_is_embedded`).
  - MOTION-CACHE done on the branch: `MotionClips.build` cached the rig-fitted derived clips per
    library only, so the first legend loaded fixed them for all (in a match: load-order dependent;
    in GUT: voxel Brann's fist golden failed after the motion tests). Now keyed by library and rig
    (`test_motion_clips_cache.gd`).

- T-D33 [desktop] (#94, merged) Sim correctness bugs from the QA harness: QA-6 (a grab placed the target at
  the hold point after its step without clamping it to the arena or the terrain, so it read
  below the ground or past the wall for a tick; vanish anchors kept a stale stand height),
  QA-1 (KO bounce and rest on the zone ground; a KO'd fighter sliding off a ledge falls),
  QA-2 (Brann's spike startup 20 -> 17, inside his air light hitstun), QA-15, FFA-4 stacking (AIs hold off
  other fighters' air juggles and never start a hit from straight under/over a target:
  FFA-4 stacking 2.73%, 1v1 1.00%).
- T-D29 [desktop] Pushboxes: per-fighter capsule bodies from `FighterStats` (radius, height, mass; Brann 2.5, Lyra 0.8) resolved in index order after movement, mass-weighted, planar on the floor, wall-aware, swept so rushes and flight never tunnel; closing speed stops at contact; vanish, KO on the floor, a grab pair and Lyra's Star-Step pass through; hit/block pushback that moves the attacker when the defender is pinned; strafe orbit capped at 180 deg/s (matches the camera turn cap) so point-blank never outruns the camera; `FighterView` fades a body pressed against the camera. Follow-ups: strike/guard clips lean heads together at contact (CharacterView could ease the lean when an opponent is touching); both fighters circling opposite ways still hides the opponent in up to ~5% of frames (owner: lower `max_orbit_turn_speed`?).
- T-D15 [desktop] Rollback core + Duo online prototype: `CombatSim.snapshot()`/
  `restore()` (reflection deep copy, `SimSnapshot`), compact `InputCodec` (8-18 B),
  transport-agnostic `RollbackSession` (2-tick delay, prediction, 8-tick rollback,
  hash desync check, frame-advantage sync), loopback + WebRTC transports, Appwrite
  lobby/signalling, `duo_lobby.tscn`. Open: provision the `skybreak_` resources
  (game/net/README.md), vendor webrtc-native in `addons/` [developer], draw the
  session in the arena, Presence-based signalling, team rules (stocks, friendly fire).
- T-128 [desktop] Front end: splash, main menu over the world flythrough, character
  select (roster read dynamically, SubViewport turntable portraits, name/title/stat
  bars, human/AI, AI level 1-5 and team per seat; Vs AI 1-3 AIs, FFA 2-4), zone
  select (7 zones, Heartbloom hearts), settings (bus volumes, graphics, camera
  sensitivity, key rebinding), pause menu, results screen; `MatchConfig` autoload
  launches `zone_match.tscn` or falls back to the test arena.

- T-D26 [desktop] Powers and gadgets (Overdrive Orb, Burst Shard, Aegis, Haste, Spike Bomb, Gravity Mine, Mirror Decoy) as sky drops alternating with weapons, plus T-D14's gaps: bow draw levels and level-3 pin, Heartstring Tether and yank, chakram out-and-back disc, repeater heat/slowed fire/dash absorb, swap-cancel, C quick-swap, 80% ranged combo starters, counter-hit heavy drops, nocked arrow, `held_ammo()` for the HUD.
- T-129 [developer, built by cloud] Training room (dummy modes, record/playback, frame-data overlay, input display, refills, reset, weapon spawner, move list) and a 9-lesson tutorial with sim-driven goal checks; entry scenes `game/modes/training/training.tscn` and `game/modes/tutorial/tutorial.tscn`. Open: combo breaker, ki blasts, chase/tech and knockdown wakeup lessons once the sim has them.
- T-D23 [desktop] Real AI opponents (`game/ai/`): `FighterAI` levels 1–5 with reaction delay, utility neutral, guard/perfect block/push-block, whiff punishes, grab techs, combo routes up to launcher → vanish → air string → spike, weapons, FFA targets; `AIDriver` from the menus' fighter list; optional P2 hookup in the test arena. Open: burst escape (no burst in the sim yet), habit adaptation (§10), rubber-banding.
- T-D27 [desktop] VFX polish: pooled `MatchVfx` layer (game/view/vfx): heavy/counter anime burst + two-tone impact frame, guard-break shatter, KO dome + colour pop, Stormfall lightning, Heartbloom petals, weapon smears, afterimages, speed lines, sonic ring, zone landing dust, aura flare, ki blast/beam components; GLES3-safe (no instance uniforms).

- T-D24 [desktop] Brann playable: FigureKit stone smith (merged mesh, ember cracks, apron, braided beard, boulder shoulders, stowed hammer and cannon), P1/P2 palettes, heavy armoured MoveSet and stats, posed move clips, roster entry, renders. Open: per-fighter flight speed needs a FighterStats field.
- T-106 + T-D13 + T-D19 [desktop] Zone match (`zone_match.tscn`, `configure()`) in all 7 zones: only the chosen zone's props, far terrain at its lowest LOD, per-zone arena box; sim floor from a quantised `ZoneGround` (`CombatSim.ground_height`), landing on islands and falling off their rims; atmosphere, weather and ambience pinned to the zone (no Stormfall rain in Heartbloom). Open: `CharacterView.is_airborne` and `WeaponLayer` pillar still use the flat floor (read `FighterState.stand_height` / the sim ground), sim lock-on and hits ignore teams, `rounds` is stored but MatchFlow is best of 3, no AIDriver yet (WeaponBot drives AI slots); Skyhold Ruins' floating stones are props only, so fighters hover there over the terrain.
- T-D25 [desktop] Lyra playable: star-cartographer zoner built with FigureKit (merged mesh, star-map
  cape on springs, astrolabe, Sky Lance + Ki Bow), Star-Step teleport, Star Trap, constellation beams,
  roster entry with 3 palettes. Ranged moves are long hitboxes until MoveData can spawn sim projectiles.
- T-123 [developer] Web build: single-threaded Compatibility/WebGL2 preset, `web` quality tier,
  `tools/web/build_web.sh` (checksummed templates), loading/click-to-start shell, headless
  Chromium smoke test, Appwrite Sites steps in `tools/web/DEPLOY.md` (not deployed yet). Follow-up: VFX,
  terrain and post read `quality_value("vfx_density" / "terrain_chunk_radius" / "post_effects")`.
- T-D16 [desktop] KO physics and round reset: KO_FALL (no flight, falls with
  its knockback, one damped floor bounce with a slide) then KO_DOWN until the
  round ends; KO_BOUNCE/KO_REST events; KO'd fighters unhittable and inputless;
  FFA/teams win (`team` per fighter, friendly fire off); `start_round(spawn_points)`
  resets positions, facing, meters (burst carries over), states, clears
  weapons, pickups and projectiles; MatchFlow passes spawn points and credits
  teams. Open: flat ground only (no TerrainHeightmap in the sim yet); KO clip is
  the existing knockdown fall (MotionLibrary `ko_fall` left to T-D22b).
- T-D14 [desktop] Weapon pickups (Brawlhalla-inspired): seeded sky drops with
  per-zone tables (Heartstring Bow only in Heartbloom), 3-slot inventory with
  switching and throwing, drop on KO/guard break/knockdown, 6 melee MoveSets,
  bow/revolver/repeater/scatter cannon/Heartstring Bow as sim projectiles,
  procedural weapon models on Kael's hands, pickup and projectile visuals,
  WeaponBot. Open: bow draw levels, Heartstring tether, chakram return flight,
  perf benchmark on the GTX 1650, HUD weapon strip.

- T-D21 [desktop] Adaptive background score: menu, character select, seven zone
  battle themes as synced calm/combat/climax stems, victory and KO stingers,
  composed as code and rendered offline; `MusicDirector` autoload switches
  layers and zones on bar lines from sim state.
- T-D22a [desktop] Motion realism spike: CMU + Bandai Namco mocap retargeted onto the humanoid profile (`game/characters/motion/`), 43 clips incl. frame-accurate strikes for all 14 Kael moves, `MotionLayers` prototype, old-vs-new metrics and comparison renders.
- T-D22b [desktop] Motion integration: `CharacterView` plays the mocap for Kael and Vexa (locomotion, flight, attacks seeked by move_tick, guard, hits, grab/throw, KO fall/lie/get-up) with inertialized switches and the old clips as per-slot fallback; `MotionLayers` runs live (lean/bank, sprung superhero flight, look-at, foot IK, flinch from `CombatSim.events`, landings, weapon arm IK); derived launcher_up / sweep_low / hit_stagger; 4 fighters 0.34 ms. Follow-ups: Vexa forearm pops in her posed clips, mocap jabs without anticipation, idle loop foot slide, turn-in-place unused.
- T-D22c [desktop] Motion pass 2: all four legends on mocap + MotionLayers with per-legend `MotionProfile`s (Kael balanced, Vexa quick/low, Brann heavy, Lyra graceful); Vexa's six posed moves and every Lyra/Brann move on fitted (retimed, mirrored, IK-reached) mocap; 0 pops in 3600-tick bot matches (was 56/52) via twist limits, IK pole memory and a world-space pop guard; jab shoulder load, sweep follow-through, smoother launcher_up; full get-up within the knockdown; turn_step for idle turns over 45°; superman dive and air-dash burst; MotionLayers is the single lean source. Follow-ups: fitted strikes still measure 0 follow-through ticks on many moves; idle mocap foot slide; Lyra's cape springs step before the layers run.
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
- T-D20 [desktop] Audio system and every gameplay sound effect: bus layout
  (Master limiter, Music, SFX, Ambience, UI, Voice), `AudioDirector` autoload,
  `CombatAudioMapper`, per-category `SoundBank`s, synthesised CC0 cues, zone
  ambience that follows altitude. Follow-ups: weapon, pickup, ki blast/beam and
  round-flow cues are banked and mapped but wait for sim events; audio volume
  sliders in the settings menu.

GAUNTLET-CLOSEUP FIXED on lookdev/reel-fixes@5a6ee72. DONE: merged (e846428) into integration/voxel-art.
