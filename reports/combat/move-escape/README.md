# MOVE-ESCAPE: getting out of, or round, the opponent's attacks (#150)

Owner report (web build of main `61925008`, keyboard, vs AI): "when opponent is attacking I am not
able to go from that place or behind".

Branch `fix/move-escape`. Repro: `tools/diag/move_escape.gd` (scenario code in
`tests/combat/escape_repro.gd`), AI-vs-AI stats `tools/diag/pressure_bouts.gd`, regression tests
`tests/combat/test_move_escape.gd`.

## The cause in plain words

When the opponent ran a string at you, nothing you pressed got you out. It was not one bug but six
that stacked up:

1. **Blocked strings had no gaps.** Every light string was a true blockstring: blockstun ended 0 or
   1 tick before the next hit, so there was never a free tick to do anything in. Kael light 1 -> 2:
   9 ticks between hits, 9 ticks of blockstun (Vexa was -1: blockstun outlasted the gap).
2. **Presses during stun were thrown away.** The input buffer holds a press for 6 ticks; blockstun
   is 8-15 and hitstun 14-32. A Shift tapped while being hit or blocking had expired before you could
   act ("dash buffer expired in BLOCKSTUN" in every log below). The player feels: "I pressed dash and
   nothing happened".
3. **Every string hit re-aimed fully.** Each light link and heavy cancel snapped the attacker to face
   you again, so a sidestep dodged one hit and the next hit tracked you into the sidestep's
   recovery. A whiffed string also carried on into your recovery.
4. **A sideways vanish went nowhere.** Shift+E+A/D under lock-on is meant to step the 6 m vanish
   distance round the target, but it went through the walking strafe's orbit cap (180 deg/s), so it
   moved **3 degrees** (0.11 m) instead.
5. **Holding guard pinned you.** Guard drift was 2.5 m/s, slower than Vexa's string lunges (~3 m/s);
   the guard could not climb, and Space with E held did nothing on the ground.
6. **The AI never used or punished an escape**, so nothing in a match taught that escapes exist.

Suspects checked and **not** the cause: pushboxes pinning the defender (#73; the body solver only
removes the closing speed, the defender still slides sideways; issue-sweep's #73 fix is view-only),
the web build's input path (the same `FighterInput` and buffer as desktop; `tools/web` tests only
cover the browser shell), and attacker forward drift on its own (the 0.6 m block pushback per hit
more than covers it once the guard walks at 4 m/s).

## What changed

Sim (`game/combat/`, all deterministic, rollback state unchanged in shape):

| Rule | Before | After |
|---|---|---|
| Dash press in blockstun / hitstun | expires after 6 ticks | held until the first free tick (a dodge), or the air-tech window on a techable knockback |
| Blockstun of a string light that the string can follow | move's value (0-1 free tick before the next hit) | ends `string_block_gap_ticks` = 4 ticks before the next light turns active; the string's last hit keeps its own |
| Facing on a light link / heavy cancel | snaps to the target | turns at most `follow_up_turn_degrees` = 15 deg; a fresh attack still faces the target |
| A light evaded by a dodge's i-frames | string carries on | string ends (no link, no cancel) |
| Sideways vanish under lock-on | clamped to 3 deg per tick by the strafe cap | the whole 6 m step round the target (at most 180 deg) |
| Guard drift | 2.5 m/s, no climbing | 4 m/s; in the air it climbs/sinks at that speed; ascend on the floor jumps out of the guard |
| Block pushback | 8-tick slide, cut short by a shorter blockstun | the whole 0.6 m inside the blockstun |

New tuning: `HitTuning.string_block_gap_ticks`, `HitTuning.follow_up_turn_degrees`;
`MovementTuning.guard_drift_speed` 2.5 -> 4.0.

