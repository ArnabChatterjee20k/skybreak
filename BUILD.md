# Skybreak web build

- Source: `ebb3c357f492f391d7b0dc2bec360f3b03c8c268` (branch `claude/T-WEB2-web-crash`, PR #133 for T-WEB2),
  which is main 2ff3609 (includes #122 T-UX1 controls/HUD, #130 T-DEF2 dodge, #131 T-KI1 ki) plus the
  T-WEB2 fixes. Built from tree 5d91d0b (identical tree).
- Godot: 4.7.2.stable.official.ed1daf0bf, official `web_nothreads_release` template
  (export_templates.tpz SHA-512 checked against SHA512-SUMS.txt), `Web` preset, release, via `tools/web/build_web.sh`
- Archive: `skybreak-web.tar.gz`, 44058635 bytes, sha256 `db7bd182daeae92e21ce6e6a174cede31f26eaad699497b7a527bc0305f8a8f1`;
  `index.html` at the root, no .gz/.br copies. Upload as-is to Appwrite Sites (static, no COOP/COEP headers needed).

## Files (bytes raw / gzip -9)

| file | raw | gzip |
|---|---:|---:|
| index.wasm | 39,514,754 | 10,084,297 |
| index.pck | 42,295,180 | 33,750,115 |
| index.js | 279,815 | 68,400 |
| index.html + worklets + icons | 48,247 | 36,732 |
| **total** | **82.1 MB (78.3 MiB)** | **43.9 MB (41.9 MiB)** |

## Smoke tests (headless Chromium, SwiftShader WebGL2, plain static server, no special headers)

- `node tools/web/match_smoke_test.js <dir>` -> **PASS**: menu -> Play (vs AI) -> Choose zone -> Fight! starts
  Kael vs Vexa on Shattered Mesa; 30 s of keyboard/mouse input, screenshots at 5/15/30 s show the HUD,
  the control-hint strip (T-UX1), both fighters and the lock-on ring. No console errors.
- `node tools/web/descend_smoke_test.js <dir>` -> **PASS**: hints shown, the fly-down prompt appears while
  hovering (719 prompt pixels), double-tap C dives and the prompt clears (0). A longer run confirmed the
  fighter stands on the ground afterwards.
- Load: click-to-start -> engine running in about 15 s from localhost (78.3 MB served uncompressed).
- Frame time: not meaningful here; SwiftShader renders on the CPU at about 1-2 fps. Measure on a real GPU.

## T-WEB2 (the FIGHT crash)

`RuntimeError: remainder by zero` came from `ZoneMatch.spawn_positions` doing `side % points.size()` with
no spawn points. Godot 4.7.2's text-to-binary export conversion empties packed arrays; main keeps text
resources since #112, so this only hit builds without that setting (433d2ee, the pre-merge #122 branch).
Zones now fall back to two spawns instead of trapping, and a zero beam block event interval no longer
divides by zero.

## Online (Duo)

Unchanged from the previous build: WebRTC is built in; Appwrite (sign-in, lobby, signalling) is unverified
from the browser. If DevTools shows CORS errors, add the site's hostname as a Web platform in the project.
