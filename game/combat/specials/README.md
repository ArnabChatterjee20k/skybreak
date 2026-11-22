# Specials (T-SP1)

Legend specials on keys `1` `2` `3`, Kael's **Momentum** and Vexa's **Afterimage**,
plus the hooks the ultimate and transformation lane fills in. Design and move
lists: `docs/GAME_DESIGN.md` §6.1.

## Files

| File | What |
|---|---|
| `special_move.gd` | `SpecialMove` (Resource): key, `MoveData` per direction variant, `Effect` (STRIKE, RUSH, COUNTER, LEAP, BLINK, DECOY_STEP), travel/blink/counter numbers, tell cue and colour, AI hooks |
| `special_kit.gd` | `SpecialKit` (Resource): the 3 specials, the legend `Mechanic`, decoy numbers, `ultimate` + burst costs |
| `fighter_specials.gd` | `FighterSpecials`: per-fighter sim state (`FighterState.specials`), in `state_values()` |
| `special_rules.gd` | `SpecialRules`: every rule, as static functions over `CombatSim` |
| `kits/*.tres` | The data. Regenerate with `make_special_kits.gd` (numbers live there) |

A legend gets specials by setting `FighterStats.special_kit`
(`moves/kael/kael_fighter_stats.tres`, `vexa_fighter_stats.tres`). Legends without
a kit (Brann, Lyra for now) are untouched.

## Sim hooks (`combat_sim.gd`)

| Where | Call | Why |
|---|---|---|
| `_step_fighter`, after `_start_attack` | `SpecialRules.start(sim, i, input, wish)` | Buffered `1/2/3/4` → special. Runs before any other reader of those keys |
| `_step_fighter`, ATTACKING movement | `SpecialRules.move(sim, i)` | Travel, leap arc, blink, multi-hit re-arm |
| `_find_contact` | `SpecialRules.catches()` / `caught_contact()` | Counter stance |
| `_resolve_hits` | `SpecialRules.apply_counter()` | The riposte |
| `_apply_hit` | `boosted_damage()`, `on_hit_landed()` | Momentum |
| `apply_damage` | `on_damaged()` | Momentum is lost when hit |
| `tick`, after projectiles | `SpecialRules.step(sim)` | Decoy countdown, strike detection, burst |
| `_reset_fighter`, `_canonicalize_zeros` | `reset_fighter()`, `canonicalize()` | New round; -0.0 |

## Rules

- **Start:** from IDLE/MOVING/FLYING, or as a SPECIAL cancel (`can_cancel_into`).
  Ki is `move.ki_cost`. A key the kit owns is **always consumed** once the fighter
  could act, also when the ki is missing (`SPECIAL_DENIED`), so the T-KI1 beam on
  `1` never fires for a legend with a kit. Merge order with T-KI1: keep
  `SpecialRules.start` before `KiRules.start` in `_step_fighter`.
- **Variants:** `Space` + key = `rise_move`, `C` + key = `dive_move` (falls back to `move`).
- **Cancels:** special moves have `cancel_level = SPECIAL`, `cancel_on_block = false`;
  so on hit they cancel only into Vanish-step or an Ultimate.
- **Events:** `SPECIAL_START` (slot, move_id, variant, cue), `SPECIAL_DENIED`,
  `SPECIAL_COUNTER`, `SPECIAL_BLINK`, `DECOY_SPAWN`, `DECOY_BURST`, `DECOY_FADE`.
  Audio (`CombatAudioMapper.SPECIAL_CUES` + `tell_cue`), VFX (`SpecialVfx`,
  `CombatFeedback`) and the HUD (`MatchHud._draw_mechanic`) read them or the state.
- **Determinism:** all state is ints or canonicalised floats in `FighterSpecials`;
  `state_values()` stays empty until something changes, so older hashes hold.
  Snapshots copy it by reflection. DetMath only.

## AI

Each `SpecialMove` names an `ai_role` (APPROACH, ANTI_GUARD, COUNTER, EVADE,
ENDER, MIXUP), a range band and the lowest AI level that uses it.
`SpecialRules.ai_pick()` returns a usable key; `game/ai/ai_specials.gd` decides
how often per level (never at level 1) and `FighterAI` presses it.

## Next lane: ultimate and transform

- `SpecialKit.ultimate` (a `SpecialMove`) + `ultimate_burst_stocks` (2): already
  wired in `start()`; while it is null, key `4` is left to the ki beam ultimate.
- `SpecialKit.transform_burst_stocks` (1), `transform_ki_drain_per_second` and the
  `FighterSpecials.transform_ticks` slot are reserved; `T` is not read yet.
