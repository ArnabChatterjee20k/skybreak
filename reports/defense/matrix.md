# T-DEF1 scripted defense matrix (082e584, 2026-11-20)

Defender Kael, attacker per table, flat floor, both locked on, 100 ki. Cell = outcome (frame advantage after it: + means the defender acts first). Option input at an ideal read: first-contact tick minus lead (perfect block 3, dash 4, vanish 2, jump 8, rising 5, jab 6; grab tech 2 ticks into the grab).
`godot --headless --path . -s res://tools/qa/defense_matrix.gd -- --out DIR`


### attacker kael (defender kael)

| attack | none | hold_block | perfect_block | sidestep_dash | back_dash | jump_ascend | vanish_neutral | vanish_side | rising_reversal | jab_mash | grab_tech |
|---|---|---|---|---|---|---|---|---|---|---|---|
| light_1 | HIT (-5) | PERFECT (+37) | PERFECT (+37) | HIT (-5) | EVADED (+6) | HIT (-5) | EVADED (+2) | EVADED (+2) | TRADE_WON (+9) | HIT (+0) | HIT (-5) |
| smash | HIT (-15) | BLOCKED (+8) | PERFECT (+51) | HIT (-15) | EVADED (+20) | HIT (-15) | EVADED (+16) | EVADED (+16) | TRADE_WON (+9) | HIT (-24) | HIT (-15) |
| breaker | HIT (-1) | BLOCKED (+4) | PERFECT (+49) | HIT (-1) | EVADED (+18) | HIT (-1) | EVADED (+14) | EVADED (+14) | TRADE_WON (+9) | HIT (-8) | HIT (-1) |
| sweep | HIT (-8) | BLOCKED (+6) | PERFECT (+48) | HIT (-8) | EVADED (+17) | EVADED (+22) | EVADED (+13) | EVADED (+13) | HIT (-8) | HIT (-14) | HIT (-8) |
| launcher | HIT (-14) | BLOCKED (+10) | PERFECT (+52) | HIT (-14) | EVADED (+21) | HIT (-14) | EVADED (+17) | EVADED (+17) | HIT (-14) | HIT (-24) | HIT (-14) |
| charged_smash_3 | HIT (-20) | BLOCKED (+10) | PERFECT (+58) | HIT (-20) | EVADED (+27) | HIT (-20) | EVADED (+23) | EVADED (+23) | HIT (-24) | HIT (-20) | HIT (-20) |
| grab | GRABBED (-44) | GRABBED (-44) | GRABBED (-44) | GRABBED (-44) | EVADED (+21) | GRABBED (-44) | EVADED (+17) | EVADED (+17) | GRABBED (-44) | TRADE_WON (+5) | TECHED (+1) |
| blade_light | HIT (-4) | BLOCKED (+3) | PERFECT (+39) | HIT (-4) | EVADED (+8) | HIT (-4) | EVADED (+4) | EVADED (+4) | TRADE_WON (+9) | HIT (-1) | HIT (-4) |
| hammer_heavy | HIT (-10) | BLOCKED (+12) | PERFECT (+62) | HIT (-10) | EVADED (+31) | HIT (-10) | EVADED (+27) | EVADED (+27) | HIT (-10) | HIT (-30) | HIT (-10) |
| revolver_shot | HIT (-20) | BLOCKED (-4) | REFLECTED (+33) | EVADED (+3) | HIT (-23) | HIT (-20) | EVADED (-1) | EVADED (-1) | EVADED (-23) | HIT (-20) | HIT (-20) |
| bow_shot | HIT (-27) | BLOCKED (-10) | REFLECTED (+42) | EVADED (+2) | HIT (+2) | EVADED (+7) | EVADED (-2) | EVADED (-2) | HIT (-31) | HIT (-30) | HIT (-27) |
| repeater_shot | HIT (-12) | REFLECTED (-1) | REFLECTED (-1) | EVADED (-6) | EVADED (-6) | HIT (-12) | EVADED (-10) | EVADED (-10) | EVADED (-32) | HIT (-15) | HIT (-12) |

### attacker vexa (defender kael)

