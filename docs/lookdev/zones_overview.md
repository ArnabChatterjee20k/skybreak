# Look-dev: the seven zones at a glance

One page to keep the zone set varied and coherent. Each zone's full sheet is in `docs/lookdev/<zone>.md` (Heartbloom's is the template). The rule: **no two zones share a hue family, a hero time of day, a landmark shape or an accent**, and every zone obeys the same readability contract with the four legends.

## The set
| Zone | Hue family (base) | Hero time of day | Signature landmark (shape) | Accent colour (the one saturated thing) | Value plan near / mid / far |
|---|---|---|---|---|---|
| **Heartbloom Gardens** | rose blossom and spring green, pastel | sunset (pink-gold dusk) | the Heart Arch (a heart-shaped arch) | soft lantern peach `#F0D2B0`, low emission (with one pale-blue replacement lantern) | light lawn / light blossoms / mid-light sky and cloud sea |
| **Shattered Mesa** | terracotta bands on cream sand | high noon | the Red Arch (a natural strata arch) | chartreuse lichen `#B4D23C` (~75°) | light sand / mid banded rock / cobalt sky, pale horizon |
| **Skyhold Ruins** | honey limestone and ivory marble, sage | golden hour (sun still up) | the Crown Gate (a monumental arch on the biggest island) | verdigris bronze `#4AB49A` (~165°) | light paving / dark undersides / bright cloud sea, blue sky |
| **Stormfall City** | slate concrete, blue-black wet asphalt | thunderstorm midnight | the Spire Tower (a needle with a beacon) | magenta neon `#FF3CA8` (~325°) | dark mirror street / dark facades / lighter storm-glow sky |
| **Frozen Peaks** | blue-white snow, slate rock | aurora night (moonlit) | the Ice Crown Peak (a summit ringed with ice teeth) | aurora green `#5CE0A0` (~150°), in the sky | bright snow / dark slate / darkest indigo sky |
| **Verdant Falls** | three jungle greens, wet basalt, white water | sunrise mist | the Great Falls (a white vertical sheet) | orchid pink-magenta `#E05AC8` (~310°) | mid moss / dark canopy / white falls and mist |
| **Ember Rift** | pale ash, black obsidian | eruption night | the Caldera Vent and its smoke plume (a column) | amber lava `#FFB040` (~38°) | pale ash / black spires and walls / lava-lit mid sky |

## Why it holds together
- **Value plans differ:** three zones put the fighters on a **light floor** (Heartbloom, Mesa, Frozen), two on a **mid floor in a dark frame** (Verdant, Ember), one on **light lids over a bright cloud floor** (Skyhold), and one on a **dark mirror under a lighter sky** (Stormfall). Day, dusk and night versions of each zone keep their hero's value order.
- **Times of day differ:** sunrise, noon, golden hour, sunset, two different nights (wet neon vs clear moonlit) and an eruption night lit from below. Each zone still ships all three presets; the hero is what its key image and sheet are tuned for.
- **Landmark shapes differ:** heart arch, natural arch on the ground, monumental gate in the sky, needle tower, crowned summit, waterfall sheet, smoke column. The two arches are told apart by setting (a garden island vs a desert floor vs a sky temple) and material (laid rose stone vs strata vs marble voussoirs).
- **Accents are spread around the wheel:** ~25° (peach, soft), ~38° (lava), ~75° (lichen), ~150° (aurora), ~165° (verdigris), ~310° (orchid), ~325° (magenta neon). The near pairs are split by everything else: aurora is sky light at night while verdigris is bronze in daylight; orchid is a tiny daytime flower while magenta is emissive neon at night. Lantern peach is pastel and dim; lava is saturated and bright.

## The readability contract (same in every sheet)
The fighters own saturation; zones own value structure.

| Legend | Accent / energy | Main mass | What every zone guarantees |
|---|---|---|---|
| Kael | burnt-orange scarf (~22°), orange-white energy | deep teal coat, L\* ~38 | no saturated orange or teal surfaces; rock and lava stay below his scarf's saturation |
| Vexa | electric violet (~270°), violet-white | near-black bodysuit L\* 10, silver jacket L\* 59 | no violet fog, sky or neon; dark zones keep a strong cool rim and a lighter ground or sky behind her |
| Lyra | cerulean (~210°), blue-white starlight | navy L\* 16, parchment L\* 75 | skies saturated only high above the horizon; ice and water never cerulean; no parchment-coloured cloth props |
| Brann | ember-red beard (~8°), molten crack lines | granite L\* 45, basalt 36, olive moss | lava is broad and amber, never thin red lines on walls; moss near spawns is lighter and yellower than his |

Shared rules:
1. **Saturation ceiling** ~45% on every zone surface (snow zones ~30%); only the zone's accent goes past it, and it covers ≤ 3–8% of the screen.
2. **No saturated gold anywhere** (the item family) and none of the team-rim colours as zone light.
3. **Each zone has a value plan** with near, mid and far in different bands, and **a sky that contrasts with the ground**.
4. **At least 5 storytelling props** per zone, one original zone emblem.
5. **Detail at three scales** on the shared T0–T3 cell ladder (2.2 / 8.8 / 35 / 140 cm); walkable tops at T1 within ±4.4 cm of the sim floor.
6. Every sheet lists the **preset fixes** it needs in its `.tres` (most fogs currently copy the ground colour), as notes for the build pass, not as changes now.

## Shared zone kit (built once, used by all seven)
| Kit piece | Used by |
|---|---|
| Terrain columns from the baked heightmap, per-tier chunk meshing with a per-chunk colour texture, baked AO | all six ground zones |
| Island mesher (column/terrace mesher over an outline: round for Heartbloom's `IslandField`, fractured polygon for Skyhold) | Heartbloom, Skyhold |
| Strata/band painter and column pattern for steep faces | Mesa, Ember, Frozen, Verdant, Skyhold undersides |
| Cap pass (paint top- or north-facing cells: moss, snow, ash, lichen) | all |
| Instanced prop pipeline (`VoxelDesign` builds as MultiMesh variants with per-instance tint, T0 fade, T2 LOD, impostors) | all |
| Tree builder (faceted trunk, limbs, stepped leaf or blossom masses) | Verdant, Heartbloom |
| Stone-block builders (drum columns, voussoir arches, laid blocks) | Skyhold, Heartbloom's arch, Stormfall's Old Tower, Ember's forge-shrine |
| Emitter bounce bake (lava, neon, lanterns) | Ember, Stormfall, Heartbloom |
| T3 puff clouds (cloud sea, plume, spray, spindrift) | Skyhold, Heartbloom, Ember, Verdant, Frozen, Mesa |

Zone-specific builders are listed in each sheet's build notes (Stormfall's facade builder is the largest).

## Suggested order
Heartbloom first (the gift, already in look-dev), then **Skyhold** (reuses the island mesher and stone builders), **Verdant** (the tree builder), **Shattered Mesa** (strata painter), **Ember Rift**, **Frozen Peaks**, and **Stormfall** last (its facade builder is the biggest new piece). One zone at a time, owner gates each.
