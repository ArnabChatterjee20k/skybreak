# game/net: rollback netcode and Duo online (T-D15, T-D15b)

Duo mode (GAME_DESIGN §8.2): two humans, one per device, against 1-2 AI
fighters. Only inputs travel. Both peers run the same `CombatSim`, and the AI
runs on both, so it costs no traffic (§12.1).

| File | What it is |
|---|---|
| `rollback_session.gd` | `RollbackSession`: 2-tick input delay, prediction (last input held, presses dropped), confirmed-input queue, rollback of up to 8 ticks, desync detection (state hash of sim + rules every 30 ticks, once all inputs are confirmed), frame-advantage time sync (skips at most 1 tick in 10), RTT estimate, time since the last packet. Rules with `accepts_input()` neutralise every input while false (intro). Transport-agnostic. |
| `input_codec.gd` | `InputCodec`: a `FighterInput` takes 8 bytes, up to 18 with presses, releases and camera offset. |
| `net_transport.gd` | `NetTransport` interface: `send()`, `poll()`, `received` signal. |
| `loopback_transport.gd` | In-process transport with latency, jitter and loss, for tests. |
| `laggy_transport.gd` | Dev tool: wraps a real transport with delay, jitter, loss and a `hold(ms)` burst (DevParams `net_lag`, `net_jitter`, `net_loss`, debug builds only). |
| `webrtc_transport.gd` | Two negotiated data channels: `inputs` (unordered, `maxRetransmits` 0) and `control` (reliable). Public STUN only (`stun.l.google.com:19302`). |
| `appwrite_client.gd` | Minimal Appwrite REST client: email/password sessions (sign in, restore and extend, sign out) and **TablesDB rows** (`/tablesdb/skybreak/tables/<table>/rows`, response format 1.8.0). Session in memory as the cookie (desktop) and `X-Fallback-Cookies` (the only thing the browser can use). Debug builds accept an endpoint override (env `SKYBREAK_APPWRITE_ENDPOINT` or URL `?appwrite=`), release builds never. |
| `session_store.gd` | `SessionStore`: "Remember me". Keeps the session (never the password) in `user://skybreak_session.cfg`, encrypted with a random per-install key. On the web `user://` is the browser's IndexedDB for the site. |
| `appwrite_signalling.gd` | Lobby rows (5-letter code) plus offer/answer/ICE rows, polled every 0.5 s; a clear "P2P blocked, needs TURN" error after 30 s without an open channel. |
| `duo_link.gd` | `DuoLink` at `/root/DuoLink`: survives scene changes (menu -> match -> menu). Owns the signed-in client, the signalling, the open transport and the lobby protocol on the control channel (hello, pick, setup, ready, start, loaded, leave). |
| `duo_screen.gd` | The front end's Duo page: sign in -> Host (code) / Join -> legends, host's zone/AI/lives/minutes -> Ready -> Start. |
| `duo_match.gd` | Builds the identical Duo config on both peers (humans on team 0, AI on team 1 with seeded legends), peers per fighter, AI drivers. |
| `duo_flow.gd` | `DuoFlow` (extends `MatchFlow`): Duo rules as rollback-safe session rules: shared team lives (duo default 6, AI 3 each), respawn 3 s after a KO, team out of lives loses, time limit, no slow motion. |
| `duo_hud.gd` | In-match overlay: lives, ping, rollback count; waiting / disconnected / out-of-sync panel with "Continue vs AI" and "Leave". |
| `duo_test_pilot.gd` | Dev tool for `tools/net/duo_browser_test.js` (DevParam `duo_test`, debug builds only): drives the Duo screen's buttons and plays the local fighter with an AI, printing `SKYBREAK_DUO {json}` lines. |
| `dev_params.gd` | Dev-only switches from the URL (web) or `-- --name=value` (desktop); empty in release builds. |

How a match runs: `ZoneMatch` with `mode == duo` and an open `DuoLink` builds the sim
from the shared config (seed, teams), makes a `RollbackSession` over the link with
the AI drivers as bots and `DuoFlow` as rules, reports "loaded" and only starts
ticking once the partner has loaded too. Each physics tick it calls
`session.advance(local_input)`; the view interpolates as usual. Online the tree never
pauses (the pause menu blocks local input only, Restart is hidden), the results go
back to the Duo lobby with the link still open. More than 1 s without a packet shows
"Waiting for partner"; 30 s, or the partner leaving, shows "Partner disconnected"
with "Continue vs AI" (the partner's fighter goes to an AI and the match runs
locally) or "Leave". A short network drop recovers by itself: unacknowledged inputs
are re-sent until confirmed.

`CombatSim.snapshot()`/`restore()` are in `game/combat/sim_snapshot.gd`. They copy
every script variable by reflection, so new sim fields are covered automatically.
Resources are treated as configuration and shared. RNG state, pickups and
projectiles are copied. Fighters are restored in place, so view references stay valid.

## Sign-in

The Appwrite project is shared with another app, so **Anonymous auth stays off**.
Duo uses two fixed player accounts, `skybreak-player-1` and `skybreak-player-2`
(emails `skybreak-player-1@example.com` / `skybreak-player-2@example.com`). Their
passwords are private: they never go in the repo, logs or tests.

