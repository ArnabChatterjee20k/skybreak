# Pure Fight (T-PF1): report

A 2.5D 1v1 hand-to-hand mode: both fighters stay on one fight line across a flat platform inside any
of the seven voxel zones. The zone stays fully 3D behind them, and a side-on camera frames them like
a classic arcade fighter. There's no flight, ki, specials, weapons or pickups; everything is physical.
The design lives in GAME_DESIGN §16 (rules, controls, camera, style sheets, full frame tables).

Branch `feature/pure-fight`. Evidence: see "Verification" at the end.

## What works

- **Sim** (`game/combat/pure_fight/`). `PureFightSim` is a `CombatSim` subclass with its own tick, so
  other modes never run its code: det_check for the default scenario is still `65ec2f54272115fd`,
  equal to main. The state is integers only (mm, mm/tick). It has:
  - the fight line, platform walls, a 6.6 m separation cap, and pushboxes sized per legend (Brann is wide);
  - best of 3, a 99 s timer that stops during finishers, KO and time-up rounds, and match over;
  - stand/crouch/air block (lows must be crouch-blocked, overheads and jump-ins stand-blocked) and
    just defend: guard raised in the last 4 ticks gives -4 blockstun and +60 meter;
  - throws: 950 mm range, a 10-tick break window, auto tech when both throw, back throws, and
    throw-proof windows after stun and on wake-up;
  - motion inputs, read leniently (236, 623, 214, 236236, 66, 44), plus a one-key technique button
    with a direction for keyboard players, and a 6-tick input buffer that is held during hitstop;
  - target combos, cancels into techniques and finisher cancels;
  - juggles with gravity scaling and a 4-point limit; one wall bounce and one ground bounce per combo;
  - counter hits (120%), punish counters (110%), damage scaling (100, 100, then -15% a hit, 30% floor)
    and hitstun decay;
  - Brann's one-hit armour, Lyra's counter stance, cinematic finishers on a 1000-point meter;
  - knockdown with get-up or a wake-up roll;
  - snapshot/restore by reflection, so it is rollback-safe.
- **Moves.** 4 legends x 19-20 moves each (`pure_moves.gd`):
  - 9 normals (L/M/H standing, crouching, air), 2 command normals (one overhead), a sweep and 2
    target combos;
  - 3-4 techniques on motions: every legend has a frame-1 strike-invulnerable reversal that also
    works as an anti-air;
  - 1 cinematic finisher and a throw.
  - Frame data for every move is in GAME_DESIGN §16.7, printed from the data. The sim measures
    startup, on block and on hit for every grounded single-hit move, and they match the table.
- **Styling** (`game/characters/fight_styles/`):
  - Every pose is keyframed in code and put on the existing voxel skeletons by a new two-bone IK rig
    (`FightRig`), so fists and feet land on their targets and planted feet stay planted.
  - Each legend has its own stance, idle, walk, guard, intro, two victory poses and a defeat pose,
    and its own body mechanics on strikes: Kael pulls the off hand to the hip (hikite), Vexa never
    stops her ginga and spins, Lyra bounces upright, Brann hooks with his whole body.
  - Shared, style-scaled poses: crouch, dash, jump, high/low block, high/low hit, juggle, knockdown,
    get-up, wake-up roll, thrown/tech.
  - Strikes have anticipation, a held active pose, follow-through, a re-chamber of the kicking foot
    before it sets down, and they are shortened at the opponent's body.
- **Presentation**:
  - the side camera with zoom by distance, vertical framing of airborne fighters, a finisher punch-in
    and shake;
  - the platform: the flattest 17 x 5 m spot in the zone's ground data, a voxel stone slab with tile
    seams, a stepped ledge, corner posts and a painted line;
  - HUD: bars with a damage trail, round pips, timer, finisher meters, combo counter, banners,
    callouts;
  - voxel-cube hit sparks by strength, impact frames, dust, speed lines, a limb trail during active
    frames, and sounds from the combat bank.
- **AI** (`game/ai/pure_fight_ai.gd`), levels 1-5:
  - reaction-delayed high/low blocking, anti-airs, punishes, spacing, jump-ins and throws;
  - target combos and confirms into techniques or the finisher;
  - a coverage mode that tries every move.
- **Modes**:
  - Play > Pure Fight: character select with two seats; P2 toggles AI or HUMAN, and HUMAN is local
    2P on one keyboard;
  - a TRAINING button: a dummy that stands, blocks all, crouch-blocks or jumps (F4); health
    refills, the meter stays full, and the HUD shows the last move's frame data and the measured
    advantage;
  - a pause-menu "Move list" with every legend's moves and frame data;
  - results through the existing MatchSession.
