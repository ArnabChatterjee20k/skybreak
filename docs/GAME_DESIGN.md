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
| Ascend / Descend | `Space` / `Left Ctrl` | Hold for continuous flight. Tap Space on the ground = jump |
| **Light attack** | `Left Mouse` | Strings, hit-confirms |
| **Heavy attack** | `Right Mouse` | Direction + heavy = different heavies (see §5.3). Hold = charged smash |
| **Block** | `E` (hold) | **Tap** just before a hit = perfect block (§5.4) |
| **Dash** | `Left Shift` + direction | Tap = short step. Hold = sustained flight-dash. Toward the target while locked = rush dash |
| Grab | `F` | Beats block. Loses to strikes |
| Pick up / throw item | `G` | Tap near an item to pick it up. Tap while holding a weapon to throw it at the target |
| Ki blast | `Q` | Tap = rapid shot. Hold = charged blast |
| Charge ki | `R` (hold) | Fast ki gain, but you're vulnerable |
| Specials 1 / 2 / 3 | `1` `2` `3` | Character-specific (cost ki) |
| Ultimate | `4` | Costs burst. Cinematic on hit |
| Transform | `T` | Costs burst. Drains ki over time |
| **Vanish** | `Shift + E` | While blocking or in the first frames of hitstun = vanish counter (§5.5) |
| Combo breaker | `X` | While in hitstun. Costs 1 burst stock |
| Lock-on toggle | `Middle Mouse` | |
| Switch target | `Tab` | For later multi-opponent modes |
| Cycle weapons | `Mouse Wheel` | Unarmed → slot 1 → slot 2 (wraps) |
| Quick-swap weapon | `C` | Toggles between the current and the last-used weapon |
| Camera | Mouse movement | Free orbit when unlocked; small offset orbit when locked (§4) |
| Pause / menu | `Esc` | |

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
| **Ki** | 100 (shown as 4 bars) | +2/s passive, +25/s while charging (`R`), +3 per landed hit, +2 per blocked hit | Dash 8, rush dash 15, vanish step 20, vanish counter 25 (40 for the second in one exchange), ki blast 4, charged blast 20, specials 25–50 | At 0 ki: no dashes or vanishes; you can still fight with melee |
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
| Ctrl + RMB | Spike | Slams the target down (ground bounce or knockdown) | −10 |
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
| **Perfect block** | Tap `E` 0–6 f before a hit lands | Strikes (attacker gets +16 recovery = free punish), ki blasts (**reflected**) | Grabs, delayed attacks (frame traps) | Nothing; mistiming means a 20 f lockout on the next perfect-block attempt (anti-mash) |
| Grab tech | Press `F` within 10 f of being grabbed | Grabs | — | — |
| Sidestep | Dash A/D at mid range | Beams, charged blasts, straight smash | Sweep heavy, homing blasts | 8 ki |
| Vanish counter | `Shift+E` while blocking or in the first 6 f of hitstun | Strings, smash | Opponent's counter-vanish or **Sense** (§5.5) | 25 / 40 ki |
| Combo breaker | `X` in hitstun | Any combo | Nothing (guaranteed escape), but it's expensive | 1 burst stock |
| Push-block | Heavy while blocking | Pressure strings (pushes them to mid range) | — | 10 guard |

**Rock-paper-scissors at close range:** *Strike* beats *Grab* (counter-hit), *Grab* beats *Block*, *Block / perfect block* beats *Strike*. Every close exchange is a read.

### 5.5 The vanish game, fixed

The classic arena-fighter problem: teleport, counter-teleport, counter-counter-teleport, forever. Skybreak's rules:

1. A **vanish counter** puts the defender behind, above or below the attacker. The **defender chooses** with the direction held on the tick the vanish triggers: `Space` = above, `Ctrl` = below, anything else (including `S`, nothing, or both `Space` and `Ctrl`) = behind. Movement doesn't apply while blocking, in hitstun or during a vanish, so these keys can't collide with ascend, descend or back-dash. It's a guess, not a reflex. The attacker's counter-vanish guess is read the same way on the tick they press it.
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
- Knockback into a **wall** gives a wall-splat (30 f, a free follow-up, no tech). Knockback into a **destructible** gives +150 damage, the rock shatters, and the fighter keeps flying (no splat).

