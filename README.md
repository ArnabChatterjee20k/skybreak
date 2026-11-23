# Skybreak

A full-3D anime arena fighter with free flight, built in Godot 4. Personal,
non-commercial project. Working title.

- Engine: Godot 4.7.2 (Forward+), GDScript
- Tests: GUT, run headless in CI on every PR
- Status and tasks: [`TODO.md`](TODO.md)
- How to contribute (humans and agents): [`AGENTS.md`](AGENTS.md)
- Plan and decisions: [`docs/handoff.md`](docs/handoff.md)

## Run

Open the folder in Godot 4.7.2 and press F5. The grey-box test arena runs with
the debug overlay (F3 toggles it).

## Controls: WASD + mouse (every mode)

One player per laptop (Duo online, vs AI, Pure Fight, training). Left hand on WASD, right hand on
the mouse. On a Mac trackpad, a two-finger click is the right click. No numpad, F-keys or
Ctrl/Cmd/Alt anywhere. The keyboard-only keys in brackets work at the same time.

**Pure Fight** (side-on 1v1, also Pure Fight training and Duo Pure Fight)

| Action | Mouse scheme | Keyboard only |
|---|---|---|
| Walk / jump / crouch | A D / W or Space / S | same |
| Light attack | **Left click** | J |
| Medium attack | Middle click or Q | K |
| Heavy attack | **Right click** | L |
| Throw | F | U |
| Technique key | R | I |
| Finisher key (full meter) | C | O |
| Dash | Left Shift + direction (or tap twice) | same |
| Block | hold back, or E | same |

Techniques: a motion + attack (quarter circles on WASD, then click), or the technique key + a
direction. Training: T (or F4) cycles the dummy. A second player on the same laptop still has the
arrows + `, . / ; ' ] [` and Right Shift (the mouse belongs to P1).

**3D arena** (Play vs AI, Free-for-All, Training, Duo): the mouse also turns the camera (click
the game once to grab the pointer, Esc lets it go).

| Action | Mouse scheme | Keyboard only |
|---|---|---|
| Move / fly up / fly down | W A S D / Space / C (tap C twice: dive to land) | same |
| Light / heavy attack | **Left click / right click** | J / L |
| Lock on / switch target | Middle click or Tab / mouse wheel | Tab |
| Block / dodge-dash / vanish | E / Shift / Shift+E | same |
| Grab / ki blast / charge ki | F / Q / R | U / Q / R |
| Specials / ultimate | 1 2 3 / 4 | 1 (or I) 2 3 / 4 (or O) |
| Transform / breaker | T / X | same |
| Weapons: pick up, throw, next, previous, quick swap | G, V, B, Z, Y | same |

Every 3D action can be rebound in Settings -> Controls, mouse buttons included.

## Test

```sh
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```