| attack | none | hold_block | perfect_block | sidestep_dash | back_dash | jump_ascend | vanish_neutral | vanish_side | rising_reversal | jab_mash | grab_tech |
|---|---|---|---|---|---|---|---|---|---|---|---|
| light_1 | HIT (-4) | PERFECT (+36) | PERFECT (+36) | HIT (-4) | EVADED (+5) | HIT (-4) | EVADED (+1) | EVADED (+1) | TRADE_WON (+9) | HIT (-4) | HIT (-4) |
| smash | HIT (-15) | BLOCKED (+6) | PERFECT (+47) | HIT (-15) | EVADED (+16) | HIT (-15) | EVADED (+12) | EVADED (+12) | TRADE_WON (+9) | HIT (-20) | HIT (-15) |
| breaker | HIT (-2) | BLOCKED (+3) | PERFECT (+46) | HIT (-2) | EVADED (+15) | HIT (-2) | EVADED (+11) | EVADED (+11) | TRADE_WON (+9) | HIT (-6) | HIT (-2) |
| sweep | HIT (-8) | BLOCKED (+5) | PERFECT (+46) | HIT (-8) | EVADED (+15) | EVADED (+20) | EVADED (+11) | EVADED (+11) | HIT (-8) | HIT (-12) | HIT (-8) |
| launcher | HIT (-14) | BLOCKED (+10) | PERFECT (+50) | HIT (-14) | EVADED (+19) | HIT (-14) | EVADED (+15) | EVADED (+15) | HIT (-14) | HIT (-22) | HIT (-14) |
| charged_smash_3 | HIT (-17) | BLOCKED (+11) | PERFECT (+57) | HIT (-17) | EVADED (+26) | HIT (-17) | EVADED (+22) | EVADED (+22) | HIT (-12) | HIT (-17) | HIT (-17) |
| grab | GRABBED (-42) | GRABBED (-42) | GRABBED (-42) | GRABBED (-42) | EVADED (+20) | GRABBED (-42) | EVADED (+16) | EVADED (+16) | GRABBED (-42) | TRADE_WON (+5) | TECHED (+1) |
| blade_light | HIT (-4) | BLOCKED (+3) | PERFECT (+39) | HIT (-4) | EVADED (+8) | HIT (-4) | EVADED (+4) | EVADED (+4) | TRADE_WON (+9) | HIT (-1) | HIT (-4) |
| hammer_heavy | HIT (-10) | BLOCKED (+12) | PERFECT (+62) | HIT (-10) | EVADED (+31) | HIT (-10) | EVADED (+27) | EVADED (+27) | HIT (-10) | HIT (-30) | HIT (-10) |
| revolver_shot | HIT (-20) | BLOCKED (-4) | REFLECTED (+33) | EVADED (+3) | HIT (-23) | HIT (-20) | EVADED (-1) | EVADED (-1) | EVADED (-23) | HIT (-20) | HIT (-20) |
| bow_shot | HIT (-27) | BLOCKED (-10) | REFLECTED (+42) | EVADED (+2) | HIT (+2) | EVADED (+7) | EVADED (-2) | EVADED (-2) | HIT (-31) | HIT (-30) | HIT (-27) |
| repeater_shot | HIT (-12) | REFLECTED (-1) | REFLECTED (-1) | EVADED (-6) | EVADED (-6) | HIT (-12) | EVADED (-10) | EVADED (-10) | EVADED (-32) | HIT (-15) | HIT (-12) |

### attacker brann (defender kael)

| attack | none | hold_block | perfect_block | sidestep_dash | back_dash | jump_ascend | vanish_neutral | vanish_side | rising_reversal | jab_mash | grab_tech |
|---|---|---|---|---|---|---|---|---|---|---|---|
| light_1 | HIT (-4) | BLOCKED (+4) | PERFECT (+40) | HIT (-4) | EVADED (+9) | HIT (-4) | EVADED (+5) | EVADED (+5) | TRADE_WON (+9) | HIT (-2) | HIT (-4) |
| smash | HIT (-13) | BLOCKED (+11) | PERFECT (+55) | HIT (-13) | EVADED (+24) | HIT (-13) | EVADED (+20) | EVADED (+20) | TRADE_WON (+9) | HIT (-26) | HIT (-13) |
| breaker | HIT (-3) | BLOCKED (+3) | PERFECT (+51) | HIT (-3) | EVADED (+20) | HIT (-3) | EVADED (+16) | EVADED (+16) | TRADE_WON (+9) | HIT (-12) | HIT (-3) |
| sweep | HIT (-5) | BLOCKED (+9) | PERFECT (+53) | HIT (-5) | EVADED (+22) | EVADED (+27) | EVADED (+18) | EVADED (+18) | HIT (-5) | HIT (-16) | HIT (-5) |
| launcher | HIT (-13) | BLOCKED (+12) | PERFECT (+55) | HIT (-13) | EVADED (+24) | HIT (-13) | EVADED (+20) | EVADED (+20) | HIT (-13) | HIT (-26) | HIT (-13) |
| charged_smash_3 | HIT | BLOCKED (+13) | PERFECT (+63) | HIT | EVADED (+32) | HIT | EVADED (+28) | EVADED (+28) | HIT | HIT | HIT |
| grab | GRABBED (-48) | GRABBED (-48) | GRABBED (-48) | GRABBED (-48) | EVADED (+25) | GRABBED (-48) | EVADED (+21) | EVADED (+21) | GRABBED (-48) | TRADE_WON (+5) | TECHED (+1) |
| blade_light | HIT (-4) | BLOCKED (+3) | PERFECT (+39) | HIT (-4) | EVADED (+8) | HIT (-4) | EVADED (+4) | EVADED (+4) | TRADE_WON (+9) | HIT (-1) | HIT (-4) |
| hammer_heavy | HIT (-10) | BLOCKED (+12) | PERFECT (+62) | HIT (-10) | EVADED (+31) | HIT (-10) | EVADED (+27) | EVADED (+27) | HIT (-10) | HIT (-30) | HIT (-10) |
| revolver_shot | HIT (-20) | BLOCKED (-4) | REFLECTED (+33) | EVADED (+3) | HIT (-23) | HIT (-20) | EVADED (-1) | EVADED (-1) | EVADED (-23) | HIT (-20) | HIT (-20) |
| bow_shot | HIT (-27) | BLOCKED (-10) | REFLECTED (+41) | EVADED (+2) | HIT (+2) | EVADED (+7) | EVADED (-2) | EVADED (-2) | HIT (-31) | HIT (-30) | HIT (-27) |
| repeater_shot | HIT (-12) | REFLECTED (-1) | REFLECTED (-1) | EVADED (-6) | EVADED (-6) | HIT (-12) | EVADED (-10) | EVADED (-10) | EVADED (-32) | HIT (-15) | HIT (-12) |