- **Online** (`game/net/pure_fight_net.gd`): the Duo rollback core runs Pure Fight as is. In a
  loopback test with 120 ms RTT, ±20 ms jitter and 5% loss over 2400 ticks there were no desyncs,
  and rollbacks happened. The lobby entry waits for the DUO-ONLINE lane (see Open).

## Controls

| | P1 | P2 |
|---|---|---|
| Move / jump / crouch | A D / W, Space / S | Arrows |
| Light / medium / heavy | J / K / L | Num1 2 3 (or , . /) |
| Throw / technique / finisher | U / I / O | Num4 / Num5 / Num6 (or ; ' ]) |
| Dash | Shift + direction or tap twice | Num0 |
| Block | hold back (down-back for lows), E | hold back |

Techniques: a motion + attack (236 / 623 / 214), or the technique key + a direction: forward or
neutral = 236, down = 623, back = 214. Finisher: 236236 + attack or the finisher key, needs a full meter.

## Move lists (names; full frame data in GAME_DESIGN §16.7)

- **Kael** (karate):
  - Normals: Snap Jab, Reverse Punch, Front Snap Kick, Shin Kick (low), Low Straight, Crane
    Uppercut (launcher), Leg Sweep, Hammer Fist (overhead), Driving Side Kick (wall bounce), Air
    Knee, Air Chop, Flying Side Kick.
  - Target combos: Kiai Elbow (5L>M), Kiai Front Kick (5M>H).
  - Techniques: Iron Lunge (236), Skyward Fist (623, reversal), Ridgeback Kick (214, overhead,
    ground bounce).
  - Finisher: Thousand Petal Breaker. Throw: Shoulder Throw.
- **Vexa** (capoeira/taekwondo):
  - Normals: Backfist Flick, Chapa Push Kick, Armada Spin Kick, Rasteira Tap (low), Low Ponteira,
    Bananeira Upkick (launcher), Half-Moon Sweep, Flip Heel (overhead), Hooking Heel (wall bounce),
    Air Toe Flick, Air Scissor, Air Spin Kick.
  - Target combos: Tornado Step (5L>M), Spin to Sweep (2M>H).
  - Techniques: Crescent Wheel (236, 2 hits), Flip Kick (623, reversal), Cartwheel Evade (214,
    passes through), Tumbling Dive Kick (air 2+H).
  - Finisher: Hurricane Ginga. Throw: Scissor Takedown.
- **Lyra** (savate/taekwondo):
  - Normals: Lead Jab, Fouetté, Chassé, Low Coup de Pied (low), Low Fouetté, Fan Kick Launcher,
    Revers Sweep, Hopping Axe (overhead), Spinning Back Kick (4H, wall bounce), Air Snap Kick, Air
    Crescent, Air Thrust Kick.
  - Target combos: Double Fouetté (5M>M), Jab-Chassé (5L>H).
  - Techniques: Vaulting Axe (236, overhead), Rising Crescent (623, reversal), Starguard Counter
    (214, counter stance).
  - Finisher: Constellation Rush. Throw: Savate Hip Toss.
- **Brann** (wrestler-boxer):
  - Normals: Gauntlet Jab, Body Hook, Haymaker, Toe Stomp (low), Gut Uppercut, Lifting Uppercut
    (launcher), Trip Hook, Hammer Drop (overhead), Armoured Shoulder (armour, wall bounce), Air
    Elbow, Air Hammer, Body Splash.
  - Target combos: One-Two Hook (5L>M), Hook-Haymaker (5M>H).
  - Techniques: Bull Charge (236, armour), Gauntlet Uppercut (623, reversal), Iron Suplex (214,
    unbreakable command grab).
  - Finisher: Mountain Drop (grab). Throw: Bear Hug Toss.

## Stills

All renders are lavapipe (software Vulkan, Forward+) at 1920x1080, with zones from their LOW-tier
voxel bakes (built locally, not committed).

- `zones_side_camera.jpg`: the side camera in all seven zones mid-fight (AI v AI, about 9 s in).
  Every shot has both fighters framed, the platform under them, and the zone behind them.
- `zone_<id>.jpg`: each zone full size.
- `strip_<legend>.jpg`: per legend, the stance, every technique on its first active frame, the
  finisher cinematic, and a victory pose.
- `poses_<legend>.jpg`: the full pose sheet: locomotion, guard, reactions, knockdown, intro, both
  wins, defeat, throw, and every move on its first active frame.

Re-render:

```sh
VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
  --disable-vsync --resolution 1920x1080 -s res://game/debug/pure_fight/match_stills.gd -- <out>
VK_ICD_FILENAMES=/opt/lavapipe/lvp_icd.json xvfb-run -a godot --path . --disable-vsync \
  -s res://game/debug/pure_fight/pose_sheet.gd -- <out> [legend ...] [--set strip|all] [--cell 540x720]
```

## Styling critique (looked at every frame myself, honestly)

- **Kael is the strongest.** The low wide stance and lead hand read as karate from across the
  screen. The hikite pull on punches is visible and the snap kicks read clearly. The Skyward Fist
  rises with the fist up, and the bow intro and raised-fist victory read.
  - Weak: the finisher still is just a straight punch (the cinematic is a fast rush of strikes,
    readable in motion but not in a single frame).
  - Weak: Kael's horse-stance victory looks stiff.
- **Vexa reads as an acrobat.** The handstand upkick, flip kick, cartwheel and spinning kicks are
  unmistakable, and the ginga keeps her moving.
  - Weak: inverted poses put her head close to the floor; the cartwheel's hands aren't quite planted.
  - Weak: her spin kicks lean the whole body rather than turning cleanly on the support foot.
- **Lyra is the weakest visually.** Her look-dev robe is floor length, so many kicks only show a
  boot poking out of the skirt. The Rising Crescent active frame shows her back, and from the front
  the Starguard stance hardly differs from her guard. The upright bouncing stance and long-legged
  intent are in the data, but the costume hides them.
  - Needs: a slit or shorter robe (a look-dev change, not mine to make), or poses turned so the kick
    happens on the camera side.
- **Brann reads as a heavyweight.** The hunch behind the gauntlets, wide base, looping hooks with
  the whole body and the lift-and-slam throws all read.
  - Weak: his hunched yaw turns his broad back to a 3/4 camera, so the review strips mostly show his
    back; the in-game side camera shows his profile (see `zone_stormfall_city.jpg`).
  - Weak: the uppercut and suplex frames are hard to tell apart from his guard in a single still.
- **Review angle.** The strips use one fixed 3/4 view. Lyra's and Brann's bladed yaw turns them
  away from it, so those strips under-sell them; the zone stills from the real camera are the fairer
  view.
- **Across the board:**
  - Hit reactions and blocks are shared poses scaled by each style's knobs, not per-legend art.
  - There are no smear frames on the meshes, only a limb trail ribbon during active frames.
  - Intro and victory poses are keyframed but hold rather than move much.
- **Reach.** The chunky voxel limbs are short (Kael's leg is about 0.65 m), and my first hitboxes
  reached 0.2-0.45 m past the visible fist or foot. I measured each move's limb end on the real rig
  and pulled the hitbox fronts in to it (+7 cm). Now what you see is what hits.
  - Remaining gaps: uppercuts, elbows and launchers still reach about 0.1-0.15 m past the visible
    limb, because their targets go up, not forward.

## Open (ranked)

1. **Online Pure Fight in the lobby.** The DUO-ONLINE lane (`net/duo-online`) is not on
   `origin/main` and has no branch on origin; I polled through the run. The rollback layer and its
   test are done (`PureFightNet`).
   - Left: a "Pure Fight 1v1" room type in the new lobby that builds
     `PureFightNet.new_sim(seed, legends)` on both peers, and a `PureFightMatch` path that steps a
     `RollbackSession` instead of `sim.tick`.
   - The Multiplayer menu entry comes with it.
2. **Lyra's styling.** The robe hides her kicks (see the critique). This needs owner/look-dev input.
3. **Per-legend reactions and art passes.** Hit, block and knockdown poses are shared (style-scaled).
   Still wanted: smear frames on the voxel mesh, a moving rather than held intro and victory, and
   per-legend dash and jump arcs (the jump physics differ per legend, the pose doesn't).
4. **Animation clips.** Poses are keyframed in code and sampled from sim state each frame. They are
   not baked to `Animation` resources, and there are no mocap clips.
5. **No gamepad bindings** (keyboard only, through FighterInput, as the rest of the game).
6. **The QA harness (`run_qa.sh`) doesn't soak Pure Fight.** The 7-zone bot test in GUT plays a full
   3-round match per zone instead. Adding a Pure Fight soak section to `QaSimChecks` is a follow-up.
7. **Balance is untested by humans.** The frame data is fair by the rules in GAME_DESIGN §16.7 (no
   plus-on-block moves, reversals at -15 or worse), but nobody has played it yet.
8. **Zone bakes.** Stills used locally built LOW bakes. A fresh clone builds a zone live the first
   time, which is slow (VOXEL-BAKES).

## Verification

Filled in at merge time below.
