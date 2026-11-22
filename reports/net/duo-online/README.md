# Duo online (T-D15b): you and your partner vs AI, on two devices

Branch `net/duo-online`. Duo now runs end to end from the main menu: sign in, host
or join with a short room code, pick legends, the host picks the zone, both ready
up, and the match against the AI starts in sync. Inputs go peer to peer over WebRTC
with rollback. Appwrite is only used for sign-in, the lobby row and signalling.

## What works (and how it was checked)

| Piece | State | Evidence |
|---|---|---|
| Menu flow: Main menu -> Duo -> sign in (remembered) -> Host / Join -> legends, host's zone, AI count and level, lives, minutes -> Ready -> Start | works | browser test below (driven through the screen's own buttons), `tests/net/test_duo_sign_in.gd`, `test_duo_lobby.gd` |
| Sign-in with the two fixed accounts, "Remember me" (session only, encrypted, never the password) | works | `test_duo_sign_in.gd` (password never stored, logged or sent anywhere but the sign-in request) |
| Lobby + signalling over the TablesDB tables `skybreak_lobbies` / `skybreak_signals` (rows API) | works against the mock | browser test: 82 mock requests, 0 errors, 0 refused origins, 0 permission refusals (`appwrite_mock.log`) |
| WebRTC with public STUN (`stun.l.google.com:19302`) | works browser <-> browser | browser test (two Chromium processes) |
| Clear error when P2P can't connect | works | after 30 s with both descriptions applied: "Could not connect directly to your partner ... needs a TURN relay" |
| Rollback: 2-frame input delay, up to 8 frames, state-hash desync check every 30 ticks, ping | works | GUT `test_duo_online.gd`; browser test |
| Waiting / disconnected / out-of-sync screens | works in code and unit tests | 2 s without packets: "Waiting for <partner>"; 30 s or the partner leaving: "Partner disconnected" with **Continue vs AI** (their fighter goes to an AI, the match runs locally) or **Leave** |
| Duo rules: both humans on team 0 vs AI on team 1, friendly fire off, shared team lives (duo 3/6/9, default 6; AI 3 each), respawn 3 s after a KO, a team out of lives loses, time limit (3/5/8 min, more lives wins on time) | works | `tests/net/test_duo_flow.gd` |
| After the match | results -> back to the Duo lobby with the link still open (play again without a new code); Main menu closes the link | |

### Browser test (two headless Chromium pages, real WebRTC, Appwrite mock)

`node tools/net/duo_browser_test.js <debug web export> <out dir> 3`, result in
`browser_test.json`, output in `browser_test_output.log`, screenshots here:

- **PASS**. Host -> code -> guest joins -> picks -> start -> match -> both finish.
- 148 s of match on both pages (8905 ticks; it ended on a KO, the duo won; wall time 673 s including two ~5 min zone loads).
- **299 state hashes confirmed by both pages, 0 mismatches**, no desync (each page also compared 296 hashes in-band).
- Forced network: 45 ms +- 20 ms one-way delay and 2% loss on every packet each way (`LaggyTransport`), plus one forced rollback burst (all host packets held 140 ms at tick 4200). Max rollback depth 8 on both, 3068 / 3105 rollbacks, median measured RTT 132 / 135 ms.
- **0 console errors** on both pages. The only Godot warnings are the known missing zone bakes (VOXEL-BAKES): "no zone manifest ... the zone builds live".
- Screenshots: `host_1_room_code.png`, `host_2_lobby_setup.png` / `guest_2_lobby_setup.png`, `*_3_match_{30,90,150}s.png`, `*_4_match_over.png`.

How the test works, honestly:
- It needs a **debug** web export: the endpoint override (`?appwrite=`) and the test pilot exist only in debug builds; release builds ignore them (`AppwriteClient.endpoint_for_build()`, tested).
- The site and the mock run on different ports, so every Appwrite call is a real cross-origin `fetch` with CORS preflight.
- `DuoTestPilot` (DevParam `duo_test`) presses the Duo screen's buttons and plays the local fighter with a level-4 AI. Those inputs are sent like a human's. The test opens the Duo screen with a real key press and mouse click on the main menu.
- SwiftShader takes ~1 s per frame in this container, so the pages draw one frame every 4 s (`render_hz=0.25`). The game loop, sim and netcode run near 60 Hz in between. Each drawn frame is a ~1 s hitch on that page, which shows up as stalls and sync skips in the stats: harder than a real device, not easier.

### GUT: two peers over the loopback transport

`tests/net/test_duo_online.gd`: two full `RollbackSession`s with the Duo rules and AI
drivers, the local human on each side played by its own AI, at **150 ms RTT, 20 ms
jitter, 2% loss**, 3600 ticks, plus a burst (all packets lost both ways for 7 ticks).
Result: frame 3597, host 1463 rollbacks (max depth 8), 119 hashes compared, no
desync; every hash both peers confirmed is equal. Also: AI drivers roll back exactly
(re-simulated hashes equal for 120 ticks) and a silent partner only gets ~10 packets/s.
In-process (one Godot), not two OS processes.

## Exact steps for the owner and partner

