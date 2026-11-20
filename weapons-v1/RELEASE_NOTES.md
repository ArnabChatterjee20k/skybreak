# Voxel weapons — turntable look-dev v1

> **Not published as a release:** this session type gets HTTP 403 when creating releases. The assets are on branch `lookdev/lyra-v2-media` under `weapons-v1/`.

Branch `lookdev/voxel-weapons` @ `fa393ce2`. Rendered with the branch's own documented capture command
(`voxel_weapon_capture.gd -- <out> turntable`), all 11 voxel weapons × 8 angles (every 45°), 1920×1080 each.

**Renderer caveat:** the GPU PC was off, so this is **lavapipe** (software Vulkan, Godot 4.7.2 official, SHA-512 verified). Colours and shapes are correct; the contact shadows are dithered/speckled (PCSS on lavapipe + large cyclorama) and SSAO is softer than on the GTX 1650. Treat shading subtlety as provisional.

**Assets**
- `<kind>_turntable_sheet.png` — one 1920×1080 sheet per weapon (8 angles, 4×2, each tile 480×270).
- `weapons_overview_sheet.png` — all 11 at the 45° angle, 3840×1620 (960×540 tiles).
- `weapons_turntable_frames_1080p.zip` — all 88 full-resolution 1920×1080 frames (the sheets are downscaled; judge detail here).

## Critique (ranked, most severe first)
1. **Heartstring Bow — sparkles render as big flat opaque squares.** `WeaponModels.sparkles()` (shared with the voxel model) is a 7 cm unshaded alpha QuadMesh with no texture/falloff and alpha 1, so at turntable distance they read as pale-yellow tiles scattered over and in front of the bow, hiding the grip in several angles. Needs a soft round/star texture, fade-over-life, smaller size (or turned off in look-dev captures). Broken, kept visible.
2. **Titan Hammer — framing too tight.** At 45°/90°/135° the head fills the frame and is cut at the bottom and side; the haft is out of shot at 90°. The capture fits the bounding box per-weapon but doesn't account for the head's depth when rotated.
3. **Ember Scythe — blade tip cut off** at the bottom edge at 45° and 135° (same bounds-fit issue).
4. **Sky Lance — tiny in frame.** The long thin silhouette gets fitted by length, so at 90°/270° it's a sliver and the fine detail (wraps, crossguard) is ~10 px. A tighter 3/4 crop would sell it better. The blue pennant reads as a blobby flame rather than cloth.
5. **Visible cyclorama seam:** a faint horizontal band is visible behind every weapon (the floor-to-wall curve of the large cyc), most noticeable at the weapon's mid-height. Minor, but it shows on every frame.
6. Hammer bands / gauntlet cuff: big flat side panels read slightly plain next to the riveted front faces (the medium/tiny-detail layer is front-loaded).

**What works:** strong, distinct silhouettes for all 11; the palette discipline (muted metals + one accent per weapon) holds; the revolver grip emblem, the hammer's orange rune plate and moss tuft, the chakram's violet inner ring and the repeater's drum read clearly; voxel edge highlights and bevels look right; no holes or mesh errors seen in any of the 88 frames.

Next: fix the sparkle material, per-weapon framing padding for hammer/scythe/lance in `voxel_weapon_capture.gd`, then a GPU render on the GTX 1650 for final judgement.
