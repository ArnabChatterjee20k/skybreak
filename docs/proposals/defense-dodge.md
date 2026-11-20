# Proposal: defense and dodge redesign (T-DEF1)

Owner question: *"What are the ways to dodge an attack? Check a lot of it. We can make it better."*
Status: **proposal, needs owner approval before any code.** Audit at `082e584` (main, 2026-11-20).
Raw data: `reports/defense/ai_matches.md`, `reports/defense/matrix.md`; scripts `tools/qa/defense_audit.gd`,
`tools/qa/defense_matrix.gd`, `tools/qa/defense_summary.py` (commands in each file header).

## 1. Current state

### 1.1 What really exists (audit of `game/combat/**`, `game/ai/**`)

Frames are 60 Hz ticks, baseline Kael. "Invuln" = hits pass through.

| Option | In code? (file: function) | Input | Frames (start / protected / recovery) | Invuln / hurtbox | Cost | Beats | Loses to | AI uses? | VFX / SFX |
|---|---|---|---|---|---|---|---|---|---|
| Block | yes, `combat_sim.gd: _start_block, _blocks` | hold E | 0 / while held / 0 | none, front 180° only | guard | strikes, shots | grab, cross-up, guard break | yes (most-used) | yes / yes |
| Perfect block | yes, `_track_block_press, _perfect_blocks, _apply_perfect_block` | press E ≤6 f before contact | window 6, lockout 20 on miss | none | 0 (+15 burst) | strikes (attacker +16 rec.), shots (reflected) | grab, frame traps | yes, rolled per attack, capped streak on L≤2 | flash + tink / yes; **no 0.8× time-slow** (§5.10) |
| Push-block | yes, `_can_push_block, _begin_push_block` | heavy while blocking (from blockstun f4) | move data | none | 10 guard | pressure strings | — | yes (0.85/min) | yes / yes |
| Grab tech | yes, `_finish_timed_action` → `_tech_grab` | F ≤10 f after grabbed | 10 push | n/a | 0 | grabs | late press | yes, `_tech`, 64% of grabs teched | yes / yes |
| Vanish step | yes, `_start_buffered_action` → `_start_vanish` | Shift+E | 0 / **12 f intangible** (`can_be_hit`) / 0 | full (state `VANISHING`) | 20 ki | **everything** incl. grabs, shots | nothing in practice | yes, almost only as a combo cancel or neutral move | hide + whoosh / yes; no afterimage |
| Rising heavy | yes, move data `invincible_*` | Space + RMB | Kael inv f3–8, startup 9 | **upper body only** | 0 | lights, smash, breaker (trade won +9) | sweep, launcher, grab | no defensive use | as a heavy |
| Lyra launcher | yes, move data | S + RMB | inv f0–7 | full | 0 | strikes in reach | — | incidental | — |
| Dash step | yes, `_start_dash` | Shift + dir | 10 f, 8 m | **none** (absorbs repeater bullets only) | 8 ki | evades by distance only | anything that reaches | rush 2.2/min, step 0.4/min | trail / whoosh |
| Knockdown | yes, `_bounce_or_knock_down` | — | 40 f lying | full (`can_be_hit` false) | — | everything | — | n/a | yes |
| **Sidestep** | **no** (dash A/D is orbit-capped, see 1.3) | — | — | — | — | — | — | — | — |
| **Vanish counter from hitstun / counter-vanish / 2-exchange Clash** | **no** (vanish only from free, dash, block or cancel; no exchange count) | — | — | — | — | — | — | — | — |
| **Sense** | partly: an E tap while an opponent is vanished skips the perfect-block window; there is no turn-and-block move | — | — | — | — | — | — | — | — |
| **Combo breaker** | **no** (`BREAKER` is bound to X but the sim never reads it) | — | — | — | — | — | — | — | — |
| **Air tech / chase** | **no** | — | — | — | — | — | — | — | — |
| **Tech roll / wakeup options** | **no** (fixed 40 f invulnerable knockdown) | — | — | — | — | — | — | — | — |
| **Ki blast, charged blast, beam, beam clash** | **no** (weapons are the only projectiles) | — | — | — | — | — | — | — | — |

So the brief's guess is half right: **there is invulnerability in the sim** (move-data i-frames on Rising/Lyra
launcher, and intangible states `VANISHING` and `KNOCKDOWN`), but **there is no dodge**: no movement option with
i-frames, no sidestep, no tech roll. The only universal evade is the 20-ki vanish.

### 1.2 Measured: AI matches (QA quick matrix, 21 matches, 64.9 fighter-minutes)

