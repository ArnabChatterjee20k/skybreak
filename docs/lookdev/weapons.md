# Look-dev: voxel weapons (sheet v1)

**Goal:** every weapon in the approved voxel style (`docs/lookdev/kael.md`,
`.claude/skills/voxel-character-lookdev/SKILL.md`), so the voxel legends stop
holding the old smooth toon meshes. Look before function: the sim, hitboxes,
grips and weapon stats are untouched, and the old models stay the default
in-game until the owner approves the look.

Code: `game/characters/voxel_weapons/`. Branch: `lookdev/voxel-weapons`.

## How it fits

- Each weapon is a `VoxelWeaponDesign` (a `VoxelDesign` without a skeleton):
  parts painted with the voxel kit's SDFs into `VoxelGrid`s, meshed by
  `VoxelMesher` (cavity AO, corner AO, bevel edges) and merged into one
  static mesh with one surface per shader material (3-4 draw calls).
- **Rigid.** No skin weights: the model rides its hand (or stow) bone through
  the same `BoneAttachment3D` the old models use (`WeaponLayer.attach`,
  `BrannView._stow_weapons`).
- **Drop-in.** Painted in the old model space (grip at the origin, long axis
  +Y, barrels along -Z, bow string at z 0.26), with the same root name, the
  ranged x1.3 root scale and a `String` part on bows. `WeaponGrip` (scale,
  sockets, off-hand points, clearance boxes) is unchanged, so holds, the bow
  draw and the arm IK behave exactly as before. A test pins size and centre
  to the old model's.
- **Cell.** The authored cell is `0.011 / (WeaponGrip.SCALE x ranged 1.3)`, so
  every weapon shows **1.1 cm voxels in the world** at the reference hand,
  the sheets' fine cell. Emblem plates and medallions use half that (5.5 mm).
- **Palette.** Each weapon fills shared material roles (`VoxelWeaponDesign.Mat`)
  with its owner's palette; the energy colour goes on `GLOW`/`GLOW_CORE`
  (GLOW surface, emission 1.1, clamped). Shared pickups stay in the item gold
  family, which no legend uses as an accent.

## Switching it on

| Where | How |
|---|---|
| One character (look-dev) | Add a `VoxelArmory` node (`voxel_armory.gd`) as the **last child of the scene root**. It tags the character's skeletons; `WeaponModels.build_for(kind, skeleton)` then returns the voxel model for everything held or stowed on that character. Voxel Kael has one. |
| Everywhere (pickups, thrown weapons, the chakram disc too) | `WeaponModels.voxel_everywhere = true` (off by default). |
| Off | Remove the node, or set `enabled = false` on it. Old meshes are the default. |

### Hooking up the other voxel legends (their scenes live on other branches)

The weapons are self-contained: nothing here depends on those branches. After
merging, add this to the scene, as the last node under the root:

```
[ext_resource type="Script" path="res://game/characters/voxel_weapons/voxel_armory.gd" id="9_armory"]

[node name="VoxelArmory" type="Node" parent="."]
script = ExtResource("9_armory")
```

(bump `load_steps` by one), in:

- `game/characters/vexa_voxel/vexa_voxel.tscn` (`lookdev/vexa-voxel`): Ki Gauntlets
  and Orbit Chakram in hand. Her idle back-mounted chakram is part of her body
  design (`VexaVoxelDesign.build_chakram`) and is not affected.
- `game/characters/lyra_voxel/lyra_voxel.tscn` (`lookdev/lyra-voxel`): Ki Bow and
  Sky Lance.