AI (`game/ai/pressure_ai.gd`, its own rng, snapshot under its own key `"pressure"` so it does not
clash with issue-sweep's #106 snapshot indices):

- In a blockstun it now and then lets go of the guard and buffers a back dodge or a sidestep for the
  gap (8/15/22/30 % per blockstun at L2-L5; L3+ sidestep a share of them), alongside the existing
  push-block.
- As the attacker it now and then punishes a seen dodge: a grab into the recovery (a counter-hit, no
  tech) close in, else a light, else walks in (15-60 % per dodge at L2-L5). Not every time, so a
  dodge is a real option.
- Guard-habit guarding sets `vertical = 0` so the new ascend-out-of-guard does not make it hop.

## Results

### Repro (`tools/diag/move_escape.gd`)

Kael defends against each legend at 1.8 m, both locked on. The attacker is either **scripted**
(worst case: infinite ki, rushes in whenever out of reach, presses each string link on the first
window tick, loops the string forever, carries on through whiffs) or the **level-5 AI**. The
defender tries 8 options x guard held or not x 3 timings (press as each hit lands, on the first
actionable tick after a contact, or 3 ticks before the stun ends) = 48 runs per attacker. It
**escapes** when, free to act (or dodging, vanished, teching), it is past every light's reach
(3.2 m; the longest light reaches 3.05 m, Lyra light 3), at least 100 deg round the attacker's
facing, or the attacker's move whiffed and is recovering (the defender has the turn). 120 ticks
to do it.

The **required** set (what `tests/combat/test_move_escape.gd` asserts, for all four legends and
both attackers) is every back dodge, sidestep and side vanish, vanish-behind except "open, press as
a hit lands" (that press becomes an air tech, which follows the held direction: in), walking back
without guard, and flying up without guard between hits.

| | main `599ab6aa` | `fix/move-escape` |
|---|---|---|
| Required, scripted attacker | **79 / 112** | **112 / 112** |
| Required, AI lv5 attacker | 104 / 112 | 112 / 112 |
| All 192 runs, scripted | 99 | 152 |
| All 192 runs, AI | 173 | 181 |
| Out of a guarded string with a dodge or vanish (scripted) | up to "never" | at most 34 ticks |

Per option, scripted attacker, runs escaped of 12 (4 legends x 3 timings), main -> branch:

| option | open | guard held |
|---|---|---|
| back dodge (Shift+S) | 12 -> 12 | 12 -> 12 |
| sidestep (Shift+A/D, locked) | **1 -> 12** | **4 -> 12** |
| side vanish (Shift+E+A/D) | 6 -> 12 | 7 -> 12 |
| vanish behind (Shift+E+W) | 8 -> 11 | 9 -> 12 |
| walk back | 12 -> 12 | 5 -> 11 |
| fly up | 11 -> 11 | 6 -> 5 |
| spot dodge (Shift) | 0 -> 9 | 0 -> 4 |
| walk round (A/D, locked) | 3 -> 5 | 3 -> 0 |

Full tables: `before_scripted.md`, `after_scripted.md`, `before_ai.md`, `after_ai.md`. Frame logs
(Kael attacking) in `logs/before/` and `logs/after/`; columns: tick, defender state (ticks/stun),
inputs held/pressed, defender step, distance, degrees round the attacker's facing, ki, attacker
state/move/tick/phase, events, note (why a press did nothing).

### Before / after frame logs

**Back dodge pressed as a blocked light lands** (`logs/*/back_dash_guard_on_hit.log`):

```
main:
 7 | BLOCKSTUN(0/9)  | DAS/DAS | dist 1.50 | light_1 6 ACTIVE  | dash held in buffer: BLOCKSTUN
14 | BLOCKSTUN(6/9)  | -/-     | dist 1.74 | light_2 4 STARTUP | dash buffer expired in BLOCKSTUN
17 | BLOCKSTUN(0/10) | -/-     | dist 1.80 | light_2 7 ACTIVE  | BLOCK        <- next hit, still stuck
branch:
 7 | BLOCKSTUN(0/9)  | DAS/DAS | dist 1.50 | light_1 6 ACTIVE  | dash held in buffer: BLOCKSTUN
10 | BLOCKSTUN(2/4)  | -/-     | dist 1.70 | light_2 0 STARTUP |              <- light 2 starts: stun cut to 4
14 | DASHING(1/0)    | -/-     | dist 2.51 | light_2 4 STARTUP |              <- the held press comes out
16 | DASHING(3/0)    | -/-     | dist 3.52 | light_2 6 STARTUP | escaped (out)
```

**Holding guard through a string** (`hold_back_guard_gap.log`): main gives one free tick between
blocked hits (`BLOCKING(1/0)` once, at t 43, before light 4); the branch gives four before every
link (`BLOCKING(1..4/0)` at t 13-16, 25-28, ...).

**Side vanish** (`vanish_side_guard_gap.log`): main `VANISHING(1/0) | step 0.10 m | 3 deg` (t 45);
branch `VANISHING(1/0) | step 2.24 m | 90 deg` (a quarter turn round at 1.6 m, in the gap before
light 2).

**Sidestep between strings** (`sidestep_open_gap.log`): on main the attacker snaps back to face
the sidestepper for light 2 (62 -> 7 deg) and light 3 lands in the sidestep's recovery (`HIT`, t
113). On the branch each link turns at most 15 deg (62 -> 55, 84 -> 70), the sidestep keeps the
defender at 70-84 deg off the attacker's facing, lights 2 and 3 miss, and the defender is free at t
116 with light 3 recovering (`escaped (whiffed)`).

