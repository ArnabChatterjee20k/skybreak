# QA goldens

Golden replays (`replays/`) and visual goldens (`visual/`) for the QA harness
(T-D31). Re-record with `tools/qa/bless_goldens.sh --replays|--visual|--all`
only in the PR that intends the change, and log it below.

## Re-bless for #125 T-ART1 zone art pass (merge of main 372bccd)

All 14 visual goldens re-blessed with `bless_goldens.sh --visual` on the merged code
(official Godot 4.7.2 linux x86_64, fresh `--import`, gl_compatibility 960x540):

- `zone_*` (6): the T-ART1 art pass (sRGB zone colours, 3-band terrain ramp, per-zone
  ground detail, inked lips and props, backdrop-only fog, re-tuned palettes) on top of
  #123's Ember Rift lava fissures. `zone_ember_rift.png` was a binary conflict (both
  PRs re-blessed it); the new render shows the fissures on the darker seamed basalt.
- `heartbloom_*` (8): #123's duel-drop telegraph pillar in frame (approved by the
  owner) plus the T-ART1 terrain and the merged ground marker.
- Ground marker: #125's contact shadow and the T-118 `HeightMarker` ring both drew
  under an airborne fighter. They are now one marker: `ContactShadows` draws the soft
  dark disc and, once the feet are above `HeightMarker.SHOW_ABOVE`, a team-colour rim;
  `HeightMarker` keeps only its drop line. After merging #122 (T-UX1, main 26019b8)
  the drop line is gone too: `HeightMarker` draws only #122's faint 3-dash tick above
  3 m, and the rim starts at 0.4 m and quiets with height (`ContactShadows.ring_strength`).

## Re-bless for #89 polish batch 2 (merge of main 3466207 into `claude/polish-batch-2`)

### Golden replays

