| Action | kael | vexa |
| move (W) | OK | OK |
| ascend (Space) | OK | OK |
| descend (Left Ctrl) | OK | OK |
| light (LMB) | OK | OK |
| smash (RMB) | OK | OK |
| breaker (W+RMB) | OK | OK |
| launcher (S+RMB) | OK | OK |
| rising (Space+RMB) | OK | OK |
| spike (Ctrl+RMB) | OK | OK |
| sweep (A+RMB) | OK | OK |
| hold heavy (RMB) | OK | OK |
| block (E) | OK | OK |
| perfect block (tap E) | OK | OK |
| dash (Shift+D) | OK | OK |
| rush dash (Shift+W, locked) | OK | OK |
| grab (F) | OK | OK |
| pick up (G) | OK | OK |
| throw (G/V armed) | OK | OK |
| cycle weapons (B/Z) | OK | OK |
| quick swap (Y) | OK | OK |
| mouse wheel (target switch) | OK | OK |
| ki blast tap (Q) | OK | OK |
| ki blast hold (Q) | OK | OK |
| charge ki (R) | OK | OK |
| special 1 (1) | OK | OK |
| special 2 (2) | OK | OK |
| special 3 (3) | OK | OK |
| ultimate (4) | OK | OK |
| transform (T) | NOT IMPLEMENTED: bit reaches FighterInput (true), the sim never reads it | NOT IMPLEMENTED: bit reaches FighterInput (true), the sim never reads it |
| vanish (Shift+E) | OK | OK |
| combo breaker (X) | NOT IMPLEMENTED: pressed in hitstun (true), bit reaches FighterInput (true), the sim never reads it | NOT IMPLEMENTED: pressed in hitstun (true), bit reaches FighterInput (true), the sim never reads it |
| lock-on toggle (MMB) | OK | OK |
| lock-on toggle (Tab) | OK | OK |

Per-legend detail (clips the player's character played, cues asked of the AudioDirector):

```
== kael (zone shattered_mesa, player 0, character kael)
  special 1 (1)              OK | clips [&"charged_smash_2"] | cues [&"rush_whoosh", &"whoosh_heavy", &"hit_heavy"]
  special 2 (2)              OK | clips [&"push_block"] | cues [&"perfect_block", &"whoosh_light"]
  special 3 (3)              OK | clips [&"spike"] | cues [&"power_up_burst", &"whoosh_heavy", &"hit_heavy"]
  ultimate (4)               OK | clips [&"push_block"] | cues [&"whoosh_heavy", &"beam_charge_loop", &"beam_fire", &"beam_loop", &"hit_heavy"]
== vexa (zone shattered_mesa, player 0, character vexa)
  special 1 (1)              OK | clips [&"breaker"] | cues [&"vanish_out", &"whoosh_heavy", &"vanish_in", &"hit_medium"]
  special 2 (2)              OK | clips [&"sweep_low", &"hover"] | cues [&"vanish_out", &"dodge", &"whoosh_light"]
  special 3 (3)              OK | clips [&"charged_smash_1"] | cues [&"whoosh_heavy", &"whoosh_light", &"hit_light"]
  ultimate (4)               OK | clips [&"push_block"] | cues [&"whoosh_heavy", &"beam_charge_loop", &"beam_fire", &"beam_loop", &"hit_heavy"]
```
