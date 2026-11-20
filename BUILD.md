# Skybreak web build

- Source: `ca58d8dc1636d6fea12b16f8005d99c7cc1d4646` (branch `claude/T-D36-web-build`, PR for T-D36; base main 66b15ce)
- Godot: 4.7.2.stable.official.ed1daf0bf, official `web_nothreads_release` template
  (export_templates.tpz SHA-512 checked against SHA512-SUMS.txt), `Web` preset, release
- Archive: `skybreak-web.tar.gz`, 43958063 bytes, sha256 `4ad389af836bfa810b9c346360d20a76d78ba11093574387ddd95cae90766cd7`; `index.html` at the root,
  no .gz/.br copies. Upload as-is to Appwrite Sites (static, no COOP/COEP headers needed).

## Files (bytes raw / gzip -9)

| file | raw | gzip |
|---|---:|---:|
| index.wasm | 39,514,754 | 10,084,297 |
| index.pck | 42,176,840 | 33,647,790 |
| index.js | 279,815 | 68,400 |
| index.html + worklets + icons | 48,247 | 36,735 |
| **total** | **82.0 MB (78.2 MiB)** | **43.8 MB (41.8 MiB)** |

## Smoke test (headless Chromium, SwiftShader WebGL2, plain static server, no special headers)

`node tools/web/match_smoke_test.js <dir>` -> **PASS**

- Boots with no console errors or warnings from the game (only Chromium's
  "GPU stall due to ReadPixels" driver notices, caused by the screenshots).
  `crossOriginIsolated` false, as expected for the single-threaded build.
- Load: click-to-start -> engine running in 11.6-15.5 s from localhost (78.2 MB served uncompressed).
- Front-end menu appears; Play (vs AI) -> Choose your legend -> Choose your zone -> Fight! starts a
  Kael vs Vexa match on Shattered Mesa; 30 s of keyboard/mouse input with screenshots at 5/15/30 s:
  HUD (names, health, meters, round timer), FIGHT! banner, both fighters and the lock-on ring visible.
- Frame time: not meaningful here; SwiftShader renders on the CPU at about 1-2 fps. Measure on a real GPU.

## Online (Duo)

WebRTC is built into the web export: two in-browser `WebRtcTransport`s opened both data channels and
exchanged packets. Appwrite (sign-in, lobby, signalling) could not be reached from the test sandbox, so
it is unverified from the browser; if DevTools shows CORS errors, add the site's hostname as a Web
platform in the Appwrite project.