- `game/characters/brann_voxel/brann_voxel.tscn` (`lookdev/brann-voxel`): the held
  hammer and cannon, **and** the stowed pair on his back and hip
  (`BrannView._stow_weapons` now calls `build_for`, so it needs no other change;
  the node must come after `Model` so the figure's skeleton exists, and before
  the root's `_ready`, which children always are). Tested on the current Brann
  with `test_a_voxel_armory_swaps_brann_s_stowed_weapons`.

Merge note: this branch edits `brann_view.gd` (one line, `build_for`) and
`weapon_layer.gd` (`build_for` in four places); `lookdev/brann-voxel` does not
touch either file.

## The weapons

Each row is big forms / medium parts / tiny details. Emblems are the legends'
originals from their sheets.

| Weapon | Owner, palette, energy | Big / medium / tiny |
|---|---|---|
| **Storm Blade** | Kael: cool steel, brass gold, orange-brown leather, scarf orange; energy orange-white | Broad diamond-section blade, winged brass guard / glowing fuller, three stepped feathers per guard side, lattice leather wrap, octagonal pommel with energy gems / guard rivets, winged-sky sigil inlaid in brass on the ricasso (5.5 mm), scarf-orange tassel, a nick in the edge |
| **Arc Revolver** | Kael: gunmetal, brass, leather, teal enamel; orange-white | Raked grip, frame, fat cylinder, octagonal barrel / three brass arc coils, trigger guard, hammer spur, teal side plates with an energy conduit / cylinder flutes and six glowing chambers, rib and front sight, grip rivets, winged-sky medallions (5.5 mm), lanyard ring |
| **Ki Gauntlets** (one fist, both hands) | Vexa: gunmetal silver `#8A8F9C`, ash-lilac wraps, charcoal leather, violet `#8A3CF0`; violet-white | Octagonal wrapped cuff, planar hand shell / four two-segment finger plates, thumb plate, raised back plate, riveted side plates, energy wrist band / slanted wrap bands, a violet slit and hot glint on each knuckle, the Crescent Eye inlaid in violet (5.5 mm), a crack stapled with silver wire (her visor story) |
| **Orbit Chakram** | Vexa: chakram steel `#9CA1AE`, edge `#D4D8E0`, wraps; violet-white | Flat ring, four crescent hook teeth / energy inner ring on four struts, wrapped grip bar, grip boss / bevelled bright edges, eight rivets a side (one is her bronze lucky coin), the Crescent Eye engraved on the boss (5.5 mm) |
| **Ki Bow** | Lyra: midnight lacquer, pale brass `#B49A64`, leather, cerulean `#1E7FD8`, parchment; blue-white | Two recurve limbs, brass riser / brass back-edge strips, cerulean inlay, leather grip, arrow shelf, nock caps / three star lights per limb, eight-point star on each tip, Wayfinder Star medallion (5.5 mm), parchment ribbon on the upper limb |
| **Sky Lance** | Lyra: as above; blue-white | Octagonal shaft, leaf head, cerulean pennant / brass bands, socket collar with a broken ring, two leather grips (main and off hand), butt spike / band rivets, degree ticks, energy channel and pale edges on the head, a constellation on the pennant, Wayfinder Stars on the head (5.5 mm) |
| **Titan Hammer** | Brann: granite `#6E6A6C`, basalt, blackened iron `#35353B` (wear `#6A6A72`, new band `#7A7A82`), oxblood leather, moss; molten ember `#FF4A12` / `#FFD9A0` | Chisel-faceted granite head, iron striking faces, long haft / two iron bands (one newer), langets, two leather grips, pommel ring / band rivets, peened dimples, molten seams on both faces and across the stone, the Hearth-Mark glowing on both sides, moss tuft with a tiny white flower |
| **Scatter Cannon** | Brann: as above (no more yellow) | Flared blackened-iron barrel, granite forge breech / three bands (the middle one newer), coal hopper, vent grilles, foregrip under the barrel, raked grip / band rivets, embers deep in the bore, Hearth-Mark on both sides, stitched grip, trigger |
| **Ember Scythe** (pickup) | Item gold `#D9A441`, charcoal, steel; ember | Crescent blade, charcoal shaft / gold spine and collars, ember edge, two leather grips / spine rivets, item spark mark at the blade root (5.5 mm), butt gem |
| **Storm Repeater** (pickup) | Item gold, charcoal, wood; gold | Receiver, stock, three barrels / gold drum, clamp, muzzle ring, foregrip / drum flutes, gold charge rails, stitched cheek pad, item spark on the drum faces (5.5 mm) |
| **Heartstring Bow** (Heartbloom pickup) | Rose lacquer, item gold, Heartbloom pink; pink-white | Lyra's recurve build / gold strips, pink inlay / heart lights, heart medallion, the old model's gold sparkles |

## Look-dev captures

Weapon alone (side and 3/4, the weapon turns so the cyclorama fills the
frame), an 8-angle turntable, and held by a voxel character (two 3/4 views
and a hand close-up). 1920x1080 PNGs. Needs a real GPU to judge looks:

```
godot --path . --disable-vsync -s res://game/characters/voxel_weapons/preview/voxel_weapon_capture.gd -- <out> all
godot --path . --disable-vsync -s res://game/characters/voxel_weapons/preview/voxel_weapon_capture.gd -- <out> turntable --kinds=hammer
godot --path . --disable-vsync -s res://game/characters/voxel_weapons/preview/voxel_weapon_capture.gd -- <out> held --kinds=blade,revolver --scene=res://game/characters/kael_voxel/kael_voxel.tscn
godot --path . --disable-vsync -s res://game/characters/voxel_weapons/preview/voxel_weapon_capture.gd -- <out> all --old   # the old meshes, same framing
ffmpeg -framerate 2 -pattern_type glob -i '<out>/hammer_turn_*.png' -vf "scale=1920:1080" -c:v libx264 -pix_fmt yuv420p hammer_turntable.mp4
```

Headless numbers (no GPU): `godot --headless --path . -s res://game/characters/voxel_weapons/preview/voxel_weapon_stats.gd`.

Draft lavapipe previews (code check only, not for judging looks):
`reports/lookdev/weapons/`.