| Per fighter-minute | Value | | Share of threatening melee strikes¹ (n = 2,300) | Value |
|---|---:|---|---|---:|
| Melee strikes thrown | 44.6 | | **Eaten** (hit, counter, armor) | **77.5%** |
| Guard raised | 40.4 | | Blocked | 8.9% |
| Blocks / perfect blocks | 4.0 / 0.72 | | Perfect-blocked | 2.0% |
| Grab techs (of 55 grabs) | 0.54 (64%) | | **Dodged** (vanish 2, dash 4) | **0.3%** |
| Vanishes: combo cancel / neutral / from guard | 1.80 / 1.60 / **0** | | Missed close (spacing) | 11.3% |
| Vanishes started while a strike was coming | 0.08 | | Projectile contacts: hit / blocked / reflected | 81% / 9.5% / 9.5% |

¹ Strikes whose active frames had an opponent within 4 m; 597 more whiffed with nobody near.

The AI defends almost only by blocking, and blocks little of what reaches it. It never dodges, never vanishes out of
guard, and a hit is 9× more likely than a block.

### 1.3 Measured: scripted 'player' matrix (`reports/defense/matrix.md`)

Every option at an ideal read against every legend's attacks (12 attacks × 11 options × 4 legends). Summary:

| Option | Beats | Loses to | Notes |
|---|---|---|---|
| Hold block / perfect block | all strikes and shots; perfect gives +36…+63 | grab (all legends) | an early hold press inside 6 f perfect-blocks lights for free |
| **Sidestep (dash A/D)** | revolver/bow/repeater shots only | **every melee attack, all legends** | the T-D29 orbit cap (180°/s) turns a 48 m/s dash into ~0.4 m of sideways travel at 1.8 m |
| Back dash | almost all melee and every grab (+5…+34) | revolver shot; Lyra's smash and charged smash (reach) | evades by distance only |
| Vanish (any direction) | **all 12 attacks** (−10…+32) | Lyra sweep when vanishing sideways | sideways vanish also orbit-capped: it stays in place and relies on 12 f intangibility |
| Rising heavy | lights, smash, breaker, weapon light | sweep, launcher, grab, heavies | the only reversal |
| Jab | grab (+5) | everything else | strike > grab works |
| Jump | sweep, bow | the rest | |

Gaps found: (1) no real dodge; sidestep is broken by the orbit cap; (2) vanish is strictly best (beats everything,
plus frames) so it would make any new dodge redundant unless re-scoped; (3) no defensive option in hitstun at all
(no vanish counter, no breaker, no air tech); (4) no anti-mash or reward for reads beyond perfect block;
(5) AI never dodges or punishes a dodge; (6) feedback is missing for evasion (no afterimage, no perfect-dodge cue).

## 2. What the reference games teach (from knowledge; frame numbers are community data, verify before tuning)

| Game | Mechanic | Numbers (60 fps, approximate) | Why it feels good | Translates? |
|---|---|---|---|---|
| Brawlhalla | spot dodge, directional dodge, chain dodge, gravity cancel | dodge ≈ 10–20 f invulnerable then a short vulnerable tail; one air dodge until you land or are hit; dodge cooldown ≈ 1–3 s, longer after a chained dodge | free (no meter) but a **cooldown** is the cost, so a dodge is a read you get to make once; recovery is punishable; gravity cancel lets a spot dodge in the air turn into a ground attack (expressive) | **yes, core.** Cooldown and refresh rules map directly to flight |
| Smash Ultimate | spot dodge, roll, air dodge | spot dodge intangible ≈ f3–17, total ≈ 27 f; roll ≈ f4–15 of ≈ 31; neutral air dodge ≈ f3–29 with heavy landing lag; repeated dodges get **staler (more recovery)** | short startup, long readable recovery; staleness kills mashing | yes: staleness = our chain rule |
| Tekken / Virtua Fighter | sidestep / evade | 1-ish f startup, evades *linear* moves only; *homing/tracking* moves catch it; VF evade-throw | sidestep is a spacing read, not a panic button; tracking moves keep it honest | yes: Sweep becomes the tracking move |
| DBZ Sparking! Zero / BT3 | Z-vanish, Super Perception, Revenge Counter, afterimage, step-in/out, dragon dash | vanish costs ki and is **count-limited per combo**; Perception is a timed guard that deflects and repositions; Revenge Counter costs skill points | the spectacle of teleport duels, kept in check by **resources and limits** | yes: vanish = costly ki answer from guard/hitstun, capped per exchange (already §5.5) |
| Granblue Fantasy Versus | dodge (invincible evade) | strike-invincible, **throw-vulnerable** recovery, punishable on whiff | simple rules, one button, clear RPS | yes: dodge recovery is grab-bait |

