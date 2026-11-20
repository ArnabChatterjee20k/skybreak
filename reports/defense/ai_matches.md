# T-DEF1 AI-match defense counters (082e584, 2026-11-20)

QA quick matrix (21 matches, every zone x 1v1/FFA-4/2v2, AI levels 2-5), 3600 ticks each, FIGHT phase only.
`godot --headless --path . -s res://tools/qa/defense_audit.gd -- --shard i/4 --ticks 3600 --out DIR` then `python3 tools/qa/defense_summary.py DIR`.

matches 21, fighter-minutes 64.9

| counter | total | per fighter-minute |
|---|---:|---:|
| attack_grab_GRAB | 55 | 0.85 |
| attack_grab_total | 78 | 1.20 |
| attack_grab_whiff_close | 5 | 0.08 |
| attack_grab_whiff_nobody_near | 18 | 0.28 |
| attack_push_block_PUSH_BLOCK | 47 | 0.72 |
| attack_push_block_total | 55 | 0.85 |
| attack_push_block_whiff_nobody_near | 8 | 0.12 |
| attack_strike_ARMOR | 16 | 0.25 |
| attack_strike_BLOCK | 204 | 3.14 |
| attack_strike_COUNTER | 292 | 4.50 |
| attack_strike_HIT | 1475 | 22.72 |
| attack_strike_PERFECT_BLOCK | 46 | 0.71 |
| attack_strike_evaded_dash | 4 | 0.06 |
| attack_strike_evaded_vanish | 2 | 0.03 |
| attack_strike_total | 2897 | 44.63 |
| attack_strike_whiff_close | 261 | 4.02 |
| attack_strike_whiff_nobody_near | 597 | 9.20 |
| dash_RUSH | 141 | 2.17 |
| dash_STEP | 24 | 0.37 |
| event_ARMOR | 17 | 0.26 |
| event_BLOCK | 261 | 4.02 |
| event_COUNTER | 313 | 4.82 |
| event_GRAB | 55 | 0.85 |
| event_GRAB_TECH | 35 | 0.54 |
| event_GUARD_BREAK | 2 | 0.03 |
| event_HIT | 1943 | 29.93 |
| event_PERFECT_BLOCK | 47 | 0.72 |
| event_PUSH_BLOCK | 48 | 0.74 |
| guard_raised | 2619 | 40.35 |
| projectile_blocked | 55 | 0.85 |
| projectile_hit | 471 | 7.26 |
| projectile_reflected | 55 | 0.85 |
| projectiles_fired | 530 | 8.16 |
| vanish_combo_cancel | 117 | 1.80 |
| vanish_combo_cancel_under_attack | 5 | 0.08 |
| vanish_neutral | 104 | 1.60 |

Strike outcomes (share of melee strikes thrown):
  ARMOR                      0.6%
  BLOCK                      7.0%
  COUNTER                   10.1%
  HIT                       50.9%
  PERFECT_BLOCK              1.6%
  evaded_dash                0.1%
  evaded_vanish              0.1%
  whiff_close                9.0%
  whiff_nobody_near         20.6%
