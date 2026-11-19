# game/net: rollback netcode and Duo online (T-D15, T-D15b)

Duo mode (GAME_DESIGN §8.2): two humans, one per device, against 1-2 AI
fighters. Only inputs travel. Both peers run the same `CombatSim`, and the AI
runs on both, so it costs no traffic (§12.1).

| File | What it is |
|---|---|
| `rollback_session.gd` | `RollbackSession`: 2-tick input delay, prediction (last input held, presses dropped), confirmed-input queue, rollback of up to 8 ticks, desync detection (state hash every 30 ticks, once all inputs are confirmed), frame-advantage time sync (skips at most 1 tick in 10). Transport-agnostic: it only calls `send(bytes)` and handles `on_receive(bytes)`. |
| `input_codec.gd` | `InputCodec`: a `FighterInput` takes 8 bytes (flags, held u24, move 2 x s8, yaw u16), up to 18 bytes with presses, releases and camera offset. Both peers simulate the decoded input. |
| `net_transport.gd` | `NetTransport` interface: `send()`, `poll()`, `received` signal. |
| `loopback_transport.gd` | In-process transport with latency, jitter and loss, for tests. |
| `webrtc_transport.gd` | Two negotiated data channels: `inputs` (unordered, `maxRetransmits` 0) and `control` (reliable). Public STUN only. |
| `appwrite_client.gd` | Minimal Appwrite REST client: email/password sessions (sign in, restore and extend, sign out), documents. The HTTP layer is one overridable `_send()`, faked in tests. |
| `session_store.gd` | `SessionStore`: "Remember me". Keeps the session cookies and player name (never the password) in `user://skybreak_session.cfg`, encrypted with a random per-install key in `user://skybreak_install.key`. |
| `appwrite_signalling.gd` | Lobby codes plus offer/answer/ICE exchange as documents, polled every 0.5 s. |
| `duo_match.gd` | Builds the Duo sim, owners and bots the same way on both peers; an instance holds the round-restart rule. |
| `duo_lobby.tscn` | Sign-in panel (email, password, Remember me; then the player name and Sign out) and host/join UI. After connecting it runs the match with a text readout and emits `match_started(session)` for an arena to draw. |

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
4. **Collection** `skybreak_lobbies`. Document security **on**. Collection
   permission: `create("users")`. The document id is the 5-letter lobby code.

   | Attribute | Type | Size | Required |
   |---|---|---|---|
   | `code` | string | 8 | yes |
   | `host` | string | 36 | yes |
   | `guest` | string | 36 | no (default "") |
   | `status` | string (`open`, `full`, `in_match`, `closed`) | 16 | yes |
   | `seed` | integer | | yes |
   | `ai_count` | integer (1-2) | | yes |

   Each lobby document gets `read("users")`, `update("users")` and
   `delete("user:<host>")`, so the guest can claim it
   (`AppwriteSignalling.lobby_permissions()`).
5. **Collection** `skybreak_signals`. Document security **on**. Collection
   permission: `create("users")`.

   | Attribute | Type | Size | Required |
   |---|---|---|---|
   | `lobby` | string | 8 | yes |
   | `from` | string | 36 | yes |
   | `to` | string | 36 | yes |
   | `kind` | string (`offer`, `answer`, `ice`) | 16 | yes |
   | `payload` | string (JSON) | 16384 | yes |

   Key index `skybreak_signals_inbox` on (`lobby`, `to`). Each signal document gets
   `read("user:<to>")`, `read("user:<from>")` and `delete("user:<to>")`
   (`AppwriteSignalling.signal_permissions()`). The receiver deletes it after use.
   Unverified: Appwrite may refuse a client granting roles it does not hold
   (`user:<to>`); if signalling fails with 401 on the first offer, switch these to
   `read("users")` / `delete("users")`.
6. Optional, not created: a scheduled cleanup function `skybreak_cleanup` that
   deletes lobbies and signals older than a day.

Follow-ups: Presence-based signalling (`upsertPresence`, as §12.1 plans), which
removes the polling and adds disconnect detection, plus TURN for networks
where direct P2P fails.

## WebRTC on desktop (developer, Windows PC)

Godot 4.7.2 ships WebRTC only in the **web** export. On desktop,
`WebRTCPeerConnection` is a stub until an extension is loaded. Verified here
on the official 4.7.2 linux build: `initialize()` reports
`_gdvirtual__initialize_call` not implemented. `WebRtcTransport.is_available()`
returns false there, and the lobby says so.

The PC needs the official **godotengine/webrtc-native** GDExtension, release
**1.2.2**:

1. From <https://github.com/godotengine/webrtc-native/releases/tag/1.2.2>, download
   the asset `godot-extension-webrtc_native.zip`.
2. Unzip it and vendor its contents under `addons/webrtc_native/` (developer owns
   `addons/`). The `.gdextension` file there uses relative library paths and
   `compatibility_minimum = 4.3`, so it loads in 4.7.2 as is, with no path edits.
3. Restart the editor. `ClassDB.class_exists("WebRTCLibPeerConnection")` is then
   true, `WebRtcTransport.is_available()` returns true, and exports bundle the
   library.

Tests never need the extension: they run over `LoopbackTransport`.

## Hooking the session into the arena (follow-up)

`DuoLobby.match_started(session)` hands over a running `RollbackSession`. An arena
should:

- build its `FighterView`s from `session.sim.fighters`;
- call `session.advance(keyboard_input)` instead of `sim.tick()` in `_physics_process`;
- stop running the sim itself.

After a rollback, `sim.events` hold only the last re-simulated tick, so feedback
can miss or repeat an event at most once per rollback.
