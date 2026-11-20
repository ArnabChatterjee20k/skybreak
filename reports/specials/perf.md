# T-SP1 sim cost

A 4-legend level-4 AI free-for-all (3 seeds x 3600 ticks), `CombatSim.tick()` only, same machine, alternating runs:

| Run | main (7d98be1) | this branch |
|---|---|---|
| 1 | 0.2634 ms/tick | 0.2717 ms/tick |
| 2 | 0.2460 ms/tick | 0.2513 ms/tick |

About +2-3%, well inside the 16.7 ms frame. The QA quick feel table flagged sim/view ms +91%; that run used 8 jobs on a 4-core container, and the baseline metrics came from another machine.
