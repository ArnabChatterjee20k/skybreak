# T-SP1 golden drift (main's goldens replayed on this branch, before the re-bless)

`godot --headless --path . -s res://tools/qa/specials_drift.gd`. Recorded inputs never press 1/2/3, so the only sim change they meet is Kael's Momentum. Every first drift is Kael's second consecutive landed hit, the first one +2% applies to (the stack itself is hashed in `state_hash`, outside the digest rows). Goldens without a Kael that lands two in a row do not drift.

| golden | first drift (tick) | events on that tick | special state then |
|---|---|---|---|
| duel_kael_mirror | 86 | HIT(f1 light_2) | f0 kael momentum 0 decoy 0 used 0; f1 kael momentum 2 decoy 0 used 0 |
| duel_vexa_vs_lyra | none | | |
| duel_brann_vs_kael | 50 | HIT(f1 light_2) | f1 kael momentum 2 decoy 0 used 0 |
| duel_lyra_vs_brann_airborne | none | | |
| duel_low_level_mirror | none | | |
| combos_level5 | 301 | HIT(f0 light_2) | f0 kael momentum 2 decoy 0 used 0 |
| ffa4_all_legends | 243 | HIT(f0 light_2) | f0 kael momentum 2 decoy 0 used 0; f1 vexa momentum 0 decoy 0 used 0 |
| teams_2v2 | none | | |
| ko_and_second_round | none | | |
| pickups_heartbloom | none | | |

After the re-bless the goldens are recorded fresh from the AIs, which now use specials: `duel_kael_mirror` (7 SPECIAL_START), `duel_vexa_vs_lyra` (3, with 3 SPECIAL_BLINK), `duel_brann_vs_kael` (3), `combos_level5` (2), `ffa4_all_legends` (4), `teams_2v2` (4).
