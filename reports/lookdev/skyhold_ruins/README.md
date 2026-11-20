# Skyhold Ruins: look-dev v1

Design sheet: `docs/lookdev/skyhold_ruins.md`. Kit: `game/world/voxel_zone_kit/README.md` (used as-is, no kit edits). Code: `game/world/zones_voxel/skyhold_ruins/` on branch `lookdev/zone-skyhold_ruins`.

Rendered with official Godot 4.7.2 (linux x86_64, SHA-512 checked against `SHA512-SUMS.txt`) on **lavapipe** (software Vulkan, colour-correct, slow) under xvfb, 1920×1080, MSAA 4×, with the kit's full stack (SSAO + baked AO, soft sun shadow, glow, fog, rim). Every still and the fly-through contact sheets were looked at before publishing. **Not yet seen on a real GPU.**

No GitHub release: this session has no `gh`/release API, so the previews are committed here instead (the task's fallback).

```sh
godot --path . --disable-vsync -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out> heroes \
    --zone=res://game/world/zones_voxel/skyhold_ruins/skyhold_ruins_voxel.gd
godot --path . --disable-vsync -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out> flythrough --time=day \
    --zone=res://game/world/zones_voxel/skyhold_ruins/skyhold_ruins_voxel.gd
# Fly-through clearance check (no frame inside an island, arch or fang):
godot --headless --path . -s res://game/world/zones_voxel/skyhold_ruins/flight_probe.gd
```

## Verification

Clean checkout of this branch, `rm -rf .godot`, `godot --headless --import` (exit 0), then the full GUT run: **1546 tests, 1540 passing, 0 failing**, 11 pending (pre-existing known issues: QA-11, QA-12 and similar), 379 s. New tests: `tests/world/test_skyhold_ruins_voxel.gd` (layout matches the sim's builder, landmarks, every column inside its fractured outline, paving = top + cap, a built top within half a T1 cell of the floor, saturation ceiling). Writing that test caught a real bug: columns on stacked islands were first assigned to the nearest centre instead of their own island.

## Assets

- `skyhold_ruins_v1_<shot>_<time>.jpg`, 1920×1080, plus `skyhold_ruins_v1_contact_sheet.jpg`:
  - **crown_gate** (key image) at day (golden hour), dusk and night: the Crown Gate, the striped column shadows across the plaza, the two bronze keepers, the altar, Kael under the gate
  - **stairs**: the stairs to nowhere over the cloud sea, Kael on the top step
  - **fallen_statue**: the face-down bronze keeper on Watch Island, Kael beside it, the Watch stump behind
  - **overview** at day, dusk and night
  - **kael_scale** (day, night): gameplay-height camera on Kael beside the one lit brazier
  - **fangs**, **underside**, **chains** (the snapped chains between two islands), **sundial**
- `skyhold_ruins_flythrough_v1.mp4`: 1920×1080, 30 fps, 20 s (600 frames), golden hour. The task asked for 720p; the skill's quality rule (1080p30 minimum) overrides that. Path: down into the cluster past the lit brazier, under Watch Island's strata, over the fallen statue, past the snapped chains, low round a Fang Rock over the cloud sea, up and through the Crown Gate, out over the far rim. Checked frame by frame for clipping with `flight_probe.gd` (0 of 600 frames inside geometry).

## What's built (sheet coverage)

- **The sim is the truth.** `SkyholdRuinsLayout` runs the sim's own `SkyholdRuinsProps` (PropKit seed 4242, `ZoneMatch`'s focus-zone order) and reads its 34 islands, 186 columns and 18 arches back. Paving sits on each island's grey-block cap top (`top + 0.6`), exactly (test: within half a T1 cell); columns and arches keep their sim positions, radii and yaws; the fangs are the baked heightmap (notches cut at most one 1.4 m slab in); the cloud sea is the world's 40 m plane. No sim, gameplay or kit file changed.
- **Big forms:** fractured polygon islands (5–8 chords per island, rim broken along 0.9 m blocks), flat paved tops, stepped strata undersides to the sim depth with hanging rock drips, the Crown Gate (attic with a cast bronze Winged Keystone), the Watch stump (T2), the Fang Rocks, the cloud deck with T3 puff towers round the fangs.
- **Medium:** fluted drum columns (whole + 4 broken heights, plinth, base, capital, 20 flutes, drum joints), voussoir arches (13 voussoirs, keystone, ashlar spandrels, glyph frieze, cornice; whole and ruined), stairs, collapsed walls with windows, fallen columns, altars, bronze braziers, robed keepers and winged lions on plinths, rubble, hanging roots and foundation blocks under every rim.
- **Tiny:** flagstone joints drawn per T1 cell (staggered rows, a ring-paved centre plaza, a marble stylobate ring under each colonnade), moss in joints creeping in from the rims, joint wildflowers plus T0 flower clumps, chips on column skins, ivy, patina streaks under bronze, an original glyph band, the Winged Keystone on keystones, plinths and altars, chain links (T0), nests with eggs and feathers (T0), offering bowls, birds wheeling round the gate.
- **Storytelling (6):** the fallen keeper face-down on Watch Island with its snapped arm at the rim; the stairs to nowhere; the snapped chains between two islands; the one lit brazier (with an unshadowed OmniLight that flickers); nests on broken capitals with feathers below; the sundial plaza whose gnomon points at the Crown Gate.
- **Value plan:** light honey/ivory lids (near), dark umber strata bodies (mid), a bright cloud sea and a blue sky (far). Verdigris only on bronze.

## Perf

### Mesh budget (the build's `stats`; quads = 2 triangles)

| Part | Count | Quads per copy (tiers) | LOD ranges |
|---|---|---|---|
| Island tops + undersides (34 islands, T2 greedy, ~32 m chunks) | 34 + 34 fields | **490 k** total | none (chunks frustum-culled) |
| Fang Rocks (T2 greedy strata) | 4 | **108 k** total | none |
| Whole column | 124 | 27.7 k / 7.9 k / 1.6 k | 35 / 120 m / ∞; shadows on the first two |
| Broken columns (4 designs) | 62 | 9.7–16.2 k / 2.4–4.4 k / 0.6–0.9 k | same |
| Arch pier | 34 (+2 grand) | 33.8 k / 9.5 k / 2.3 k | 50 / 160 m / ∞ |
| Arch top (whole / ruined, 2×T1 near) | 17 | 49–55 k / 9–10 k | 120 m / ∞ |
| Crown Gate top (T1) | 1 | 318 k / 73 k / 14 k | 60 / 200 m / ∞ |
| Stairs, walls, fallen columns, statues, altars, braziers, gnomon | 1–19 each | 2–29 k / 0.2–3.3 k | 40–70 m / 150–200 m |
| Rubble, roots, foundations | ~670 | 0.9–1.6 k / 0.1 k | 40–50 m / 150–200 m |
| Flowers (T0) | 1.9 k | ~0.6 k | 30 m, no shadow |
| Chain links (T0) | 205 | 240 / 38 | 40 / 220 m |

Tiles: 128 m for sparse props, 16 m for flowers and feathers (fewer draw calls than the kit's 48 m default).

### Per shot (Godot's counters at 1080p; they may count the depth pre-pass and the colour pass both)

| Shot | Visible tris | Draws | Shadow tris | Shadow draws |
|---|---|---|---|---|
| crown_gate (day/dusk/night) | 1.27 M | 82 | 2.33–2.36 M | 96–112 |
| stairs | 1.90 M | 450 | 2.67 M | 151 |
| fallen_statue | 1.52 M | 290 | 1.77 M | 175 |
| overview | 2.29 M | 646 | 0.06–0.11 M | 21–40 |
| kael_scale | 1.29 M | 302 | 0.82–0.88 M | 125–146 |
| fangs | 0.84 M | 215 | 0.40 M | 91 |
| underside | 1.05 M | 251 | 0.67 M | 98 |
| chains | 1.34 M | 256 | 1.27 M | 79 |
| sundial | 1.01 M | 109 | 1.65 M | 75 |

### Estimated budget (an estimate, not a measurement)

**GTX 1650 at 1080p60, medium.** Sheet target: ≤ 1.2 M visible tris, ≤ 250 draws; world ≤ 3 ms GPU.
- **Now:** 0.84–2.29 M visible tris (median ~1.3 M), 82–646 draws, and up to 2.7 M shadow tris. Over target by roughly 10–90% on tris, and up to 2.6× on draws in the wide overview (34 islands × top + underside chunks, plus far prop tiers).
- **Vertex cost:** ~2.5–4 ms for main + shadow passes (the 1650 does roughly 1 G tris/s in practice for this kind of geometry).
- **Pixel cost:** ~1–1.5 ms SSAO, 0.3 ms glow, ~0.5–1 ms terrain/props.
- **Total:** the world probably lands at **4.5–7 ms GPU**. It fits a 16.6 ms frame with room for fighters and VFX, but it is **1.5–2.3× over the zone's 3 ms budget**.
- **Biggest levers (tuning values, not redesigns):** the Crown Gate's T1 top (318 k quads; drop to 2×T1 near, ~73 k), whole-column T1 range 35 → 20 m, shadows only on the first tier of columns and arches (the shadow pass is the larger cost here: long golden-hour shadows across the plaza), a single far tier for undersides of islands beyond 250 m, and merging the 34 islands' top+underside chunks per area to cut draws.
- **The real check** is the render benchmark on the dev PC (AGENTS.md). Lavapipe frame times (1–2.5 s) say nothing about a GPU.

**Web build (Compatibility, WebGL2).** Target ≤ 500 k tris, ≤ 120 draws. The scene is about **2.5–4.5× over on tris and 1–5× on draws**. It needs a web preset that doesn't exist yet: no T1 tier for columns, arches or the gate (start at the 2×/4× tiers), flowers and feathers off, prop shadows off, one shadow split, no SSAO (Compatibility has none), far islands' undersides at the coarse tier only. Rough guess for that preset: ~450–550 k tris, ~120–180 draws, so the draw count still needs the chunk merge.

## Self-critique, ranked by severity

1. **Unproven on hardware and over budget.** Everything here is software rendered; the numbers are counts plus estimates, and the zone is probably 1.5–2.3× over its 3 ms GPU budget and well over its web target. No web preset exists.
2. **The Fang Rocks still read as smooth cones** from a distance. They are stepped strata at T2, but the silhouette is the sim's heightmap cone, and I kept it (the rock is collision terrain; reshaping it visually would make fighters hit invisible rock). A real fix is a sim-side terrain change, or crag props hugging the cone.
3. **Statues read as blocks.** The fallen keeper was a "bronze crate" in two drafts; after slimming it (narrower robe, bigger hood, front folds, a cloak) it reads as a lying hooded figure up close but still as a teal block from mid range. Winged lions read as teal blobs (see the sundial shot). Verdigris is limited to bronze but is still the brightest saturated thing in close shots (well under 3% of the screen).
4. **The paving pattern is very regular.** Rows of rectangular flags on the world grid read clean, but large plazas look like tiled floors; there are no sunken or missing flags (the floor rule keeps the walkable top flat), and the joints fade to flat colour past ~100 m.
5. **The fly-through's bronze keepers use the earlier, boxier statue design** (it was rendering while I slimmed the keepers for the stills; `crown_gate_*` and `fallen_statue` were re-rendered with the new design, the other stills don't show a keeper up close). Speed through the path is uneven (long hops between the fang and the gate).
6. **Night is too bright on the paving** (moonlit ivory reads almost white) and the cloud deck's far edge shows as a straight line in the dusk and night overviews (the kit's deck plane is 3× the zone rect).
7. **The Watch stump's far tier is nearly empty** (4×T2 = 1.4 m cells leaves ~30 quads): past 150 m it pops to a few blocks. Needs a 2×T2 tier.
8. **Sim caveats noticed (not fixed, sim files untouched):** the grey-block arches (`PropKit.merged_boxes`, mesh space y 0..1, placed with `PropKit.placed`'s +0.5 offset) float 10 m above their bases in the sim and in the camera's obstacle boxes; the voxel arches stand on the paving. Columns float 0.4 m over the grey-block cap; the voxel columns bridge that with a stylobate block. Islands are still props only (T-106), so fighters hover through them.
9. **Missing from the sheet:** drifting dust and leaves, island bob (off by the sheet's rule anyway), terraced garden beds, inscriptions on lintels other than the frieze, chain swing, render benchmark output (needs the dev PC).

## Next (v2)
Gate top to 2×T1, a web preset and benchmark numbers from the dev PC; crag props on the fangs; bigger, simpler statue silhouettes; sunken/missing flags inside the floor tolerance via colour only; a closer cloud deck edge; the stump's middle tier; dust and leaves.