- The lobby's sign-in panel posts `POST /v1/account/sessions/email`. The client keeps
  the `a_session_<project>` cookie (and `X-Fallback-Cookies`) in memory and sends it
  on every request. The password field is cleared after the request.
- With **Remember me**, `SessionStore` saves the session, not the password, to
  `user://skybreak_session.cfg` (the OS user data dir, outside the project) with
  `ConfigFile.save_encrypted_pass` and a random per-install key. On the next start
  the lobby restores it, extends it (`PATCH /account/sessions/current`) and reads
  `GET /account`; if that fails the file is deleted and the player signs in again.
- **Sign out** deletes the server session (`DELETE /account/sessions/current`) and
  the saved file.
- Lobby and signal documents carry the signed-in user ids (permissions below).

`tests/net/test_appwrite_live.gd` is an optional live smoke test: it runs only when
`SKYBREAK_TEST_EMAIL` and `SKYBREAK_TEST_PASSWORD` are set, signs in, creates a
lobby document, reads it back and deletes it.

## Appwrite resources (provisioned)

Project `6a113777000db893b12e`, endpoint `https://sgp.cloud.appwrite.io/v1`. The
game uses only this public config: no API key goes in code. These exist now (only
add, never change shared resources):

1. **Auth**: email/password, with the two player accounts above. Anonymous stays off.
2. **Platforms**: a **Web** platform for the web build's hostname, when there is one.
   The desktop build sends no `Origin`, so it needs none.
3. **Database** `skybreak` (name "Skybreak").
4. **Table** `skybreak_lobbies` (TablesDB). Row security **on**. Table
   permission: `create("users")`. The row id is the 5-letter lobby code.

   | Attribute | Type | Size | Required |
   |---|---|---|---|
   | `code` | string | 8 | yes |
   | `host` | string | 36 | yes |
   | `guest` | string | 36 | no (default "") |
   | `status` | string (`open`, `full`, `in_match`, `closed`) | 16 | yes |
   | `seed` | integer | | yes |
   | `ai_count` | integer (1-2) | | yes |

   Each lobby row gets `read("users")`, `update("users")` and
   `delete("user:<host>")`, so the guest can claim it
   (`AppwriteSignalling.lobby_permissions()`).
5. **Table** `skybreak_signals` (TablesDB). Row security **on**. Table
   permission: `create("users")`.

   | Attribute | Type | Size | Required |
   |---|---|---|---|
   | `lobby` | string | 8 | yes |
   | `from` | string | 36 | yes |
   | `to` | string | 36 | yes |
   | `kind` | string (`offer`, `answer`, `ice`) | 16 | yes |
   | `payload` | string (JSON) | 16384 | yes |

   Key index `skybreak_signals_inbox` on (`lobby`, `to`). Each signal row gets
   `read("users")` and `delete("users")` (`AppwriteSignalling.signal_permissions()`):
   Appwrite refuses a client granting a role it does not hold, so `user:<partner>`
   would fail with 401 on the first offer (the mock enforces the same rule). The inbox
   query filters by lobby and receiver; the receiver deletes each row after use.
6. Optional, not created: a scheduled cleanup function `skybreak_cleanup` that
   deletes lobbies and signals older than a day.

Follow-ups: TURN for networks where direct P2P fails; Presence/Realtime-based
signalling (`upsertPresence`, as §12.1 plans) instead of polling. The client uses no
Realtime websocket today.

## Testing without Appwrite

`tools/net/appwrite_mock.js` mocks the endpoints the client uses (CORS with a Web
platform allowlist and exposed `X-Fallback-Cookies`, email sessions, TablesDB rows
with row security and the granted-roles rule). `tools/net/duo_browser_test.js` runs
the full Duo flow in two headless Chromium pages over real browser WebRTC against an
exported debug web build (see `reports/net/duo-online/README.md`).

## WebRTC on desktop (developer, Windows PC)

Godot 4.7.2 ships WebRTC only in the **web** export. On desktop,
`WebRTCPeerConnection` is a stub until an extension is loaded. Verified here
on the official 4.7.2 linux build: `initialize()` reports
`_gdvirtual__initialize_call` not implemented. `WebRtcTransport.is_available()`
returns false there, and the lobby says so.

The PC needs the official **godotengine/webrtc-native** GDExtension. The Windows
x86_64 build of release **1.2.2-stable** is committed under `addons/webrtc_native/`
(debug and release DLLs plus `webrtc_native.gdextension`), so Windows runs and
Windows exports work with no setup. Verified on the GTX 1650 PC with 4.7.2:
`ClassDB.class_exists("WebRTCLibPeerConnection")` is true,
`WebRTCPeerConnection.initialize()` returns OK and `WebRtcTransport.is_available()`
is true.

Other desktop platforms (Linux, macOS) are a local install step:

1. From <https://github.com/godotengine/webrtc-native/releases>, tag `1.2.2-stable`,
   download `godot-extension-webrtc_native.zip`.
2. Unzip it. It holds `addons/webrtc_native/` with `webrtc_native.gdextension`
   and `lib/` binaries for every platform. Copy that folder over the committed
   one (don't commit the extra libraries). The `.gdextension` library paths are
   relative (`lib/...`), so they need no edits. `compatibility_minimum` is 4.3.
3. Restart the editor.

The web build uses the browser's native WebRTC and needs no extension.

Tests never need the extension: they run over `LoopbackTransport`.
