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

## Pure Fight controls (two players, one laptop)

No numpad, F-keys or Ctrl/Cmd/Alt: it works on a Mac laptop in the browser.

| | P1 | P2 |
|---|---|---|
| Move / jump / crouch | A D / W or Space / S | Left Right / Up / Down arrows |
| Light / medium / heavy | J / K / L | , / . / / |
| Throw / technique / finisher | U / I / O | ; / ' / ] |
| Dash | Left Shift + direction (or tap twice) | Right Shift + direction (or tap twice) |
| Block | hold back, or E | hold back, or [ |

Techniques: a motion + attack (quarter circles on WASD or the arrows), or the technique key +
a direction. Training: T (or F4) cycles the dummy.

## Test

```sh
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd
```