### AI vs AI (`tools/diag/pressure_bouts.gd`, 4 matchups x 3 seeds x 3600 ticks, L5 vs L4)

| | main | branch |
|---|---|---|
| Blocked hits | 156 | 144 |
| Longest run of blocked hits without acting | 6 | 6 |
| Dodges out of a blockstun | 0 | 21 |
| Dodges punished (counter-hit grab) | 0 | 6 |
| Push-blocks | 39 | 39 |
| Hits landed | 1016 | 984 |

Tables: `bouts_before.md`, `bouts_after.md`.

## QA quick (`tools/qa/run_qa.sh --quick --jobs 2`, same box, same settings)

| Section | main `599ab6aa` | branch `b1f01aca` |
|---|---|---|
| Invariant soak (sim) | PASS | PASS |
| Invariant soak (view) | FAIL | FAIL |
| Scenario library | PASS | PASS |
| Golden replays | PASS | PASS (re-blessed) |
| Visual goldens | NOT RUN | NOT RUN |
| Feel metrics trend | PASS | PASS |

Feel metrics, main -> branch: camera jerk p95 0.00873 -> 0.00895 (+2.5 %), hitstop consistency
0.722 -> 0.714, foot slide 0.0317 -> 0.0312 cm/frame, foot error p95 0.93 -> 0.92 cm, pops
0.036 -> 0.036 per fighter-minute, locked on-screen share 0.982 -> 0.976, sim 1.18 -> 1.20 ms/tick,
view 1.21 -> 1.23 ms/frame. Press-to-active latency unchanged for every legend and attack.

**The view soak has more violations than main** (same FAIL verdict): camera_on_screen 2/21 -> 5/21
matches (5 frames), foot_ground 3/21 (4 frames) -> 5/21 (19 frames), pop 1 -> 1. Main's numbers are
identical run to run (the same matches every time), so to check whether this is the matches
diverging or a real effect, I ran both at 4800 ticks per match (headless, view checks on):

| 4800-tick A/B, 21 matches | main | branch |
|---|---|---|
| camera_on_screen | 1 match | 4 matches (92.4-94.9 %, limit 95 %) |
| foot_ground | 9 matches / 17 frames | 11 matches / 69 frames |
| fighter_overlap | 6 / 12 | 6 / 12 |
| pop | 1 / 1 | 1 / 1 |

49 of the branch's 69 foot frames are three clusters on cliffs: two AI fighters flying up a
Shattered Mesa cliff at 28 m/s and landing on a ledge the voxel art does not show (+2.6 to +3.1 m,
`IDLE, clip land`), a -77 cm sink on an Ember Rift slope, and a -18 cm `walk_back` sink. That is the
existing terrain-vs-voxel ledge class (main has the same class at 50-90 cm), reached because the
matches now go elsewhere. None involve a guard state. The camera misses are borderline shares at
the end of long matches. Ablations on those four matches: putting the side vanish back on the strafe
cap changes nothing; switching `PressureAI` off clears one of four. So they are not one new mechanic;
more lateral movement in general is the likely cause, and it lands on the open developer camera item
(T-135-c, hybrid camera). Filed on the board; not hidden, no threshold changed.

## How it feels now (honest critique)

I could not play it: this is headless sim evidence plus frame logs, not hands-on feel. What the
numbers say a player will notice:

- **Blocking is no longer a cage.** Every continued blocked light leaves 4 free ticks. Tap Shift
  plus a direction any time during the blockstun (you no longer have to time it) and the dodge
  comes out on the first free tick. A back dodge clears light reach in about 3 ticks, a sidestep
  goes round in about 20, a side vanish is instant. A lone jab keeps its old frame data (Kael light
  1 is still -2 on block), so the change is about strings, not about making every button unsafe.
- **Mashing a button in the gap still loses.** The gap is shorter than any light's startup (4-8
  ticks), so a jab in the gap gets counter-hit by the next link. That is deliberate (escape tools
  beat strings, buttons do not), but a player who mashes light instead of Shift will still feel
  stuck. The AI shows it by doing it: at L4-L5 it rolls a dodge-out 22-30 % of the time it is
  caught in a blockstring.
- **Pressing Shift while being comboed now air-techs at the earliest tick** (tick 12 of a
  knockback) instead of being thrown away. Escaping gets easier and more forgiving, but an early
  mash techs on a predictable tick, and a chaser can read that. This is a skill change to the T-DEF3
  air tech; it may want a "fresh press only" window if it turns out too easy.
