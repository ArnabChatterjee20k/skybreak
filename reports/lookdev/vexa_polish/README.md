# Voxel Vexa polish: neutral jacket

These previews are **lavapipe** renders (software Vulkan in a cloud session) from `lookdev_capture.gd … turntable`. Judge the final colour on the GTX 1650.

| File | What it shows |
|---|---|
| `vexa_turntable_000.jpg`, `vexa_turntable_045.jpg` | Before (cc930de, `#3A3A4C`) on the left, after (`#3C3A48`) on the right |
| `vexa_jacket_closeup.jpg` | Jacket front at 0°, crop scaled 2×, before on the left and after on the right |

## Change
| Material | Before | After |
|---|---|---|
| `JACKET` | `#3A3A4C` | `#3C3A48` |
| `JACKET_EDGE` | `#343445` | `#363441` |
| `JACKET_DARK` | `#2E2E3C` | `#302E38` |

- Luminance is unchanged (0.233 / 0.209 / 0.185). Red goes up 2 and blue down 4–5.
- HSV value goes 0.298 → 0.282. It stays below the hood purple (0.314) and the wraps (0.502).
- `JACKET_EDGE` was not named in the brief. It got the same shift so the jacket family stays one hue, and the ordering jacket > edge > seams still holds.

## Measured on the renders
These are the pixels that changed, so mostly jacket:

| View | Before (mean RGB) | Blue over red | After (mean RGB) | Blue over red |
|---|---|---|---|---|
| 0° | (63, 60, 78) | +15 | (66, 60, 73) | +7 |
| 45° | (60, 58, 78) | +19 | (62, 58, 73) | +12 |

## Weak spots (kept visible)
1. On the GTX 1650 the v3 jacket rendered `#282940`, with blue +24 over red. The same shift should roughly halve that on the GPU, but the jacket may still read faintly cool there. If it does, the next step is about `#3E3A46`. Check on the GPU.
2. Under lavapipe the difference is subtle at turntable distance. It is clear in the close-up.
