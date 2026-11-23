# Gameplay QA report: bbc45d0f (quick)

Matches: 21, ticks: 50400, total wall 427 s. Thresholds are documented in `AGENTS.md` (QA).

| Section | Result |
|---|---|
| Invariant soak (sim) | **PASS** |
| Invariant soak (view) | **FAIL** |
| Scenario library | **PASS** |
| Golden replays | **PASS** |
| Visual goldens | **NOT RUN** |
| Feel metrics trend | **PASS** |

## Invariant soak: sim

No violations.

## Invariant soak: view

| Check | Matches hit | Frames | Note |
|---|---|---|---|
| foot_ground | 4 / 21 | 5 |  |
| camera_on_screen | 1 / 21 | 1 |  |
| pop | 1 / 21 | 1 |  |

## Top 10 violations

1. **foot_ground**, fighter 2, legend lyra, weapon unarmed, zone frozen_peaks, 2v2, seed 117, worst at tick 268 (first 268, 2 frames): lowest sole +22.0 cm off the visible ground (IDLE, clip fight_idle)  
   `tools/qa/run_qa.sh --repro '117:frozen_peaks:2v2:vexa,brann,lyra,kael:2343' --tick 268 --fighter 2`

   ![foot_ground](../../../../../tmp/claude-0/-home-user-skybreak/4e186c43-dc1a-5ea7-9490-c8cfd16237c6/scratchpad/qa_main/captures/117_frozen_peaks_2v2_vexa-brann-lyra-kael_2343_t268/frame_00268.png) [2 s clip](../../../../../tmp/claude-0/-home-user-skybreak/4e186c43-dc1a-5ea7-9490-c8cfd16237c6/scratchpad/qa_main/captures/117_frozen_peaks_2v2_vexa-brann-lyra-kael_2343_t268/clip.mp4)

2. **camera_on_screen**, fighter 0, legend vexa, weapon unarmed, zone ember_rift, 2v2, seed 105, worst at tick 2400 (first 2400, 1 frames): both locked fighters on screen in 93.8% of 1989 locked frames  
   `tools/qa/run_qa.sh --repro '105:ember_rift:2v2:vexa,brann,lyra,kael:3224' --tick 2400 --fighter 0`

   ![camera_on_screen](../../../../../tmp/claude-0/-home-user-skybreak/4e186c43-dc1a-5ea7-9490-c8cfd16237c6/scratchpad/qa_main/captures/105_ember_rift_2v2_vexa-brann-lyra-kael_3224_t2400/frame_02400.png) [2 s clip](../../../../../tmp/claude-0/-home-user-skybreak/4e186c43-dc1a-5ea7-9490-c8cfd16237c6/scratchpad/qa_main/captures/105_ember_rift_2v2_vexa-brann-lyra-kael_3224_t2400/clip.mp4)

3. **pop**, fighter 1, legend vexa, weapon repeater, zone ember_rift, 1v1, seed 112, worst at tick 1690 (first 1690, 1 frames): RightHand turned 1.21 rad in one frame (HITSTUN, move , clip hit_light)  
   `tools/qa/run_qa.sh --repro '112:ember_rift:1v1:kael,vexa:45' --tick 1690 --fighter 1`

   ![pop](../../../../../tmp/claude-0/-home-user-skybreak/4e186c43-dc1a-5ea7-9490-c8cfd16237c6/scratchpad/qa_main/captures/112_ember_rift_1v1_kael-vexa_45_t1690/frame_01690.png) [2 s clip](../../../../../tmp/claude-0/-home-user-skybreak/4e186c43-dc1a-5ea7-9490-c8cfd16237c6/scratchpad/qa_main/captures/112_ember_rift_1v1_kael-vexa_45_t1690/clip.mp4)

4. **foot_ground**, fighter 3, legend brann, weapon unarmed, zone frozen_peaks, ffa4, seed 110, worst at tick 2369 (first 2369, 1 frames): lowest sole +6.1 cm off the visible ground (IDLE, clip turn_step)  
   `tools/qa/run_qa.sh --repro '110:frozen_peaks:ffa4:lyra,kael,vexa,brann:3523' --tick 2369 --fighter 3`

   ![foot_ground](../../../../../tmp/claude-0/-home-user-skybreak/4e186c43-dc1a-5ea7-9490-c8cfd16237c6/scratchpad/qa_main/captures/110_frozen_peaks_ffa4_lyra-kael-vexa-brann_3523_t2369/frame_02369.png) [2 s clip](../../../../../tmp/claude-0/-home-user-skybreak/4e186c43-dc1a-5ea7-9490-c8cfd16237c6/scratchpad/qa_main/captures/110_frozen_peaks_ffa4_lyra-kael-vexa-brann_3523_t2369/clip.mp4)

