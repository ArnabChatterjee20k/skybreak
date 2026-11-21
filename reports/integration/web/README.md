# Web / Compatibility check (VOXEL-COMPAT, fix/web-voxel-compat)

Godot 4.7.2 official (SHA-512 checked), Mesa 25.2.8 llvmpipe.

- `browser_webgl2_*.jpg`: the exported Web preset in headless Chromium, WebGL2 on
  ANGLE/Vulkan/lavapipe (`MAX_UNIFORM_BLOCK_SIZE` 65536, so 4096 global-uniform
  slots): front end and legend select with voxel Kael. Driving past legend select
  did not work at the ~2 fps lavapipe gives in the browser.
- `compat_webtier_*.jpg`: `game/debug/web_zone_view.gd` (a ZoneMatch at the WEB
  tier) under `--rendering-method gl_compatibility` (OpenGL 4.5 Mesa) in Ember
  Rift, Frozen Peaks and Stormfall City; no renderer errors.
- `compat_heartbloom_*_light.jpg`, `compat_zone_verdant_falls.jpg`: the QA
  visual-golden shots under gl_compatibility (all 14 ran with no errors): the four
  voxel legends with their weapons.

Web export: index.wasm 39.5 MB (10.1 MB gzip), index.pck 57.6 MB (46.8 MB gzip),
93 MB total.
