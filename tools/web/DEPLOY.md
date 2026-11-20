# Deploying the web build to Appwrite Sites

Target: Appwrite Cloud, region **sgp**, project `6a113777000db893b12e`, site
**`skybreak-web`** (site ID `skybreak-web`). The build is a plain static site:
no server code, no COOP/COEP headers needed (single-threaded export).

## 1. Build and smoke-test locally

```sh
tools/web/build_web.sh                 # needs Godot 4.7.2 as `godot` (or GODOT=...)
node tools/web/smoke_test.js build/web build/web_smoke.png   # needs `npm i playwright`
node tools/web/match_smoke_test.js build/web build/web_match_smoke   # menu -> vs AI match, 30 s
```

`build_web.sh` downloads the official 4.7.2 export templates once, checks their
SHA-512 against `SHA512-SUMS.txt`, exports the `Web` preset to `build/web/` and
prints raw/gzip sizes. Deploy only if the smoke test prints `PASS`.

Upload these files (skip the `.gz`/`.br` copies; Appwrite compresses itself):
`index.html`, `index.js`, `index.wasm`, `index.pck`, `index.audio.worklet.js`,
`index.audio.position.worklet.js`, `index.png`, `index.icon.png`,
`index.apple-touch-icon.png`.

## 2. One-time: create the site (Console)

1. Open https://cloud.appwrite.io/console/project-sgp-6a113777000db893b12e/sites
   and sign in as the owner.
2. **Create site** -> **Manual deployment** (upload, no Git).
3. Name `skybreak-web`, site ID `skybreak-web`, framework **Other** (static),
   no install or build command, output directory `./`.
4. Upload the files from step 1 (zip or tar.gz of the contents of
   `build/web/` without the `.gz`/`.br` files, `index.html` at the root).
5. Activate the deployment and open the generated `*.appwrite.network` domain.

## 3. Later deploys (CLI)

```sh
npm i -g appwrite-cli
appwrite client --endpoint https://sgp.cloud.appwrite.io/v1
appwrite login                          # interactive; no keys in the repo
cd build/web && rm -f *.gz *.br
tar -czf ../skybreak-web.tar.gz .
appwrite sites create-deployment \
  --site-id skybreak-web \
  --code ../skybreak-web.tar.gz \
  --activate true
```

If the CLI version differs, `appwrite sites create-deployment --help` lists the
flags. Never commit API keys or `appwrite.json` with secrets.

## 4. Check the live site

- Page shows the SKYBREAK loading screen, the bar fills, then **CLICK TO START**.
- After the click the arena loads and music plays (the click unlocks audio).
- DevTools: `index.wasm` served as `application/wasm`, transfer compressed
  (`content-encoding: gzip` or `br`), no console errors.
- Duo (online) uses the browser's own WebRTC. If DevTools shows CORS errors on
  `sgp.cloud.appwrite.io`, add the site's hostname as a **Web platform** in the
  Appwrite project (Overview -> Platforms).
- If the upload is refused for size, check the plan's deployment size limit:
  the uncompressed build is about 76 MB (39.5 MB gzip), `index.pck` alone ~40 MB.