### 5.7 Knockdown and wakeup (okizeme)

On knockdown, the defender picks:
- **Tech roll** forward, back or sideways (WASD + Space within 10 f of landing)
- **Neutral wakeup** (do nothing; up after 40 f)
- **Delayed wakeup** (hold Ctrl; up after 70 f, which messes with the attacker's timing)

Every wakeup has 6 f of invincibility, then is vulnerable. The attacker reads it and sets up a strike, a grab or a bait.

### 5.8 Ki blasts and beams: zoning that can be beaten

- **Tap blasts** (4 ki): fast, weak, small chip. They interrupt ki charging. They're absorbed by dashing toward them (dash armor against tap blasts only, +2 ki cost per blast absorbed).
- **Charged blast** (20 ki): a big projectile that dash doesn't absorb. You must block, sidestep or perfect-block (reflect).
- **Beams** (special or ultimate, 40–100 ki): long startup (≥24 f) with a big tell. They're dodged by sidestepping, and if they whiff the recovery is huge.
- **Beam Clash:** if two beams meet, a **rhythm minigame** starts. Four to eight beat prompts on `Q`/`E`/`F`/`R` scroll toward a hit line; accuracy pushes your beam forward. Spending ki mid-clash adds push. The loser takes the beam's full damage; the winner gains 50 burst. Mashing does nothing, because only on-beat presses count.
- **Anti-turtle:** charging ki is loud (aura sound and visual tell) and leaves you vulnerable, so the opponent can always punish a charger by rush-dashing.

### 5.9 Transformations and ultimates

- **Transform** (`T`, 1 burst stock): a 1.5 s cinematic (skippable, invincible). Gives +15% damage and speed, new specials and a new ultimate, but **drains 5 ki/s**. When ki hits 0 you **revert with Exhaustion** (2 s of slower movement and no dashes). Timing a transformation is a strategic decision.
- **Ultimate** (`4`, 2 burst stocks): each character has 2 (one base, one transformed). On hit, it plays a cinematic with camera cuts (skippable after first view). On whiff it's punishable. A **Last Stand** rule: below 15% health, once per match, you get 1 free burst stock.

### 5.10 Game feel ("juice") values

| Event | Hitstop (both fighters freeze) | Camera shake | Other |
|---|---|---|---|
| Light hit | 4 f | none | small white spark |
| Heavy hit | 8 f | 0.15 (directional) | orange spark, impact ring |
| Counter-hit (hit during their startup) | +4 f | +50% | "COUNTER" text pop, red flash |
| Perfect block | 10 f | 0.1 | blue flash, bright "tink" sound, slight time-slow (0.8× for 6 f) |
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
  - `C` quick-swaps between the current weapon and the last one you used, the fastest way to flip between, say, a revolver and a blade.
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

**Kael's look (binding, original design; supersedes any earlier brief):**
- **Hair:** silver-white, swept back with volume (not upward spikes), one crimson streak over the left brow, short tail at the nape.
- **Outfit:** a sleeveless, high-collared fitted coat in **teal and charcoal** with **gold trim**, split at the hips into two tails; an **asymmetric white sash** from right shoulder to left hip; black fitted pants; **orange armoured shin guards** over dark boots; **fingerless dark gloves** with gold knuckle plates.
- **Signature:** a **long orange scarf** that trails in flight and dashes (secondary motion).
- **Energy colour:** orange-white (aura and rim), unchanged.
- **Do not** use: an orange gi, a blue/navy undershirt with matching wristbands, a wide knotted belt over a gi, white boots, or tall black upward spikes. Together those read as an existing anime hero.
- The same rule applies to every fighter: each design must be checked against well-known characters in the genre before it's built.

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