- **Strings look a bit less sticky.** Links turn 15 degrees at most, so a side-stepping or circling
  target makes them whiff. Against a target standing still nothing changes.
- **Still not an escape, by design:** a spot dodge (Shift alone) dodges a hit or two, then its
  14-frame recovery is open to a blind string (4/12 guarded, 9/12 open). Walking round under lock-on
  is capped at 180 deg/s (the camera's turn cap) and does not beat a re-aiming attacker; while
  guarding it scores worse than before against the scripted presser (3/12 -> 0/12; I did not dig
  into why, it was never an escape route). The sidestep and the side vanish are the
  "get behind" tools. Flying up with guard held climbs at 4 m/s and a chaser flying at 30 m/s
  follows; let go of guard to fly.
- **Walking back with guard held (4 m/s) breaks the string, but a rush tails you.** After the
  string, the scripted attacker's homing rush follows a retreating blocker at 2.57 m for its whole
  90 ticks, because its brake never quite reaches the stop point against a target moving away (the
  one guarded walk-back miss, Vexa). That is an attacker-side quirk, filed below.
- **The AI is less canned:** it now sometimes dodges out of your strings and sometimes grabs your
  dodge's recovery (a counter-hit, no tech), so dodging on reflex is punishable while dodging on a
  read is rewarded.

## Lanes

- **Pure Fight** (`feature/pure-fight`, merged into main as `599ab6aa` before this branch merged
  main): `PureFightSim` extends `CombatSim` but never runs `CombatSim.tick`, so none of these rules
  reach it. Shared combat code that changed: `CombatSim._record_presses` (dash presses wait out
  stun), `_begin_light`/`_open_block_gap`, `_face_for_attack` (light and heavy facing),
  `_find_contact` (a dodged light ends the string), `_start_vanish`/`_move_around_target(max_turn)`,
  `_move_blocking(vertical)`, `_jumps_out_of_guard`, `_start_pushback` (slide fits in the stun), plus
  `HitTuning.string_block_gap_ticks`, `HitTuning.follow_up_turn_degrees` and
  `MovementTuning.guard_drift_speed` 4.0. If Pure Fight ever calls these helpers, it inherits them.
- **Issue sweep** (`fix/issue-sweep`, not on main): fetched before the AI and pushbox parts. Its
  #73 fix is view-only (`BodySeparation`), no clash with the sim. Its #106 AI string variety was
  reverted on that branch (`859c6bad`, kept on `fix/issue-106-ai-variety`); `PressureAI` keeps its
  own snapshot key (`"pressure"`), not new indices in `FighterAI.snapshot().values`, so #106's
  `v[33]`/`v[34]` merge cleanly later.

## Tests and evidence

- `tests/combat/test_move_escape.gd`: the 112 required escapes x 4 legends x {scripted, AI}, a
  guarded dodge or vanish out within 40 ticks against the scripted attacker, and one test per rule
  (buffered dash out of blockstun, gap before each next light, an unfollowed light keeps its
  blockstun, follow-up turn cap, a dodged light ends the string, quarter-turn side vanish, jump out
  of guard and guard climb, guard drift faster than every string lunge, the AI dodges out and
  punishes dodges in seeded bouts, `PressureAI` snapshot/restore).
- Test changes outside the new file, each for a stated reason, no threshold loosened:
  `tests/playtest/test_flight_camera.gd` (developer's): the screen-size check skips vanished frames,
  like the on-screen check beside it; its one sub-15 % frame (0.1497) is the frame the player is
  invisible after a side vanish, which now moves. Seeds re-picked where a seeded bot match stopped
  producing its precondition event: `test_weapons` 5 -> 6, `test_powers` 6 -> 8,
  `tests/net/test_sim_snapshot.gd` (developer's) 12 -> 13, as earlier sim changes did.
- Goldens: all ten replays and `tests/combat/data/flat_floor_golden.json` re-blessed (reason in
  `tests/qa/goldens/README.md`).
- det_check: `65ec2f54272115fd` (main) -> **`b8bab850a4256dc7`**, identical on two runs; reason:
  the combat timing above. Reference in `reports/gameplay/det_check_move_escape.txt`.

## Open

- Rush tailgating: a rush toward a target retreating at walking/guard speed never reaches its stop
  point and follows for all of `rush_max_ticks` (90). Suggest ending a rush that has not closed in for
  N ticks. Not changed here (attacker-side feel, needs its own look).
- The air-tech-from-held-press rule (above) wants an owner play to decide whether it is too easy.
- Walking round under lock-on stays capped at 180 deg/s by the camera's turn cap (developer).
- Hands-on: play one match vs AI L4 on the web build and block a full string, then Shift+S in it.
