# QA-24 / QA-22 on fix/voxel-soles-perf

Lavapipe stills (1920x1080 rendered, 960 px previews): guard at the boots (`feet_090` side,
`feet_035` 3/4) and knockdown (`knockdown_090`, `knockdown_035`).


Per legend, 1v1 mirror soaks (heartbloom, stormfall, frozen peaks; 2400 ticks; headless):

| Legend | foot_error_p95 before (cm) | after | classic | view_ms before | after | classic* | pops/min before, after |
|---|---|---|---|---|---|---|---|
| kael | 1.80, 1.99, 1.93 | 0.80, 1.05, 0.99 | 0.80, 1.06, 0.99 | 0.572 | 0.561 | 0.576 | 0, 0 |
| vexa | 1.05, 1.49, 1.38 | 0.66, 1.09, 0.98 | 0.71, 1.14, 1.03 | 0.695 | 0.674 | 0.685 | 0, 0 |
| lyra | 1.75, 2.32, 1.84 | 0.75, 1.36, 0.97 | 0.74, 1.30, 1.05 | 0.545 | 0.545 | 0.658 | 0, 0 |
| brann | 1.92, 2.19, 2.15 | 0.92, 1.20, 1.15 | 0.92, 1.20, 1.15 | 1.087 | 1.038 | 0.668 | 0, 0 |

*classic soaks ran with a lavapipe render alongside, so their ms are a little high.

QA-22 is not done: voxel Brann's view is still ~1.6x classic. Profile (apply_state, us/frame on a
guard-heavy sequence): base view 189, braid 96, wrist 13, fist clearance 124. In guard the fists
really are at the boulders, and every solver turn dirties the skeleton so the next pose read rebuilds
all bones. The early-out and caching here are output-identical (golden to 5e-15 m, same 2496 turns)
but only save ~5% in matches.