### attacker lyra (defender kael)

| attack | none | hold_block | perfect_block | sidestep_dash | back_dash | jump_ascend | vanish_neutral | vanish_side | rising_reversal | jab_mash | grab_tech |
|---|---|---|---|---|---|---|---|---|---|---|---|
| light_1 | HIT (-3) | PERFECT (+38) | PERFECT (+38) | HIT (-3) | EVADED (+7) | HIT (-3) | EVADED (+3) | EVADED (+3) | TRADE_WON (+9) | HIT (+1) | HIT (-3) |
| smash | HIT (-9) | BLOCKED (+10) | PERFECT (+51) | HIT (-9) | HIT (-9) | HIT (-9) | EVADED (+16) | EVADED (+16) | TRADE_WON (+9) | HIT (-18) | HIT (-9) |
| breaker | HIT (+1) | BLOCKED (+6) | PERFECT (+49) | HIT (+1) | EVADED (+18) | HIT (+1) | EVADED (+14) | EVADED (+14) | TRADE_WON (+9) | HIT (-6) | HIT (+1) |
| sweep | HIT (+5) | BLOCKED (+25) | PERFECT (+65) | HIT (+5) | EVADED (+34) | EVADED (+39) | HIT (-5) | HIT (-5) | HIT (+5) | HIT (-18) | HIT (+5) |
| launcher | HIT (-13) | BLOCKED (+11) | PERFECT (+51) | EVADED (+20) | EVADED (+20) | HIT (-14) | EVADED (+16) | EVADED (+16) | HIT (-13) | HIT (-13) | HIT (-13) |
| charged_smash_3 | HIT (-7) | BLOCKED (+21) | PERFECT | HIT (-7) | HIT (-7) | HIT (-7) | EVADED (+32) | EVADED (+32) | HIT (-11) | HIT (-32) | HIT (-7) |
| grab | GRABBED (-42) | GRABBED (-42) | GRABBED (-42) | GRABBED (-42) | EVADED (+22) | GRABBED (-42) | EVADED (+18) | EVADED (+18) | GRABBED (-42) | TRADE_WON (+5) | TECHED (+1) |
| blade_light | HIT (-4) | BLOCKED (+3) | PERFECT (+39) | HIT (-4) | EVADED (+8) | HIT (-4) | EVADED (+4) | EVADED (+4) | TRADE_WON (+9) | HIT (-1) | HIT (-4) |
| hammer_heavy | HIT (-10) | BLOCKED (+12) | PERFECT (+62) | HIT (-10) | EVADED (+31) | HIT (-10) | EVADED (+27) | EVADED (+27) | HIT (-10) | HIT (-30) | HIT (-10) |
| revolver_shot | HIT (-20) | BLOCKED (-4) | REFLECTED (+33) | EVADED (+3) | HIT (-23) | HIT (-20) | EVADED (-1) | EVADED (-1) | EVADED (-23) | HIT (-20) | HIT (-20) |
| bow_shot | HIT (-27) | BLOCKED (-10) | REFLECTED (+42) | EVADED (+2) | HIT (+2) | EVADED (+7) | EVADED (-2) | EVADED (-2) | HIT (-31) | HIT (-30) | HIT (-27) |
| repeater_shot | HIT (-12) | REFLECTED (-1) | REFLECTED (-1) | EVADED (-6) | EVADED (-6) | HIT (-12) | EVADED (-10) | EVADED (-10) | EVADED (-32) | HIT (-15) | HIT (-12) |
