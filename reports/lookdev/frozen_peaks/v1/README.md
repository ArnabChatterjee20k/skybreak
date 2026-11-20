# Frozen Peaks: look-dev v1

Design sheet: `docs/lookdev/frozen_peaks.md`. Kit: `game/world/voxel_zone_kit/README.md` (from `lookdev/heartbloom-zone`). Code: `game/world/zones_voxel/frozen_peaks/` on branch `lookdev/zone-frozen_peaks`.

Rendered with official Godot 4.7.2 (linux x86_64, SHA-512 checked against `SHA512-SUMS.txt`, fresh `.godot` import) on **lavapipe** under xvfb, 1920×1080, MSAA 4×, the kit's stack (SSAO + baked AO, soft 2-split sun shadow, glow, fog, rim). Every published still and the fly-through contact sheet were looked at. **Not yet seen on a real GPU.**

```sh
godot --path . --disable-vsync -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out> heroes \
    --zone=res://game/world/zones_voxel/frozen_peaks/frozen_peaks_voxel.gd
godot --path . --disable-vsync -s res://game/world/voxel_zone_kit/zone_capture.gd -- <out> flythrough \
    --time=night --fps=30 --seconds=20 --zone=res://game/world/zones_voxel/frozen_peaks/frozen_peaks_voxel.gd
```

## The sim stays the truth

- **Ground:** the baked `TerrainHeightmap` (`TerrainShape._peaks`). The valley floor is a smooth top on a 1 m lattice aligned with the 2 m sim grid, so the visible floor stays within 4.4 cm of `ZoneGround` (tested: `tests/world/test_frozen_peaks_voxel.gd`). The first pass used the kit's 1.4 m quadtree blocks and the new test caught it 7.9 cm off; fixed before rendering.
- **Props:** `FrozenPeaksProps.build` runs exactly as `ZoneMatch` runs it (fresh `PropKit`, seed 4242, every ground zone's spawns kept clear), and the voxel spires, shelves and boulders take its 60 / 26 / 120 transforms. Spires pick the closest of 6 variants and keep the sim's base and height exactly (footprint within ±15%); shelves keep the sim box's centre, jut and width exactly; boulders keep centre and size. Tested.
- No sim, gameplay, `.tres` or kit change. Everything new is under `game/world/zones_voxel/frozen_peaks/`.

## What's built (sheet → build)

| Scale | Built |
|---|---|
| Big forms | glacier band (cyan-grey ice with flow streaks, clear margins) down the valley's S-curve; snow floor; T2 foothill terraces; T3 slate mountains with strata walls and snow on every ledge (slope + coherent noise rule); the Ice Crown as a ring of 11 faceted ice teeth around the highest summit near the landmark; a stand-in range beyond the zone box |
| Medium | 6 spire-cluster variants (hex prisms with stepped tips, 2–4 tilted satellites, snow on every up face); 4 stratified shelf variants (ice / blue / old-snow layers, drifted top, cornice, jagged outer edge, icicle fringe); 6 faceted boulders (3 ice, 3 slate with tilted strata); 47 crevasses with raised clear-ice lips; 10 slate cairns every 60 m; the frozen waterfall on the north cliff; the camp; the rope bridge; sastrugi ridges |
| Tiny | sastrugi colour ripples, frost sparkle cells, trapped bubbles in the glacier, icicles, rope lashings and guy-lines, crate seams and iron corners, lichen spots, the mug, the lantern, the tally marks, boot prints, drift against every windward foot |

**Storytelling (6):** the standing tent with its flap tied open and a lantern glowing inside, beside the collapsed tent under a drift; the crate stack with a mug on top; the half-buried sledge with three lashed crates, one split open on coiled rope; boot prints along the cairn line that stop at a crevasse, the fresh-planked rope bridge beside it; an ice axe frozen into the spire nearest the camp at head height; the flag tripod with a torn pennant (±4° stiff flap); the first cairn, taller, with a tally-marked capstone and the Crown Star carved on its biggest slab. **Emblem:** the Crown Star (six points, the top three longer) on the crates and the first cairn.

**Value plan:** night (hero) is bright snow / dark slate / darkest indigo sky with the aurora as the only saturated colour, high over the Ice Crown, voxel-stepped curtains in a zone sky shader (`frozen_sky.gdshader`). Day flips the sky to a mid blue darker than the snow. Dusk uses the sheet's colder lilac fog.