Common rule: **the dodge is cheap to press but expensive to whiff**, via cooldown, staleness and a punishable tail.
Flight-heavy 3D needs dodges in every direction including up/down, and everything must be integer ticks for rollback.

## 3. Redesign

### Must (one lane each, in order)

**M1. Dodge (replaces the dash step).** Tap `Shift` = dodge; holding `Shift` past the dodge still becomes the
sustained flight-dash, and `Shift` toward the locked target is still the rush dash (no i-frames). No new key, no
browser conflict (no Alt/Ctrl combos), unaffected by descend leaving Left Ctrl (T-UX1).

| Kind | Input | Startup | Invuln | Recovery (vulnerable) | Total | Travel | Cost |
|---|---|---:|---:|---:|---:|---|---|
| Directional (ground or air) | tap Shift + WASD (+Space/descend in the air) | 2 | f3–14 (12) | 12 | 26 | 4.5 m, ease-out | 0 ki |
| Spot (no direction) | tap Shift | 1 | f2–17 (16) | 14 | 31 | none | 0 ki |
| Sidestep (locked, A/D) | tap Shift + A/D | 2 | f3–14 | 12 | 26 | 70° arc around the target (min 3 m), **exempt from the orbit cap** | 0 ki |

- I-frames beat strikes, grabs and projectiles. Sweep (and future beams' sweep variant) gets `tracks_sidestep`:
  a sidestep's i-frames don't apply to it. That is the Tekken rule and the doc's "Sweep hits sidesteppers".
- **Cooldown and chains (anti-mash):** after a dodge ends, a new dodge within 45 f is a *chain*: allowed once,
  with recovery +8 f and i-frames −4 f. A third dodge within the chain window gets **no i-frames** (plain dash) until
  a 90 f cooldown passes. In the air: **2 dodges per airborne spell**, refreshed on landing, on being hit, or
  after 120 f with no dodge.
- Startable only from free states (idle, moving, flying, falling) and dash. **Not from blockstun or hitstun.**
  That job belongs to vanish (M3), so the two never overlap.

**M2. Perfect dodge (rewards reads, not mashing).** A dodge whose i-frames **f3–8** (spot: f2–7) actually overlap
an opponent's active hitbox or a projectile is a *perfect dodge*:
- dodger: recovery −6 f, +10 ki (once per 180 f), its chain/cooldown counter resets;
- attacker: 6 f sim freeze (hitstop on the attacker only);
- view: afterimage left at the dodge start, white-blue rim flash, "READ" pop, a whoosh with a reverse tail;
  local offline only, a view-side 0.85× slow for 8 frames (the sim never changes speed).

A dodge with no live threat in that window gets nothing and keeps its full recovery. So mashing is strictly
worse than blocking (see the tests in §5).

**M3. Re-scope vanish so dodge doesn't make it redundant, and fix its relocation.**
- Vanish keeps 12 f intangibility, but from neutral it costs **30 ki** (was 20). It's the long-range,
  repositioning, combo-extending tool, not a free panic button.
- **Vanish counter** (doc §5.5, missing today): Shift+E from blocking, blockstun, or the **first 6 f of hitstun**,
  25 ki (40 for the second in one exchange). It lands behind/above/below the attacker by the held direction.
  This is the only escape from pressure, and it costs ki.
- Exchange counter, counter-vanish (40 ki, right guess only), Sense (E within 12 f of the opponent vanishing
  turns and blocks), Clash after 2 exchanges: as already written in §5.5.
- Fix: vanish placement is exempt from the orbit cap (today a locked sideways vanish moves ~0.1 m).

**M4. AI uses defence.** Per level (1→5):

| Rule | L1 | L2 | L3 | L4 | L5 |
|---|---:|---:|---:|---:|---:|
| Dodge a *seen* attack with startup ≥ 12 f, or a projectile | 0 | 5% | 15% | 25% | 35% |
| Of those, aim for a perfect dodge (press at active − 4) | 0 | 0 | 30% | 50% | 70% |
| Punish a seen whiffed dodge (recovery) | 0 | 10% | 30% | 50% | 70% |
| Vanish counter from guard when pressured and ki ≥ 40 | 0 | 0 | 10% | 20% | 30% |

Never dodge a light on reaction (6 f startup can't be reacted to), only on a read (`mixup` weight); always respect
the cooldown; Normal (L≤2) at most 2 perfect dodges in a row (same fun limiter as perfect blocks).
`game/ai/**` is not in the desktop lane table, so M4 needs developer's OK or a lane grant.

### Should

| # | Item | Numbers |
|---|---|---|
| S1 | **Combo breaker** (X in hitstun, 1 burst stock): pushes the attacker to mid range, 20 f intangible | already bound; sim ignores it today |
| S2 | **Air tech** after knockback: Shift + direction in flight frames 12–24 = recover with 8 f invuln; chase rules per §5.6 | |
| S3 | Perfect-block polish: an early *held* press no longer perfect-blocks (needs a fresh press within 6 f); add the §5.10 0.8× view slow | matrix shows a held E perfect-blocks lights |
| S4 | Dodge feedback in `CharacterView` (dodge lean/roll clips per legend) and `AudioDirector` (dodge, perfect-dodge cues) | characters / audio lanes |
| S5 | Grab punishes dodge tail: recovery frames are throw-vulnerable *and* count as counter-hit for grabs (+4 hitstop) | GBVS rule, keeps RPS |

### Could

| # | Item |
|---|---|
| C1 | Tech roll on knockdown (WASD + Space within 10 f, 6 f invuln) and delayed wakeup (§5.7); replace the flat 40 f invulnerable knockdown |
| C2 | Gravity-cancel analogue: an attack during a spot dodge's last 4 invuln frames cancels into a grounded/air light (high skill) |
| C3 | Ki blasts, charged blasts and beams (§5.8) with sidestep and dodge as their counters; beam clash |
| C4 | Training mode: dodge timeline in the frame meter, perfect-dodge drill in the tutorial |

## 4. Determinism and rollback

- New `FighterState` ints: `dodge_kind`, `dodge_chain`, `dodge_cooldown_ticks`, `air_dodges_left`,
  `perfect_dodge_reward_ticks`, `vanish_exchange`. All in `state_values()` (hashed) and `SimSnapshot`.
- Invulnerability is **derived**, not stored: `is_invincible_to()` extends to `DASHING` with `dodge_kind != NONE`
  by `state_ticks` against tuning windows. No floats, no timers outside the tick count.
- Perfect-dodge detection runs in `_find_contact` / `_projectile_contact` where i-frames already skip hits, so it
  is order-independent within a tick (it reads the pre-tick snapshot like contacts do).
- All numbers live in a new `DodgeTuning` resource (desktop) beside `MovementTuning`.
- Golden replays change (AI behaviour): re-bless with `tools/qa/bless_goldens.sh --replays` in M1/M4 with a PR line.

## 5. Proof it feels good (tests and QA metrics)

| Proof | Where | Pass |
|---|---|---|
| Exact i-frame windows, chain/cooldown, air refresh, no dodge from stun | `tests/combat/test_dodge.gd` | frame-exact |
| Perfect dodge only with a live hitbox/projectile in f3–8; no ki when mashing | `tests/combat/test_dodge.gd` | |
| Sweep tracks sidestep; grab punishes dodge tail; vanish counter only from guard/hitstun ≤6 f | `tests/qa/scenarios/test_defense.gd` | |
| Defense matrix: every attack has ≥ 2 answers; **no option beats all 12 attacks** (vanish does today) | `tools/qa/defense_matrix.gd` → GUT scenario | |
| Mash bot (dodge every 30 f) takes **more** damage than a block bot over 3,600 ticks vs L4 AI | scenario | mash ≥ 1.3× block damage |
| AI matches, per fighter-minute: strikes eaten **77% → 55–65%**, dodged **0.3% → 8–15%**, blocked ≥ 15% | `tools/qa/defense_audit.gd` in `run_qa.sh` metrics | |
| Dodge success (evaded a live threat) ≥ 60% of AI dodges at L5; whiffed-dodge punish ≥ 12 f average advantage | same | |
| Vanish share of defensive escapes ≤ 40% (not redundant, not dominant) | same | |

## 6. Lanes and size

| Lane | Scope | Owner | Size |
|---|---|---|---|
| T-DEF2 | M1 + M2 sim: dodge, sidestep, cooldown/chain, perfect dodge, `DodgeTuning`, tests | desktop (combat) | M (2–3 days) |
| T-DEF3 | M3 vanish counter, exchange count, counter-vanish, Sense, Clash, orbit-cap fix | desktop (combat) | M |
| T-DEF4 | M4 AI dodge, perfect dodge, dodge punish, vanish counter | developer OK needed (`game/ai`) | S–M |
| T-DEF5 | M2/S4 feedback: afterimage shader, flash, "READ" pop, audio cues | desktop (shaders, audio, characters) | S |
| T-DEF6 | QA: fold `defense_audit` metrics into `run_qa.sh` and the matrix into a GUT scenario | desktop (tests/qa) + developer (`tools/`) | S |
| T-DEF7 | S1 combo breaker, S2 air tech, S3 perfect-block fix, S5 | desktop | M |

Recommended order: DEF2 → DEF3 → DEF6 → DEF4 → DEF5 → DEF7. Must items (DEF2–DEF6) are about 1.5 weeks of
agent lanes.
