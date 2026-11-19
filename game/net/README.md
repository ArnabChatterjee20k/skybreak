# game/net: rollback netcode and Duo online (T-D15)

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
| `appwrite_client.gd` | Minimal Appwrite REST client (anonymous sign-in, documents). |
| `appwrite_signalling.gd` | Lobby codes plus offer/answer/ICE exchange as documents, polled every 0.5 s. |
| `duo_match.gd` | Builds the Duo sim, owners and bots the same way on both peers; an instance holds the round-restart rule. |
| `duo_lobby.tscn` | Host/join UI. After connecting it runs the match with a text readout and emits `match_started(session)` for an arena to draw. |

`CombatSim.snapshot()`/`restore()` are in `game/combat/sim_snapshot.gd`. They copy
every script variable by reflection, so new sim fields are covered automatically.
Resources are treated as configuration and shared. RNG state, pickups and
projectiles are copied. Fighters are restored in place, so view references stay valid.

## Appwrite resources to provision

Project `6a113777000db893b12e`, endpoint `https://sgp.cloud.appwrite.io/v1`. The
game uses only this public config: no API key goes in code. Nothing has been
created yet. Add these (only add, never change shared resources):

1. **Auth**: enable **Anonymous** sessions.
2. **Platforms**: add a **Web** platform for the web build's hostname. The desktop
   build sends no `Origin`, so it needs none.
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
   `delete("user:<host>")`, so the guest can claim it.
5. **Collection** `skybreak_signals`. Document security **on**. Collection
   permission: `create("users")`.

   | Attribute | Type | Size | Required |
   |---|---|---|---|
   | `lobby` | string | 8 | yes |
   | `from` | string | 36 | yes |
   | `to` | string | 36 | yes |
   | `kind` | string (`offer`, `answer`, `ice`) | 16 | yes |
   | `payload` | string (JSON) | 16384 | yes |

   Add a key index `skybreak_signals_inbox` on (`lobby`, `to`). Each signal
   document gets `read("user:<to>")`, `read("user:<from>")` and `delete("user:<to>")`.
   The receiver deletes it after use.
6. Optional: a scheduled cleanup function `skybreak_cleanup` that deletes lobbies
   and signals older than a day.

Follow-ups: Presence-based signalling (`upsertPresence`, as §12.1 plans), which
removes the polling and adds disconnect detection, plus TURN for networks
where direct P2P fails.

## WebRTC on desktop (developer, Windows PC)

Godot 4.7.2 ships WebRTC only in the **web** export. On desktop,
`WebRTCPeerConnection` is a stub until an extension is loaded. Verified here
on the official 4.7.2 linux build: `initialize()` reports
`_gdvirtual__initialize_call` not implemented. `WebRtcTransport.is_available()`
returns false there, and the lobby says so.

The PC needs the official **godotengine/webrtc-native** GDExtension:

1. Download the latest release from <https://github.com/godotengine/webrtc-native/releases>.
   Take the `godot-extension-4.1` build (`godot-extension-4.1-webrtc.zip`). The 4.1
   extension API loads in 4.1 and later, including 4.7. I could not open the release
   page from the cloud sandbox (HTTP 403), so check the newest tag there.
2. Unzip it. It holds a `webrtc/` folder with `webrtc.gdextension` and `lib/`
   binaries for Windows, Linux and macOS. Vendor it under `addons/webrtc/`
   (developer owns `addons/`), and update the library paths in
   `webrtc.gdextension` from `res://webrtc/...` to `res://addons/webrtc/...`.
3. Restart the editor. `ClassDB.class_exists("WebRTCLibPeerConnection")` is then
   true, `WebRtcTransport.is_available()` returns true, and exports bundle the DLL.

Tests never need the extension: they run over `LoopbackTransport`.

## Hooking the session into the arena (follow-up)

`DuoLobby.match_started(session)` hands over a running `RollbackSession`. An arena
should:

- build its `FighterView`s from `session.sim.fighters`;
- call `session.advance(keyboard_input)` instead of `sim.tick()` in `_physics_process`;
- stop running the sim itself.

After a rollback, `sim.events` hold only the last re-simulated tick, so feedback
can miss or repeat an event at most once per rollback.
