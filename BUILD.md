# Skybreak web build

- Source: `7d98be187b525f732bb78bef3ce679ad2faae521` (`origin/main`, merge of PR #125 T-ART1-zone-look)
- Godot: 4.7.2.stable.official.ed1daf0bf, official `web_nothreads_release` template
  (export_templates.tpz SHA-512 verified by `tools/web/build_web.sh`), `Web` preset, release,
  `editor/export/convert_text_resources_to_binary=false`
- Archive: `skybreak-web.tar.gz`, 44066240 bytes (42.0 MiB), sha256
  `d868d2a88ef2ad5ea5a05e02eebe406dfb5abd773d99f2b287347066ec7fb902`; `index.html` at the root,
  no .gz/.br copies. Upload as-is to a static host (no COOP/COEP headers needed).
- Unpacked: 82,150,136 bytes (index.wasm 39,514,754; index.pck 42,307,320; index.js 279,815).

## Smoke tests (headless Chromium, SwiftShader WebGL2, plain static server, no special headers)

- `node tools/web/match_smoke_test.js build/web` -> **PASS**: menu -> Play (vs AI) -> zone -> Fight,
  30 s of input, screenshots at 5/15/30 s, no console errors. Engine running 18.0 s after start click.
  The 30 s screenshot shows Kael vs Vexa on the mesa, HUD, timer 98, lock-on ring and the control hint bar.
- `node tools/web/descend_smoke_test.js build/web` (T-UX1) -> **PASS**: hints shown, fly-down prompt
  appeared, double-tap C landed (prompt pixels 69 -> 1).
- Frame time is not meaningful here (software GL, ~1-2 fps); measure on a real GPU.
- Not tested: online Duo (Appwrite unreachable from the sandbox).