1. Both open the game: the web build (`https://skybreak-web-6a113777000db893b12e.appwrite.network`) or the Windows build (webrtc-native is in `addons/webrtc_native`). Any mix works (see open item 5 on cross-platform).
2. Main menu -> **Duo**.
3. Sign in once: owner `skybreak-player-1@example.com`, partner `skybreak-player-2@example.com`, with the passwords you set in Appwrite. Leave **Remember me** on; next time it signs in by itself.
4. Owner: **Host a room**. A 5-letter code appears (no 0/O or 1/I). Tell it to your partner.
5. Partner: type the code -> **Join**. Within a few seconds both screens switch to the room.
6. Each picks a legend with `<` `>`. The host picks the zone, the number of AI (1-3) and their level, lives and minutes. Any change by the host clears both Ready flags.
7. Both press **Ready**; the host presses **Start**. Both load the zone, then the match starts on the same tick ("Get ready" shows while the other is still loading).
8. During the match: the line under the clock shows lives and ping. **Esc** opens the menu without pausing (online can't pause). If your partner drops, wait, or press **Continue vs AI**.
9. After the results, **Rematch** goes back to the room: pick again and start without a new code.

If it says "Could not connect directly to your partner", one of the networks blocks
peer to peer (no TURN relay yet): try a phone hotspot on one side.

## Appwrite side: what the desktop controller must add (I did not touch Appwrite)

1. **Web platform for the site, if sign-in on the web says "Invalid Origin".**
   Console -> project `6a113777000db893b12e` -> Overview -> Platforms -> Add platform -> **Web** ->
   hostname **`skybreak-web-6a113777000db893b12e.appwrite.network`** (no scheme, no path).
   Why: Appwrite only answers browser requests from registered origins (CORS). The desktop build
   sends no `Origin` and needs nothing. Unverified: this environment's network policy blocks
   `sgp.cloud.appwrite.io` (`403 ... no rule or network setting allows this host`), so I could not
   check whether Appwrite Sites already trusts its own `*.appwrite.network` domain. Add it if the
   web sign-in fails; it is harmless if not needed.
2. **Nothing else.** The existing tables, columns, row security and the `skybreak_signals_inbox`
   index are what the code uses. Signal rows now use `read("users")` / `delete("users")`:
   Appwrite refuses a client granting `user:<partner>` (a role it does not hold), so the old
   permissions would have failed with 401 on the first offer. The table only needs
   `create("users")` (as provisioned).

Browser audit (item 5 of the task):
- **CORS:** see 1. The client only sends `X-Appwrite-Project`, `Content-Type`,
  `X-Appwrite-Response-Format` and `X-Fallback-Cookies`, all on Appwrite's allowed-headers list.
- **Cookies vs `X-Fallback-Cookies`:** Godot's web `HTTPRequest` uses `fetch` without credentials
  (checked in the exported `index.js`: `const init={method,headers,body}`), and a page can't read
  `Set-Cookie` anyway. The web build therefore authenticates **only** with `X-Fallback-Cookies`:
  read from the sign-in response (Appwrite exposes the header) and sent on every request. The mock
  does the same and the browser test signs in, creates, reads, updates and deletes rows this way.
- **Realtime websocket:** not used. Signalling polls rows every 0.5 s (fine for a one-off
  offer/answer), so there's no websocket URL or auth to get wrong.
- **Single-threaded web export:** the build runs without cross-origin isolation (no
  SharedArrayBuffer); networking is `fetch` plus the browser's WebRTC. No threads are used.
  A hidden tab stops the game loop; the other side then shows "Waiting", and the session sends
  only ~10 packets/s to a silent partner so the browser's data-channel buffer doesn't overflow.

## Verification on this branch

- Godot 4.7.2 official linux x86_64, SHA-512 checked
  (`9aa00f7a…ed54c65`, matches `SHA512-SUMS.txt`); web templates SHA-512 checked
  (`ca4d71c4…ccb84079`). `rm -rf .godot`, `--headless --import`.
- Full GUT: see the merge commit message / section below for totals.
- det_check: `det_check total 65ec2f54272115fd` on two runs, equal to main. The sim gained
  `CombatSim.respawn_fighter()` (used only by Duo rules), which no existing path calls.
- QA quick: see below.

## Open, ranked

1. **Try it for real on the deployed site.** The only Appwrite-dependent unknown is the Web
   platform (above). Everything else was exercised against the mock, which copies Appwrite's CORS,
   fallback-cookie and permission rules but is still a mock.
2. **TURN relay** for networks where STUN-only P2P fails (strict NAT / some mobile carriers).
   Today the lobby says so after 30 s.
3. **Rejoin after a real drop.** Short drops recover by themselves (unacked inputs are re-sent).
   A dropped connection can't be rebuilt mid-match: the remaining player continues vs AI or
   leaves. Needs re-signalling plus sending a snapshot.
4. **Respawn invincibility (2 s) and team-assist shared combos** (GAME_DESIGN §8.1/§8.2) need new
   sim state, which changes det_check; left out on purpose.
5. **Windows <-> browser in one match** is covered by det_check (the same hash on every platform)
   but was not run live here (no Windows machine). Play one owner-PC + partner-browser match and
   watch for the "Out of sync" panel.
6. Signalling polls every 0.5 s (about 4 requests/s for both players while connecting). Presence
   or Realtime would cut that and add instant disconnect detection.
7. `ZoneMatch` ignores the configured `team` outside Duo (2v2 teammates hit each other): filed as
   DUO-5 (QA 2v2 metrics would move).
8. Zone loading in the browser builds the voxel zone live without bakes (~5 min in SwiftShader);
   with the owner's bakes deployed this is the normal pack download (VOXEL-BAKES).