5. **foot_ground**, fighter 0, legend kael, weapon unarmed, zone stormfall_city, 2v2, seed 102, worst at tick 2383 (first 2383, 1 frames): lowest sole +5.5 cm off the visible ground (BLOCKING, clip guard)  
   `tools/qa/run_qa.sh --repro '102:stormfall_city:2v2:kael,vexa,brann,lyra:4455' --tick 2383 --fighter 0`

   ![foot_ground](../../../../../tmp/claude-0/-home-user-skybreak/4e186c43-dc1a-5ea7-9490-c8cfd16237c6/scratchpad/qa_main/captures/102_stormfall_city_2v2_kael-vexa-brann-lyra_4455_t2383/frame_02383.png) [2 s clip](../../../../../tmp/claude-0/-home-user-skybreak/4e186c43-dc1a-5ea7-9490-c8cfd16237c6/scratchpad/qa_main/captures/102_stormfall_city_2v2_kael-vexa-brann-lyra_4455_t2383/clip.mp4)

6. **foot_ground**, fighter 2, legend kael, weapon unarmed, zone shattered_mesa, ffa4, seed 107, worst at tick 782 (first 782, 1 frames): lowest sole +5.5 cm off the visible ground (BLOCKING, clip guard)  
   `tools/qa/run_qa.sh --repro '107:shattered_mesa:ffa4:brann,lyra,kael,vexa:2445' --tick 782 --fighter 2`

   ![foot_ground](../../../../../tmp/claude-0/-home-user-skybreak/4e186c43-dc1a-5ea7-9490-c8cfd16237c6/scratchpad/qa_main/captures/107_shattered_mesa_ffa4_brann-lyra-kael-vexa_2445_t782/frame_00782.png) [2 s clip](../../../../../tmp/claude-0/-home-user-skybreak/4e186c43-dc1a-5ea7-9490-c8cfd16237c6/scratchpad/qa_main/captures/107_shattered_mesa_ffa4_brann-lyra-kael-vexa_2445_t782/clip.mp4)

## Ki usage by the AI (T-KI1)

| blasts | charged | beams | ultimates | clashes | reflects | soaks | beam_whiffs | ki_hits |
|---|---|---|---|---|---|---|---|---|
| 26 | 11 | 5 | 0 | 0 | 0 | 0 | 3 | 22 |

Per fighter-minute (46.7 fighter-minutes): blasts 0.56, charged 0.24, beams 0.11, clashes 0.00.


## Scenario library

38 tests: 38 passing, 0 failing, 0 pending (strict mode: known issues fail).


## Golden replays

11 tests, 0 failing.


## Visual goldens

Not run: numpy/Pillow missing.

## Feel metrics

Compared with reports/qa/2026-11-23-d270c6ad-quick/metrics.json; regression = worse by more than 15%.

| Metric | Now | Before | Change |
|---|---|---|---|
| hitstop_consistency | 0.7535 | 0.7535 | +0% |
| pops_per_fighter_minute | 0.03573 | 0.03573 | +0% |
| finger_pops_per_fighter_minute | 0.03573 | 0.03573 | +0% |
| foot_slide_cm_per_frame | 0.02945 | 0.02945 | +0% |
| foot_error_p95_cm | 0.8954 | 0.8954 | +0% |
| camera_jerk_p95 | 0.0094 | 0.0094 | +0% |
| locked_on_screen_share | 0.9875 | 0.9875 | +0% |
| sim_ms_per_tick | 1.185 | 1.156 | +2% |
| view_ms_per_frame | 1.326 | 1.284 | +3% |

Press to first active frame (ticks at 60 Hz):

| Legend | grab@air | grab@ground | heavy@air | heavy@ground | light@air | light@ground |
|---|---|---|---|---|---|---|
| brann | 10 | 10 | 19 | 19 | 9 | 9 |
| kael | 8 | 8 | 15 | 15 | 7 | 7 |
| lyra | 9 | 9 | 16 | 16 | 7 | 7 |
| vexa | 7 | 7 | 12 | 12 | 5 | 5 |

