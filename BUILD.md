# Skybreak web build

- Source: `68f64292f233aa133ffcd81026cf6d57e21c5a43` (origin/main, merge of PR #143 T-UI1 HUD restyle; includes
  #142 T-ART2 and #139 AI pickup; descends from 7d98be1).
- Godot: 4.7.2.stable.official.ed1daf0bf, official `web_nothreads_release` template
  (export_templates.tpz SHA-512 checked against SHA512-SUMS.txt), `Web` preset, release, via `tools/web/build_web.sh`
  (`editor/export/convert_text_resources_to_binary=false` kept).
- Archive: `skybreak-web.tar.gz`, 44092900 bytes, sha256 `eca336f4fa702ae54f743e6d6f24d0de9263ba4b485fb1c16a47606a1d317d31`;
  `index.html` at the root, no .gz/.br copies. Upload as-is to Appwrite Sites (static, no COOP/COEP headers needed).

## Files (bytes raw)

| file | raw |
|---|---:|
| index.wasm | 39,514,754 |
| index.pck | 42,335,808 |
| index.js | 279,815 |
| index.html + worklets + icons | 47,247 |
| **total** | **78.4 MB** (gzip 41.9 MB) |

## Smoke tests (headless Chromium, SwiftShader WebGL2, plain static server, no special headers)

- `node tools/web/match_smoke_test.js build/web` -> **PASS**: menu -> vs AI match ran 30 s, no console errors,
  screenshots at 5/15/30 s. Load: click-to-start -> engine running in 22.2 s from localhost.
- `node tools/web/descend_smoke_test.js build/web` -> first run (default pace) FAILED: at ~1 fps the fighter had not
  risen when sampled (36 prompt pixels, threshold 50); hints were visible. Rerun with `SLOW=10` -> **PASS**:
  hints shown, fly-down prompt appeared (1633 prompt pixels), double-tap C dived and the prompt cleared (17).
  So this check is timing-sensitive under software rendering.
- Frame time is not meaningful here (SwiftShader, about 1 fps); measure on a real GPU.
