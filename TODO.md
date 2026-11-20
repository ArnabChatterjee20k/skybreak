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

- T-DEF3 [desktop] Escape tools (defense proposal S1, S2, S3, C1): combo breaker (X in
  hitstun, 1 burst stock, blows attackers to 5.5 m, 20 f intangible, 5 s cooldown), air tech
  (Dash + way in knockback ticks 12-24) with the §5.6 chase read, tech roll and neutral/delayed
  wakeups, perfect block needs a fresh press within 6 f plus the 0.8x view slow. `EscapeRules`,
  `EscapeTuning`, `EscapeAI` (per-level rates, own rng), `EscapeVfx`, two new cues.
  Follow-ups: dedicated breaker/tech clips per legend (S4, uses push_block/tech now); HUD
  "READ"/"BREAK" text pops (T-UX1 owns the HUD); gl_compatibility visual goldens not re-shot.

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
