# Skybreak: Game Design Document

> Working title. Owner: Arnab. Authors: `desktop` (design) with `developer` (build).
> Status: v1, written before milestone 0. Every number here is a **starting point to tune in playtests**, not a law.
> Platform: Windows, keyboard + mouse, GTX 1650-class GPU, 1080p/60.

---

## 1. What makes this game good: the five pillars

Most 3D arena fighters fail in the same ways: button mashing wins, auto-combos play themselves, the camera fights you, ki spam from far away is safe, and every exchange ends in an endless teleport loop. Skybreak is designed against each of these.

| # | Pillar | What it means in practice | Failure it prevents |
|---|---|---|---|
| 1 | **Every action is a commitment** | Every strong option has recovery frames that can be punished. Nothing is free, not even blocking forever (guard meter) or spamming (ki cost). | Mashing and spam winning |
| 2 | **Neutral is a real game** | The space between fighters has three range bands, each with its own tools. Winning the approach matters as much as the combo. | "Whoever presses first wins" |
| 3 | **Reads beat reflexes** | Big defensive tools (vanish, tech, wakeup, beam-clash) are guesses and timing tests against a human opponent, not reflex checks a machine wins. | Endless teleport loops, AI feeling unfair |
| 4 | **Readable at speed** | Every attack has a clear tell (pose, sound, flash color). Hit/block/parry each look and sound different. The camera always shows both fighters. | Chaos you can't learn from |
| 5 | **Spectacle is earned** | Beams, transformations, slow-mo and cinematic ultimates come from winning exchanges, so the big moments feel deserved. | Hollow visual noise |

**Design test for every feature:** *Does it give the player a decision, and does the opponent have an answer?* If not, cut it or rework it.

---

## 2. The core loop

```
            ┌──────────────── NEUTRAL (range game) ─────────────────┐
            │  Far: ki blasts, charge, beams                        │
            │  Mid: dash, rush, strafe, bait                        │
            │  Close: strikes, grabs, block, perfect block          │
            └───────────────┬───────────────────────────────────────┘
                            │ someone lands a hit / guard breaks / parry
                            ▼
                     ┌──────────────┐  defender: vanish counter (costs ki, can be countered)
                     │    COMBO     │  defender: combo breaker (costs burst)
                     └──────┬───────┘
                            │ knockback ender (launcher / spike / wall-splat / blowback)
                            ▼
                     ┌──────────────┐  attacker: chase dash (direction guess)
                     │  CHASE/TECH  │  defender: air tech (direction + timing)
                     └──────┬───────┘
                            │ knockdown or escape
                            ▼
                     ┌──────────────┐  attacker: set up pressure (okizeme)
                     │   WAKEUP     │  defender: tech roll / delayed / neutral wakeup
                     └──────┬───────┘
                            └──────────► back to NEUTRAL (new range, new meters)
```

A round is a sequence of these loops. Meters (ki, guard, burst) carry over between loops, so every exchange changes the next one.

**Match format:** best of 3 rounds, 99-second timer per round (optional ∞). Each round starts with full health, 50 ki and full guard. **Burst carries over** between rounds, so saving meter for the next round is a real choice.

---

## 3. Controls (keyboard + mouse)

All rebindable. Designed so the left hand moves and defends and the right hand attacks and aims.

| Action | Default | Notes |
|---|---|---|
| Move | `W A S D` | Relative to camera. When locked on, W/S = toward/away, A/D = circle-strafe |
| Ascend / Descend | `Space` / `C` | Hold for continuous flight. Tap Space on the ground = jump. **Double-tap `C`** = dive straight down until you land (`Space` cancels). `Left Ctrl` also descends on desktop, never in the web build (Ctrl+W closes the tab) |
| **Light attack** | `Left Mouse` (or `J`) | Strings, hit-confirms. A Mac trackpad's tap counts even when shorter than a tick |
| **Heavy attack** | `Right Mouse` (or `L`) | Direction + heavy = different heavies (see §5.3). Hold = charged smash. Trackpad: two-finger click |
| **Block** | `E` (hold) | **Tap** just before a hit = perfect block (§5.4) |
| **Dodge / dash** | `Left Shift` (+ direction) | Tap = **dodge** (§5.4): with a direction a directional dodge, alone a spot dodge, locked with `A`/`D` a sidestep round the target. Hold = the dodge turns into the sustained flight-dash. Toward the target while locked = rush dash (no i-frames) |
| Grab | `F` (or `U`) | Beats block. Loses to strikes |
| Pick up / throw item | `G` / `V` | Tap `G` near an item to pick it up; with nothing in reach it throws the held weapon at the target. `V` always throws |
| Ki blast | `Q` | Tap = rapid shot. Hold = charged blast |
| Charge ki | `R` (hold) | Fast ki gain, but you're vulnerable |
| Specials 1 / 2 / 3 | `1` (or `I`) `2` `3` | Character-specific, 25–35 ki (§6.1). `Space`/`C` + key = rising/diving variant where a special has one |
| Ultimate | `4` (or `O`) | Costs burst. Cinematic on hit |
| Transform | `T` | Costs burst. Drains ki over time |
| **Vanish** | `Shift + E` | While blocking or in the first frames of hitstun = vanish counter (§5.5) |
| Combo breaker | `X` | While in hitstun. Costs 1 burst stock |
| Lock-on toggle | `Middle Mouse` or `Tab` | |
| Switch target | `Mouse Wheel` | Multi-opponent modes |
| Cycle weapons | `B` / `Z` | Next / previous: Unarmed → slot 1 → slot 2 → slot 3 (wraps) |
| Quick-swap weapon | `Y` | Toggles between the current and the last-used weapon |
| Camera | Mouse movement | Free orbit when unlocked; small offset orbit when locked (§4) |
| Pause / menu | `Esc` | |
| Control hints | `H` | Toggles the on-screen controls strip. Shown by default for the first matches, then remembered |

**Input buffer:** 6 frames for every button (press early, it still comes out). **Shortcuts for execution**, not auto-combos: a 4-hit light string is *4 presses with timing*, not 1 held button.

**Why these keys:** blocking is on `E` (index finger rests there) because defense must be instant; dash is on `Shift` (pinky) because it's held with direction; attacks are on mouse buttons for speed and precision.

---

## 4. Camera: the make-or-break system

The camera is a gameplay system, not a presentation detail. Rules:

1. **Both fighters always on screen** when locked on. The camera sits behind the player, offset over the shoulder (shoulder side chosen by the opponent's screen position, with a smooth switch).
2. **Distance scales with the range band.** At close range the camera pulls slightly sideways (≈25°) so attacks read clearly. At far range it goes directly behind and lower, to show depth for ki and beams.
3. **Mouse offset while locked:** the mouse can orbit up to ±35° yaw / ±20° pitch around the lock axis, and it springs back when released. This gives the player control without losing the target.
4. **Never blocked.** Terrain between the camera and the fighters fades out (dither shader) instead of the camera snapping forward. The camera collides only with large terrain, smoothly.
5. **No camera cuts during player control.** Cuts happen only in ultimates, transformations and round intro/outro, and all of them are skippable with `Esc` or any attack button after their first view.
6. **Smoothing tuned per axis:** position lerp is fast (responsive), rotation slightly slower (no nausea). No camera shake on the player's own light attacks; shake only on received heavy hits and big impacts.
7. **Off-screen indicator:** if lock-on is off and the opponent is off-screen, an edge arrow shows where.

---

## 5. Combat system

### 5.1 Simulation rules
- Fixed **60 ticks/second**, deterministic: the same inputs give the same result. This is what enables replays, training-mode recording, fair AI and, one day, rollback netplay.
- The sim is pure data and logic (no Nodes, no rendering). Presentation reads sim state each tick and plays animations and VFX.
- All moves are data (`MoveData` resources): startup, active and recovery frames, hitbox shape and offset per frame, damage, hitstun, blockstun, hitstop, knockback vector, guard damage, ki cost and gain, burst gain, cancel windows, armor frames and properties.

### 5.2 Meters (all integers in the sim)

**Fixed-point rule:** the sim stores every meter as an integer in **sixtieths** (value × 60). That way every per-second rate in this document is a whole number per tick (ki +2/s = +2 per tick, health regen 150/s = +150 per tick), with no floats and no rounding drift. Displays divide by 60. Costs and maximums in the table are in display units (ki 100 = 6,000 stored).


| Meter | Max | Gains | Spends | Notes |
|---|---|---|---|---|
| **Health** | 10,000 | Recoverable part: 40% of combo damage turns grey and regenerates at 150/s after 3 s without being hit | — | Losing all health loses the round |
| **Ki** | 100 (shown as 4 bars) | +2/s passive, +25/s while charging (`R`), +3 per landed hit, +2 per blocked hit, +10 per perfect dodge (once per 3 s) | Dodge free, rush dash 15, vanish step 20, vanish counter 25 (40 for the second in one exchange), ki blast 4, charged blast 20, specials 25–50 | At 0 ki: no dashes or vanishes; you can still fight with melee |
| **Guard** | 100 | +20/s after 1 s of not blocking | Blocking: light −6, heavy −18, blast −4, beam −2/tick | At 0: **Guard Break**, 60 f stun, opponent gets a free combo |
| **Burst** | 3 stocks × 100 | Dealing damage (+1 per 100 damage), taking damage (+1.5 per 100), perfect blocks (+15) | Combo breaker 1, transform 1, ultimate 2 | The comeback meter: you gain more from taking damage than dealing it |

### 5.3 Offense

**Light string (LMB):** up to 4 hits. Each hit has a **12-frame timing window** for the next press. Pressing too early or too late drops the string. This is the execution skill floor; mashing at random drops combos.

**Heavies (RMB + direction):**

| Input | Name | Effect | On block |
|---|---|---|---|
| RMB (neutral) | Smash | Big blowback, sends far (→ chase) | −8 (punishable by light) |
| W + RMB | Breaker | Guard damage ×2, slow 18 f startup | −4 |
| S + RMB | Launcher | Pops the target up (aerial follow-up) | −10 |
| Space + RMB | Rising | Anti-air, upper-body invincible frames 4–9 | −14 |
| C + RMB | Spike | Slams the target down (ground bounce or knockdown) | −10 |
| A/D + RMB | Sweep | Wide arc, hits sidesteppers | −6 |
| Hold RMB | Charged Smash | 3 charge levels; level 3 crushes guard and wall-splats | level 3: guard break if guard < 40 |

**Cancel hierarchy** (only during a hit's cancel window, on hit *or* block):
`Light → Heavy → Special → Vanish-step → (Ultimate)`. Each level can cancel into a later one, never backwards. This creates combo routes with real choices: cash out damage, spend ki for a wall-splat, or save meter.

**Starting frame data (baseline fighter "Kael"):**

| Move | Startup | Active | Recovery | Damage | Hitstun | On block |
|---|---|---|---|---|---|---|
| Light 1 | 6 | 2 | 10 | 300 | 16 | −2 |
| Light 2 | 7 | 2 | 11 | 320 | 17 | −2 |
| Light 3 | 8 | 3 | 13 | 350 | 18 | −3 |
| Light 4 (ender) | 10 | 3 | 18 | 450 | knockback | −6 |
| Smash | 14 | 4 | 22 | 800 | blowback | −8 |
| Launcher | 13 | 3 | 24 | 650 | launch | −10 |
| Grab | 7 | 2 | 25 (whiff) | 1,100 | throw | — (unblockable) |
| Ki blast (tap) | 8 | projectile | 12 | 120 | 8 | +1 |
| Charged blast | 22 | projectile | 18 | 700 | 20 | −2 |

**Damage scaling** (anti-touch-of-death): hit *n* in a combo deals `max(30%, 100% − 8% × (n − 1))`. Ultimates use a floor of 50% so they still matter at the end of a combo.

**Hitstun decay** (anti-infinite): each hit after the 8th in a combo has 2 fewer frames of hitstun, cumulatively. At some point every combo drops naturally, so practical combos run 10–16 hits.

### 5.4 Defense

| Tool | How | Beats | Loses to | Cost |
|---|---|---|---|---|
| Block | Hold `E` | Strikes, blasts | Grabs, Breaker heavy, guard depletion | Guard meter |
| **Perfect block** | A fresh press of `E` within 6 f of a hit (0–5 f before it lands; an early held press only blocks) | Strikes (attacker gets +16 recovery = free punish), ki blasts (**reflected**) | Grabs, delayed attacks (frame traps) | Nothing; mistiming means a 20 f lockout on the next perfect-block attempt (anti-mash) |
| Grab tech | Press `F` within 10 f of being grabbed | Grabs | — | — |
| **Dodge** (T-DEF2) | Tap `Shift` (+ direction) | Strikes, grabs and projectiles during its i-frames | Anything that meets its recovery; **grabs counter-hit the recovery and can't be teched** | Free; chain and cooldown rules below |
| **Sidestep** | Locked, tap `Shift` + `A`/`D` | Straight attacks, shots, grabs (70° arc round the target, ignores the orbit cap) | **Sweep** (tracks sidesteps through i-frames), grabs on the recovery | Free |
| Vanish counter | `Shift+E` while blocking or in the first 6 f of hitstun | Strings, smash | Opponent's counter-vanish or **Sense** (§5.5) | 25 / 40 ki |
| Combo breaker | `X` in hitstun: 8 f freeze and burst ring, attacker blown out to 5.5 m, breaker intangible for 20 f (its 12 f burst pose first; attacking ends it) | Any combo | Nothing (guaranteed escape), but it's expensive and has a 5 s cooldown | 1 burst stock |
| Push-block | Heavy while blocking | Pressure strings (pushes them to mid range) | — | 10 guard |

**Dodge frames** (60 Hz ticks, frame 1 = the press; all in `DodgeTuning`):

| Kind | I-frames | Recovery (vulnerable, throw bait) | Total | Travel |
|---|---|---|---|---|
| Directional | f3–14 | f15–26 | 26 | 4.5 m, eased out |
| Spot | f2–17 | f18–31 | 31 | none |
| Sidestep | f3–14 | f15–26 | 26 | 70° arc round the target at the same distance (wider up to 90° closer than 3 m) |

- **Anti-mash:** a dodge within 45 f of the last one ending is a *chain*: +8 f recovery, −4 i-frames. A third in a chain has **no i-frames** (a plain step, grey trail) until 90 quiet ticks pass. In the air: **2 dodges per airborne spell** (landing, being hit or 120 f without a dodge refreshes them); more come out with no i-frames.
- Only from free states (and out of a rush). **Never out of hitstun or blockstun**: that is the vanish counter's job.
- Holding `Shift` past f10 turns the dodge into the flight-dash: the i-frames end there and the dash can't be let go before the dodge's last frame (no free recovery cancel).
- **Perfect dodge:** a live hitbox or projectile meeting the first 6 i-frames (f3–8, spot f2–7). The attacker freezes 6 f (hitstop on the attacker only), the dodger gets −6 f recovery, a fresh chain and +10 ki (once per 180 f). A white-blue afterimage, a flash, a **READ!** pop and a whoosh with a reverse tail mark it. A dodge with nothing to dodge gets nothing, so mashing is worse than blocking.
- **Feel:** each legend leans, banks or twists through its dodge (`MotionProfile` dodge values); the afterimage trail is white on i-frames, plain on recovery and grey on a stale dodge, so the invulnerable window reads.

**Rock-paper-scissors at close range:** *Strike* beats *Grab* (counter-hit), *Grab* beats *Block*, *Block / perfect block* beats *Strike*. Every close exchange is a read.

### 5.5 The vanish game, fixed

The classic arena-fighter problem: teleport, counter-teleport, counter-counter-teleport, forever. Skybreak's rules:

1. A **vanish counter** puts the defender behind, above or below the attacker. The **defender chooses** with the direction held on the tick the vanish triggers: `Space` = above, descend (`C`) = below, anything else (including `S`, nothing, or both `Space` and `C`) = behind. Movement doesn't apply while blocking, in hitstun or during a vanish, so these keys can't collide with ascend, descend or back-dash. It's a guess, not a reflex. The attacker's counter-vanish guess is read the same way on the tick they press it.
2. The attacker can answer in two ways:
   - **Counter-vanish** (`Shift+E`, costs 40 ki): this only works against a vanish *in the direction they press*. A wrong guess wastes the ki.
   - **Sense** (tap `E` within 12 f after the opponent disappears): the attacker turns and blocks the incoming strike. It's cheap (0 ki), but only blocks, so the attacker loses the advantage. Sense is its own input context: a tap of `E` while an opponent is vanished is a Sense attempt, **not** a missed perfect block, so it never triggers the 20 f perfect-block lockout. One Sense attempt per vanish; a wrong-timed tap uses it up.
3. **Maximum of 2 vanish exchanges per sequence.** After the second, a **Clash** happens: both fighters' fists meet with a shockwave, they're pushed apart to mid range, and neutral resets. It looks spectacular and ends the loop.

The result: vanishing is a read with real costs, and it can never loop.

### 5.6 Chase and tech (after knockback)

After a Smash/Blowback sends the opponent flying:
- **Attacker:** press Dash within 20 f to **chase** (auto-homing rush). While chasing, choose a follow-up direction: over (spike), under (launcher) or straight (smash).
- **Defender:** press Dash + direction within the **tech window** (frames 12–24 of the flight) to recover in that direction.
- If the defender techs in the direction the attacker chased, the attacker connects. If not, the defender escapes and gets +8 frame advantage.
- Numbers (T-DEF3, `EscapeTuning`): the chase costs 15 ki and homes on a point 1.8 m above (Space, over), below (Ctrl, under) or at the target (straight), so its way is visible; it tails the target until the tech window closes. A tech moves 4 m over 14 f, intangible for the first 8 f, once per knockback (blowback, launch, sweep, a spike before its bounce). A caught tech stays in hitstun 18 f longer. Lights without knockback cannot be teched.
- Knockback into a **wall** gives a wall-splat (30 f, a free follow-up, no tech). Knockback into a **destructible** gives +150 damage, the rock shatters, and the fighter keeps flying (no splat).

### 5.7 Knockdown and wakeup (okizeme)

On knockdown, the defender picks:
- **Tech roll** forward, back or sideways (WASD + Space within 10 f of landing)
- **Neutral wakeup** (do nothing; up after 40 f)
- **Delayed wakeup** (hold descend; up after 70 f, which messes with the attacker's timing)

Every wakeup has 6 f of invincibility, then is vulnerable. The attacker reads it and sets up a strike, a grab or a bait. The roll covers 3.5 m in 18 f; neutral and delayed wakeups count from landing (T-DEF3). Attacking out of a wakeup ends its invincibility (no invincible reversals).

### 5.8 Ki blasts and beams: zoning that can be beaten

- **Tap blasts** (4 ki): fast, weak, small chip. They interrupt ki charging. They're absorbed by dashing toward them (dash armor against tap blasts only, +2 ki cost per blast absorbed).
- **Charged blast** (20 ki): a big projectile that dash doesn't absorb. You must block, sidestep or perfect-block (reflect).
- **Beams** (special or ultimate, 40–100 ki): long startup (≥24 f) with a big tell. They're dodged by sidestepping, and if they whiff the recovery is huge.
- **Beam Clash:** if two beams meet, a **rhythm minigame** starts. Four to eight beat prompts on `Q`/`E`/`F`/`R` scroll toward a hit line; accuracy pushes your beam forward. Spending ki mid-clash adds push. The loser takes the beam's full damage; the winner gains 50 burst. Mashing does nothing, because only on-beat presses count.
- **Anti-turtle:** charging ki is loud (aura sound and visual tell) and leaves you vulnerable, so the opponent can always punish a charger by rush-dashing.

**As built (T-KI1).** Numbers live in `game/combat/ki/kits/<legend>_ki_kit.tres` and `default_ki_tuning.tres`.

| | Kael | Vexa | Brann | Lyra |
|---|---|---|---|---|
| Tap blast (Q) | 8 f, 120 dmg, 44 m/s | 8 f, 100, 52 m/s, 9 f recovery | 8 f, 150, 34 m/s, big | 8 f, 110, 40 m/s, **homing** 2.4 rad/s |
| Charged blast (hold Q past 8 f) | 22 f, 700 | 22 f, 620 | 24 f, 820 | 22 f, 700 |
| Beam (1) | Dawnspear: 50 ki, 26 f, 1500 | Hexline: 45 ki, 24 f, 1300, thin | Forgemaw: 60 ki, 30 f, 1800, short and wide | Constellation Ray: 40 ki, 26 f, 1300, **splits in three** |
| Beam ultimate (4, 2 burst stocks) | Zenith Lance 2800 | Umbral Rift 2500 | Magma Torrent 3100 | Starfall Array 2700 |

- Projectile hits use the ranged 80% combo start (§5.11). Hitstop freezes only the target.
- A beam's aim follows the target until 12 f before it fires, then its line is fixed: a sidestep after that point makes it whiff. A whiff adds 30 f of recovery. It hits once (blowback) and stops at the first body it hits or that blocks it; blocking costs 2 guard and 6 chip per tick and pushes the blocker along it. Beams eat oncoming blasts.
- Beam clash: beats start 36 f after the clash, then one every 22 f; a press within 4 f of its beat with the right key pushes 10 (16 within 1 f); a wrong or off-beat press gives 6 back; up to 3 presses of `1` spend 10 ki for 6 push. The starting push favours the stronger beam (1 per 100 damage).

### 5.9 Transformations and ultimates

- **Transform** (`T`, 1 burst stock): a 1.5 s cinematic (skippable, invincible). Gives +15% damage and speed, new specials and a new ultimate, but **drains 5 ki/s**. When ki hits 0 you **revert with Exhaustion** (2 s of slower movement and no dashes). Timing a transformation is a strategic decision.
- **Ultimate** (`4`, 2 burst stocks): each character has 2 (one base, one transformed). On hit, it plays a cinematic with camera cuts (skippable after first view). On whiff it's punishable. A **Last Stand** rule: below 15% health, once per match, you get 1 free burst stock.

### 5.10 Game feel ("juice") values

| Event | Hitstop (both fighters freeze) | Camera shake | Other |
|---|---|---|---|
| Light hit | 4 f | none | small white spark |
| Heavy hit | 8 f | 0.15 (directional) | orange spark, impact ring |
| Counter-hit (hit during their startup) | +4 f | +50% | "COUNTER" text pop, red flash |
| Perfect block | 10 f | 0.1 | blue flash, bright "tink" sound, slight time-slow (0.8× for 6 f, view only: `Engine.time_scale`, the sim never changes speed) |
| Combo breaker | 8 f | 0.55 | one shockwave ring in the breaker's colour (about 1.2x, under 0.25 s) and a 2-frame flash in its hitstop (rationed with K.O. and guard break), deep boom + ring sound, shove pose |
| Guard break | 14 f | 0.3 | glass-shatter sound, guard bar shards |
| Wall-splat | 10 f | 0.35 | wall cracks decal, dust |
| Round-ending hit | 20 f, then 0.3× slow-mo for 1.2 s | 0.5 | camera orbits the impact, white impact frame (1 frame of inverted colors) |

**Sound is half of the feel:** every hit has three layers (impact thud + whoosh tail + character voice grunt). Light, heavy, blocked and perfect hits each sound distinct, so the player can hear what happened without looking.

---

### 5.11 Pickups: weapons, powers and gadgets

Inspired by platform fighters like Brawlhalla, adapted to 3D flight: items **drop from the sky during the fight** and change how you fight for a while. Every pickup creates a decision: grab it, deny it to the opponent, or keep pressing your advantage. All of it can be switched off in match setup ("pure duel").

**Spawning (deterministic, in the sim):**
- Every 12–18 s (seeded rng), an item spawns 25–60 m from the midpoint between the fighters, above the ground, with a **2 s telegraph**: a light pillar from the sky plus a sound, visible on the HUD as an edge marker when off-screen.
- At most 3 items on the map at once. Items despawn after 30 s. Weapons and powers alternate, so each type appears about evenly.
- Picking up takes `G` within 2.5 m. The pickup is instant but has 6 f of recovery, so grabbing in front of the opponent is a risk.

**Weapons** (each replaces your unarmed move set while held; unarmed stays fully viable):

| Weapon | Style | Strength | Weakness |
|---|---|---|---|
| **Ki Gauntlets** | Fast, short, combo-heavy | Longest strings, quick cancels | Short reach |
| **Storm Blade** | Balanced sword arcs | Good reach and speed | No standout tool |
| **Sky Lance** | Long pokes, a dash-thrust | Best range control | Slow recovery on whiff |
| **Titan Hammer** | Slow, huge hits | Guard crush, wall-splats | Easy to punish |
| **Orbit Chakram** | Thrown and returning disc | Hits from mid range twice (out and back) | Weak up close |
| **Ember Scythe** | Wide sweeping arcs | Pulls opponents in, hits sidesteppers | Long startup |

**Ranged weapons** (same pickup rules; each has an ammo count and is auto-thrown when empty):

| Weapon | Fire | Ammo | Strength | Counterplay |
|---|---|---|---|---|
| **Ki Bow** | Hold LMB to draw (3 levels), release to fire; level 3 arrow pierces and pins the target to walls | 12 arrows | Long-range punish and wall pins | Slow draw is loud and visible; sidestep or rush during the draw |
| **Arc Revolver** | LMB single shots (hard hitstun); RMB "fan" fires 3 fast shots | 6 per cylinder, 18 total, 1.2 s reload | Precise mid-range pressure and combo starters | The reload is a big punish window; perfect block **reflects** shots |
| **Storm Repeater** | Hold LMB for sustained fire, low damage per bullet, lots of guard chip | 120 rounds; overheats after 2 s of fire (1.5 s cool-down) | Area denial, guard pressure | You move at 60% speed while firing; **dash absorbs** its bullets (like tap blasts, +2 ki each) |
| **Scatter Cannon** | LMB short-range spread blast with strong knockback | 8 shells | Close-range burst; knocks fighters into walls | Useless past ~12 m; long recovery |

Rules that keep ranged weapons fair in a melee-first game:
- **Projectiles, not hitscan.** Every shot travels (fast, but dodgeable) and is a deterministic sim projectile, which also keeps rollback simple.
- **Aim:** along the lock-on line with a small, seeded spread. When unlocked, aim follows the camera.
- **Defense works:** all shots can be blocked (guard damage). A perfect block reflects arrows and revolver shots and deflects repeater bullets. Sidestepping beats aimed single shots.
- **Combo scaling:** ranged hits start combos at 80% damage, so the strongest punishes stay melee.
- **Melee while holding a gun:** RMB heavies become a weak weapon-bash, so a ranged fighter who gets rushed should throw (`G`) or vanish out.
- **Readability:** tracers and projectiles use the gold item colour family, never fighter energy colours.

- **Throwing:** `G` while holding a weapon throws it at the target as a fast projectile (damage plus a short stun). It's the classic "throw it before you lose it" play.
- **Losing a weapon:** you drop it on guard break, knockdown, or when hit by a counter-hit heavy. Dropped weapons stay on the map for 10 s and anyone can grab them.
- Each weapon is a `MoveSet` (the same data as unarmed), so balance is pure data tuning.

**Zone-exclusive weapon: Heartstring Bow** (spawns only in Heartbloom Gardens):
- **Shots (LMB):** arrows that make the target **Smitten** for 1.5 s: it drifts toward the shooter with hearts over its head and can't attack (it can still block). Repeat Smitten within 6 s lasts half as long, so it can't be chained.
- **Charged shot (hold LMB):** a **Heartstring Tether**, a glowing string linking shooter and target for 4 s. Neither can move further apart than the string's length at the moment it hit. Either fighter can **yank** the other closer with RMB, which sets up combos for whoever yanks first.
- 8 arrows, then auto-thrown like other weapons. Pink-gold projectiles, so they still read as an item colour (§11).

**Carrying several weapons (inventory):**
- You always have **Unarmed** plus **two weapon slots**. Any mix works: two melee, two ranged, or one of each.
- **Switching:**
  - `Mouse Wheel` cycles Unarmed → slot 1 → slot 2.
  - `Y` quick-swaps between the current weapon and the last one you used, the fastest way to flip between, say, a revolver and a blade.
- **Swap speed:** a swap takes **6 ticks** from neutral (no attacks during it) and is **buffered** like any press, so it comes out the moment you're free.
- **Swap-cancel (the mastery tool):** during a move's cancel window, **after contact**, you can swap weapons for **10 ki** and immediately use the new weapon's next move. It sits at the SPECIAL level in the cancel hierarchy (§5.3), so it goes after heavies and before vanish and ultimate. A combo like "blade string → swap-cancel → revolver fan → vanish" becomes possible, at a meter cost.
- **Picking up with full slots:** the new weapon replaces the weapon **in your hand** (that one drops to the ground). If you're unarmed, it fills the first empty slot, or slot 1 when both are full.
- **Ammo** is kept per weapon, so you can swap out of an empty-ish revolver and come back to it later.
- **Throwing (`G`)** throws only the weapon in your hand. **Losing weapons** on guard break, knockdown or a counter-hit heavy drops only the one in your hand; the other slot is safe.
- **HUD:** a small three-icon strip (Unarmed / slot 1 / slot 2) near your meters, with ammo counts on ranged weapons and the active one highlighted.

**Powers** (instant, timed buffs that show as an aura colour):
- **Overdrive Orb:** ki regen ×3 for 10 s.
- **Burst Shard:** +50 burst.
- **Aegis:** absorbs the next hit completely (shield flash).
- **Haste:** +20% movement and dash speed for 8 s.

**Gadgets** (one-shot throwables, thrown with `G`):
- **Spike Bomb:** explodes after 1.5 s or on contact; launches.
- **Gravity Mine:** placed in the air; pulls nearby fighters in for 2 s.
- **Mirror Decoy:** spawns a fake that copies your last action for 3 s.

**Readability:** weapons and items have bold silhouettes and their own colour family (gold), so they never get confused with fighter energy colours (§11).

## 6. Fighters (launch roster: 4)

Each fighter has a clear playstyle, one strength, one weakness and one unique mechanic. All are **original characters**.

| Fighter | Archetype | Strength | Weakness | Unique mechanic | Transformation |
|---|---|---|---|---|---|
| **Kael** | All-rounder | Solid tools at every range, easy to learn | No standout strength | **Momentum:** consecutive hits without being hit raise his damage +2% per hit (max +20%), lost when hit | *Ascended*: golden-white aura; specials gain extra hits |
| **Vexa** | Speed / trickster | Fastest movement, cheapest vanishes (20/30 ki) | Lowest health (8,500), light damage | **Afterimage:** can leave a decoy that absorbs one hit and explodes | *Phase Form*: violet; dashes become short teleports |
| **Brann** | Heavy / grappler | Huge damage, armored heavies (absorb 1 hit), command grabs | Slowest flight, vanishes cost 35/55 ki, big hurtbox | **Unstoppable:** charged smash has full armor at level 3 | *Titan*: red-bronze; grabs become unblockable rushes |
| **Lyra** | Zoner / trapper | Best ki blasts and beams, places floating mines | Weak at close range, low guard (80) | **Seal mines:** up to 3 mines in the air that detonate on contact or on command | *Starlight*: blue-white; blasts home, beams split |

**Art direction for fighters (owner's decision: Brawlhalla-style, not DBZ-style):**
- **Proportions:** chunky and stylized, about **4.5 heads tall**: big head, broad shoulders, **oversized hands and feet**, compact torso and short legs. A toy-like, instantly readable silhouette from any angle at fight distance.
- **Shapes:** simple, bold forms with few small details. Every fighter has **one big silhouette feature** (hat, hood, horns, cape, scarf, pauldrons).
- **Colour:** bright, saturated, 2–3 main colours per fighter plus an accent. Thick ink outlines (our outline shader) and 2–3 cel bands.
- **Theme:** a roster of **fantasy "legends"** from different worlds and eras (knight, rogue, brawler, mage and so on), each with a **signature weapon pair** that matches the pickup weapons (§5.11). Fighters can use any weapon; their pair is their best fit and appears on their idle pose.
- **Animation:** snappy and exaggerated, with big anticipation and squash/stretch on impacts. Read at a glance, not realistic.
- **Originality:** inspired by the *style* of platform fighters like Brawlhalla, but **no existing character, costume or name is copied**. Every design is checked against well-known characters before it's built.

**Launch roster looks (original):**
- **Kael** (all-rounder; signature weapons: Storm Blade + Arc Revolver): a young **sky-knight adventurer** with silver-white tufted hair under brass flight goggles, a short teal-and-gold armoured coat over a charcoal tunic, oversized gold gauntlets, chunky orange boots, and a **long orange scarf** that trails in flight. Energy colour orange-white.
- **Vexa** (speed/trickster; Ki Gauntlets + Orbit Chakram): a masked **shadow rogue** with a deep violet hood with long ear-like points, a cropped silver jacket, wrapped arms, and a mischievous visor-mask with glowing eyes.
- **Brann** (heavy grappler; Titan Hammer + Scatter Cannon): a huge **stone-forged blacksmith** with mossy rock shoulders, a leather apron, a braided ember-red beard, and anvil-sized fists.
- **Lyra** (zoner; Ki Bow + Sky Lance): a **star-cartographer mage** with a wide-brimmed midnight-blue hat dotted with constellation lights, a flowing star-map cape and floating brass astrolabe rings.

### 6.1 Specials (T-SP1)

Keys `1` `2` `3`, all in `game/combat/specials/` (data in `kits/*.tres`, API in its README). Specials sit at the **Special** level of the cancel hierarchy: they come out of a free state or cancel a Light or Heavy that made contact (inside its cancel window), and on hit they cancel only into Vanish-step or an Ultimate, never into another special or backwards. Whiffed or blocked, every special is punishable. Frames are 60 Hz ticks; *on block* is the defender's advantage when the first active frame is blocked.

**Kael** (all-rounder, orange-white) · **Momentum:** +2% damage per consecutive landed hit, up to +20% (10 diamond pips beside his burst stocks), all lost the moment he takes damage.

| Key | Special | Cost | Startup / active / recovery | Damage | What it does | Beats | Loses to |
|---|---|---|---|---|---|---|---|
| 1 | **Comet Drive** | 25 ki | 12 / 10 / 22 | 900 | Crouch and flare, then a 6 m shoulder-first rush toward the target; blowback. `Space`+1 climbs (launch, 800), `C`+1 dives (spike, 850) | Backdashes, whiffs, mid-range ki; chases a heavy ender | Block (−17 blocked early, −8 late), sidestep, a jab in its face |
| 2 | **Gale Counter** | 25 ki | 3 / 20 (stance) / 24 | 1,000 riposte | A guard stance; a strike landing in it is caught (no damage), the attacker freezes and Kael answers with a blowback riposte | Strikes, strings, rushes | Grabs, ki shots, waiting it out (47 f whiff) |
| 3 | **Skyfall** | 35 ki | 22 / 4 / 22 | 850 | Leaps up to 5 m in an arc and crashes down; spike. 40 guard damage, breaks a guard under 40 | Turtling | Anti-air Rising heavy, dodges and sidesteps (huge tell) |

**Vexa** (trickster, violet) · **Afterimage:** Mirage Step leaves a decoy where she stood for 2.5 s. The first opponent hitbox or shot that touches it is wasted on it, and it bursts (2.4 m, 500 damage, blowback; blockable). One decoy at a time; a violet marker beside her burst stocks shows it is out.

| Key | Special | Cost | Startup / active / recovery | Damage | What it does | Beats | Loses to |
|---|---|---|---|---|---|---|---|
| 1 | **Shade Flicker** | 30 ki | 14 / 3 / 18 | 600 | Sinks into violet smoke (invulnerable f7–13), reappears 1.6 m round the target, past its guard but to the side (`A`/`D` picks which, so the player's camera keeps her in view; within 8 m), and strikes; +6 on hit links a light | A late-turning or unlocked guard, zoning | A locked guard that turns in time (−8), spot dodge, a fast button on her arrival |
| 2 | **Mirage Step** | 25 ki | 3 / 10 (slide) / 12 | — (decoy 500) | Slides 4.5 m: `A`/`D` sideways, `W` forward, otherwise back; leaves the afterimage | Committed attacks, rushes, beams aimed at her spot | Tracking attacks and anyone who ignores the decoy |
| 3 | **Razor Waltz** | 35 ki | 9 / 18 / 20 | 3 × 260 | A spinning three-cut rush; the confirm ender | Cashing out a confirmed string | Block (−13), a jab before it starts |

Ultimates (`4`) and transformations (`T`) slot into the same kit (`SpecialKit.ultimate`, 2 burst; `transform_burst_stocks`, 1 burst; `FighterSpecials.transform_ticks`) in the next lane. Until a kit defines an ultimate, key 4 is left to the ki beam ultimate (T-KI1); key 1 stays the ki beam special for legends without a kit (Brann, Lyra).

**Balance target:** in AI-vs-AI simulations and playtests, no fighter wins more than 55% of matches against any other.

**Character presentation:** 2 intro poses, 2 victory poses, a defeat pose, 6 voice lines (from free voice packs or TTS) and a color palette with 4 alternate colors per fighter.

---

## 7. The world: one big map, six fighting zones

Fights happen on **one continuous world map** instead of small separate arenas. Knockbacks, chases and beams carry the fight across zone borders, which is the core fantasy: smashing someone through a canyon wall and finishing the fight over a volcano.

### 7.1 Map
- **About 2 km x 2 km**, sky ceiling at about 400 m, an energy-dome boundary at the edge that acts as a wall-splat surface. No ring-outs.
- **Seven zones** (six main zones plus the special Heartbloom Gardens), each roughly 600–800 m across, blending into each other at the borders (terrain, colour and fog transitions over about 100 m).
- **Match setup:** pick a **start zone** (or random) and **time of day** (day / dusk / night). Fighters spawn about 40 m apart in that zone.
- **Navigation aids:** zone name on entering, and the off-screen opponent arrow (§4.7) always works across the map.

### 7.2 Zones

| Zone | Look | Gameplay character | Destructibles / hazards |
|---|---|---|---|
| **Shattered Mesa** | Red desert canyons, mesas, bright sky | Open, long sight lines: favours zoning | Rock pillars, mesa tops shear off |
| **Skyhold Ruins** | Floating stone islands over a sea of clouds, golden hour | Tight gaps between islands, many walls: favours rushdown | Columns, arches, falling island chunks |
| **Stormfall City** | Ruined city at night, rain, neon, lightning | Buildings for cover and line-of-sight breaks | Building corners, water towers, cars |
| **Frozen Peaks** | Glaciers, ice cliffs, snow storms | Vertical cliffs, ice shelves; visibility drops in storms | Ice spires shatter, avalanche slabs |
| **Verdant Falls** | Jungle valley, giant trees, a huge waterfall and lake | Mixed cover; water spray hides you briefly | Giant trunks snap, waterfall curtain |
| **Ember Rift** | Volcanic crater, lava rivers, obsidian spires, glowing at night | Open crater with hot zones: lava geysers knock fighters up | Obsidian spires, geyser vents |
| **Heartbloom Gardens** (special) | Floating islands of cherry-blossom trees, a pink-gold sunset sky, a slow river of falling petals, lantern bridges, a big heart-shaped stone arch; fireflies and glowing lanterns at night; softer music | Romantic, playful zone made for the owner and their partner: open sky between islands, lots of mid-range space | Petal whirlwinds lift fighters (no damage); the Wishing Fountain slowly heals whoever stands in its spray; lanterns and blossom branches break into petal bursts |

All zones share these rules: knocked-into-ground craters (decals), destructibles respawn after 30 s, and no instant-kill hazards (hazards deal small damage and knock up; they never decide a round on their own).

### 7.3 Technical approach
- **Terrain:** procedural, chunked heightmap meshes with distance LOD. The sim reads the **same heightmap data** for ground height, so landing and knockdowns stay deterministic (no physics engine in the sim).
- **Props:** MultiMesh instancing for rocks, trees, debris; impostors or low LODs in the distance.
- **Atmosphere:** per-zone fog, light and weather presets blended by position; distance fog hides the far LOD.
- **Performance budget:** the world costs **≤ 3 ms GPU p95 at medium** on the GTX 1650 at 1080p, measured with the render benchmark on the world level.
- **Build order:** grey-blocked layout of all six zones first (shapes, heights, landmarks), then one art pass per zone.

## 8. Game modes

| Mode | What | Why it matters |
|---|---|---|
| **Versus AI** | Pick your fighter, the start zone and time of day, then **choose 1–3 AI opponents**. Set each one's fighter and level (Easy / Normal / Hard / Brutal) separately, or randomise. 1 AI = a classic duel; 2–3 AIs = offline free-for-all (§8.1 rules) | The main mode |
| **Arcade** | 6 fights in a row against escalating AI, with a short scripted story per fighter (§9). The final boss is a transformed rival. | Gives the game structure and a "finish" |
| **Tutorial** | 10 interactive lessons (move → lock-on → light string → heavies → block → perfect block → grab → vanish → chase/tech → meters) | Teaches the deep systems step by step |
| **Combo Trials** | 10 trials per fighter, from easy to very hard, with the input display | The mastery loop, and the main reason to keep playing |
| **Training** | Dummy settings (block / perfect block / tech / random), recording and playback (5 slots), frame data overlay, hitbox viewer, input history, damage readout, meter refill toggles | Where skill is built |
| **Survival** | Endless AI fights; health carries over, partial heal between fights | Replay value |
| **Replays** | Every match is saved as inputs (tiny files), plays back from any camera | Free thanks to the deterministic sim |
| **Local 2P** *(milestone 7, later)* | Split-screen | Already planned for in the input layer |

**Progression (light, for personal replay value):** clearing trials, Arcade and Survival milestones unlocks alternate colors, a title card, arena variants (Stormfall at dawn, Mesa at night) and music tracks. No grinding.

---

## 8.1 Free-for-all (the main multiplayer format)

The owner chose **free-for-all from the start**. Every mode that can have more than two fighters supports it, online and against AI bots.

- **Players:** 2–4 per match (humans online and/or AI bots filling empty seats). Teams (2v2) come later on the same code.
- **Win conditions** (chosen in match setup):
  - **Stock:** 3 lives each; the last fighter standing wins.
  - **Timed:** 5 minutes; most KOs wins, with KO steals counting for whoever landed the final hit.
- **Respawn after a KO (stock and timed):** 3 s later, at the spawn point furthest from the other fighters, with 2 s of invincibility (a flashing aura) and full health, 50 ki, full guard. **Burst is kept** (comeback rule, §5.2).
- **Targeting:** lock-on picks the nearest fighter, and `Tab` cycles through targets by distance. HUD edge arrows show every off-screen fighter in their player colour. The camera frames you plus your **current** target (§4); others are shown by arrows and name tags.
- **Third-party hits:** anyone can hit anyone, including a fighter who is in someone else's combo. That's part of the chaos. Two rules stop it feeling cheap:
  - **Combo scaling is per victim**, so a gang-up still scales down.
  - **Burst fills 50% faster while two or more fighters have hit you in the last 3 s**, so the combo breaker comes sooner.
- **Hitstop** freezes only the two fighters in that exchange; everyone else keeps moving.
- **Pickups:** spawn rate scales with player count (one more item cap per extra player).
- **Spawns:** each zone defines 4 spawn points about 40 m apart around a centre.
- **AI bots** use the same input interface and know about all fighters (they pick targets by threat and distance, and avoid being the third wheel too often).
- **Online (§12.1):** rollback with up to 4 peers. Each peer sends its input to the others. The transport (Appwrite Realtime) relays them, and every peer simulates all fighters.

## 8.2 Duo mode (co-op: two players vs AI, online)

The owner's priority mode: **the owner and their partner, each on their own device (Windows PC and/or the web build), as one team against AI fighters.**

- **Teams:** 2 humans on team A against **1–4 AI fighters** on team B (or split into AI teams). Each AI's fighter and level can be set separately.
- **Friendly fire:** off by default (teammates' hitboxes pass through each other), with a toggle in match setup.
- **Team stocks:** each team shares a pool (default 6 lives for the duo). While one partner respawns (§8.1 rules), the other holds on. The team that runs out first loses.
- **Team assists:** a hit on an enemy that is in your partner's combo **continues that combo** (shared combo count, shared scaling) instead of starting a new one, so partners can extend each other's combos. Burst gains for both.
- **Shared camera rules:** each player's camera works as usual (you plus your target). The partner gets a coloured marker and name tag, and an arrow when off-screen.
- **Pickups:** item spawn rate as in §8.1; the Heartstring Bow appears in Heartbloom Gardens as usual.
- **Online path:** this mode is the first online mode to ship. AI fighters must be **computed inside the deterministic sim** from sim state and the seeded rng, so every peer simulates the same AI inputs without sending them (§12.1).

## 9. Scripting: story beats and dramatic moments

A small data-driven **event system** lets designers script moments without code.

- **Scripts** are Godot Resources (`.tres`) containing a list of **triggers** and **actions**.
- **Triggers:** `round_start`, `health_below(fighter, pct)`, `transform(fighter)`, `beam_clash_won(fighter)`, `combo_length_at_least(n)`, `timer_below(s)`, `round_end(winner)`.
- **Actions:** `dialogue(speaker, text, portrait, duration)`, `camera_shot(name)`, `slow_mo(scale, seconds)`, `ai_force_transform`, `ai_change_level`, `play_music(track)`, `spawn_vfx(name, at)`, `set_weather(storm_intensity)`.
- Dialogue shows in-fight as short subtitle-style bubbles that **don't pause the game** (except at round start and end).

**Example (Arcade, final fight vs. rival Kael):**
```
on round_start(1):          dialogue(Kael, "You've been holding back. Don't.")
on health_below(Kael, 50):  ai_force_transform; camera_shot("rival_transform"); play_music("finale_phase2")
on beam_clash_won(player):  slow_mo(0.4, 1.0); dialogue(Kael, "...Again!")
on round_end(player):       dialogue(Kael, "Next time, the sky breaks for me.")
```

---

## 10. AI opponent

**The AI uses exactly the same input interface as the player.** No reading inputs, no frame-perfect reactions, no cheating with meters.

- **Perception delay** by level: Easy 28 f, Normal 20 f, Hard 14 f, Brutal 11 f. The AI "sees" the game state that many frames late.
- **Decision making:** a utility AI scores options (approach, zone, charge, attack, block, grab, bait, vanish) using distance band, meters, health lead and opponent state.
- **Execution accuracy** by level: Easy drops 40% of combos and perfect-blocks almost never; Brutal drops 5% and perfect-blocks ~35% of the time it correctly anticipates.
- **Adaptation (Hard / Brutal):** the AI tracks the player's habits per situation (wakeup choice, after-block action, tech direction, vanish direction) with a decaying histogram and leans toward the counter. Players who change habits beat it, which is the intended lesson.
- **Personality per fighter:** Brann's AI is aggressive and grabs often; Lyra's AI keeps distance and lays mines; Vexa's AI baits and vanishes; Kael's AI is balanced.
- **Fun limiter:** the AI never chains more than 2 perfect blocks in a row on Normal or below, and it "gives" the player openings after a long losing streak (rubber-banding only on Easy and Normal).

---

## 11. UI and presentation

- **HUD:** health (with grey recoverable part) and burst stocks top-left/right; ki bars and guard ring near each fighter's portrait; combo counter and damage pops near the hit. Minimal and readable; it fades during cinematics.
- **Readability colors:** your attacks warm (orange/white), the opponent's cool (cyan/purple) in effect tints; perfect block = blue, guard break = red, counter-hit = red text.
- **Menus:** animated backgrounds (an arena flyover), fast navigation (mouse + keyboard), character select with live 3D models doing idle animations, and a 0.3 s max transition between screens.
- **Loading:** under 5 s on the target PC, with a tips screen showing combat tips.
- **Settings:** graphics (low / medium / high, resolution scale, vsync, fps cap), audio volumes, full key rebinding, camera sensitivity and smoothing, toggles for screen shake and hitstop strength (accessibility).

---

## 12. Technical architecture (for builders)

```
game/
  combat/      # deterministic sim: no Nodes, unit-tested headless
    combat_sim.gd      # CombatSim: tick(inputs: Array[FighterInput]) -> void, then read its state
    fighter_state.gd   # position, velocity, state machine, meters
    move_data.gd       # Resource: frame data, hitboxes, cancels
    collision.gd       # hitbox vs hurtbox (capsules/spheres, simple math)
    rules/             # damage scaling, hitstun decay, vanish, chase/tech, beam clash
  input/       # keyboard+mouse -> FighterInput (buttons, stick, lock-on); AI emits the same struct
  ai/          # perception delay, utility scoring, habit tracking
  view/        # reads sim state each frame: animation, VFX, camera, audio
  arenas/      # scenes, destructibles, boundaries
  ui/          # HUD, menus, training overlay
  script/      # event triggers/actions (§9)
  data/        # fighters/*.tres, moves/*.tres, scripts/*.tres
tests/         # GUT tests: frame data, cancels, meters, vanish limits, determinism
```

Key rules:
- **`CombatSim.tick()` returns nothing.** The view and tests read `current_tick` and `fighters` (each a `FighterState`) after each tick.
- **The sim never reads the clock or uses randomness without a seeded RNG** carried in the state. Same inputs give the same state (there's a determinism test: run 10,000 ticks twice, compare hashes).
- **Interpolation:** the view interpolates between the last two sim states, so rendering at any fps stays smooth.
- **Data-driven tuning:** a dev overlay (F1) shows and edits live frame data in a running match, with save-back to `.tres`.
- **Performance budget (GTX 1650 / 16 GB):** 1080p at 60 fps, VRAM under 3 GB, textures ≤ 2K, Forward+ with no SDFGI or volumetrics, and a low/med/high settings menu from the start.

---

## 12.1 Online play (future: Appwrite Realtime)

Online versus is planned for later, using **Appwrite** (auth, lobbies, presence) with **Appwrite Realtime** as the transport. Design for it now so nothing has to be rebuilt:

- **Netcode model: rollback with input delay.** Only inputs travel. Each peer runs the same deterministic sim, predicts the remote input, and rolls back and re-simulates when the real input arrives. Targets: 2 frames of input delay, up to 8 frames of rollback.
- **Requirements on the sim, starting today:**
  - fully deterministic: already the rule, with seeded rng and no wall clock
  - **snapshot and restore** of the whole sim state in under 1 ms, so rollback can rewind
  - **compact, serializable inputs**: action bitmask plus quantised stick, camera yaw and offset (about 10–12 bytes per tick)
  - all pickup spawns come from the seeded rng in the sim, never from the view
- **AI is part of the deterministic sim** (or a pure function of sim state plus seeded rng), so AI fighters never need to be sent over the network.
- **Appwrite project (owner's decision):** use the **same Appwrite Cloud project as MisterMime** (`6a113777000db893b12e`, region `sgp`, endpoint `https://sgp.cloud.appwrite.io/v1`). The project is shared with other apps: only **add** Skybreak resources (its own database, collections and functions, prefixed `skybreak`), never change or delete existing ones.
- **Online tracking with Appwrite Presence** (as MisterMime does it): each signed-in player calls `realtime.upsertPresence({presenceId, status, metadata, permissions})` over the Realtime socket:
  - `status` is `menu`, `lobby` or `in_match`
  - `metadata` holds the display name, fighter, lobby id and platform
  - Friends and lobbies watch the `presences` channel live; menus can also read the HTTP `presences.list`.
  - The record is **deleted automatically when the socket drops**, so a partner disconnecting mid-match is detected at once. The match then **pauses for up to 30 s or hands that fighter to the AI** until they reconnect (setting).
  - Presence metadata is client-published over the socket, so the spike also tests it as the **WebRTC signalling** channel (offer/answer/ICE), avoiding database writes.
- **Godot client:** a small GDScript Appwrite client (HTTPRequest for REST, WebSocketPeer for Realtime), so the same code runs on Windows and in the web build. No addon is needed for that part.
- **Transport decision (measured 2026-11-19, India to the Appwrite `sgp` region, two test users):**

  | Path | p50 | p95 |
  |---|---|---|
  | TCP connect to Appwrite | 98 ms | — |
  | Presence one-way (A publishes → B sees it) | 196 ms | 317 ms |
  | Presence round trip (A → B → A) | 411 ms | 548 ms |

  Presence also coalesces fast updates: 9 of 40 were overwritten, because it is state, not a queue.
  - **Decision:** **per-tick inputs travel peer-to-peer over WebRTC data channels** (unreliable/unordered channel for inputs plus redundancy, reliable channel for match control). Expect about 2–10 ms on the same home Wi-Fi.
  - **Appwrite Presence** is the **signalling channel** (offer/answer/ICE in presence metadata), and it also handles online status and disconnect detection. Signalling tolerates about 400 ms.
  - Godot: WebRTC is built in for the web export. Windows needs the official `webrtc-native` GDExtension, which `developer` vendors in `addons/` when the netcode task starts.
  - TURN fallback: for networks where direct P2P fails; decide later (STUN-only first).
- **Transport abstraction:** a `NetTransport` interface, so Appwrite Realtime (or the Appwrite Push/MQTT path already used by MisterMime) can be swapped in without touching the sim.
- **Lobbies and matchmaking:** Appwrite Auth plus a lobbies collection; Realtime presence shows who is online.
- **Known risk:** floating-point determinism across different CPUs. The same build on Windows x86-64 is fine. If cross-platform play is ever wanted, the sim's movement math may need fixed-point.

## 13. Playtest plan

Each milestone ends with a playtest by the owner, with a short checklist:

- **Milestone 1 (flight & camera):** *Does flying feel fast and precise? Does the camera ever lose the opponent or get stuck in terrain? Any motion sickness?*
- **Milestone 2 (melee):** *Do hits feel heavy? Can you tell light from heavy hits with your eyes closed (by sound)? Do combos feel earned, not automatic?*
- **Milestone 3 (depth):** *Is perfect block learnable in 10 minutes? Is vanishing a fun guess or annoying? Can you beat ki spam?*
- **Milestone 6 (AI):** *Does Brutal feel smart or cheap? Does it punish your habits so you can feel it?*

Tuning targets: an average round lasts 45–75 s; an average combo deals 12–20% health; a perfect block happens in roughly 1 of 10 blocks for an intermediate player.

---

## 14. Changes from the original handoff

| Area | Handoff | This design | Why |
|---|---|---|---|
| Close-range RPS | Block, perfect block, guard break | **+ Grab** (beats block, loses to strikes) | Without grabs, blocking is too safe and close range lacks reads |
| Vanish | Timed teleport, counterable | **Direction guess, Sense option, max 2 exchanges then Clash** | Prevents the endless teleport loop |
| Knockback | Wall/ground bounces | **+ Chase/tech direction game, destructibles** | Turns every knockback into a mini-read |
| Ki | Charge to refill | **+ dash absorbs tap blasts, charging is loud** | Makes zoning beatable |
| Perfect block | 6 f window | **+ 20 f lockout on a miss, reflects blasts** | Anti-mash; ties defense into zoning |
| Modes | Versus, training, menus | **+ Tutorial, Combo Trials, Arcade with scripted story, Survival, Replays** | Learning curve, mastery and replay value |
| Comeback | — | **Burst gains more from taking damage, Last Stand** | Matches stay tense |

---

## 15. Open questions for the owner

*(Free-for-all chosen by the owner on 2026-11-19 as the main multiplayer format, §8.1. Pickups and online answered on 2026-11-19: yes to Brawlhalla-style weapons and powers in the arena, and Appwrite Realtime online later.)*

1. Is a 99 s round timer right, or do you want ∞ by default?
2. Do you want **Arcade story mode** in the first full version (milestone 7), or later?
3. Voice lines: free voice packs, text-to-speech, or no voices (just grunts)?
4. Are the fighter names and concepts (Kael, Vexa, Brann, Lyra) OK, or do you want different characters?

## 16. Pure Fight (2.5D 1v1, T-PF1)

Owner request: "a certain angle mode as zone ... pure fight mode. no special powers, ki, etc.
pure hand to hand combat. the camera angle would be like street fighter. 3d but on a platform
kind on any zone. would be available on the online as well", then "combat styling actually".
Defaults chosen by the desktop controller; the owner can redirect any of them.

### 16.1 Rules

- 1v1 on one **fight line** laid across a flat platform inside any of the seven zones. The zone
  stays fully 3D as the backdrop; fighters only move along the line and up (jumps).
- No flight, ki, beams, energy specials, auras, weapons, pickups or vanish. Everything is physical.
- Fighters auto-face each other on the ground (not in the air, so jump-ins can cross up).
- Platform ends are **walls** (no ring-outs). The two fighters can be at most 6.6 m apart, so the
  camera always frames both.
- **Best of 3 rounds**, a **99 s** timer (it stops during a finisher cinematic). Time up: the higher
  health share wins the round; equal is a draw (no round win; at most 5 rounds).
- Health bars and a **finisher meter** (0-1000, carried across rounds). Chip damage is off.
- Sim: `PureFightSim` (`game/combat/pure_fight/`), a `CombatSim` subclass whose own tick replaces
  the flight game's, so every other mode stays bit-identical. Integer state (mm, mm/tick), 60 Hz,
  snapshot/restore by reflection, so rollback (`RollbackSession`) takes it unchanged.

### 16.2 Controls (WASD + mouse; two players can still share one laptop)

No numpad, F-keys or Ctrl/Cmd/Alt anywhere, so it works on a Mac laptop in a browser. P1 plays
WASD + mouse by default (one player per laptop, Duo included); P1's keyboard-only keys work at
the same time. The mouse never drives P2.

| Action | P1 (WASD + mouse) | P1 keyboard only | P2 |
|---|---|---|---|
| Walk / jump / crouch | A D / W (or Space) / S | same | Left Right / Up / Down arrows |
| Light / medium / heavy | Left click / middle click or Q / right click | J / K / L | , / . / / |
| Throw | F | U | ; |
| Technique key | R | I | ' |
| Finisher key | C | O | ] |
| Dash | Left Shift + direction, or tap forward/back twice | same | Right Shift + direction, or tap twice |
| Block | hold back (down-back for lows); E blocks from the front | same | hold back; [ blocks from the front |

- Normals: button alone (standing), with down (crouching), in the air (jump attacks). Command
  normals: forward + M (overhead), forward + H or back + H (legend), down-forward + H (sweep).
- **Target combos**: press the listed second button while the first hits or is blocked.
- **Techniques**: a motion + any attack (236 quarter-circle forward, 623 forward-down-downforward,
  214 quarter-circle back), read leniently (the diagonal can be skipped, 16-tick window, the last
  direction at most 8 ticks old), or the **technique key + a direction** (forward/neutral = 236,
  down = 623, back = 214) for keyboard players.
- **Finisher**: 236236 + attack or the finisher key with a full meter; normals marked "cancels into
  techniques" cancel into techniques on contact, techniques marked "finisher cancel" cancel into it
  on hit.
- Buffer: presses stay 6 ticks (frozen during hitstop, so a combo input made during a heavy hit's
  freeze still comes out).

### 16.3 Universal system

| System | Rule |
|---|---|
| Walk | Per legend (Kael 2.5 m/s forward, Vexa 2.8, Lyra 2.6, Brann 2.0); back is slower |
| Dash / backdash | 14-22 ticks; backdash is strike- and throw-invulnerable for 8 ticks |
| Jump | 4-tick prejump, neutral/forward/back, about 37 ticks in the air, one air attack per jump |
| Block | Hold away from the attacker. Standing blocks mids, overheads and air attacks; crouching blocks mids and lows; air block blocks everything but lows can't reach you |
| Just defend | Guard raised at most 4 ticks before the hit: 4 ticks less blockstun, +60 meter, blue flash |
| Throw | 5f startup, 950 mm range, beats blocking; no throws on airborne, stunned, waking or just-released fighters (3-4 ticks) |
| Throw break | Press throw within 10 ticks of being grabbed: both push apart, no damage. Throw on the same tick as the opponent: auto tech |
| Back throw | Hold back while throwing: the opponent lands behind you |
| Knockdown | 38 ticks down (invulnerable), then a get-up (22 ticks) or a **wake-up roll** (hold forward/back: 26 ticks, 1.5 m, invulnerable) |
| Counter hit | Hitting a move in startup: 120% damage, +4 hitstop and hitstun, red sparks |
| Punish counter | Hitting a move in recovery (or a heavy landing): 110% damage |
| Damage scaling | 100%, 100%, then -15% a hit, at least 30% (finishers at least 50%) |
| Hitstun decay | -1 tick per combo hit, at most -6 (never under 8 ticks) |
| Juggles | Launchers pop the target up; each air hit adds juggle points and gravity; at 4 points the target falls out invulnerable. Air hits on a jumping opponent are an air reset (lands on its feet) |
| Wall bounce | Moves marked wall bounce, once per combo |
| Ground bounce | Moves marked ground bounce, once per combo |
| Hitstop | Light 7, medium 10, heavy 13, techniques/finishers 16 ticks (on block 5/7/9/11); screen shake scales the same way |
| Meter | +40/60/80/110 per hit by strength (half on block); +15 when hit, +20 when blocking (+60 just defend); the finisher spends 1000 |
| Armour | Brann's armoured moves absorb one strike (half damage, no stun) |

### 16.4 Camera and stage

- `SideCamera` (`game/view/camera/side_camera.gd`): perpendicular to the fight line, looking toward
  the zone centre so landmarks fill the background; screen right is +x. It frames both fighters
  inside 72% of the width (distance 5.2-9 m, zooms out with their gap), eye 1.6 m over the floor,
  looking 1.05 m up. A short punch-in on finishers, a decaying shake on heavy hits.
- `PureFightStage`: the flattest 17 x 5 m spot within 70 m of the zone's spawns (12 headings), read
  from the zone's ground data. A voxel-style stone slab (tile seams, stepped ledge, a foot into the
  ground, gold-capped corner posts at the walls, a painted line) sits 5 cm over the highest ground.

### 16.5 Presentation

- Hit sparks are small emissive cubes (clamped colour: gold hit, red counter, cyan block, blue just
  defend), count and speed by strength; an impact frame (1-4 frames) on heavy hits, counters, the
  finisher and KO; dust on landings, knockdowns and dashes; speed lines on dashes and finishers; a
  motion trail ribbon on the striking limb during active frames.
- HUD: health bars with a white damage trail, round pips, 99 s timer, finisher meters ("FINISHER
  READY"), combo counters (hits and damage), banners (ROUND n / FINAL ROUND, FIGHT!, K.O., TIME,
  WINS / DRAW) and callouts (COUNTER, PUNISH, JUST DEFEND, ARMOR, TECH, WALL BOUNCE, the finisher's
  name). Training shows the last move's frame data and the measured advantage.
- Sounds come from the combat bank (light/medium/heavy hits, block, perfect block, armour, grab,
  tech, wall splat, KO, whooshes).

### 16.6 Legends: style sheets

Every pose is keyframed in code (`game/characters/fight_styles/`) and put on the voxel rig by
two-bone IK (`FightRig`), so a fist or foot reaches the move's hitbox on its first active frame and
planted feet stay planted. Strikes have anticipation (a windup key at half the startup), a held
active pose (a kiai freeze), follow-through and a settle back; hits snap in 1.5 frames.

- **Kael, karate shoto.** Low, wide front stance (hips down 17 cm, feet 80 cm apart), bladed 38
  degrees, lead hand forward, rear fist chambered. Linear punches with the off hand pulled to the hip
  (hikite); snap front kicks; a hammer-fist overhead; a driving side kick. Bows in, ends on a raised
  fist or a horse-stance punch. Personality: precise, still between strikes, explosive.
- **Vexa, capoeira/taekwondo acrobat.** Never still: a ginga where the feet trade back steps every
  0.75 s and the same-side arm sweeps across the face. Spinning outside kicks, a handstand upkick
  launcher, a flip kick reversal, a cartwheel that passes through, a tumbling dive kick. Cartwheels
  in; wins with a flourish or a low ginga crouch.
- **Lyra, savate/taekwondo kicker.** Tall and narrow on the balls of her feet with a light bounce,
  hands loose and low. Long precise kicks from a high chamber (fouetté, chassé, a spinning back kick),
  a hopping axe overhead, a vaulting axe kick, and the Starguard counter stance answered by a spinning
  back kick. Salutes with a held head-high kick.
- **Brann, wrestler-boxer heavyweight.** Hunched behind the gauntlets (spine forward 20 degrees),
  wide, a slow heavy side-to-side weight shift. Looping hooks that turn the whole body, a big
  haymaker, a two-handed hammer drop, an armoured shoulder advance, a suplex command grab and the
  Mountain Drop slam. Smashes the gauntlets together to start.

Each legend has: stance/idle, walk forward/back, dash/backdash, crouch, jump, high/low block, high
and low hit reactions, juggle, knockdown and get-up, wake-up roll, intro, two victory poses and a
defeat pose, a throw and a throw reaction.

### 16.7 Move lists and frame data

Startup counts the first active frame (startup 5 = the 5th frame hits). On block / on hit assume the
first active frame connects; KD = knockdown or launch. Air attacks show a deep jump-in (hit just
before landing). The sim measures these numbers in `tests/combat/pure_fight/test_pure_fight_frames.gd`,
and the tables below are printed from `PureMoves` by `tools/diag/pure_fight_tables.gd`.


#### Kael

| Move | Input | Startup | Active | Recovery | On block | On hit | Damage | Guard | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Snap Jab | `5L` | 4 | 2 | 7 | +0 | +3 | 30 | mid | chains |
| Reverse Punch | `5M` | 6 | 3 | 12 | -3 | +2 | 55 | mid | chains |
| Front Snap Kick | `5H` | 9 | 3 | 20 | -5 | +3 | 85 | mid | cancels into techniques |
| Shin Kick | `2L` | 5 | 2 | 8 | -2 | +1 | 25 | low | chains |
| Low Straight | `2M` | 6 | 3 | 11 | -3 | +2 | 50 | mid | chains |
| Crane Uppercut | `2H` | 7 | 4 | 24 | -16 | KD | 70 | mid | launcher, cancels into techniques |
| Leg Sweep | `3H` | 8 | 3 | 23 | -12 | KD | 75 | low | knockdown |
| Hammer Fist | `6M` | 17 | 2 | 14 | -4 | +2 | 55 | overhead |  |
| Driving Side Kick | `6H` | 14 | 3 | 18 | -4 | KD | 80 | mid | wall bounce |
| Air Knee | `j.L` | 4 | 8 | 0 | +6 (deep) | +9 (deep) | 30 | high |  |
| Air Chop | `j.M` | 6 | 6 | 0 | +9 (deep) | +13 (deep) | 50 | high |  |
| Flying Side Kick | `j.H` | 8 | 6 | 0 | +12 (deep) | +17 (deep) | 80 | high |  |
| Kiai Elbow | `5L > M` | 5 | 2 | 14 | -4 | +2 | 45 | mid | cancels into techniques |
| Kiai Front Kick | `5M > H` | 7 | 3 | 20 | -7 | KD | 80 | mid | launcher |
| Iron Lunge | `236 + attack` | 12 | 4 | 18 | -6 | +2 | 100 | mid | finisher cancel on hit |
| Skyward Fist | `623 + attack` | 3 | 10 | 29 | -24 | KD | 120 | mid | strike invuln 1-8, launcher, 2 hits, finisher cancel on hit |
| Ridgeback Kick | `214 + attack` | 20 | 3 | 16 | -5 | KD | 90 | overhead | ground bounce |
| Thousand Petal Breaker | `236236 + attack / finisher key` | 6 | 6 | 40 | -26 | KD | 320 | mid | strike invuln 1-12, cinematic, needs full meter |
| Shoulder Throw | `throw (close)` | 5 | 2 | 23 | - | KD | 110 | throw |  |

#### Vexa

| Move | Input | Startup | Active | Recovery | On block | On hit | Damage | Guard | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Backfist Flick | `5L` | 4 | 2 | 7 | +0 | +3 | 30 | mid | chains |
| Chapa Push Kick | `5M` | 7 | 3 | 12 | -3 | +2 | 55 | mid | chains |
| Armada Spin Kick | `5H` | 10 | 4 | 19 | -5 | +3 | 85 | mid | cancels into techniques |
| Rasteira Tap | `2L` | 5 | 2 | 8 | -2 | +1 | 25 | low | chains |
| Low Ponteira | `2M` | 6 | 3 | 12 | -4 | +1 | 50 | mid | chains |
| Bananeira Upkick | `2H` | 8 | 4 | 24 | -16 | KD | 70 | mid | launcher, cancels into techniques |
| Half-Moon Sweep | `3H` | 9 | 4 | 22 | -12 | KD | 75 | low | knockdown |
| Flip Heel | `6M` | 18 | 2 | 13 | -3 | +3 | 55 | overhead |  |
| Hooking Heel | `6H` | 13 | 3 | 19 | -6 | KD | 80 | mid | wall bounce |
| Air Toe Flick | `j.L` | 4 | 8 | 0 | +6 (deep) | +9 (deep) | 30 | high |  |
| Air Scissor | `j.M` | 6 | 6 | 0 | +9 (deep) | +13 (deep) | 50 | high |  |
| Air Spin Kick | `j.H` | 8 | 6 | 0 | +12 (deep) | +17 (deep) | 80 | high |  |
| Tornado Step | `5L > M` | 6 | 3 | 13 | -4 | +1 | 45 | mid | cancels into techniques |
| Spin to Sweep | `2M > H` | 9 | 3 | 22 | -12 | KD | 75 | low | knockdown |
| Crescent Wheel | `236 + attack` | 11 | 8 | 18 | -11 | -4 | 105 | mid | 2 hits, finisher cancel on hit |
| Flip Kick | `623 + attack` | 4 | 8 | 30 | -23 | KD | 115 | mid | strike invuln 1-8, launcher, finisher cancel on hit |
| Cartwheel Evade | `214 + attack` | 1 | 0 | 26 | - | - | 0 | none | strike invuln 3-18, passes through |
| Tumbling Dive Kick | `j.2 + H (air)` | 6 | 30 | 0 | -1 (deep) | +6 (deep) | 70 | high |  |
| Hurricane Ginga | `236236 + attack / finisher key` | 5 | 6 | 42 | -28 | KD | 310 | mid | strike invuln 1-11, cinematic, needs full meter |
| Scissor Takedown | `throw (close)` | 5 | 2 | 23 | - | KD | 110 | throw |  |

#### Lyra

| Move | Input | Startup | Active | Recovery | On block | On hit | Damage | Guard | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Lead Jab | `5L` | 4 | 2 | 7 | +0 | +3 | 30 | mid | chains |
| Fouetté | `5M` | 7 | 3 | 12 | -3 | +2 | 55 | mid | chains |
| Chassé | `5H` | 10 | 3 | 20 | -5 | +3 | 85 | mid | cancels into techniques |
| Low Coup de Pied | `2L` | 5 | 2 | 9 | -2 | +1 | 25 | low | chains |
| Low Fouetté | `2M` | 7 | 3 | 12 | -4 | +1 | 50 | mid | chains |
| Fan Kick Launcher | `2H` | 8 | 4 | 24 | -16 | KD | 70 | mid | launcher, cancels into techniques |
| Revers Sweep | `3H` | 9 | 3 | 23 | -12 | KD | 75 | low | knockdown |
| Hopping Axe | `6M` | 18 | 2 | 14 | -4 | +2 | 55 | overhead |  |
| Spinning Back Kick | `4H` | 13 | 3 | 19 | -6 | KD | 85 | mid | wall bounce |
| Air Snap Kick | `j.L` | 4 | 8 | 0 | +6 (deep) | +9 (deep) | 30 | high |  |
| Air Crescent | `j.M` | 6 | 6 | 0 | +9 (deep) | +13 (deep) | 50 | high |  |
| Air Thrust Kick | `j.H` | 8 | 6 | 0 | +12 (deep) | +17 (deep) | 80 | high |  |
| Double Fouetté | `5M > M` | 6 | 3 | 15 | -7 | -1 | 50 | mid | cancels into techniques |
| Jab-Chassé | `5L > H` | 8 | 3 | 20 | -7 | KD | 80 | mid | launcher |
| Vaulting Axe | `236 + attack` | 21 | 3 | 16 | -5 | KD | 95 | overhead | ground bounce |
| Rising Crescent | `623 + attack` | 4 | 8 | 30 | -23 | KD | 115 | mid | strike invuln 1-8, launcher, finisher cancel on hit |
| Starguard Counter | `214 + attack` | 1 | 0 | 24 | - | - | 110 | none | counters strikes 3-22 |
| Constellation Rush | `236236 + attack / finisher key` | 6 | 6 | 40 | -26 | KD | 315 | mid | strike invuln 1-12, cinematic, needs full meter |
| Savate Hip Toss | `throw (close)` | 5 | 2 | 23 | - | KD | 110 | throw |  |

#### Brann

| Move | Input | Startup | Active | Recovery | On block | On hit | Damage | Guard | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Gauntlet Jab | `5L` | 5 | 2 | 8 | -1 | +3 | 35 | mid | chains |
| Body Hook | `5M` | 8 | 3 | 13 | -4 | +2 | 65 | mid | chains |
| Haymaker | `5H` | 13 | 4 | 21 | -7 | +3 | 100 | mid | cancels into techniques |
| Toe Stomp | `2L` | 6 | 2 | 9 | -3 | +1 | 30 | low | chains |
| Gut Uppercut | `2M` | 7 | 3 | 13 | -5 | +1 | 60 | mid | chains |
| Lifting Uppercut | `2H` | 9 | 4 | 25 | -17 | KD | 80 | mid | launcher, cancels into techniques |
| Trip Hook | `3H` | 10 | 3 | 24 | -13 | KD | 85 | low | knockdown |
| Hammer Drop | `6M` | 20 | 3 | 15 | -6 | +1 | 70 | overhead |  |
| Armoured Shoulder | `6H` | 16 | 4 | 18 | -6 | KD | 90 | mid | 1-hit armour 5-16, wall bounce |
| Air Elbow | `j.L` | 5 | 7 | 0 | +6 (deep) | +9 (deep) | 35 | high |  |
| Air Hammer | `j.M` | 7 | 6 | 0 | +9 (deep) | +13 (deep) | 60 | high |  |
| Body Splash | `j.H` | 9 | 8 | 0 | +12 (deep) | +17 (deep) | 90 | high |  |
| One-Two Hook | `5L > M` | 7 | 3 | 14 | -5 | +1 | 55 | mid | cancels into techniques |
| Hook-Haymaker | `5M > H` | 11 | 4 | 22 | -11 | KD | 95 | mid | launcher |
| Bull Charge | `236 + attack` | 14 | 6 | 18 | -8 | +0 | 105 | mid | 1-hit armour 4-19, finisher cancel on hit |
| Gauntlet Uppercut | `623 + attack` | 5 | 7 | 31 | -23 | KD | 125 | mid | strike invuln 1-8, launcher, finisher cancel on hit |
| Iron Suplex | `214 + attack` | 6 | 3 | 32 | - | KD | 160 | throw | unbreakable |
| Mountain Drop | `236236 + attack / finisher key` | 5 | 3 | 42 | - | KD | 330 | throw | strike invuln 1-8, unbreakable, cinematic, needs full meter |
| Bear Hug Toss | `throw (close)` | 5 | 2 | 23 | - | KD | 130 | throw |  |

Fairness rules (tested): every legend has a reversal (strike-invulnerable from frame 1), an
anti-air, a low, an overhead and a throw; nothing is plus on block; only lights are safe on block;
reversals are at least -15 on block.

### 16.8 AI

`PureFightAI` (`game/ai/pure_fight_ai.gd`), levels 1-5: reads the opponent's move after a reaction
delay (24 down to 6 ticks) and blocks high or low with a level-scaled chance; anti-airs with its 623
technique or crouching heavy; punishes whiffed recovery; spaces with walks, dashes and jump-ins; runs
its target combos and cancels confirmed hits into techniques or the finisher. Deterministic from its
seed and never touches the sim's rng.

### 16.9 Modes

Play > Pure Fight (vs AI or a second local player on the same keyboard), Training > Pure Fight
Training (a dummy that stands, blocks all, crouch-blocks or jumps: T or F4; health refills, meter full,
frame data on screen), and Multiplayer > Duo with the host's **Game: Pure Fight 1v1** choice (16.10).

### 16.10 Online

Pure Fight 1v1 runs through the Duo lobby (`DuoScreen` / `DuoLink`, §8.2):
- The host steps **Game** between Duo vs AI and Pure Fight 1v1. Both players pick legends and the
  host picks the zone (AI, lives and minutes don't apply).
- Start sends one config (`mode pure_fight_online`, seed, legends, zone) to both peers.
- Each peer builds the same `PureFightSim` and steps it through `RollbackSession` (2-tick input
  delay, up to 8 ticks of rollback, state hashes every 30 ticks). The host plays the left fighter,
  the guest the right one, both on P1's keys.
- The match waits for the partner to load.
- If the partner leaves (or 30 s pass without a packet), the match carries on locally against the
  AI. Results go back to the Duo lobby.