#89 adds `ko_origin` to the hashed fighter fields, so every stored hash differs
from tick 0. To find the real first drift, each #90 golden's recorded inputs
were played on main (3466207, which matches every #90 hash) and on the merge,
comparing every field the #90 goldens hash, per tick. Every first drift is the
#89 close-air knockback guard (intended): a hit or counter with a fighter off
the floor and the pair closer than `air_knockback_separation` (1.5 m). Only the
target's planar velocity changes, raised to `air_light_knockback_min_out`
(3 m/s) away from the attacker; vertical speed is unchanged. No replay drifts
first on a KO tick (the KO travel cap acts later, in an already drifted match),
and none at any other kind of tick. No ulp-level drift remains: #90 already
took the DetMath ulps (below).

| Replay | First drift (tick) | Event | Field | Planar speed main -> merged (m/s) | vy | Heights before (m) | Attacker-target gap (m) |
|---|---|---|---|---|---|---|---|
| combos_level5 | 188 | COUNTER 1->0 | f0.velocity | 2.49 -> 3.00 | unchanged | f0 1.16, f1 1.00 | 1.12 |
| duel_brann_vs_kael | 110 | HIT 1->0 | f0.velocity | 1.60 -> 3.00 | unchanged | f0 6.39, f1 4.39 | 0.88 |
| duel_kael_mirror | 675 | HIT 1->0 | f0.velocity | 1.97 -> 3.00 | unchanged | f0 1.00, f1 1.32 | 1.08 |
| duel_low_level_mirror | 116 | COUNTER 0->1 | f1.velocity | 1.50 -> 3.00 | unchanged | f0 1.00, f1 1.03 | 1.11 |
| duel_lyra_vs_brann_airborne | 21 | COUNTER 0->1 | f1.velocity | 1.44 -> 3.00 | unchanged | f0 11.48, f1 12.09 | 1.45 |
| duel_vexa_vs_lyra | 122 | HIT 0->1 | f1.velocity | 1.44 -> 3.00 | unchanged | f0 5.15, f1 5.72 | 0.95 |
| ffa4_all_legends | 355 | HIT 1->3 | f3.velocity | 1.49 -> 3.00 | unchanged | f0 1.00, f1 1.17, f2 1.00, f3 1.00 | 1.27 |
| ko_and_second_round | 620 | COUNTER 0->1 | f1.velocity | 2.47 -> 3.00 | unchanged | f0 1.00, f1 1.34 | 1.16 |
| pickups_heartbloom | 347 | HIT 0->1 | f1.velocity | 1.50 -> 3.00 | unchanged | f0 1.01, f1 1.00 | 1.36 |
| teams_2v2 | 158 | HIT 2->0 | f0.velocity | 1.18 -> 3.00 | unchanged | f0 6.53, f1 1.00, f2 4.76, f3 2.10 | 0.89 |

Heights are capsule centres the tick before (standing reads 1.00); the gap is
planar, at the hit tick. All ten re-recorded on the merge.

## Re-baseline after #87 DetMath (from 525efd1)

### Golden replays

#87 replaced libm `sin`/`cos`/`atan2` in the sim and AI with `DetMath` and
canonicalised `-0.0`, so floats move by ulps. #86's AI-spacing code had four
libm calls left in `fighter_ai.gd` (a merge race that failed the determinism
lint); they now use `DetMath` too. The goldens keep only a 1-byte digest per
field, so the old values come from replaying the same inputs on 5399ac1
(before #87). Every replay's first drift is after tick 0 (hash index 1), with
the same events on both sides at that tick:

| Replay | Slot / field | Old | New | Size |
|---|---|---|---|---|
| duel_kael_mirror | f0 position.x | 0.006051136 | 0.0060511352 | 2 ulp |
| duel_kael_mirror | f0 facing_yaw | 0.0005052825994681568 | 0.000505282521700776 | 1 ulp (double) |
| duel_vexa_vs_lyra | f0 position.x | -0.006051136 | -0.0060511352 | 2 ulp |
| duel_vexa_vs_lyra | f0 facing_yaw | -0.0005052825994681568 | -0.000505282521700776 | 1 ulp (double) |
| duel_brann_vs_kael | f0 position.x | -0.006051136 | -0.0060511352 | 2 ulp |
| duel_brann_vs_kael | f0 facing_yaw | -0.0005052825994681568 | -0.000505282521700776 | 1 ulp (double) |
| duel_lyra_vs_brann_airborne | f1 facing_yaw | -3.141592653589793 | 3.141592653589793 | same angle: atan2(-0.0, -1) gave -pi, now +pi after `-0.0` canonicalisation |
| duel_low_level_mirror | f0 position.x | 0.006051136 | 0.0060511352 | 2 ulp |
| duel_low_level_mirror | f0 facing_yaw | 0.0005052825994681568 | 0.000505282521700776 | 1 ulp (double) |
| combos_level5 | f0 position.x | -0.006051136 | -0.0060511352 | 2 ulp |
| combos_level5 | f0 facing_yaw | -0.0005052825994681568 | -0.000505282521700776 | 1 ulp (double) |
| ffa4_all_legends | f3 velocity.x | 0.7763313 | 0.77633137 | 1 ulp |
| teams_2v2 | f2 velocity.x | 0.36233106 | 0.3623312 | 5 ulp |
| ko_and_second_round | f0 position.x | -0.006051136 | -0.0060511352 | 2 ulp |
| ko_and_second_round | f0 facing_yaw | -0.0005052825994681568 | -0.000505282521700776 | 1 ulp (double) |
| pickups_heartbloom | f0 position.x | -0.006051136 | -0.0060511352 | 2 ulp |
| pickups_heartbloom | f0 facing_yaw | -0.0005052825994681568 | -0.000505282521700776 | 1 ulp (double) |

All ten re-blessed. `tools/diag/det_check.gd` still ends `det_check total 2bb1c571b216b165`.

## Re-baseline after #69 pushboxes and #72 motion pass 2 (from bc9aa29)

### Golden replays

#69 added `pushback_velocity`, `pushback_ticks` and `pushback_from` to the
hashed fighter fields, so every stored hash differs from tick 0. To find the
real first drift, each replay was played on the new sim and compared field by
field on the fields the old goldens hashed. Every first drift lands on a
pushbox contact (the bodies' gap reaches 0 that tick) or on the first tick of a
hit/block pushback slide (the slide waits out hitstop, then moves the target).

| Replay | Old first-drift hash index (after tick) | Fields | Cause |
|---|---|---|---|
| duel_kael_mirror | 37 (36) | f0, f1 position, velocity | first pushbox contact 0-1 (#69) |
| duel_vexa_vs_lyra | 41 (40) | f0 position | block at tick 38, first pushback slide step (#69) |
| duel_brann_vs_kael | 36 (35) | f0, f1 position, velocity | first pushbox contact 0-1 (#69) |
| duel_lyra_vs_brann_airborne | 30 (29) | f1 position | hit pushback started at tick 21, first slide step after hitstop (#69) |
| duel_low_level_mirror | 39 (38) | f1 position | hit at tick 34, first pushback slide step (#69) |
| combos_level5 | 42 (41) | f0, f1 position, velocity | pushbox contact 0-1 (gap 0.002 m at 41, resolved at 42) (#69) |
| ffa4_all_legends | 33 (32) | f0, f2 position, velocity | first pushbox contact 0-2 (#69) |
| teams_2v2 | 35 (34) | f1, f3 position, velocity | first pushbox contact 1-3 (#69) |
| ko_and_second_round | 68 (67) | f1 position | hit pushback started at tick 57, first slide step after hitstop (#69) |
| pickups_heartbloom | 40 (39) | f1 position | block at tick 37, first pushback slide step (#69) |

### Visual goldens

Re-blessed: the eight `heartbloom_<legend>_{idle,light}` shots. Their diffs sit
only on the fighters and their shadows: the new mocap poses from #72 (Brann's
idle fails the tile threshold, 5.4%; the rest pass but have moved).

Kept: the six `zone_*` shots. They pass, and none of their diffs comes from an
intended change. `zone_skyhold_ruins` scores SSIM 0.944 / 4.2% tiles against
the golden, and the same 0.944 between two renders of this commit: its cloud
sea is not deterministic across renders (filed as QA-10 in `TODO.md`).

## T-D34: zone shots without the HUD, re-blessed for #81

The six `zone_*` shots failed on main (QA-14). Two possible causes were named: #81
(zone readability: `lava` / `terrain_toon` shaders, zone palettes, props; merged
in #84 without re-blessing) and #88's HUD changes, since the shots captured the HUD.
Renders of each zone shot (gl_compatibility, 960x540, this container), compared
with the old goldens:

| Shot | main, HUD on | main with #81 reverted, HUD on |
|---|---|---|
| zone_ember_rift | 0.827 / 43.3% (HUD off) | 0.989 / 1.7% PASS |
| zone_frozen_peaks | 0.876 / 88.1% (HUD off) | 0.989 / 2.1% PASS |
| zone_shattered_mesa | 0.916 / 31.2% (HUD off) | 0.992 / 1.7% PASS |
| zone_skyhold_ruins | 0.785 / 56.9% (HUD off) | 0.933 / 7.1% (QA-10 cloud noise) |
| zone_stormfall_city | 0.921 / 18.8% (HUD off) | 0.985 / 0.8% PASS |
| zone_verdant_falls | 0.891 / 31.7% (HUD off) | 0.995 / 0.6% PASS |

With #81 reverted and #88's HUD still drawn, five of six pass, and the sixth only
misses on the known Skyhold cloud noise. So the cause is #81, not the HUD. The
remaining main-vs-reverted diff (HUD hidden on both) is the #81 change as shown in
its own `game/world/preview/renders/zone_contrast_before_after.jpg`: lighter Ember
Rift walls with orange lava, blue ice and darker snow on Frozen Peaks, paler
Skyhold islands.

The zone shots now hide every `CanvasLayer` in the level (`scene_only` in
`QaShots`, `_hide_overlays` in `qa_soak.gd`), so HUD and overlay changes can no
longer move them, and the six were re-blessed with `bless_goldens.sh --visual`.
The eight `heartbloom_*` fighter shots still draw the HUD and were not re-blessed
(they pass; their new renders were discarded).

## T-D34: foot-slide metric v2 (feel trend re-baseline)

`QaViewChecks` foot slide now only counts a planted foot over two consecutive
presented frames of IDLE: not across a vanish (or any sim move over 0.5 m between
frames), hidden frames, or the first 10 frames of a match or round, and only when
the lowest sole is within `FOOT_TOLERANCE` (5 cm) of the ground. Floating or sunk
frames are left out and counted as `foot_slide_skipped_frames`. `qa_report.py`
tags `metrics.json` with `metric_versions` (`foot_slide_cm_per_frame: 2`), and the
trend skips a metric whose version differs from the reference report ("re-baselined").
The first v2 quick report is the new foot-slide reference.

## T-UI1 + T-ART2: merged re-bless

PR #143 (HUD restyle on `MenuTheme`: plates, clock, banners, portraits) and PR #142
(art round 2: zones, KO beat, model changes) both re-blessed the `heartbloom_*`
shots. After merging main into #143 all visual goldens were re-rendered on the
merged code with `bless_goldens.sh --visual` (Godot 4.7.2 linux x86_64). The eight
`heartbloom_*` shots change because they show the new HUD over the art round 2
Heartbloom zone; the zone shots changed only by art round 2 noise.

## Re-bless for #150 (MOVE-ESCAPE, `fix/move-escape`)

Intended combat change, all ten replays and `tests/combat/data/flat_floor_golden.json`
re-recorded: a dash pressed in blockstun or hitstun now waits for the first free tick (or
the air-tech window), a string's next light cuts the blocker's blockstun to leave a 4-tick
gap, light links and heavy cancels turn at most 15 degrees, a dodged light ends the string,
a side vanish goes up to 90 degrees round the target, guard drift 2.5 -> 4 m/s (climbs in the
air, ascend on the floor jumps out), and the AI's new `PressureAI` rolls. First drift on main's
goldens: facing_yaw within 30-150 ticks (the follow-up turn cap). `det_check total` goes from
`65ec2f54272115fd` to `b8bab850a4256dc7` (`reports/gameplay/det_check_move_escape.txt`).
